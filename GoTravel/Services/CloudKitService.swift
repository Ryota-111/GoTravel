import Foundation
import CloudKit
import SwiftUI

// MARK: - CloudKit Service
final class CloudKitService {

    // MARK: - Properties
    static let shared = CloudKitService()

    private let container: CKContainer
    private let publicDatabase: CKDatabase
    private let privateDatabase: CKDatabase

    // MARK: - Initialization
    private init() {
        // iCloud.com.gmail.taismryotasis.Travory コンテナを使用
        container = CKContainer(identifier: "iCloud.com.gmail.taismryotasis.Travory")
        publicDatabase = container.publicCloudDatabase
        privateDatabase = container.privateCloudDatabase
    }

    // MARK: - Account Status
    /// iCloudアカウントの状態を確認
    func checkAccountStatus() async throws -> CKAccountStatus {
        return try await container.accountStatus()
    }

    /// iCloudにサインインしているか確認
    func isICloudAvailable() async -> Bool {
        do {
            let status = try await checkAccountStatus()
            return status == .available
        } catch {
            return false
        }
    }

    // MARK: - Basic CRUD Operations

    /// レコードを保存
    func save(_ record: CKRecord) async throws -> CKRecord {

        do {
            let savedRecord = try await privateDatabase.save(record)
            return savedRecord
        } catch {
            throw error
        }
    }

    /// 複数のレコードを保存
    func saveRecords(_ records: [CKRecord]) async throws -> [CKRecord] {
        let (savedRecords, _) = try await privateDatabase.modifyRecords(saving: records, deleting: [])
        return savedRecords.compactMap { try? $0.value.get() }
    }

    /// レコードを取得
    func fetch(recordID: CKRecord.ID) async throws -> CKRecord {
        return try await privateDatabase.record(for: recordID)
    }

    /// クエリでレコードを検索
    func query(recordType: String, predicate: NSPredicate = NSPredicate(value: true), sortDescriptors: [NSSortDescriptor] = []) async throws -> [CKRecord] {
        let query = CKQuery(recordType: recordType, predicate: predicate)
        query.sortDescriptors = sortDescriptors

        let (results, _) = try await privateDatabase.records(matching: query)
        return results.compactMap { try? $0.1.get() }
    }

