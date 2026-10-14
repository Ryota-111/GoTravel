import Foundation
import CoreData

/// カテゴリ（カレンダー）ごとに友達と共有する（3.0、`docs/設計_3.0.md` 5章）。
///
/// - カテゴリに「共有する」を付けると共有コード（PLAN-）ができる。相手は「共有コードで参加」から入る
/// - そのカテゴリの予定とタグを、メンバー全員で見て書ける。誰が書き換えても全員にとどく
/// - 共有をやめた・抜けたカテゴリは、手元では自分だけのカテゴリとして残る（予定とタグも残る）
///
/// Core Data を直接読み書きする（一覧は `NSFetchedResultsController` が拾う）。
/// **手元をそのまま送らない。** 相手の最新を取ってきて、前回そろえた内容と3つで突き合わせてから送る
@MainActor
final class SharedCategoryService {
    static let shared = SharedCategoryService()

    enum SharingError: LocalizedError {
        case notFound

        var errorDescription: String? {
            "共有コードに一致するカテゴリが見つかりませんでした。コードを確認してください。相手も Travory 3.0 以降が必要です。"
        }
    }

    private var context: NSManagedObjectContext { CoreDataManager.shared.viewContext }
    private var categories: PlanCategoryManager { PlanCategoryManager.shared }
    private var tagManager: PlanTagManager { PlanTagManager.shared }
    /// 同じカテゴリ・予定の同期を重ねない
    private var running: [String: Task<Void, Never>] = [:]

    private init() {}

    /// そのカテゴリを共有しているか
    func isShared(categoryId: String?) -> Bool {
        categories.category(for: categoryId)?.isShared == true
    }

    // MARK: - 共有する・やめる・抜ける

    /// カテゴリを共有する。**公開に成功してから**手元を共有中にする（失敗したコードを相手に送らないため）
    func share(_ category: PlanCategory, userId: String) async throws -> PlanCategory {
        if category.isShared { return category }
        var shared = category
        shared.isShared = true
        shared.shareCode = Plan.generateShareCode()
        shared.ownerId = userId
        shared.sharedWith = [userId]
        let tags = localTags(categoryId: category.id)
        try await CloudKitService.shared.publishSharedCategory(SharedCategoryRecord(category: shared, tags: tags))
        PlanShareBaseStore.saveCategoryTags(tags, categoryId: category.id)
        categories.upsert(shared)

        // このカテゴリの予定を、みんなの予定にする
        for var plan in localPlans(userId: userId) where plan.categoryId == category.id {
            plan.updatedAt = plan.updatedAt ?? Date()
            plan.lastEditedBy = userId
            saveLocal(plan, userId: userId)
            if (try? await CloudKitService.shared.publishSharedPlan(plan)) != nil {
                PlanShareBaseStore.save(plan)
            }
        }
        return shared
    }

    /// 共有をやめる（持ち主）。友達の手元からは更新されなくなる。自分のカテゴリはそのまま残る
    func stopSharing(_ category: PlanCategory, userId: String) {
        unshareLocally(categoryId: category.id)
        Task {
            if let plans = try? await CloudKitService.shared.fetchSharedPlans(categoryId: category.id) {
                for plan in plans { try? await CloudKitService.shared.deleteSharedPlan(planId: plan.id) }
            }
            try? await CloudKitService.shared.deleteSharedCategory(categoryId: category.id)
        }
    }

    /// 抜ける（参加していた人）。ほかの人の予定はそのまま。自分の手元には、それまでの予定が残る
    func leave(_ category: PlanCategory, userId: String) {
        unshareLocally(categoryId: category.id)
        Task {
            guard var record = try? await CloudKitService.shared.fetchSharedCategory(categoryId: category.id) else { return }
            record.sharedWith.removeAll { $0 == userId }
            record.updatedAt = Date()
            try? await CloudKitService.shared.publishSharedCategory(record)
        }
    }

    /// 共有したカテゴリの名前・色を変えたら、みんなにもとどける
    func categoryDidChange(_ category: PlanCategory) {
        guard category.isShared else { return }
        Task { await syncCategoryRecord(categoryId: category.id) }
    }

    /// 共有したカテゴリのタグを足した・直した・消したら、みんなにもとどける
    func categoryTagsDidChange(categoryId: String) {
        guard isShared(categoryId: categoryId) else { return }
        Task { await syncCategoryRecord(categoryId: categoryId) }
    }

    // MARK: - 参加する

    func join(code: String, userId: String) async throws -> PlanCategory {
        guard var record = try await CloudKitService.shared.fetchSharedCategory(byShareCode: code) else {
            throw SharingError.notFound
        }
        if !record.sharedWith.contains(userId) {
            record.sharedWith.append(userId)
            record.updatedAt = Date()
            try await CloudKitService.shared.publishSharedCategory(record)
        }
        let category = record.applied(to: categories.category(for: record.id),
                                      order: (categories.categories.map(\.order).max() ?? -1) + 1)
        categories.upsert(category)
        applyTags(record.tags, categoryId: record.id)
        PlanShareBaseStore.saveCategoryTags(record.tags, categoryId: record.id)
        await syncPlans(categoryId: record.id, userId: userId)
        return category
    }

