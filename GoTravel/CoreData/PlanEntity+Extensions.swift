import Foundation
import CoreData
import SwiftUI

/// PlanEntity - Core Data Entity
@objc(PlanEntity)
public class PlanEntity: NSManagedObject {
    @NSManaged public var id: String?
    @NSManaged public var title: String?
    @NSManaged public var startDate: Date?
    @NSManaged public var endDate: Date?
    @NSManaged public var createdAt: Date?
    @NSManaged public var userId: String?
    @NSManaged public var planType: String?
    @NSManaged public var cardColorHex: String?
    @NSManaged public var localImageFileName: String?
    @NSManaged public var time: Date?
    @NSManaged public var descriptionText: String?
    @NSManaged public var linkURL: String?
    @NSManaged public var placesData: Data?
    @NSManaged public var scheduleItemsData: Data?
}

// MARK: - Fetch Request

extension PlanEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<PlanEntity> {
        return NSFetchRequest<PlanEntity>(entityName: "PlanEntity")
    }

    /// すべてのPlanを取得
    static func fetchAll(context: NSManagedObjectContext) throws -> [PlanEntity] {
        let request = fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
        return try context.fetch(request)
    }

    /// ユーザーIDでフィルタリング
    static func fetchByUser(userId: String, context: NSManagedObjectContext) throws -> [PlanEntity] {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@", userId)
        request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
        return try context.fetch(request)
    }

    /// IDで検索
    static func fetchById(id: String, context: NSManagedObjectContext) throws -> PlanEntity? {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    /// PlanTypeでフィルタリング
    static func fetchByType(planType: PlanType, userId: String, context: NSManagedObjectContext) throws -> [PlanEntity] {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@ AND planType == %@", userId, planType.rawValue)
        request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
        return try context.fetch(request)
    }
}

// MARK: - Conversion: Entity ⇔ Plan

extension PlanEntity {
    /// Plan構造体に変換
    func toPlan() -> Plan {
        // placesをデコード
        var places: [PlannedPlace] = []
        if let data = placesData {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            places = (try? decoder.decode([PlannedPlace].self, from: data)) ?? []
        }

        // scheduleItemsをデコード
        var scheduleItems: [PlanScheduleItem] = []
        if let data = scheduleItemsData {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            scheduleItems = (try? decoder.decode([PlanScheduleItem].self, from: data)) ?? []
        }

        var cardColor: Color? = nil
        if let hex = cardColorHex {
            cardColor = Color(hex: hex)
        }

        return Plan(
            id: id ?? UUID().uuidString,
            title: title ?? "",
            startDate: startDate ?? Date(),
            endDate: endDate ?? Date(),
            places: places,
            cardColor: cardColor,
            localImageFileName: localImageFileName,
            userId: userId ?? "",
            createdAt: createdAt ?? Date(),
            planType: PlanType(rawValue: planType ?? "") ?? .daily,
            time: time,
            description: descriptionText,
            linkURL: linkURL,
            scheduleItems: scheduleItems
        )
    }

    /// Plan構造体からEntityを更新
    func update(from plan: Plan) {
        self.id = plan.id
        self.title = plan.title
        self.startDate = plan.startDate
        self.endDate = plan.endDate
        self.createdAt = plan.createdAt
        self.userId = plan.userId ?? ""
        self.planType = plan.planType.rawValue

        if let color = plan.cardColor {
            self.cardColorHex = color.toHex()
        } else {
            self.cardColorHex = nil
        }

        self.localImageFileName = plan.localImageFileName
        self.time = plan.time
        self.descriptionText = plan.description
        self.linkURL = plan.linkURL

        // placesをエンコード
        if !plan.places.isEmpty {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            self.placesData = try? encoder.encode(plan.places)
        }

        // scheduleItemsをエンコード
        if !plan.scheduleItems.isEmpty {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            self.scheduleItemsData = try? encoder.encode(plan.scheduleItems)
        }
    }

    /// Plan構造体から新しいEntityを作成
    static func create(from plan: Plan, context: NSManagedObjectContext) -> PlanEntity {
        let entity = PlanEntity(context: context)
        entity.update(from: plan)
        return entity
    }
}
