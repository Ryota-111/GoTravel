import Foundation
import CloudKit
import SwiftUI
import os

// MARK: - カテゴリ（カレンダー）ごとの共有（3.0）
//
// 旅行計画の共有（`SharedTravelPlan`）と同じく、パブリックDBに手で読み書きする。
// - 共有したカテゴリ：レコードタイプ `SharedCategory`、レコード ID は `sharedcategory_<categoryId>`。
//   カテゴリのタグも `tagsJSON` に入れて一緒に持つ
// - カテゴリの予定：レコードタイプ `SharedPlan`、レコード ID は `sharedplan_<planId>`、`categoryId` で引く
//
// **Production への反映が要る**（`docs/設計_3.0.md` 6章）。
// - `SharedCategory` の `shareCode`・`ownerId`・`sharedWith`、`SharedPlan` の `categoryId` に QUERYABLE の索引
// - 書き込みの権限は `SharedTravelPlan` と同じ設定にする
extension CloudKitService {

    static let sharedCategoryRecordType = "SharedCategory"
    static let sharedSchedulePlanRecordType = "SharedPlan"

    private var publicDB: CKDatabase {
        CKContainer(identifier: "iCloud.com.gmail.taismryotasis.Travory").publicCloudDatabase
    }

    // MARK: - 共有したカテゴリ

    private static func categoryRecordID(_ categoryId: String) -> CKRecord.ID {
        CKRecord.ID(recordName: "sharedcategory_\(categoryId)")
    }

    private static func parseCategory(_ record: CKRecord) -> SharedCategoryRecord? {
        guard record.recordID.recordName.hasPrefix("sharedcategory_"),
              let name = record["name"] as? String,
              let code = record["shareCode"] as? String,
              let ownerId = record["ownerId"] as? String else { return nil }
        let tags = (record["tagsJSON"] as? String)?.data(using: .utf8)
            .flatMap { try? JSONDecoder().decode([PlanTag].self, from: $0) } ?? []
        return SharedCategoryRecord(id: String(record.recordID.recordName.dropFirst("sharedcategory_".count)),
                                    name: name,
                                    colorHex: record["colorHex"] as? String,
                                    shareCode: code,
                                    ownerId: ownerId,
                                    sharedWith: record["sharedWith"] as? [String] ?? [],
                                    tags: tags,
                                    updatedAt: record["updatedAt"] as? Date)
    }

    /// 共有したカテゴリを公開・更新する
    func publishSharedCategory(_ category: SharedCategoryRecord) async throws {
        let id = Self.categoryRecordID(category.id)
        func apply(_ record: CKRecord) {
            record["name"] = category.name
            record["colorHex"] = category.colorHex
            record["shareCode"] = category.shareCode
            record["ownerId"] = category.ownerId
            record["sharedWith"] = category.sharedWith.isEmpty ? nil : category.sharedWith
            record["tagsJSON"] = (try? JSONEncoder().encode(category.tags)).flatMap { String(data: $0, encoding: .utf8) }
            record["updatedAt"] = category.updatedAt ?? Date()
        }
        let record = (try? await publicDB.record(for: id)) ?? CKRecord(recordType: Self.sharedCategoryRecordType, recordID: id)
        apply(record)
        do {
            _ = try await publicDB.save(record)
        } catch let ckError as CKError where ckError.code == .serverRecordChanged {
            guard let server = ckError.serverRecord else { throw ckError }
            apply(server)
            _ = try await publicDB.save(server)
        }
    }

    func fetchSharedCategory(categoryId: String) async throws -> SharedCategoryRecord? {
        do {
            return Self.parseCategory(try await publicDB.record(for: Self.categoryRecordID(categoryId)))
        } catch let ckError as CKError where ckError.code == .unknownItem {
            return nil
        }
    }

    func fetchSharedCategory(byShareCode code: String) async throws -> SharedCategoryRecord? {
        let query = CKQuery(recordType: Self.sharedCategoryRecordType, predicate: NSPredicate(format: "shareCode == %@", code))
        return try await publicDB.records(matching: query).matchResults
            .compactMap { try? $0.1.get() }.compactMap(Self.parseCategory).first
    }

    /// 自分が持ち主、またはメンバーの共有したカテゴリ
    func fetchSharedCategories(memberId: String) async throws -> [SharedCategoryRecord] {
        var records: [String: CKRecord] = [:]
        for predicate in [NSPredicate(format: "ownerId == %@", memberId),
                          NSPredicate(format: "sharedWith CONTAINS %@", memberId)] {
            let query = CKQuery(recordType: Self.sharedCategoryRecordType, predicate: predicate)
            for (_, result) in try await publicDB.records(matching: query).matchResults {
                if let record = try? result.get() { records[record.recordID.recordName] = record }
            }
        }
        return records.values.compactMap(Self.parseCategory)
    }

    func deleteSharedCategory(categoryId: String) async throws {
        do {
            _ = try await publicDB.deleteRecord(withID: Self.categoryRecordID(categoryId))
        } catch let ckError as CKError where ckError.code == .unknownItem {
        }
    }