    // MARK: - 同期

    /// 共有したカテゴリと、その予定・タグを最新にする（一覧を開いたとき・引っぱって更新したとき）
    func syncAll(userId: String) async {
        guard let remotes = try? await CloudKitService.shared.fetchSharedCategories(memberId: userId) else { return }
        var seen = Set<String>()
        for record in remotes where record.sharedWith.contains(userId) || record.ownerId == userId {
            seen.insert(record.id)
            await syncCategoryRecord(categoryId: record.id, fetched: record)
            await syncPlans(categoryId: record.id, userId: userId)
        }

        // 手元では共有中なのに一覧に無いカテゴリ。検索に出るのが遅れることがあるので、直接確かめてから外す
        for category in categories.categories where category.isShared && !seen.contains(category.id) {
            let record = try? await CloudKitService.shared.fetchSharedCategory(categoryId: category.id)
            if let record, record.sharedWith.contains(userId) || record.ownerId == userId { continue }
            // 持ち主が共有をやめた・メンバーから外れた。カテゴリと予定は自分のものとして残す
            unshareLocally(categoryId: category.id)
        }
    }

    /// カテゴリ（名前・色・メンバー・タグ）を、手元・相手・前回の3つで突き合わせる
    private func syncCategoryRecord(categoryId: String, fetched: SharedCategoryRecord? = nil) async {
        await serialized("category:\(categoryId)") {
            guard let local = self.categories.category(for: categoryId) else { return }
            var remote: SharedCategoryRecord
            if let fetched {
                remote = fetched
            } else if let current = try? await CloudKitService.shared.fetchSharedCategory(categoryId: categoryId) {
                remote = current
            } else {
                return
            }

            let base = PlanShareBaseStore.loadCategoryTags(categoryId: categoryId)
            let localTags = self.localTags(categoryId: categoryId)
            let mergedTags = SharedCategoryRecord.mergedTags(local: localTags, remote: remote.tags, base: base)
            self.applyTags(mergedTags, categoryId: categoryId)

            // 名前・色は、相手が持ち主として決めたものを正にする（手元で変えたときは手元を送る）
            var updated = remote
            updated.tags = mergedTags
            let localChangedLook = fetched == nil && (local.name != remote.name || local.colorHex != remote.colorHex)
            if localChangedLook {
                updated.name = local.name
                updated.colorHex = local.colorHex
            }
            if updated != remote {
                updated.updatedAt = Date()
                guard (try? await CloudKitService.shared.publishSharedCategory(updated)) != nil else { return }
            }
            PlanShareBaseStore.saveCategoryTags(mergedTags, categoryId: categoryId)
            let applied = updated.applied(to: local, order: local.order)
            if applied != local { self.categories.upsert(applied) }
        }
    }

    /// 1つのカテゴリの予定をそろえる
    func syncPlans(categoryId: String, userId: String) async {
        await serialized("plans:\(categoryId)") {
            guard let remotes = try? await CloudKitService.shared.fetchSharedPlans(categoryId: categoryId) else { return }
            let locals = self.localPlans(userId: userId).filter { $0.categoryId == categoryId }
            let remoteIds = Set(remotes.map(\.id))

            for remote in remotes {
                await self.reconcile(remote: remote, userId: userId)
            }

            for local in locals where !remoteIds.contains(local.id) {
                if PlanShareBaseStore.load(planId: local.id) == nil {
                    // まだ送っていない（自分が足したばかり）
                    if (try? await CloudKitService.shared.publishSharedPlan(local)) != nil {
                        PlanShareBaseStore.save(local)
                    }
                    continue
                }
                // 前はあったのに一覧に無い。検索に出るのが遅れることもあるので、直接確かめる
                if let direct = try? await CloudKitService.shared.fetchSharedPlan(planId: local.id) {
                    await self.reconcile(remote: direct, userId: userId)
                } else {
                    // 誰かが消した
                    self.deleteLocal(planId: local.id)
                }
            }
        }
    }

