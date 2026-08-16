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
        fetchRequest.predicate = NSPredicate(format: "userId == %@ OR ownerId == %@", userId, userId)

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
            if let imageData = image.jpegData(compressionQuality: 0.7) {
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

        // Core Data保存は非同期なので、ローカル配列を即時更新（楽観的更新）
        // これにより連続追加時に stale な plan を参照するのを防ぐ
        if let index = travelPlans.firstIndex(where: { $0.id == planId }) {
            travelPlans[index] = plan
        }

        var planToSave = plan
        planToSave.updatedAt = Date()

        // 画像を保存（新しい画像がある場合）
        if let image = image {
            // 古い画像を削除
            if let oldFileName = plan.localImageFileName {
                try? FileManager.removeDocumentFile(named: oldFileName)
            }

            // 新しい画像を保存
            let fileName = "travel_plan_\(UUID().uuidString).jpg"
            if let imageData = image.jpegData(compressionQuality: 0.7) {
                do {
                    try FileManager.saveImageDataToDocuments(data: imageData, named: fileName)
                    planToSave.localImageFileName = fileName
                } catch {
                }
            }
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

        // 共有中のプランは他メンバーにも見えるようパブリックDBへ反映
        var sharedPlan = planToSave
        sharedPlan.lastEditedBy = userId
        publishSharedPlanIfNeeded(sharedPlan)
    }

    /// TravelPlanを削除（Core Dataから削除 → 自動的にCloudKitと同期）
    @MainActor
    func delete(_ plan: TravelPlan, userId: String? = nil) {

        guard let planId = plan.id else {
            return
        }

        // 通知をキャンセル
        NotificationService.shared.cancelTravelPlanNotifications(for: planId)

        // ローカル画像を削除
        if let fileName = plan.localImageFileName {
            try? FileManager.removeDocumentFile(named: fileName)
        }

        // この旅行に紐づくアルバムも一緒に片付ける（travelPlanIdが宙に浮くのを防ぐ）
        AlbumManager.shared.deleteAlbums(forTravelPlanId: planId)

        // Core Dataから削除
        context.perform {
            do {
                if let entity = try TravelPlanEntity.fetchById(id: planId, context: self.context) {
                    self.context.delete(entity)
                    CoreDataManager.shared.saveContext()
                }
            } catch {
            }
        }

        // 共有中プランのパブリックDB側の処理
        if plan.isShared {
            if let userId = userId, !plan.isOwner(userId: userId) {
                // メンバーが削除 → 自分をメンバーから外すだけ
                var updated = plan
                updated.sharedWith.removeAll { $0 == userId }
                updated.lastEditedBy = userId
                updated.updatedAt = Date()
                Task {
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

                // 自分のローカルストアにコピーを保存（一覧に表示される）
                try await self.saveSharedPlanLocally(plan, currentUserId: userId)

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

    /// パブリックDBから共有プランの最新状態を取得してローカルにマージ
    func refreshSharedPlans(userId: String) async {
        do {
            let remotePlans = try await CloudKitService.shared.fetchSharedTravelPlans(memberId: userId)

            for remote in remotePlans {
                guard let planId = remote.id else { continue }

                let local = await MainActor.run {
                    self.travelPlans.first(where: { $0.id == planId })
                }

                if let local = local {
                    if remote.updatedAt > local.updatedAt {
                        // リモートの方が新しい → ローカルへ取り込み
                        try await saveSharedPlanLocally(remote, currentUserId: userId)
                    } else if local.updatedAt > remote.updatedAt {
                        // ローカルの方が新しい（オフライン編集など） → パブリックDBへ反映
                        try? await CloudKitService.shared.publishSharedTravelPlan(local)
                    }
                } else {
                    // まだローカルにない共有プラン → 取り込み
                    try await saveSharedPlanLocally(remote, currentUserId: userId)
                }
            }
        } catch {
            // オフライン時などは次回のrefreshで再同期される
        }
    }

    /// 共有プランをローカルのCore Dataに保存（新規 or 上書き）
    private func saveSharedPlanLocally(_ plan: TravelPlan, currentUserId: String) async throws {
        // ローカルストアの行は常に端末ユーザーのuserIdで保持する
        // （FetchedResultsControllerのpredicateにマッチさせるため。
        //   本来のオーナーはownerIdが保持している）
        var localPlan = plan
        localPlan.userId = currentUserId

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

    /// 共有プランの変更をパブリックDBへ非同期に反映
    private func publishSharedPlanIfNeeded(_ plan: TravelPlan) {
        guard plan.isShared else { return }
        Task {
            try? await CloudKitService.shared.publishSharedTravelPlan(plan)
        }
    }
}

// MARK: - NSFetchedResultsControllerDelegate

extension TravelPlanViewModel: NSFetchedResultsControllerDelegate {
    /// Core Dataの変更を検知してUIを自動更新
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        DispatchQueue.main.async {
            self.updateTravelPlans()
        }
    }
}