    /// 全レコードを取得（index不要）
    func fetchAllRecords(recordType: String) async throws -> [CKRecord] {
        var allRecords: [CKRecord] = []
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        let operation = CKQueryOperation(query: query)
        operation.resultsLimit = CKQueryOperation.maximumResults

        return try await withCheckedThrowingContinuation { continuation in
            operation.recordMatchedBlock = { recordID, result in
                if case .success(let record) = result {
                    allRecords.append(record)
                }
            }

            operation.queryResultBlock = { result in
                switch result {
                case .success(_):
                    continuation.resume(returning: allRecords)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            privateDatabase.add(operation)
        }
    }

    /// レコードを削除
    func delete(recordID: CKRecord.ID) async throws {
        _ = try await privateDatabase.deleteRecord(withID: recordID)
    }

    /// 複数のレコードを削除
    func deleteRecords(recordIDs: [CKRecord.ID]) async throws {
        let (_, deletedIDs) = try await privateDatabase.modifyRecords(saving: [], deleting: recordIDs)
        _ = deletedIDs.compactMap { try? $0.value.get() }
    }

    // MARK: - Asset Operations

    /// 画像をCKAssetとして保存
    func saveImage(_ image: UIImage, recordType: String, recordName: String) async throws -> CKRecord {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw CloudKitError.invalidImageData
        }

        // 一時ファイルに保存
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try imageData.write(to: tempURL)

        let asset = CKAsset(fileURL: tempURL)
        let recordID = CKRecord.ID(recordName: recordName)
        let record = CKRecord(recordType: recordType, recordID: recordID)
        record["image"] = asset

        let savedRecord = try await save(record)

        // 一時ファイルを削除
        try? FileManager.default.removeItem(at: tempURL)

        return savedRecord
    }

    /// CKAssetから画像を取得
    func fetchImage(from record: CKRecord, key: String = "image") async throws -> UIImage? {
        guard let asset = record[key] as? CKAsset,
              let fileURL = asset.fileURL,
              let data = try? Data(contentsOf: fileURL) else {
            return nil
        }
        return UIImage(data: data)
    }

    // MARK: - Subscription (リアルタイム更新)

    /// サブスクリプションを作成してリアルタイム更新を受け取る
    func createSubscription(recordType: String, predicate: NSPredicate = NSPredicate(value: true)) async throws {
        let subscription = CKQuerySubscription(
            recordType: recordType,
            predicate: predicate,
            subscriptionID: "\(recordType)Subscription",
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        _ = try await privateDatabase.save(subscription)
    }

    /// サブスクリプションを削除
    func deleteSubscription(subscriptionID: String) async throws {
        _ = try await privateDatabase.deleteSubscription(withID: subscriptionID)
    }

    // MARK: - VisitedPlace Operations

    /// VisitedPlaceをCloudKitに保存（画像付き）
    func saveVisitedPlace(_ place: VisitedPlace, userId: String, image: UIImage? = nil) async throws -> VisitedPlace {

        let recordName = place.id ?? UUID().uuidString

        let recordID = CKRecord.ID(recordName: recordName)

        // 既存のレコードを取得してから更新、存在しない場合は新規作成
        let record: CKRecord
        if place.id != nil {
            // 既存レコードの取得を試みる
            do {
                record = try await privateDatabase.record(for: recordID)
            } catch {
                // レコードが存在しない場合は新規作成
                record = CKRecord(recordType: "VisitedPlace", recordID: recordID)
            }
        } else {
            // idがnilの場合は新規作成
            record = CKRecord(recordType: "VisitedPlace", recordID: recordID)
        }

        // Required fields
        record["userId"] = userId
        record["title"] = place.title
        record["latitude"] = place.latitude
        record["longitude"] = place.longitude
        record["createdAt"] = place.createdAt

        // Optional fields
        if let notes = place.notes {
            record["notes"] = notes
        }
        if let visitedAt = place.visitedAt {
            record["visitedDate"] = visitedAt
        }
        if let tags = place.tags, !tags.isEmpty {
            record["tags"] = tags
        }
        if let address = place.address {
            record["address"] = address
        }
        if let travelPlanId = place.travelPlanId {
            record["travelPlanId"] = travelPlanId
        }

        record["category"] = place.category.rawValue

        // 画像ファイル名（ローカルファイル名を保持）
        if let fileName = place.localPhotoFileName {
            record["imageFileNames"] = [fileName]
        }

        // 画像をCKAssetとして保存
        var tempURL: URL?
        if let image = image {
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                throw CloudKitError.invalidImageData
            }

            let imageSize = Double(imageData.count) / 1024.0 / 1024.0

            // 一時ファイルに保存
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
            try imageData.write(to: url)
            tempURL = url

            let asset = CKAsset(fileURL: url)
            record["image"] = asset
        }

        // レコードを保存（CloudKitが一時ファイルをアップロード）
        let savedRecord = try await save(record)

        // アップロード完了後に一時ファイルを削除
        if let tempURL = tempURL {
            try? FileManager.default.removeItem(at: tempURL)
        }

        // 保存されたレコードからVisitedPlaceを再構築
        var updatedPlace = place
        updatedPlace.id = savedRecord.recordID.recordName
        updatedPlace.userId = userId

        return updatedPlace
    }

    /// ユーザーのVisitedPlaceを全て取得（画像付き）
    func fetchVisitedPlaces(userId: String) async throws -> [(place: VisitedPlace, image: UIImage?)] {
        let predicate = NSPredicate(format: "userId == %@", userId)
        let records = try await query(recordType: "VisitedPlace", predicate: predicate)

        var results: [(place: VisitedPlace, image: UIImage?)] = []

        for record in records {
            if let place = parseVisitedPlace(from: record) {
                let image = try? await fetchImage(from: record, key: "image")
                results.append((place: place, image: image))
            }
        }

        return results
    }

    /// VisitedPlaceの画像のみを取得
    func fetchVisitedPlaceImage(placeId: String) async throws -> UIImage? {
        let recordID = CKRecord.ID(recordName: placeId)
        let record = try await fetch(recordID: recordID)
        return try await fetchImage(from: record, key: "image")
    }

    /// VisitedPlaceを削除
    func deleteVisitedPlace(placeId: String) async throws {
        let recordID = CKRecord.ID(recordName: placeId)
        try await delete(recordID: recordID)
    }

    /// CKRecordからVisitedPlaceをパース
    private func parseVisitedPlace(from record: CKRecord) -> VisitedPlace? {
        guard let userId = record["userId"] as? String,
              let title = record["title"] as? String,
              let latitude = record["latitude"] as? Double,
              let longitude = record["longitude"] as? Double,
              let createdAt = record["createdAt"] as? Date else {
            return nil
        }

        let notes = record["notes"] as? String
        let visitedAt = record["visitedDate"] as? Date
        let tags = record["tags"] as? [String]
        let address = record["address"] as? String
        let travelPlanId = record["travelPlanId"] as? String
        let categoryRaw = record["category"] as? String ?? "other"
        let category = PlaceCategory(rawValue: categoryRaw) ?? .other

        // 画像ファイル名（配列の最初の要素を取得）
        let imageFileNames = record["imageFileNames"] as? [String]
        let localPhotoFileName = imageFileNames?.first

        return VisitedPlace(
            id: record.recordID.recordName,
            title: title,
            notes: notes,
            latitude: latitude,
            longitude: longitude,
            createdAt: createdAt,
            visitedAt: visitedAt,
            photoURL: nil,
            localPhotoFileName: localPhotoFileName,
            address: address,
            tags: tags,
            category: category,
            travelPlanId: travelPlanId,
            userId: userId
        )
    }

    // MARK: - Plan Operations

    /// PlanをCloudKitに保存
    func savePlan(_ plan: Plan, userId: String) async throws -> Plan {

        let recordID = CKRecord.ID(recordName: plan.id)

        // 既存のレコードを取得してから更新、存在しない場合は新規作成
        let record: CKRecord
        do {
            record = try await privateDatabase.record(for: recordID)
        } catch {
            record = CKRecord(recordType: "Plan", recordID: recordID)
        }

        // Required fields
        record["userId"] = userId
        record["title"] = plan.title
        record["startDate"] = plan.startDate
        record["endDate"] = plan.endDate
        record["createdAt"] = plan.createdAt
        record["planType"] = plan.planType.rawValue

        // Optional fields
        if let cardColorHex = plan.cardColorHex {
            record["cardColorHex"] = cardColorHex
        }
        if let localImageFileName = plan.localImageFileName {
            record["localImageFileName"] = localImageFileName
        }
        if let time = plan.time {
            record["time"] = time
        }
        if let description = plan.description {
            record["description"] = description
        }
        if let linkURL = plan.linkURL {
            record["linkURL"] = linkURL
        }

        // JSON fields
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        // places を JSON文字列に変換
        if let placesData = try? encoder.encode(plan.places),
           let placesJSON = String(data: placesData, encoding: .utf8) {
            record["placesJSON"] = placesJSON
        }

        // scheduleItems を JSON文字列に変換
        if let scheduleItemsData = try? encoder.encode(plan.scheduleItems),
           let scheduleItemsJSON = String(data: scheduleItemsData, encoding: .utf8) {
            record["scheduleItemsJSON"] = scheduleItemsJSON
        }

        let savedRecord = try await save(record)

        // 保存されたレコードからPlanを再構築
        var updatedPlan = plan
        updatedPlan.userId = userId

        return updatedPlan
    }

    /// ユーザーのPlanを全て取得
    func fetchPlans(userId: String) async throws -> [Plan] {
        let predicate = NSPredicate(format: "userId == %@", userId)
        let records = try await query(recordType: "Plan", predicate: predicate)

        return records.compactMap { record -> Plan? in
            parsePlan(from: record)
        }
    }

    /// Planを削除
    func deletePlan(planId: String) async throws {
        let recordID = CKRecord.ID(recordName: planId)
        try await delete(recordID: recordID)
    }

    /// CKRecordからPlanをパース
    private func parsePlan(from record: CKRecord) -> Plan? {
        guard let userId = record["userId"] as? String,
              let title = record["title"] as? String,
              let startDate = record["startDate"] as? Date,
              let endDate = record["endDate"] as? Date,
              let createdAt = record["createdAt"] as? Date,
              let planTypeRaw = record["planType"] as? String,
              let planType = PlanType(rawValue: planTypeRaw) else {
            return nil
        }

        let cardColorHex = record["cardColorHex"] as? String
        let localImageFileName = record["localImageFileName"] as? String
        let time = record["time"] as? Date
        let description = record["description"] as? String
        let linkURL = record["linkURL"] as? String

        // JSON fields をパース
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var places: [PlannedPlace] = []
        if let placesJSON = record["placesJSON"] as? String,
           let placesData = placesJSON.data(using: .utf8),
           let decodedPlaces = try? decoder.decode([PlannedPlace].self, from: placesData) {
            places = decodedPlaces
        }

        var scheduleItems: [PlanScheduleItem] = []
        if let scheduleItemsJSON = record["scheduleItemsJSON"] as? String,
           let scheduleItemsData = scheduleItemsJSON.data(using: .utf8),
           let decodedItems = try? decoder.decode([PlanScheduleItem].self, from: scheduleItemsData) {
            scheduleItems = decodedItems
        }

        return Plan(
            id: record.recordID.recordName,
            title: title,
            startDate: startDate,
            endDate: endDate,
            places: places,
            cardColor: cardColorHex.flatMap { Color(hex: $0) },
            localImageFileName: localImageFileName,
            userId: userId,
            createdAt: createdAt,
            planType: planType,
            time: time,
            description: description,
            linkURL: linkURL,
            scheduleItems: scheduleItems
        )
    }

    // MARK: - TravelPlan Operations

    /// TravelPlanをCloudKitに保存（画像付き）
    func saveTravelPlan(_ plan: TravelPlan, userId: String, image: UIImage? = nil) async throws -> TravelPlan {

        let recordName = plan.id ?? UUID().uuidString

        let recordID = CKRecord.ID(recordName: recordName)

        // 既存のレコードを取得してから更新、存在しない場合は新規作成
        let record: CKRecord
        if plan.id != nil {
            // 既存レコードの取得を試みる
            do {
                record = try await privateDatabase.record(for: recordID)
            } catch {
                // レコードが存在しない場合は新規作成
                record = CKRecord(recordType: "TravelPlan", recordID: recordID)
            }
        } else {
            // idがnilの場合は新規作成
            record = CKRecord(recordType: "TravelPlan", recordID: recordID)
        }

        // Required fields
        record["userId"] = userId
        record["title"] = plan.title
        record["startDate"] = plan.startDate
        record["endDate"] = plan.endDate
        record["destination"] = plan.destination
        record["createdAt"] = plan.createdAt
        record["updatedAt"] = plan.updatedAt

        // Optional location fields
        if let latitude = plan.latitude {
            record["latitude"] = latitude
        }
        if let longitude = plan.longitude {
            record["longitude"] = longitude
        }

        // Optional fields
        if let cardColorHex = plan.cardColorHex {
            record["cardColorHex"] = cardColorHex
        }
        if let localImageFileName = plan.localImageFileName {
            record["localImageFileName"] = localImageFileName
        }

        // Sharing fields
        record["isShared"] = plan.isShared
        if let shareCode = plan.shareCode {
            record["shareCode"] = shareCode
        }
        if !plan.sharedWith.isEmpty {
            record["sharedWith"] = plan.sharedWith
        }
        if let ownerId = plan.ownerId {
            record["ownerId"] = ownerId
        }
        if let lastEditedBy = plan.lastEditedBy {
            record["lastEditedBy"] = lastEditedBy
        }

        // JSON fields
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        // daySchedules を JSON文字列に変換
        if !plan.daySchedules.isEmpty {
            if let daySchedulesData = try? encoder.encode(plan.daySchedules),
               let daySchedulesJSON = String(data: daySchedulesData, encoding: .utf8) {
                record["daySchedulesJSON"] = daySchedulesJSON
            }
        }

        // packingItems を JSON文字列に変換
        if !plan.packingItems.isEmpty {
            if let packingItemsData = try? encoder.encode(plan.packingItems),
               let packingItemsJSON = String(data: packingItemsData, encoding: .utf8) {
                record["packingItemsJSON"] = packingItemsJSON
            }
        }

        // 画像をCKAssetとして保存
        var tempURL: URL?
        if let image = image {
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                throw CloudKitError.invalidImageData
            }

            let imageSize = Double(imageData.count) / 1024.0 / 1024.0

            let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
            try imageData.write(to: url)
            tempURL = url

            let asset = CKAsset(fileURL: url)
            record["image"] = asset
        }

        // レコードを保存
        let savedRecord = try await save(record)

        // アップロード完了後に一時ファイルを削除
        if let tempURL = tempURL {
            try? FileManager.default.removeItem(at: tempURL)
        }

        // 保存されたレコードからTravelPlanを再構築
        var updatedPlan = plan
        updatedPlan.id = savedRecord.recordID.recordName
        updatedPlan.userId = userId

        return updatedPlan
    }