    /// 自分が予定を足した・直したあとに呼ぶ。相手の最新と突き合わせてから送る
    func planDidChange(_ plan: Plan, previous: Plan?, userId: String) {
        let wasShared = isShared(categoryId: previous?.categoryId)
        let isNowShared = isShared(categoryId: plan.categoryId)
        let moved = previous != nil && previous?.categoryId != plan.categoryId

        if wasShared && moved && !isNowShared {
            // 共有したカテゴリから出した → みんなの予定からは消える（自分の予定は残る）
            PlanShareBaseStore.remove(planId: plan.id)
            Task { try? await CloudKitService.shared.deleteSharedPlan(planId: plan.id) }
            return
        }
        guard isNowShared else { return }
        Task {
            await serialized("plan:\(plan.id)") {
                if !moved, let remote = try? await CloudKitService.shared.fetchSharedPlan(planId: plan.id) {
                    await self.reconcile(remote: remote, userId: userId)
                } else if let current = self.localPlan(id: plan.id),
                          (try? await CloudKitService.shared.publishSharedPlan(current)) != nil {
                    PlanShareBaseStore.save(current)
                }
            }
        }
    }

    /// 共有したカテゴリの予定を消したとき。みんなの予定からも消える
    func planDidDelete(_ plan: Plan) {
        guard isShared(categoryId: plan.categoryId) else { return }
        PlanShareBaseStore.remove(planId: plan.id)
        Task { try? await CloudKitService.shared.deleteSharedPlan(planId: plan.id) }
    }

    // MARK: - 中身

    /// `PlanShareMerge` が決めたことを行うだけ
    private func reconcile(remote: Plan, userId: String) async {
        // 自分が入っていないカテゴリへ動かされた予定は、手元から消す
        if !isShared(categoryId: remote.categoryId) {
            if localPlan(id: remote.id) != nil { deleteLocal(planId: remote.id) }
            return
        }
        let local = localPlan(id: remote.id)
        let base = PlanShareBaseStore.load(planId: remote.id)
        switch PlanShareMerge.decide(local: local, remote: remote, base: base, myUserId: userId) {
        case .takeRemote(let merged):
            saveLocal(merged, userId: userId, isNew: local == nil)
            PlanShareBaseStore.save(remote)
        case .pushLocal(let plan):
            guard (try? await CloudKitService.shared.publishSharedPlan(plan)) != nil else { return }
            PlanShareBaseStore.save(plan)
        case .takeAndPush(let merged):
            guard (try? await CloudKitService.shared.publishSharedPlan(merged)) != nil else { return }
            saveLocal(merged, userId: userId)
            PlanShareBaseStore.save(merged)
        case .doNothing:
            PlanShareBaseStore.save(remote)
        }
    }

    /// カテゴリのタグを、届いた内容にそろえる（足す・直す・消す）
    private func applyTags(_ tags: [PlanTag], categoryId: String) {
        let incoming = Set(tags.map(\.id))
        for tag in tags {
            var copy = tag
            copy.categoryId = categoryId
            if tagManager.tag(for: tag.id) != copy { tagManager.upsert(copy) }
        }
        for tag in localTags(categoryId: categoryId) where !incoming.contains(tag.id) {
            tagManager.deleteWithoutSharing(tag)
        }
    }

    /// 共有していない状態に戻す。カテゴリ・予定・タグは自分のものとして残す
    private func unshareLocally(categoryId: String) {
        if var category = categories.category(for: categoryId) {
            category.isShared = false
            category.shareCode = nil
            category.ownerId = nil
            category.sharedWith = []
            categories.upsert(category)
        }
        PlanShareBaseStore.removeCategoryTags(categoryId: categoryId)
        for plan in localPlans(userId: categories.userId ?? "") where plan.categoryId == categoryId {
            PlanShareBaseStore.remove(planId: plan.id)
        }
    }

    private func serialized(_ key: String, _ work: @escaping @MainActor () async -> Void) async {
        let previous = running[key]
        let task = Task { @MainActor in
            await previous?.value
            await work()
        }
        running[key] = task
        await task.value
    }

    // MARK: - Core Data

    private func localTags(categoryId: String) -> [PlanTag] {
        tagManager.tags.filter { $0.categoryId == categoryId }
    }

    private func localPlans(userId: String) -> [Plan] {
        ((try? PlanEntity.fetchByUser(userId: userId, context: context)) ?? []).map { $0.toPlan() }
    }

    private func localPlan(id: String) -> Plan? {
        (try? PlanEntity.fetchById(id: id, context: context))?.toPlan()
    }

    private func saveLocal(_ plan: Plan, userId: String, isNew: Bool = false) {
        var copy = plan
        copy.userId = userId
        if let entity = try? PlanEntity.fetchById(id: plan.id, context: context) {
            entity.update(from: copy)
        } else {
            _ = PlanEntity.create(from: copy, context: context)
        }
        CoreDataManager.shared.saveContext()
        // 参加して届いた予定にも、既定の通知を入れる（通知は各自のもの）
        if isNew { NotificationService.shared.schedulePlanNotifications(for: copy) }
    }

    private func deleteLocal(planId: String) {
        NotificationService.shared.cancelPlanNotifications(for: planId)
        PlanShareBaseStore.remove(planId: planId)
        if let entity = try? PlanEntity.fetchById(id: planId, context: context) {
            context.delete(entity)
            CoreDataManager.shared.saveContext()
        }
    }
}
