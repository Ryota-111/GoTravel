import Foundation
import CoreData

/// TaskEntity - Core Data Entity
///
/// 持ち物や下調べのやることリスト。
/// 以前は `UserDefaults` に JSON で持っていたため、**アプリを消すと一緒に消え、
/// 端末を変えても引き継げなかった。** 他のデータと同じ CloudKit 自動同期に載せる。
@objc(TaskEntity)
public class TaskEntity: NSManagedObject {
    @NSManaged public var id: String?
    @NSManaged public var title: String?
    /// `TaskItem.Priority` の rawValue（高・中・低）
    @NSManaged public var priority: String?
    @NSManaged public var dueDate: Date?
    @NSManaged public var isCompleted: Bool
    @NSManaged public var createdAt: Date?
    @NSManaged public var userId: String?
}

// MARK: - Fetch Request

extension TaskEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<TaskEntity> {
        return NSFetchRequest<TaskEntity>(entityName: "TaskEntity")
    }

    /// 並べ替えは `TaskManager.tasks(for:)` が優先度と期限で行う。
    /// ここは取り出す順を決めるだけなので作成日で足りる
    static var defaultSortDescriptors: [NSSortDescriptor] {
        [NSSortDescriptor(key: "createdAt", ascending: true)]
    }

    static func fetchByUser(userId: String, context: NSManagedObjectContext) throws -> [TaskEntity] {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@", userId)
        request.sortDescriptors = defaultSortDescriptors
        return try context.fetch(request)
    }

    static func fetchById(id: String, context: NSManagedObjectContext) throws -> TaskEntity? {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }
}

// MARK: - Conversion: Entity ⇔ TaskItem

extension TaskEntity {
    func toTaskItem() -> TaskItem {
        TaskItem(
            id: id ?? UUID().uuidString,
            title: title ?? "",
            // 古いデータや壊れた値でも消さずに拾う。「中」に寄せておく
            priority: TaskItem.Priority(rawValue: priority ?? "") ?? .medium,
            dueDate: dueDate,
            isCompleted: isCompleted,
            createdAt: createdAt ?? Date()
        )
    }

    func apply(_ task: TaskItem, userId: String) {
        id = task.id
        title = task.title
        priority = task.priority.rawValue
        dueDate = task.dueDate
        isCompleted = task.isCompleted
        createdAt = task.createdAt
        self.userId = userId
    }

    @discardableResult
    static func create(from task: TaskItem,
                       userId: String,
                       context: NSManagedObjectContext) -> TaskEntity {
        let entity = TaskEntity(context: context)
        entity.apply(task, userId: userId)
        return entity
    }
}
