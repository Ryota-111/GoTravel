import Foundation
import CoreData
import SwiftUI

/// VisitedPlaceEntity - Core Data Entity
@objc(VisitedPlaceEntity)
public class VisitedPlaceEntity: NSManagedObject {
    @NSManaged public var id: String?
    @NSManaged public var title: String?
    @NSManaged public var notes: String?
    @NSManaged public var latitude: NSNumber?
    @NSManaged public var longitude: NSNumber?
    @NSManaged public var createdAt: Date?
    @NSManaged public var visitedAt: Date?
    @NSManaged public var localPhotoFileName: String?
    @NSManaged public var address: String?
    @NSManaged public var tagsData: Data?
    @NSManaged public var category: String?
    @NSManaged public var travelPlanId: String?
    @NSManaged public var userId: String?
}

// MARK: - Fetch Request

extension VisitedPlaceEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<VisitedPlaceEntity> {
        return NSFetchRequest<VisitedPlaceEntity>(entityName: "VisitedPlaceEntity")
    }

    /// すべてのVisitedPlaceを取得
    static func fetchAll(context: NSManagedObjectContext) throws -> [VisitedPlaceEntity] {
        let request = fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "visitedAt", ascending: false)]
        return try context.fetch(request)
    }

    /// ユーザーIDでフィルタリング
    static func fetchByUser(userId: String, context: NSManagedObjectContext) throws -> [VisitedPlaceEntity] {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@", userId)
        request.sortDescriptors = [NSSortDescriptor(key: "visitedAt", ascending: false)]
        return try context.fetch(request)
    }

    /// IDで検索
    static func fetchById(id: String, context: NSManagedObjectContext) throws -> VisitedPlaceEntity? {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    /// カテゴリーでフィルタリング
    static func fetchByCategory(category: PlaceCategory, userId: String, context: NSManagedObjectContext) throws -> [VisitedPlaceEntity] {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@ AND category == %@", userId, category.rawValue)
        request.sortDescriptors = [NSSortDescriptor(key: "visitedAt", ascending: false)]
        return try context.fetch(request)
    }

    /// TravelPlanIDでフィルタリング
    static func fetchByTravelPlan(travelPlanId: String, context: NSManagedObjectContext) throws -> [VisitedPlaceEntity] {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "travelPlanId == %@", travelPlanId)
        request.sortDescriptors = [NSSortDescriptor(key: "visitedAt", ascending: false)]
        return try context.fetch(request)
    }
}

// MARK: - Conversion: Entity ⇔ VisitedPlace

extension VisitedPlaceEntity {
    /// VisitedPlace構造体に変換
    func toVisitedPlace() -> VisitedPlace {
        // tagsをデコード
        var tags: [String]? = nil
        if let data = tagsData {
            let decoder = JSONDecoder()
            tags = try? decoder.decode([String].self, from: data)
        }

        return VisitedPlace(
            id: id ?? UUID().uuidString,
            title: title ?? "",
            notes: notes,
            latitude: latitude?.doubleValue ?? 0.0,
            longitude: longitude?.doubleValue ?? 0.0,
            createdAt: createdAt ?? Date(),
            visitedAt: visitedAt,
            photoURL: nil, // ローカルファイルから読み込むため
            localPhotoFileName: localPhotoFileName,
            address: address,
            tags: tags,
            category: PlaceCategory(rawValue: category ?? "") ?? .other,
            travelPlanId: travelPlanId,
            userId: userId ?? ""
        )
    }

    /// VisitedPlace構造体からEntityを更新
    func update(from place: VisitedPlace) {
        if let id = place.id {
            self.id = id
        } else {
            self.id = UUID().uuidString
        }
        self.title = place.title
        self.notes = place.notes
        self.latitude = NSNumber(value: place.latitude)
        self.longitude = NSNumber(value: place.longitude)
        self.createdAt = place.createdAt
        self.visitedAt = place.visitedAt
        self.localPhotoFileName = place.localPhotoFileName
        self.address = place.address
        self.category = place.category.rawValue
        self.travelPlanId = place.travelPlanId
        self.userId = place.userId ?? ""

        // tagsをエンコード
        if let tags = place.tags, !tags.isEmpty {
            let encoder = JSONEncoder()
            self.tagsData = try? encoder.encode(tags)
        }
    }

    /// VisitedPlace構造体から新しいEntityを作成
    static func create(from place: VisitedPlace, context: NSManagedObjectContext) -> VisitedPlaceEntity {
        let entity = VisitedPlaceEntity(context: context)
        entity.update(from: place)
        return entity
    }
}
