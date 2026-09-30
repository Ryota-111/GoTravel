import Foundation
import Combine
import CoreData

/// やることリスト。
///
/// 以前は `UserDefaults` に JSON で持っていた。そのため
/// **アプリを削除するとタスクが消え、端末を変えても引き継げなかった。**
/// 旅行計画や予定と同じく Core Data（CloudKit 自動同期）で持つ。
///
/// 作りは `AlbumManager` に合わせてある。`setup(userId:)` で
/// `NSFetchedResultsController` を張り、変更があれば `tasks` を作り直す。
final class TaskManager: NSObject, ObservableObject {
    static let shared = TaskManager()

    @Published var tasks: [TaskItem] = []

    private let context: NSManagedObjectContext
    private var fetchedResultsController: NSFetchedResultsController<TaskEntity>?
    private var currentUserId: String?

    /// 旧バージョンの UserDefaults 保存分を一度だけ Core Data へ移す
    private let legacyKey = "SavedTaskItems"
    private let migrationDoneKey = "TasksMigratedToCoreData_v1"

    private override init() {
        self.context = CoreDataManager.shared.viewContext
        super.init()
    }

    // MARK: - Setup

    /// ユーザーが確定したタイミングで呼ぶ。二重セットアップは行わない
    func setup(userId: String) {
        guard currentUserId != userId else { return }
        currentUserId = userId

        migrateLegacyTasksIfNeeded(userId: userId)
        setupFetchedResultsController(userId: userId)
    }

    private func setupFetchedResultsController(userId: String) {
        let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@", userId)
        request.sortDescriptors = TaskEntity.defaultSortDescriptors

        let controller = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        controller.delegate = self
        fetchedResultsController = controller

        do {
            try controller.performFetch()
            updateTasks()
        } catch {
        }
    }

    private func updateTasks() {
        tasks = fetchedResultsController?.fetchedObjects?.map { $0.toTaskItem() } ?? []
    }

    // MARK: - Migration

    /// UserDefaults に残っているタスクを Core Data に移す。
    /// 移行できたぶんだけ元データを消すので、途中で失敗しても次の起動でやり直せる
    private func migrateLegacyTasksIfNeeded(userId: String) {
        // 空データモードでは走らせない。中身は空なのに「移行済み」の印だけが
        // 端末に残り、実データでの移行が二度と走らなくなる
        guard !CoreDataManager.isEmptyDataMode else { return }
        guard !UserDefaults.standard.bool(forKey: migrationDoneKey) else { return }

        // 移行対象がない場合だけ、ここで「済み」にして終える
        guard let data = UserDefaults.standard.data(forKey: legacyKey) else {
            UserDefaults.standard.set(true, forKey: migrationDoneKey)
            return
        }

        // デコードに失敗した場合はフラグを立てず、次回の起動でやり直せるようにする
        guard let legacyTasks = try? JSONDecoder().decode([TaskItem].self, from: data) else {
            return
        }

        guard !legacyTasks.isEmpty else {
            UserDefaults.standard.set(true, forKey: migrationDoneKey)
            return
        }

        for task in legacyTasks {
            // 同じIDが既にある場合は移行済みとみなす
            if (try? TaskEntity.fetchById(id: task.id, context: context)) != nil {
                continue
            }
            TaskEntity.create(from: task, userId: userId, context: context)
        }
        CoreDataManager.shared.saveContext()

        UserDefaults.standard.set(true, forKey: migrationDoneKey)
        UserDefaults.standard.removeObject(forKey: legacyKey)
    }

    // MARK: - CRUD

    func add(_ task: TaskItem) {
        guard let userId = currentUserId else { return }

        TaskEntity.create(from: task, userId: userId, context: context)
        CoreDataManager.shared.saveContext()
        updateTasks()

        NotificationService.shared.scheduleTaskNotifications(for: task)
    }

    func update(_ task: TaskItem) {
        guard let userId = currentUserId else { return }

        guard let entity = try? TaskEntity.fetchById(id: task.id, context: context) else { return }
        entity.apply(task, userId: userId)
        CoreDataManager.shared.saveContext()
        updateTasks()

        if task.isCompleted {
            NotificationService.shared.cancelTaskNotifications(for: task.id)
        } else {
            NotificationService.shared.scheduleTaskNotifications(for: task)
        }
    }

    func delete(_ task: TaskItem) {
        if let entity = try? TaskEntity.fetchById(id: task.id, context: context) {
            context.delete(entity)
            CoreDataManager.shared.saveContext()
        }
        updateTasks()

        NotificationService.shared.cancelTaskNotifications(for: task.id)
    }

    func toggleComplete(_ task: TaskItem) {
        var t = task
        t.isCompleted.toggle()
        update(t)
    }

    // MARK: - Filtered

    func tasks(for priority: TaskItem.Priority?) -> [TaskItem] {
        let base = priority == nil ? tasks : tasks.filter { $0.priority == priority }
        return base.sorted {
            if $0.isCompleted != $1.isCompleted { return !$0.isCompleted }
            if $0.priority.sortOrder != $1.priority.sortOrder { return $0.priority.sortOrder < $1.priority.sortOrder }
            if let d0 = $0.dueDate, let d1 = $1.dueDate { return d0 < d1 }
            if $0.dueDate != nil { return true }
            if $1.dueDate != nil { return false }
            return $0.createdAt < $1.createdAt
        }
    }

    var pendingCount: Int { tasks.filter { !$0.isCompleted }.count }
}

// MARK: - NSFetchedResultsControllerDelegate

extension TaskManager: NSFetchedResultsControllerDelegate {
    /// 他の端末から降ってきた変更もここに来る
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        updateTasks()
    }
}
