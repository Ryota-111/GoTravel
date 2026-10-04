import Foundation
import Combine
import UIKit
import CoreData
import os

/// TravelPlan管理用ViewModel（Core Data + CloudKit自動同期版）
final class TravelPlanViewModel: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var travelPlans: [TravelPlan] = []
    @Published var planImages: [String: UIImage] = [:] // planId: image
    @Published var isLoading: Bool = false

    /// 共有計画ごとの同期の様子。画面に出すために持つ。
    /// いままで失敗しても完全に無音で、古いのか最新なのかも分からなかった
    @Published var syncStates: [String: SyncState] = [:]

    enum SyncState: Equatable {
        case syncing
        /// 相手の変更を取り込んだ
        case updated
        /// 確かめたが、変わっていなかった
        case upToDate
        case failed
        /// 共有が解除された、または計画ごと消された
        case unshared
    }

    // MARK: - Private Properties
    private let context: NSManagedObjectContext
    private var fetchedResultsController: NSFetchedResultsController<TravelPlanEntity>?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    override init() {
        self.context = CoreDataManager.shared.viewContext
        super.init()
    }

    // MARK: - Core Data Fetch

    /// 指定ユーザーのTravelPlanを取得（Core Dataから）
    func setupFetchedResultsController(userId: String) {

        let fetchRequest: NSFetchRequest<TravelPlanEntity> = TravelPlanEntity.fetchRequest()

        // ユーザーIDでフィルタリング（自分のプランのみ）
        // 注: sharedWithはBinaryデータなので、NSPredicateで直接フィルタリングできない
        // 共有されたプランは、updateTravelPlans()でメモリ内フィルタリング
        // ゴミ箱に入れたものは一覧に出さない（`recentlyDeleted` が受け持つ）
        fetchRequest.predicate = NSPredicate(
            format: "(userId == %@ OR ownerId == %@) AND deletedAt == nil", userId, userId
        )
        currentUserId = userId

        // 開始日で降順ソート
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]

        fetchedResultsController = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )

        fetchedResultsController?.delegate = self

        do {
            try fetchedResultsController?.performFetch()
            updateTravelPlans()
        } catch {
        }

        // 30日を過ぎたものを片付けてから、ゴミ箱の中身を読む
        purgeExpiredDeletions()
        loadRecentlyDeleted()

        // パブリックDB上の共有プランをローカルに取り込む
        Task {
            await refreshSharedPlans(userId: userId)
        }
    }

    /// FetchedResultsControllerの結果をtravelPlans配列に変換
    private func updateTravelPlans() {
        guard let entities = fetchedResultsController?.fetchedObjects else {
            travelPlans = []
            return
        }

        travelPlans = entities.map { $0.toTravelPlan() }

        // ローカル画像を読み込み
        loadLocalImages()
    }

    /// ローカルファイルシステムから画像を読み込む
    private func loadLocalImages() {
        for plan in travelPlans {
            guard let fileName = plan.localImageFileName,
                  let planId = plan.id else { continue }

            if let image = FileManager.documentsImage(named: fileName) {
                planImages[planId] = image
            }
        }
    }

    // MARK: - CRUD Operations

    /// TravelPlanを追加（Core Dataに保存 → 自動的にCloudKitと同期）
    @MainActor
    func add(_ plan: TravelPlan, userId: String, image: UIImage? = nil) {

        var planToSave = plan
        planToSave.userId = userId

        // 画像をローカルに保存
        if let image = image {
            let fileName = "travel_plan_\(UUID().uuidString).jpg"
            if let imageData = image.storedPhotoData() {
                do {
                    try FileManager.saveImageDataToDocuments(data: imageData, named: fileName)
                    planToSave.localImageFileName = fileName
                } catch {
                }
            }
        }

        // Core Dataに保存
        context.perform {
            _ = TravelPlanEntity.create(from: planToSave, context: self.context)
            CoreDataManager.shared.saveContext()

            // 通知をスケジュール
            DispatchQueue.main.async {
                NotificationService.shared.scheduleTravelPlanNotifications(for: planToSave)
            }
        }
    }

    /// TravelPlanを更新（Core Dataに保存 → 自動的にCloudKitと同期）
    @MainActor
    func update(_ plan: TravelPlan, userId: String, image: UIImage? = nil) {

        guard let planId = plan.id else {
            return
        }

        // **中身が変わったかは、上書きする前に見る。**
        //
        // 更新時刻を保存のたびに進めていたため、画面を開いて閉じただけでも
        // 手元が「新しい」ことになっていた。共有では更新時刻の大小で
        // 取り込みを決めるので、それだけで相手の編集が取り込まれなくなる。
        // しかも手元の古い内容が「新しい」として相手に送られ、上書きしていた。
        let previous = travelPlans.first(where: { $0.id == planId })
        let hasChanges = previous.map { !$0.isContentEqual(to: plan) } ?? true

        var planToSave = plan
        if hasChanges || image != nil {
            planToSave.updatedAt = Date()
            planToSave.lastEditedBy = userId
        }

        // 画像を保存（新しい画像がある場合）
        if let image = image {
            // 古い画像を削除
            if let oldFileName = plan.localImageFileName {
                try? FileManager.removeDocumentFile(named: oldFileName)
            }

            // 新しい画像を保存
            let fileName = "travel_plan_\(UUID().uuidString).jpg"
            if let imageData = image.storedPhotoData() {
                do {
                    try FileManager.saveImageDataToDocuments(data: imageData, named: fileName)
                    planToSave.localImageFileName = fileName
                    // 共有した旅行なら、次に送るときに写真も載せる（全員がこの写真になる）
                    SharedCoverPhoto.markChanged(planId: planId)
                } catch {
                }
            }
        }

        // Core Data保存は非同期なので、ローカル配列を即時更新（楽観的更新）
        // これにより連続追加時に stale な plan を参照するのを防ぐ。
        // **更新時刻を進めたあとの姿を入れる。** 共有の突き合わせはここを
        // 手元として読むので、古い時刻のままだと自分の編集を「古い」と判断する
        if let index = travelPlans.firstIndex(where: { $0.id == planId }) {
            travelPlans[index] = planToSave
        }

        // Core Dataを更新
        context.perform {
            do {
                if let entity = try TravelPlanEntity.fetchById(id: planId, context: self.context) {
                    entity.update(from: planToSave)
                    CoreDataManager.shared.saveContext()

                    // 通知を更新
                    DispatchQueue.main.async {
                        NotificationService.shared.scheduleTravelPlanNotifications(for: planToSave)
                    }
                }
            } catch {
            }
        }

        // 共有中のプランは、相手の最新と突き合わせてから送る。
        // 手元をそのまま送ると、まだ取り込んでいない相手の編集を上書きしてしまう
        if planToSave.isShared && hasChanges {
            scheduleSharedSync(planId: planId, userId: userId)
        }
    }

    /// TravelPlanをゴミ箱に入れる。
    ///
    /// **すぐには消さない。** 30日間は「最近削除した旅行計画」から戻せる（`restore`）。
    /// 写真・アルバムは戻したときのために残し、完全に消すときに片付ける（`deletePermanently`）。
    ///
    /// 共有していた計画は、ここで共有を切る。戻したときは自分だけの計画になる。
    /// 共有コードは作り直してもらう（相手側の扱いは今までの削除と同じ）
    @MainActor
    func delete(_ plan: TravelPlan, userId: String? = nil) {

        guard let planId = plan.id else {
            return
        }

        // 通知をキャンセル（戻したときに入れ直す）
        NotificationService.shared.cancelTravelPlanNotifications(for: planId)

        // 共有の突き合わせに使う覚え書きも片付ける。
        // 残っていても実害は無いが、同じIDで作り直したときに古い基準が効いてしまう
        SharedPlanBaseStore.remove(planId: planId)

        // 戻したときに、自分だけの計画として出るようにしておく
        var detached = plan
        if plan.isShared {
            detached.isShared = false
            detached.shareCode = nil
            detached.sharedWith = []
            detached.ownerId = nil
            // 参加していただけの計画でも、自分のゴミ箱に入るように
            detached.userId = userId ?? plan.userId
        }

        // 一覧からはすぐに消す（Core Data の反映を待つと一瞬残って見える）
        travelPlans.removeAll { $0.id == planId }

        context.perform {
            do {
                if let entity = try TravelPlanEntity.fetchById(id: planId, context: self.context) {
                    if plan.isShared { entity.update(from: detached) }
                    entity.deletedAt = Date()
                    CoreDataManager.shared.saveContext()
                }
            } catch {
            }
            DispatchQueue.main.async { self.loadRecentlyDeleted() }
        }

        // 共有中プランのパブリックDB側の処理
        if plan.isShared {
            if let userId = userId, !plan.isOwner(userId: userId) {
                // メンバーが削除 → 自分をメンバーから外すだけ。
                // **相手の最新から外す。** 手元の計画を土台にすると、
                // まだ取り込んでいない他の人の編集を古い内容で上書きしてしまう
                Task {
                    guard var updated = try? await CloudKitService.shared
                        .fetchSharedTravelPlan(planId: planId) else { return }
                    updated.sharedWith.removeAll { $0 == userId }
                    updated.lastEditedBy = userId
                    updated.updatedAt = Date()
                    try? await CloudKitService.shared.publishSharedTravelPlan(updated)
                }
            } else {
                // オーナーが削除 → 共有レコード自体を削除
                Task {
                    try? await CloudKitService.shared.deleteSharedTravelPlan(planId: planId)
                }
            }
        }
    }

    // MARK: - ゴミ箱（最近削除した旅行計画）

    /// ゴミ箱に入れてから、完全に消すまでの日数
    static let trashRetentionDays = 30

    struct DeletedTravelPlan: Identifiable {
        let plan: TravelPlan
        let deletedAt: Date

        var id: String { plan.id ?? UUID().uuidString }

        /// 完全に消えるまでの残り日数（0なら今日中）
        var daysUntilPurge: Int {
            let purgeDate = Calendar.current.date(
                byAdding: .day, value: TravelPlanViewModel.trashRetentionDays, to: deletedAt
            ) ?? deletedAt
            let days = Calendar.current.dateComponents([.day], from: Date(), to: purgeDate).day ?? 0
            return max(0, days)
        }
    }

    /// ゴミ箱の中身。新しく消したものが先
    @Published var recentlyDeleted: [DeletedTravelPlan] = []

    private var currentUserId: String?

    private func loadRecentlyDeleted() {
        guard let userId = currentUserId else {
            recentlyDeleted = []
            return
        }
        let request = TravelPlanEntity.fetchRequest()
        request.predicate = NSPredicate(
            format: "(userId == %@ OR ownerId == %@) AND deletedAt != nil", userId, userId
        )
        request.sortDescriptors = [NSSortDescriptor(key: "deletedAt", ascending: false)]

        let entities = (try? context.fetch(request)) ?? []
        recentlyDeleted = entities.compactMap { entity in
            guard let deletedAt = entity.deletedAt else { return nil }
            return DeletedTravelPlan(plan: entity.toTravelPlan(), deletedAt: deletedAt)
        }
    }

    /// ゴミ箱から戻す
    @MainActor
    func restore(planId: String) {
        context.perform {
            guard let entity = try? TravelPlanEntity.fetchById(id: planId, context: self.context) else { return }
            entity.deletedAt = nil
            CoreDataManager.shared.saveContext()
            let plan = entity.toTravelPlan()
            DispatchQueue.main.async {
                NotificationService.shared.scheduleTravelPlanNotifications(for: plan)
                self.loadRecentlyDeleted()
            }
        }
    }

    /// ゴミ箱から完全に消す。写真とアルバムもここで片付ける
    @MainActor
    func deletePermanently(planId: String) {
        context.perform {
            if let entity = try? TravelPlanEntity.fetchById(id: planId, context: self.context) {
                self.removeForever(entity)
                CoreDataManager.shared.saveContext()
            }
            DispatchQueue.main.async { self.loadRecentlyDeleted() }
        }
    }

    /// ゴミ箱を空にする
    @MainActor
    func emptyTrash() {
        let ids = recentlyDeleted.map(\.id)
        context.perform {
            for id in ids {
                if let entity = try? TravelPlanEntity.fetchById(id: id, context: self.context) {
                    self.removeForever(entity)
                }
            }
            CoreDataManager.shared.saveContext()
            DispatchQueue.main.async { self.loadRecentlyDeleted() }
        }
    }

    /// 30日を過ぎたものを完全に消す。起動して一覧を読むたびに呼ぶ
    private func purgeExpiredDeletions() {
        guard let threshold = Calendar.current.date(
            byAdding: .day, value: -Self.trashRetentionDays, to: Date()
        ) else { return }

        let request = TravelPlanEntity.fetchRequest()
        request.predicate = NSPredicate(format: "deletedAt != nil AND deletedAt < %@", threshold as NSDate)

        context.perform {
            let expired = (try? self.context.fetch(request)) ?? []
            guard !expired.isEmpty else { return }
            expired.forEach(self.removeForever)
            CoreDataManager.shared.saveContext()
            DispatchQueue.main.async { self.loadRecentlyDeleted() }
        }
    }

    /// 写真・アルバムごと消す。context.perform の中から呼ぶこと
    private func removeForever(_ entity: TravelPlanEntity) {
        if let fileName = entity.localImageFileName {
            try? FileManager.removeDocumentFile(named: fileName)
        }
        if let planId = entity.id {
            // この旅行に紐づくアルバムも一緒に片付ける（travelPlanIdが宙に浮くのを防ぐ）
            DispatchQueue.main.async {
                AlbumManager.shared.deleteAlbums(forTravelPlanId: planId)
                self.planImages[planId] = nil
            }
        }
        context.delete(entity)
    }

    // MARK: - Image Loading

    /// 特定のTravelPlanの画像を取得（ローカルファイルから）
    func loadImage(for planId: String) async -> UIImage? {
        // キャッシュをチェック
        if let cached = planImages[planId] {
            return cached
        }

        // プランを検索して画像ファイル名を取得
        guard let plan = travelPlans.first(where: { $0.id == planId }),
              let fileName = plan.localImageFileName else {
            return nil
        }

        // ローカルファイルから読み込み
        if let image = FileManager.documentsImage(named: fileName) {
            await MainActor.run {
                self.planImages[planId] = image
            }
            return image
        }

        return nil
    }

    // MARK: - Sharing Methods
    //
    // 共同編集はCloudKitのパブリックDBを介して行う。
    // Core Data（プライベートDB同期）は他のApple IDから参照できないため、
    // 共有プランは publishSharedTravelPlan / fetchSharedTravelPlans で
    // パブリックDBと双方向に同期する。

    /// 共有停止時に飛ばした削除のうち、まだ完了していないもの。
    ///
    /// 削除は投げっぱなしのTaskなので、直後に共有を作り直すと
    /// 新レコードの公開と旧レコードの削除が同じレコードID
    /// （shared_<planId>）に対して並走する。削除が後から着弾すると
    /// **発行したばかりのコードのレコードが消える**ため、
    /// 公開の前に必ずここを待つ
    private var pendingShareDeletions: [String: Task<Void, Never>] = [:]

    /// 共有コードを設定してプランをパブリックDBに公開
    ///
    /// 公開に**成功してから**ローカルを共有状態にする。
    /// 以前は公開を投げっぱなしにしていたため、失敗しても画面にはコードが表示され、
    /// 「公開されていないコード」を相手に送れてしまっていた
    /// （参加側には「共有コードに一致する旅行計画が見つかりませんでした」と出る）。
    @MainActor
    func updateShareCode(planId: String, shareCode: String, userId: String) async throws {
        // 直前の共有停止の削除がまだ残っていれば、先に完了させる
        if let pendingDeletion = pendingShareDeletions.removeValue(forKey: planId) {
            await pendingDeletion.value
        }

        guard var plan = travelPlans.first(where: { $0.id == planId }) else {
            Logger(subsystem: "com.gmail.taismryotasis.Travory", category: "sharing")
                .error("共有コード設定中止: 手元にプランが見つからない planId=\(planId, privacy: .public)")
            throw APIClientError.notFound
        }

        Logger(subsystem: "com.gmail.taismryotasis.Travory", category: "sharing")
            .notice("共有コード設定 planId=\(planId, privacy: .public) code=\(shareCode, privacy: .public)")

        plan.isShared = true
        plan.shareCode = shareCode
        plan.ownerId = plan.ownerId ?? plan.userId ?? userId

        // オーナー自身もメンバーに含める（共有メンバー一覧に表示される）
        if let ownerId = plan.ownerId, !plan.sharedWith.contains(ownerId) {
            plan.sharedWith.append(ownerId)
        }

        plan.lastEditedBy = userId
        plan.updatedAt = Date()

        // 先にパブリックDBへ公開する。失敗したらローカルは共有状態にしない
        try await CloudKitService.shared.publishSharedTravelPlan(plan)
        writeDefaultMemberName(planId: planId, userId: userId)

        // update() 内の再公開は保存済みレコードへの上書きになるだけなので無害
        update(plan, userId: userId)
    }

    /// 共有を停止（オーナー用）: 共有コードを無効化してパブリックDBのレコードを削除
    @MainActor
    func stopSharing(planId: String, userId: String) {
        guard var plan = travelPlans.first(where: { $0.id == planId }) else { return }

        plan.isShared = false
        plan.shareCode = nil
        plan.sharedWith = []
        plan.lastEditedBy = userId
        plan.updatedAt = Date()

        // isShared = false なので update() からパブリックDBへは公開されない
        update(plan, userId: userId)

        // 突き合わせの覚え書きを捨てる。
        // 共有を作り直したときに、前の共有のときの基準が効いてしまうのを防ぐ
        SharedPlanBaseStore.remove(planId: planId)

        // 削除は待たずに返すが、再発行時に順序を保証できるよう覚えておく
        pendingShareDeletions[planId] = Task {
            try? await CloudKitService.shared.deleteSharedTravelPlan(planId: planId)
        }
    }

    /// 写し間違いの救済候補。O↔0・I↔1 は見た目が紛らわしく、
    /// 手入力や口頭伝達で混同されるため、見つからない場合は置換した候補でも検索する
    private func shareCodeCandidates(for code: String) -> [String] {
        var candidates = [code]
        let toDigits = code
            .replacingOccurrences(of: "O", with: "0")
            .replacingOccurrences(of: "I", with: "1")
        let toLetters = code
            .replacingOccurrences(of: "0", with: "O")
            .replacingOccurrences(of: "1", with: "I")
        for candidate in [toDigits, toLetters] where !candidates.contains(candidate) {
            candidates.append(candidate)
        }
        return candidates
    }

    /// 共有コードでプランに参加（パブリックDBを検索）
    func joinPlanByShareCode(_ shareCode: String, userId: String, completion: @escaping (Result<TravelPlan, Error>) -> Void) {
        Task {
            do {
                var foundPlan: TravelPlan?
                for candidate in shareCodeCandidates(for: shareCode) {
                    if let plan = try await CloudKitService.shared.fetchSharedTravelPlan(byShareCode: candidate) {
                        foundPlan = plan
                        break
                    }
                }

                guard var plan = foundPlan else {
                    await MainActor.run {
                        completion(.failure(APIClientError.notFound))
                    }
                    return
                }

                // 現在のユーザーをsharedWith配列に追加してパブリックDBへ反映
                if !plan.sharedWith.contains(userId) {
                    plan.sharedWith.append(userId)
                    plan.lastEditedBy = userId
                    plan.updatedAt = Date()
                    try await CloudKitService.shared.publishSharedTravelPlan(plan)
                }

                // 自分のローカルストアにコピーを保存（一覧に表示される）。
                // 参加した直後なので手元には無い。マージの入口を通して
                // userId の付け替えを一箇所に寄せる
                let adopted = SharedPlanMerge
                    .decide(local: nil, remote: plan, myUserId: userId)
                    .takenPlan ?? plan
                try await self.saveSharedPlanLocally(adopted)
                SharedPlanBaseStore.save(plan)
                if let planId = plan.id {
                    await MainActor.run {
                        self.storeMemberNames(plan.memberNames, planId: planId)
                        self.writeDefaultMemberName(planId: planId, userId: userId)
                    }
                }

                await MainActor.run {
                    completion(.success(plan))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }

    /// 1件の共有計画をそろえる。
    ///
    /// 旅行計画の画面から更新を押したときに使う。
    /// 全件を取りに行く `refreshSharedPlans` と違い、開いている計画だけを見る
    @MainActor
    func refreshSharedPlan(planId: String, userId: String) async {
        await runSerialized(planId: planId) {
            // 始まった時点で「待ち」ではなくなる。ここから先の編集は次の回で送る
            self.queuedSharedSyncs.remove(planId)
            await self.syncSharedPlan(planId: planId, userId: userId)
        }
    }

    @MainActor
    private func syncSharedPlan(planId: String, userId: String) async {
        syncStates[planId] = .syncing
        do {
            guard let remote = try await CloudKitService.shared
                .fetchSharedTravelPlan(planId: planId) else {
                // 共有が解除された、または相手が計画ごと消した
                syncStates[planId] = .unshared
                return
            }

            let tookRemote = try await reconcile(remote: remote, userId: userId)
            SharedPlanBaseStore.markSynced(planId: planId)
            lastSharedSyncAt[planId] = Date()
            syncStates[planId] = tookRemote ? .updated : .upToDate

        } catch {
            CloudKitService.shareLogger.error("""
                1件の同期に失敗 planId=\(planId, privacy: .public) \
                error=\(String(describing: error), privacy: .public)
                """)
            syncStates[planId] = .failed
        }
    }

    // MARK: - 共有メンバーの表示名

    /// 計画ごとの、メンバーの表示名（ユーザーID → 名前）
    @MainActor @Published private(set) var memberNamesByPlan: [String: [String: String]] = [:]

    @MainActor
    func memberNames(for planId: String?) -> [String: String] {
        guard let planId else { return [:] }
        return memberNamesByPlan[planId] ?? SharedMemberNameStore.names(planId: planId)
    }

    @MainActor
    private func storeMemberNames(_ names: [String: String], planId: String) {
        guard !names.isEmpty else { return }
        SharedMemberNameStore.save(names, planId: planId)
        memberNamesByPlan[planId] = names
    }

    /// まだ名前を付けていなければ、プロフィールの名前を書く。
    /// プロフィールに名前が無ければ何もしない（画面では「メンバー2」のように出る）
    @MainActor
    private func writeDefaultMemberName(planId: String, userId: String) {
        guard let name = SharedMemberNameStore.profileName(userId: userId) else { return }
        Task { try? await self.setMyMemberName(name, planId: planId, userId: userId) }
    }

    /// この旅行での自分の呼び方を変える（「父」「さくら」など）。空にするとプロフィールの名前に戻す
    @MainActor
    func setMyMemberName(_ name: String, planId: String, userId: String) async throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = trimmed.isEmpty ? (SharedMemberNameStore.profileName(userId: userId) ?? "") : trimmed
        let names = try await CloudKitService.shared.updateMemberName(planId: planId, userId: userId, name: value)
        storeMemberNames(names, planId: planId)
    }

    // MARK: - 共有の同期を1件ずつ順に流す

    /// 計画ごとに、いま走っている（または最後に積んだ）同期
    @MainActor private var sharedSyncTasks: [String: Task<Void, Never>] = [:]
    /// 積んだがまだ始まっていない同期。持ち物を続けてチェックしたときなどに、
    /// 同じ計画の同期を何本も積まないためのもの
    @MainActor private var queuedSharedSyncs: Set<String> = []
    /// 計画ごとに、最後に1件の同期を終えた時刻
    @MainActor private var lastSharedSyncAt: [String: Date] = [:]

    /// 編集を保存したあと、相手の最新と突き合わせて送る。
    ///
    /// **手元をそのまま送らない。** まだ取り込んでいない相手の編集があると、
    /// 古い内容で上書きしてしまう（2.6 で報告された「最初の内容のまま」の原因）。
    @MainActor
    private func scheduleSharedSync(planId: String, userId: String) {
        // まだ始まっていない同期があれば、それが今の手元を拾うので足さなくてよい
        guard !queuedSharedSyncs.contains(planId) else { return }
        queuedSharedSyncs.insert(planId)
        Task { await refreshSharedPlan(planId: planId, userId: userId) }
    }

    /// 同じ計画の同期を、前のものが終わってから始める。
    ///
    /// 並んで走ると、片方が「前回そろえた内容」を書き換えた直後に
    /// もう片方が古い前提で突き合わせ、相手の予定を「消された」と取り違える
    @MainActor
    private func runSerialized(planId: String, _ work: @escaping @MainActor () async -> Void) async {
        let previous = sharedSyncTasks[planId]
        let task = Task { @MainActor in
            await previous?.value
            await work()
        }
        sharedSyncTasks[planId] = task
        await task.value
    }

    /// 相手の内容と手元を突き合わせ、共有のヘッダー写真も取り込む。戻り値は取り込んだかどうか
    @MainActor
    @discardableResult
    private func reconcile(remote: TravelPlan, userId: String) async throws -> Bool {
        let tookRemote = try await reconcileContent(remote: remote, userId: userId)
        await adoptSharedCover(from: remote)
        return tookRemote
    }

    /// 共有レコードのヘッダー写真を、ルールに沿ってこの端末の写真にする（`SharedCoverPhoto`）
    @MainActor
    private func adoptSharedCover(from remote: TravelPlan) async {
        guard let planId = remote.id,
              let version = remote.sharedCoverVersion,
              let local = travelPlans.first(where: { $0.id == planId }) else { return }

        switch SharedCoverPhoto.adoption(remoteVersion: version,
                                         adoptedVersion: SharedCoverPhoto.adoptedVersion(planId: planId),
                                         hasLocalPhoto: SharedCoverPhoto.hasLocalPhoto(local),
                                         changedLocally: SharedCoverPhoto.isChanged(planId: planId)) {
        case .none:
            return
        case .keepOwn:
            SharedCoverPhoto.setAdopted(version, planId: planId)
        case .adopt:
            guard let url = remote.sharedCoverFileURL, let data = try? Data(contentsOf: url) else { return }
            let fileName = "travel_plan_\(UUID().uuidString).jpg"
            do {
                try FileManager.saveImageDataToDocuments(data: data, named: fileName)
                var updated = local
                let oldFileName = updated.localImageFileName
                updated.localImageFileName = fileName
                // 写真のファイル名は端末の中の話なので、送り返さずに手元だけ書き換える
                try await saveSharedPlanLocally(updated)
                if let oldFileName { try? FileManager.removeDocumentFile(named: oldFileName) }
                // カードと詳細の写真はここから読むので、すぐ差し替える
                planImages[planId] = UIImage(data: data)
                SharedCoverPhoto.setAdopted(version, planId: planId)
                CloudKitService.shareLogger.notice("ヘッダー写真を取り込み planId=\(planId, privacy: .public)")
            } catch {
                try? FileManager.removeDocumentFile(named: fileName)
            }
        }
    }

    /// 相手の内容と手元を突き合わせる。戻り値は取り込んだかどうか
    @MainActor
    @discardableResult
    private func reconcileContent(remote: TravelPlan, userId: String) async throws -> Bool {
        guard let planId = remote.id else { return false }

        // 名前は共有レコードが正。取り込むたびに控えへ写し、自分の名前が無ければ書く
        storeMemberNames(remote.memberNames, planId: planId)
        if remote.memberNames[userId] == nil {
            writeDefaultMemberName(planId: planId, userId: userId)
        }

        let local = travelPlans.first(where: { $0.id == planId })

        // どうするかは `SharedPlanMerge` が決める。
        // ここは決まったことを実行するだけにしておくと、
        // 判断の正しさをテストで確かめられる（実機2台が要らない）。
        // 前回そろえたときの内容が無いと「自分が足した」と
        // 「相手が消した」を区別できない
        let base = SharedPlanBaseStore.load(planId: planId)

        /// 通信している間に手元が編集されていないか。
        /// 編集されていたら、ここで作った結果で上書きするとその編集が消える。
        /// 保存も「前回」の更新もせず、積まれている次の同期に任せる
        func localIsUnchanged() -> Bool {
            travelPlans.first(where: { $0.id == planId })?.updatedAt == local?.updatedAt
        }

        switch SharedPlanMerge.decide(local: local,
                                      remote: remote,
                                      base: base,
                                      myUserId: userId) {
        case .takeRemote(let merged):
            guard localIsUnchanged() else { return false }
            try await saveSharedPlanLocally(merged)
            // **覚えるのは受け取った姿そのまま。** マージ後の姿を覚えると、
            // 次回に自分が足したぶんを相手のものと取り違える
            SharedPlanBaseStore.save(remote)
            CloudKitService.shareLogger.notice(
                "取り込み planId=\(planId, privacy: .public)")
            return true

        case .pushLocal(let plan):
            // 送れなかったときは「前回」を進めない。次の同期で同じ差分をもう一度送る
            try await CloudKitService.shared.publishSharedTravelPlan(plan)
            // 送ったぶんは相手も持っている状態になる
            SharedPlanBaseStore.save(plan)
            CloudKitService.shareLogger.notice(
                "手元の変更を送信 planId=\(planId, privacy: .public)")
            return false

        case .takeAndPush(let merged):
            try await CloudKitService.shared.publishSharedTravelPlan(merged)
            guard localIsUnchanged() else { return false }
            try await saveSharedPlanLocally(merged)
            SharedPlanBaseStore.save(merged)
            CloudKitService.shareLogger.notice(
                "取り込んで送り返し planId=\(planId, privacy: .public)")
            return true

        case .doNothing:
            // 同じ内容でそろっているので、これを基準にできる
            SharedPlanBaseStore.save(remote)
            CloudKitService.shareLogger.notice(
                "変更なし planId=\(planId, privacy: .public)")
            return false
        }
    }

    /// パブリックDBから共有プランの最新状態を取得してローカルにマージ
    func refreshSharedPlans(userId: String) async {
        let startedAt = Date()
        do {
            let remotePlans = try await CloudKitService.shared.fetchSharedTravelPlans(memberId: userId)

            for remote in remotePlans {
                guard let planId = remote.id else { continue }
                await runSerialized(planId: planId) {
                    // 一覧を取ってから順番が回ってくるまでに、この計画だけの同期が
                    // 済んでいれば、手元の remote はもう古い。取り直す
                    if let last = self.lastSharedSyncAt[planId], last > startedAt {
                        await self.syncSharedPlan(planId: planId, userId: userId)
                        return
                    }
                    do {
                        try await self.reconcile(remote: remote, userId: userId)
                        SharedPlanBaseStore.markSynced(planId: planId)
                    } catch {
                        CloudKitService.shareLogger.error("""
                            共有の同期に失敗 planId=\(planId, privacy: .public) \
                            error=\(String(describing: error), privacy: .public)
                            """)
                    }
                }
            }
        } catch {
            // オフライン時などは次回のrefreshで再同期される。
            // 黙って諦めると「引っぱっても何も起きない」の原因が追えない
            CloudKitService.shareLogger.error(
                "共有の同期に失敗 error=\(String(describing: error), privacy: .public)")
        }
    }

    /// 共有プランをローカルのCore Dataに保存（新規 or 上書き）。
    ///
    /// **渡ってくる時点でマージは済んでいる**（`SharedPlanMerge.decide`）。
    /// ここは保存だけを担当する
    private func saveSharedPlanLocally(_ plan: TravelPlan) async throws {
        let localPlan = plan

        // 一覧への反映（NSFetchedResultsController 経由）を待たずに手元を差し替える。
        // 次の同期がこの配列を手元として読むので、古いままだと
        // 取り込んだばかりの相手の予定を「自分が消した」と取り違える
        await MainActor.run {
            if let index = self.travelPlans.firstIndex(where: { $0.id == localPlan.id }) {
                self.travelPlans[index] = localPlan
            }
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            context.perform {
                do {
                    if let planId = localPlan.id,
                       let entity = try TravelPlanEntity.fetchById(id: planId, context: self.context) {
                        entity.update(from: localPlan)
                    } else {
                        _ = TravelPlanEntity.create(from: localPlan, context: self.context)
                    }
                    CoreDataManager.shared.saveContext()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// MARK: - NSFetchedResultsControllerDelegate

extension TravelPlanViewModel: NSFetchedResultsControllerDelegate {
    /// Core Dataの変更を検知してUIを自動更新
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        DispatchQueue.main.async {
            self.updateTravelPlans()
            // 別の端末でゴミ箱に入れた・戻したものも、ここで拾う
            self.loadRecentlyDeleted()
        }
    }
}
