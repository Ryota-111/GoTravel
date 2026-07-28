import Foundation
import CoreData

/// PlaceCategoryEntity - Core Data Entity
/// ユーザーが自分で作った場所カテゴリー。既定カテゴリーはコード側に定義があるので保存しない
@objc(PlaceCategoryEntity)
public class PlaceCategoryEntity: NSManagedObject {
    @NSManaged public var id: String?
    @NSManaged public var name: String?
    @NSManaged public var icon: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var userId: String?
}

// MARK: - Fetch Request

extension PlaceCategoryEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<PlaceCategoryEntity> {
        return NSFetchRequest<PlaceCategoryEntity>(entityName: "PlaceCategoryEntity")
    }

    static func fetchByUser(userId: String, context: NSManagedObjectContext) throws -> [PlaceCategoryEntity] {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@", userId)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        return try context.fetch(request)
    }

    static func fetchById(id: String, context: NSManagedObjectContext) throws -> PlaceCategoryEntity? {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }
}

// MARK: - Conversion

extension PlaceCategoryEntity {
    func toCategory() -> CustomPlaceCategory {
        CustomPlaceCategory(
            id: id ?? UUID().uuidString,
            name: name ?? "",
            icon: icon ?? "mappin.circle.fill",
            isDefault: false
        )
    }

    func update(from category: CustomPlaceCategory, userId: String, createdAt: Date = Date()) {
        self.id = category.id
        self.name = category.name
        self.icon = category.icon
        self.userId = userId
        if self.createdAt == nil {
            self.createdAt = createdAt
        }
    }

    static func create(from category: CustomPlaceCategory, userId: String, createdAt: Date = Date(), context: NSManagedObjectContext) -> PlaceCategoryEntity {
        let entity = PlaceCategoryEntity(context: context)
        entity.createdAt = createdAt
        entity.update(from: category, userId: userId, createdAt: createdAt)
        return entity
    }
}