    // MARK: - カテゴリの予定

    private static func planRecordID(_ planId: String) -> CKRecord.ID {
        CKRecord.ID(recordName: "sharedplan_\(planId)")
    }

    /// みんなで持つ項目だけを載せる（通知・済みの印・写真は載せない）
    private static func apply(_ plan: Plan, to record: CKRecord) {
        record["categoryId"] = plan.categoryId
        record["tagIDsJSON"] = (try? JSONEncoder().encode(plan.tagIDs)).flatMap { String(data: $0, encoding: .utf8) }
        record["title"] = plan.title
        record["startDate"] = plan.startDate
        record["endDate"] = plan.endDate
        record["time"] = plan.time
        record["endTime"] = plan.endTime
        record["planType"] = plan.planType.rawValue
        record["descriptionText"] = plan.description
        record["linkURL"] = plan.linkURL
        record["recurrence"] = plan.recurrence.rawValue
        record["cardColorHex"] = plan.cardColorHex
        record["createdAt"] = plan.createdAt
        record["updatedAt"] = plan.updatedAt
        record["lastEditedBy"] = plan.lastEditedBy

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        record["placesJSON"] = (try? encoder.encode(plan.places)).flatMap { String(data: $0, encoding: .utf8) }
        record["scheduleItemsJSON"] = (try? encoder.encode(plan.scheduleItems)).flatMap { String(data: $0, encoding: .utf8) }
    }

    private static func parsePlan(_ record: CKRecord) -> Plan? {
        guard record.recordID.recordName.hasPrefix("sharedplan_"),
              let title = record["title"] as? String,
              let startDate = record["startDate"] as? Date else { return nil }
        let id = String(record.recordID.recordName.dropFirst("sharedplan_".count))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let places = (record["placesJSON"] as? String)?.data(using: .utf8)
            .flatMap { try? decoder.decode([PlannedPlace].self, from: $0) } ?? []
        let items = (record["scheduleItemsJSON"] as? String)?.data(using: .utf8)
            .flatMap { try? decoder.decode([PlanScheduleItem].self, from: $0) } ?? []
        let tagIDs = (record["tagIDsJSON"] as? String)?.data(using: .utf8)
            .flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? []
        return Plan(
            id: id,
            title: title,
            startDate: startDate,
            endDate: record["endDate"] as? Date ?? startDate,
            places: places,
            cardColor: (record["cardColorHex"] as? String).flatMap { Color(hex: $0) },
            createdAt: record["createdAt"] as? Date ?? Date(),
            planType: PlanType(rawValue: record["planType"] as? String ?? "") ?? .outing,
            time: record["time"] as? Date,
            endTime: record["endTime"] as? Date,
            description: record["descriptionText"] as? String,
            linkURL: record["linkURL"] as? String,
            scheduleItems: items,
            tagIDs: tagIDs,
            recurrence: PlanRecurrence(rawValue: record["recurrence"] as? String ?? "") ?? .none
        ).withSharing(categoryId: record["categoryId"] as? String,
                      lastEditedBy: record["lastEditedBy"] as? String,
                      updatedAt: record["updatedAt"] as? Date)
    }

    /// カテゴリの予定を公開・更新する。同時に保存して競合したら、最新のレコードに載せ直す
    func publishSharedPlan(_ plan: Plan) async throws {
        let recordID = Self.planRecordID(plan.id)
        let record = (try? await publicDB.record(for: recordID))
            ?? CKRecord(recordType: Self.sharedSchedulePlanRecordType, recordID: recordID)
        Self.apply(plan, to: record)
        do {
            _ = try await publicDB.save(record)
        } catch let ckError as CKError where ckError.code == .serverRecordChanged {
            guard let server = ckError.serverRecord else { throw ckError }
            Self.apply(plan, to: server)
            _ = try await publicDB.save(server)
        }
        Self.shareLogger.notice("予定を公開 planId=\(plan.id, privacy: .public)")
    }

    func fetchSharedPlan(planId: String) async throws -> Plan? {
        do {
            return Self.parsePlan(try await publicDB.record(for: Self.planRecordID(planId)))
        } catch let ckError as CKError where ckError.code == .unknownItem {
            return nil
        }
    }

    /// そのカテゴリの予定を全部取る（続きがあれば最後まで読む）
    func fetchSharedPlans(categoryId: String) async throws -> [Plan] {
        let query = CKQuery(recordType: Self.sharedSchedulePlanRecordType, predicate: NSPredicate(format: "categoryId == %@", categoryId))
        var (results, cursor) = try await publicDB.records(matching: query)
        var records = results.compactMap { try? $0.1.get() }
        while let next = cursor {
            (results, cursor) = try await publicDB.records(continuingMatchFrom: next)
            records += results.compactMap { try? $0.1.get() }
        }
        return records.compactMap(Self.parsePlan)
    }

    func deleteSharedPlan(planId: String) async throws {
        do {
            _ = try await publicDB.deleteRecord(withID: Self.planRecordID(planId))
        } catch let ckError as CKError where ckError.code == .unknownItem {
            // もう無ければ成功とみなす
        }
    }
}