    /// ユーザーのTravelPlanを全て取得（画像付き）
    func fetchTravelPlans(userId: String) async throws -> [(plan: TravelPlan, image: UIImage?)] {

        // CloudKitはOR条件をサポートしていないため、2つのクエリを実行してマージ

        // 1. 自分が所有しているプランを取得
        let ownedPredicate = NSPredicate(format: "userId == %@", userId)
        let ownedRecords = try await query(recordType: "TravelPlan", predicate: ownedPredicate)

        // 2. 共有されているプランを取得（sharedWithフィールドが存在しない場合はスキップ）
        var sharedRecords: [CKRecord] = []
        do {
            let sharedPredicate = NSPredicate(format: "sharedWith CONTAINS %@", userId)
            sharedRecords = try await query(recordType: "TravelPlan", predicate: sharedPredicate)
        } catch {
            // sharedWithフィールドがまだCloudKitスキーマに存在しない場合
            if let ckError = error as? CKError, ckError.code == .invalidArguments {
            } else {
                // その他のエラーは再スロー
                throw error
            }
        }

        // 3. 重複を避けてマージ（recordIDで重複チェック）
        var recordsMap: [String: CKRecord] = [:]
        for record in ownedRecords {
            recordsMap[record.recordID.recordName] = record
        }
        for record in sharedRecords {
            recordsMap[record.recordID.recordName] = record
        }

        let allRecords = Array(recordsMap.values)

        var results: [(plan: TravelPlan, image: UIImage?)] = []

        for record in allRecords {
            if let plan = parseTravelPlan(from: record) {
                let image = try? await fetchImage(from: record, key: "image")
                results.append((plan: plan, image: image))
            }
        }


        return results
    }

