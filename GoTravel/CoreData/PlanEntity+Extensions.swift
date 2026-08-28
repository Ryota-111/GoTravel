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
    @NSManaged public var endTime: Date?
    @NSManaged public var descriptionText: String?
    @NSManaged public var linkURL: String?
    @NSManaged public var placesData: Data?
    @NSManaged public var scheduleItemsData: Data?
    @NSManaged public var isCompleted: Bool
    /// タグが自由入力の文字列だった頃の保存先。
    /// `PlanTagManager` の移行が済むと nil になる。読むのは移行処理だけ
    @NSManaged public var tagsData: Data?
    @NSManaged public var recurrence: String?
    @NSManaged public var tagIDsData: Data?
    /// 鳴らす通知。未設定（nil）と「通知しない」（空配列）を区別する必要があるので、
    /// 空でも書き込む。詳しくは `Plan.reminders`
    @NSManaged public var remindersData: Data?
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

        // タグをデコード（持っているのはIDだけ。名前と色は PlanTagManager が解決する）
        var tagIDs: [String] = []
        if let data = tagIDsData {
            tagIDs = (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }

        var cardColor: Color? = nil
        if let hex = cardColorHex {
            cardColor = Color(hex: hex)
        }

        // 通知の設定。値が無ければ nil のままにして、既定の組み合わせを使わせる
        var reminders: [PlanReminder]? = nil
        if let data = remindersData {
            reminders = try? JSONDecoder().decode([PlanReminder].self, from: data)
        }

        let type = PlanType(rawValue: planType ?? "") ?? .daily
        let start = startDate ?? Date()

        // 日常と記念日は1日で完結する種別。終了日は持たない前提なので、開始日に揃える。
        //
        // 終了日を編集できるのはおでかけだけなのに、以前は種別を問わず保存していた。
        // そのため日常の予定の日付を変えると古い終了日が残り、開始日より前になって、
        // 一覧が「◯◯まで」の複数日表示になったり期間の判定から外れたりしていた。
        // 保存側は直したが、すでにそうなっている予定をここで拾い直す
        let end = type == .outing ? (endDate ?? start) : start

        return Plan(
            id: id ?? UUID().uuidString,
            title: title ?? "",
            startDate: start,
            endDate: end,
            places: places,
            cardColor: cardColor,
            localImageFileName: localImageFileName,
            userId: userId ?? "",
            createdAt: createdAt ?? Date(),
            planType: type,
            time: time,
            endTime: endTime,
            description: descriptionText,
            linkURL: linkURL,
            scheduleItems: scheduleItems,
            isCompleted: isCompleted,
            tagIDs: tagIDs,
            recurrence: PlanRecurrence(rawValue: recurrence ?? "") ?? .none,
            reminders: reminders
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
        self.endTime = plan.endTime
        self.descriptionText = plan.description
        self.linkURL = plan.linkURL

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        // 空になったときも必ず書くこと。
        // 空なら書かない作りだと、最後の1件を消しても前の値が残り、
        // 画面を開き直したときに消したはずのものが復活する
        self.placesData = plan.places.isEmpty
            ? nil
            : try? encoder.encode(plan.places)

        self.scheduleItemsData = plan.scheduleItems.isEmpty
            ? nil
            : try? encoder.encode(plan.scheduleItems)

        self.tagIDsData = plan.tagIDs.isEmpty
            ? nil
            : try? encoder.encode(plan.tagIDs)

        self.isCompleted = plan.isCompleted
        self.recurrence = plan.recurrence == .none ? nil : plan.recurrence.rawValue

        // 空配列は「通知しない」という設定なので、他の配列と違って空でも書く。
        // 書かないと未設定に戻り、既定の通知が復活してしまう
        if let reminders = plan.reminders {
            self.remindersData = try? encoder.encode(reminders)
        } else {
            self.remindersData = nil
        }
    }

    /// Plan構造体から新しいEntityを作成
    static func create(from plan: Plan, context: NSManagedObjectContext) -> PlanEntity {
        let entity = PlanEntity(context: context)
        entity.update(from: plan)
        return entity
    }
}
