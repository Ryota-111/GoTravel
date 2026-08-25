import Foundation
import Combine
import CoreData

/// Plan管理用ViewModel（Core Data + CloudKit自動同期版）
final class PlansViewModel: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var plans: [Plan] = []
    @Published var isLoading: Bool = false

    // MARK: - Private Properties
    private let context: NSManagedObjectContext
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

        Task { @MainActor in generateNextOccurrencesIfNeeded() }
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
            plan.recurrence != .none
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
            next.createdAt = Date()
            next.startDate = nextStart
            next.endDate = calendar.date(byAdding: .day, value: span, to: nextStart) ?? nextStart
            next.scheduleItems = plan.scheduleItems.map { item in
                var copy = item
                copy.id = UUID().uuidString
                return copy
            }

            add(next, userId: userId)
        }
    }

    // MARK: - CRUD Operations

    /// Planを追加（Core Dataに保存 → 自動的にCloudKitと同期）
    @MainActor
    func add(_ plan: Plan, userId: String) {

        var planToSave = plan
        planToSave.userId = userId

        // Core Dataに保存
        context.perform {
            _ = PlanEntity.create(from: planToSave, context: self.context)
            CoreDataManager.shared.saveContext()

            // 通知をスケジュール
            DispatchQueue.main.async {
                NotificationService.shared.schedulePlanNotifications(for: planToSave)
            }
        }
    }

    /// Planを更新（Core Dataに保存 → 自動的にCloudKitと同期）
    @MainActor
    func update(_ plan: Plan, userId: String) {

        var planToSave = plan
        planToSave.userId = userId

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

extension PlansViewModel: NSFetchedResultsControllerDelegate {
    /// Core Dataの変更を検知してUIを自動更新
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        DispatchQueue.main.async {
            self.updatePlans()
        }
    }
}
