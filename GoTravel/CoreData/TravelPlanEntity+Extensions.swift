import Foundation
import CoreData
import SwiftUI

/// TravelPlanEntity - Core Data Entity
@objc(TravelPlanEntity)
public class TravelPlanEntity: NSManagedObject {
    @NSManaged public var id: String?
    @NSManaged public var title: String?
    @NSManaged public var startDate: Date?
    @NSManaged public var endDate: Date?
    @NSManaged public var destination: String?
    @NSManaged public var latitude: NSNumber?
    @NSManaged public var longitude: NSNumber?
    @NSManaged public var localImageFileName: String?
    @NSManaged public var cardColorHex: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var userId: String?
    @NSManaged public var isShared: NSNumber?
    @NSManaged public var shareCode: String?
    @NSManaged public var sharedWithData: Data?
    @NSManaged public var ownerId: String?
    @NSManaged public var lastEditedBy: String?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var daySchedulesData: Data?
    @NSManaged public var packingItemsData: Data?
}

// MARK: - Fetch Request

extension TravelPlanEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<TravelPlanEntity> {
        return NSFetchRequest<TravelPlanEntity>(entityName: "TravelPlanEntity")
    }

    /// すべてのTravelPlanを取得
    static func fetchAll(context: NSManagedObjectContext) throws -> [TravelPlanEntity] {
        let request = fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
        return try context.fetch(request)
    }

    /// ユーザーIDでフィルタリング
    static func fetchByUser(userId: String, context: NSManagedObjectContext) throws -> [TravelPlanEntity] {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@", userId)
        request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
        return try context.fetch(request)
    }

    /// IDで検索
    static func fetchById(id: String, context: NSManagedObjectContext) throws -> TravelPlanEntity? {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    /// 共有コードで検索
    static func fetchByShareCode(shareCode: String, context: NSManagedObjectContext) throws -> TravelPlanEntity? {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "shareCode == %@", shareCode)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }
}

// MARK: - Conversion: Entity ⇔ TravelPlan

extension TravelPlanEntity {
    /// TravelPlan構造体に変換
    func toTravelPlan() -> TravelPlan {
        // daySchedulesをデコード
        var daySchedules: [DaySchedule] = []
        if let data = daySchedulesData {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            daySchedules = (try? decoder.decode([DaySchedule].self, from: data)) ?? []
        }

        // packingItemsをデコード
        var packingItems: [PackingItem] = []
        if let data = packingItemsData {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            packingItems = (try? decoder.decode([PackingItem].self, from: data)) ?? []
        }

        // sharedWithをデコード
        var sharedWith: [String] = []
        if let data = sharedWithData {
            let decoder = JSONDecoder()
            sharedWith = (try? decoder.decode([String].self, from: data)) ?? []
        }

        var cardColor: Color? = nil
        if let hex = cardColorHex {
            cardColor = Color(hex: hex)
        }

        return TravelPlan(
            id: id ?? UUID().uuidString,
            title: title ?? "",
            startDate: startDate ?? Date(),
            endDate: endDate ?? Date(),
            destination: destination ?? "",
            latitude: latitude?.doubleValue,
            longitude: longitude?.doubleValue,
            localImageFileName: localImageFileName,
            cardColor: cardColor,
            createdAt: createdAt ?? Date(),
            userId: userId ?? "",
            daySchedules: daySchedules,
            packingItems: packingItems,
            isShared: isShared?.boolValue ?? false,
            shareCode: shareCode,
            sharedWith: sharedWith,
            ownerId: ownerId,
            lastEditedBy: lastEditedBy,
            updatedAt: updatedAt ?? Date()
        )
    }

    /// TravelPlan構造体からEntityを更新
    func update(from plan: TravelPlan) {
        if let id = plan.id {
            self.id = id
        } else {
            self.id = UUID().uuidString
        }

        self.title = plan.title
        self.startDate = plan.startDate
        self.endDate = plan.endDate
        self.destination = plan.destination
        self.latitude = plan.latitude.map { NSNumber(value: $0) }
        self.longitude = plan.longitude.map { NSNumber(value: $0) }
        self.localImageFileName = plan.localImageFileName

        if let color = plan.cardColor {
            self.cardColorHex = color.toHex()
        } else {
            self.cardColorHex = nil
        }

        self.createdAt = plan.createdAt
        self.userId = plan.userId ?? ""
        self.isShared = NSNumber(value: plan.isShared)
        self.shareCode = plan.shareCode
        self.ownerId = plan.ownerId
        self.lastEditedBy = plan.lastEditedBy
        self.updatedAt = plan.updatedAt

        // sharedWithをエンコード
        if !plan.sharedWith.isEmpty {
            let encoder = JSONEncoder()
            self.sharedWithData = try? encoder.encode(plan.sharedWith)
        }

        // daySchedulesをエンコード
        if !plan.daySchedules.isEmpty {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            self.daySchedulesData = try? encoder.encode(plan.daySchedules)
        }

        // packingItemsをエンコード
        if !plan.packingItems.isEmpty {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            self.packingItemsData = try? encoder.encode(plan.packingItems)
        }
    }

    /// TravelPlan構造体から新しいEntityを作成
    static func create(from plan: TravelPlan, context: NSManagedObjectContext) -> TravelPlanEntity {
        let entity = TravelPlanEntity(context: context)
        entity.update(from: plan)
        return entity
    }
}