    /// 共有コードでTravelPlanを検索
    func findTravelPlanByShareCode(_ shareCode: String) async throws -> TravelPlan? {
        let predicate = NSPredicate(format: "shareCode == %@", shareCode)
        let records = try await query(recordType: "TravelPlan", predicate: predicate)

        guard let record = records.first else {
            return nil
        }

        return parseTravelPlan(from: record)
    }

    /// TravelPlanの画像のみを取得
    func fetchTravelPlanImage(planId: String) async throws -> UIImage? {
        let recordID = CKRecord.ID(recordName: planId)
        let record = try await fetch(recordID: recordID)
        return try await fetchImage(from: record, key: "image")
    }

    /// TravelPlanを削除
    func deleteTravelPlan(planId: String) async throws {
        let recordID = CKRecord.ID(recordName: planId)
        try await delete(recordID: recordID)
    }

    /// CKRecordからTravelPlanをパース
    private func parseTravelPlan(from record: CKRecord) -> TravelPlan? {
        guard let userId = record["userId"] as? String,
              let title = record["title"] as? String,
              let startDate = record["startDate"] as? Date,
              let endDate = record["endDate"] as? Date,
              let destination = record["destination"] as? String,
              let createdAt = record["createdAt"] as? Date else {
            return nil
        }

        let latitude = record["latitude"] as? Double
        let longitude = record["longitude"] as? Double
        let cardColorHex = record["cardColorHex"] as? String
        let localImageFileName = record["localImageFileName"] as? String
        let updatedAt = record["updatedAt"] as? Date ?? Date()

        // Sharing fields
        let isShared = record["isShared"] as? Bool ?? false
        let shareCode = record["shareCode"] as? String
        let sharedWith = record["sharedWith"] as? [String] ?? []
        let ownerId = record["ownerId"] as? String
        let lastEditedBy = record["lastEditedBy"] as? String

        // JSON fields をパース
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var daySchedules: [DaySchedule] = []
        if let daySchedulesJSON = record["daySchedulesJSON"] as? String,
           let daySchedulesData = daySchedulesJSON.data(using: .utf8),
           let decodedSchedules = try? decoder.decode([DaySchedule].self, from: daySchedulesData) {
            daySchedules = decodedSchedules
        }

        var packingItems: [PackingItem] = []
        if let packingItemsJSON = record["packingItemsJSON"] as? String,
           let packingItemsData = packingItemsJSON.data(using: .utf8),
           let decodedItems = try? decoder.decode([PackingItem].self, from: packingItemsData) {
            packingItems = decodedItems
        }

        return TravelPlan(
            id: record.recordID.recordName,
            title: title,
            startDate: startDate,
            endDate: endDate,
            destination: destination,
            latitude: latitude,
            longitude: longitude,
            localImageFileName: localImageFileName,
            cardColor: cardColorHex.flatMap { Color(hex: $0) },
            createdAt: createdAt,
            userId: userId,
            daySchedules: daySchedules,
            packingItems: packingItems,
            isShared: isShared,
            shareCode: shareCode,
            sharedWith: sharedWith,
            ownerId: ownerId,
            lastEditedBy: lastEditedBy,
            updatedAt: updatedAt
        )
    }
}

// MARK: - CloudKit Errors
enum CloudKitError: LocalizedError {
    case accountNotAvailable
    case invalidImageData
    case recordNotFound
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .accountNotAvailable:
            return "iCloudアカウントが利用できません。設定からiCloudにサインインしてください。"
        case .invalidImageData:
            return "画像データが無効です。"
        case .recordNotFound:
            return "レコードが見つかりませんでした。"
        case .permissionDenied:
            return "iCloudへのアクセスが拒否されました。"
        }
    }
}
