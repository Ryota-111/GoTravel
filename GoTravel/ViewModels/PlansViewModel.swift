import Foundation
import Combine
import CoreData

/// Plan管理用ViewModel（Core Data + CloudKit自動同期版）
final class PlansViewModel: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var plans: [Plan] = []
    @Published var isLoading: Bool = false

    // MARK: - Private Properties
    let context: NSManagedObjectContext
    private var fetchedResultsController: NSFetchedResultsController<PlanEntity>?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    override init() {
        self.context = CoreDataManager.shared.viewContext
        super.init()
    }

    // MARK: - Core Data Fetch

    /// 指定ユーザーのPlanを取得（Core Dataから）
    func setupFetchedResultsController(userId: String) {

        let fetchRequest: NSFetchRequest<PlanEntity> = PlanEntity.fetchRequest()

        // ユーザーIDでフィルタリング
        fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)

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
            updatePlans()
        } catch {
        }
    }

    /// FetchedResultsControllerの結果をplans配列に変換
    private func updatePlans() {
        guard let entities = fetchedResultsController?.fetchedObjects else {
            plans = []
            return
        }

        plans = entities.map { $0.toPlan() }

        let current = plans
        Task { @MainActor in
            generateNextOccurrencesIfNeeded()
            // カレンダーに入れてある予定は、カレンダーの予定も直す（`CalendarExportService`）
            CalendarExportService.shared.scheduleSync(plans: current)
        }
    }

    // MARK: - 繰り返し

    /// 日付が過ぎた繰り返しの予定について、次回分を1件だけ作る。
    ///
    /// 以前は「完了にする」を押したときに作っていたが、そのボタンをやめたため
    /// 日付が過ぎたことを合図にする。未来の分をまとめて作らないのは、
    /// 1件だけ直したいときにどれを直せばいいのか分からなくなるため。
    ///
    /// 作り終えた回には `isCompleted` を立てて、二度作らない印にしている
    @MainActor
    private func generateNextOccurrencesIfNeeded() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let due = plans.filter { plan in
            // 共有したカテゴリの予定の次の回は、カテゴリの持ち主の端末だけが作る（メンバーごとに作ると人数分に増える）
            if let category = PlanCategoryManager.shared.category(for: plan.categoryId), category.isShared,
               category.ownerId != plan.userId { return false }
            return plan.recurrence != .none
                && !plan.isCompleted
                && calendar.startOfDay(for: plan.endDate) < today
        }

        guard !due.isEmpty else { return }

        for plan in due {
            guard let userId = plan.userId,
                  let nextStart = plan.recurrence.nextDate(after: plan.startDate) else { continue }

            // 同じ予定が既にあるなら作らない（別の端末で作られている場合）
            let exists = plans.contains { other in
                other.id != plan.id
                    && other.title == plan.title
                    && calendar.isDate(other.startDate, inSameDayAs: nextStart)
            }

            var handled = plan
            handled.isCompleted = true
            update(handled, userId: userId)

            guard !exists else { continue }

            let span = calendar.dayDifference(from: plan.startDate, to: plan.endDate)
            var next = plan
            next.id = UUID().uuidString
            next.isCompleted = false
            // 次の回も同じカテゴリに入る（共有したカテゴリでは持ち主の端末だけが作る。メンバーは届いたものを受け取る）
            next.lastEditedBy = nil
            next.updatedAt = nil
            next.createdAt = Date()
            next.startDate = nextStart
            next.endDate = calendar.date(byAdding: .day, value: span, to: nextStart) ?? nextStart
            next.scheduleItems = plan.scheduleItems.map { item in
                var copy = item
                copy.id = UUID().uuidString
                return copy
            }

            add(next, userId: userId)

            // 繰り返しは1回ずつ別の予定として作るので、カレンダーにも次の回を入れる
            if CalendarExportService.shared.isLinked(CalendarExportService.key(planId: plan.id)) {
                try? CalendarExportService.shared.export(next)
            }
        }
    }

    // MARK: - CRUD Operations

    /// Planを追加（Core Dataに保存 → 自動的にCloudKitと同期）
    @MainActor
    func add(_ plan: Plan, userId: String) {

        var planToSave = plan
        planToSave.userId = userId
        // 共有したカテゴリに作ったら、みんなの予定にする（`SharedCategoryService`）
        planToSave.tagIDs = Self.tagIDs(planToSave.tagIDs, inCategory: planToSave.categoryId)
        if SharedCategoryService.shared.isShared(categoryId: planToSave.categoryId) {
            planToSave.updatedAt = Date()
            planToSave.lastEditedBy = userId
        }

        // Core Dataに保存
        context.perform {
            _ = PlanEntity.create(from: planToSave, context: self.context)
            CoreDataManager.shared.saveContext()

            // 通知をスケジュール
            DispatchQueue.main.async {
                NotificationService.shared.schedulePlanNotifications(for: planToSave)
                SharedCategoryService.shared.planDidChange(planToSave, previous: nil, userId: userId)
            }
        }
    }

    /// Planを更新（Core Dataに保存 → 自動的にCloudKitと同期）
    @MainActor
    func update(_ plan: Plan, userId: String) {

        var planToSave = plan
        planToSave.userId = userId

        // 共有している予定は、みんなで持つ部分が変わったときだけ時刻を進めて送る。
        // 済みの印やタグ（自分だけの項目）を変えただけで「新しい」ことにすると、相手の編集を取り込めなくなる
        let previous = plans.first { $0.id == plan.id }
        // 更新時刻は共有の処理だけが進める。予定の画面は開いたときの写しを持っているので、そのまま使わない
        if let previous {
            planToSave.updatedAt = previous.updatedAt
            planToSave.lastEditedBy = previous.lastEditedBy
        }
        // タグはカテゴリのものだけ。カテゴリを変えたら、前のカテゴリのタグは外す
        planToSave.tagIDs = Self.tagIDs(planToSave.tagIDs, inCategory: planToSave.categoryId)
        let isShared = SharedCategoryService.shared.isShared(categoryId: planToSave.categoryId)
        let sharedChanged = previous.map { !$0.isSharedContentEqual(to: planToSave) } ?? true
        if isShared && sharedChanged {
            planToSave.updatedAt = Date()
            planToSave.lastEditedBy = userId
        }
        if let index = plans.firstIndex(where: { $0.id == plan.id }) {
            plans[index] = planToSave
        }

        // Core Dataを更新
        context.perform {
            do {
                if let entity = try PlanEntity.fetchById(id: plan.id, context: self.context) {
                    entity.update(from: planToSave)
                    CoreDataManager.shared.saveContext()

                    // 通知を更新
                    DispatchQueue.main.async {
                        NotificationService.shared.schedulePlanNotifications(for: planToSave)
                    }
                }
            } catch {
            }
        }

        if (isShared && sharedChanged) || previous?.categoryId != planToSave.categoryId {
            SharedCategoryService.shared.planDidChange(planToSave, previous: previous, userId: userId)
        }
    }

    /// そのカテゴリのタグだけを残す。手元に無いタグ（届く前のもの）は残しておく
    static func tagIDs(_ ids: [String], inCategory categoryId: String?) -> [String] {
        ids.filter { id in
            guard let tag = PlanTagManager.shared.tag(for: id) else { return true }
            return tag.categoryId == categoryId
        }
    }

    /// IndexSetから削除
    func delete(at offsets: IndexSet, userId: String? = nil) {
        for index in offsets {
            let plan = plans[index]
            Task {
                await deletePlan(plan, userId: userId)
            }
        }
    }

    /// Planを削除（Core Dataから削除 → 自動的にCloudKitと同期）
    @MainActor
    func deletePlan(_ plan: Plan, userId: String? = nil) async {

        // 通知をキャンセル
        NotificationService.shared.cancelPlanNotifications(for: plan.id)
        CalendarExportService.shared.unlink(CalendarExportService.key(planId: plan.id))
        // 共有したカテゴリの予定なら、みんなの予定からも消える
        SharedCategoryService.shared.planDidDelete(plan)

        // Core Dataから削除
        await context.perform {
            do {
                if let entity = try PlanEntity.fetchById(id: plan.id, context: self.context) {
                    self.context.delete(entity)
                    CoreDataManager.shared.saveContext()
                }
            } catch {
            }
        }
    }
}

// MARK: - NSFetchedResultsControllerDelegate

extension PlansViewModel {
    /// まとめて削除する。1件ずつ保存すると同期が件数ぶん走るので、最後に1回だけ保存する
    func deletePlans(_ plans: [Plan]) async {
        for plan in plans {
            NotificationService.shared.cancelPlanNotifications(for: plan.id)
            await CalendarExportService.shared.unlink(CalendarExportService.key(planId: plan.id))
            await SharedCategoryService.shared.planDidDelete(plan)
        }

        await context.perform {
            for plan in plans {
                if let entity = try? PlanEntity.fetchById(id: plan.id, context: self.context) {
                    self.context.delete(entity)
                }
            }
            CoreDataManager.shared.saveContext()
        }
    }
}

extension PlansViewModel: NSFetchedResultsControllerDelegate {
    /// Core Dataの変更を検知してUIを自動更新
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        DispatchQueue.main.async {
            self.updatePlans()
        }
    }
}
