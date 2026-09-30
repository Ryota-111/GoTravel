import Foundation
import CoreData

/// PlanTagEntity - Core Data Entity
/// 予定につける自由タグ。既定のタグは持たない（`PlaceCategoryEntity` と違い、全部ユーザーが作る）
@objc(PlanTagEntity)
public class PlanTagEntity: NSManagedObject {
    @NSManaged public var id: String?
    @NSManaged public var name: String?
    @NSManaged public var colorHex: String?
    @NSManaged public var order: Int32
    @NSManaged public var createdAt: Date?
    @NSManaged public var userId: String?
}

// MARK: - Fetch Request

extension PlanTagEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<PlanTagEntity> {
        return NSFetchRequest<PlanTagEntity>(entityName: "PlanTagEntity")
    }

    /// 並べ替えの順が主。別々の端末で同時に作ると order が同じ値になりうるので、
    /// 作成日で必ず決着がつくようにしておく
    static var defaultSortDescriptors: [NSSortDescriptor] {
        [
            NSSortDescriptor(key: "order", ascending: true),
            NSSortDescriptor(key: "createdAt", ascending: true)
        ]
    }

    static func fetchByUser(userId: String, context: NSManagedObjectContext) throws -> [PlanTagEntity] {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@", userId)
        request.sortDescriptors = defaultSortDescriptors
        return try context.fetch(request)
    }

    static func fetchById(id: String, context: NSManagedObjectContext) throws -> PlanTagEntity? {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }
}

// MARK: - Conversion

extension PlanTagEntity {
    func toTag() -> PlanTag {
        PlanTag(
            id: id ?? UUID().uuidString,
            name: name ?? "",
            colorHex: colorHex,
            order: Int(order)
        )
    }

    func update(from tag: PlanTag, userId: String, createdAt: Date = Date()) {
        self.id = tag.id
        self.name = tag.name
        self.colorHex = tag.colorHex
        self.order = Int32(tag.order)
        self.userId = userId
        if self.createdAt == nil {
            self.createdAt = createdAt
        }
    }

    static func create(from tag: PlanTag, userId: String, createdAt: Date = Date(), context: NSManagedObjectContext) -> PlanTagEntity {
        let entity = PlanTagEntity(context: context)
        entity.createdAt = createdAt
        entity.update(from: tag, userId: userId, createdAt: createdAt)
        return entity
    }
}
