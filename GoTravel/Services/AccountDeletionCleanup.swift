import Foundation
import CoreData
import UserNotifications
import WidgetKit

/// 退会（アカウント削除）のときに、Core Data の外に残るものを片付ける。
///
/// Core Data の中身は `CoreDataManager.deleteAllUserData` が消し、iCloud（プライベートDB）にも
/// 削除が同期される。ただしそれだけでは、次のものが残っていた。
///
/// - **パブリックDBの共有レコード。** 共有した旅行計画・カテゴリは自動同期の外にあるので、
///   退会しても共有コードで読める状態のまま残る（ウェブで見るページも開ける）。
///   参加していた計画には、メンバーとして名前が残る
/// - 端末の中の写真（旅行計画のヘッダー写真・保存した場所の写真・予定の写真）
/// - 予約済みの通知。消した旅行の「明日です」が鳴る
/// - ウィジェットとライブアクティビティ。消した旅行が出続ける
/// - 端末の中の控え（旅行計画の控え・共有の突き合わせ用の覚え書き）
enum AccountDeletionCleanup {

    // MARK: - パブリックDBの共有

    /// 退会で片付ける共有レコード
    nonisolated struct SharedRecords: Codable, Equatable {
        var userId: String
        /// 自分が持ち主の旅行計画。レコードごと消す
        var ownedTravelPlanIds: [String] = []
        /// 参加していた旅行計画。自分だけを外す
        var joinedTravelPlanIds: [String] = []
        /// 自分が持ち主のカテゴリ。カテゴリと、その予定を消す
        var ownedCategoryIds: [String] = []
        /// 参加していたカテゴリ。自分だけを外す
        var joinedCategoryIds: [String] = []
        /// 片付けを試した回数。通信できないまま退会したときは、次の起動で続きをする
        var attempts = 0

        var isEmpty: Bool {
            ownedTravelPlanIds.isEmpty && joinedTravelPlanIds.isEmpty
                && ownedCategoryIds.isEmpty && joinedCategoryIds.isEmpty
        }
    }

    /// 手元のデータから、片付ける共有レコードを決める。
    ///
    /// 持ち主かどうかは `ownerId` で見る。**分からないもの（ownerId の無い古い共有）は
    /// 「参加していた」側に入れる。** そちらは外す前にレコードの持ち主を確かめるので、
    /// 他の人の計画を誤って消すことがない
    static func sharedRecords(travelPlans: [TravelPlan], categories: [PlanCategory],
                              userId: String) -> SharedRecords {
        var records = SharedRecords(userId: userId)
        for plan in travelPlans where plan.isShared {
            guard let planId = plan.id else { continue }
            if plan.ownerId == userId {
                records.ownedTravelPlanIds.append(planId)
            } else {
                records.joinedTravelPlanIds.append(planId)
            }
        }
        for category in categories where category.isShared {
            if category.ownerId == userId {
                records.ownedCategoryIds.append(category.id)
            } else {
                records.joinedCategoryIds.append(category.id)
            }
        }
        return records
    }

    /// Core Data を消す**前に**呼んで、片付ける共有レコードを控える
    static func collectSharedRecords(userId: String, context: NSManagedObjectContext) -> SharedRecords {
        let planRequest = TravelPlanEntity.fetchRequest()
        planRequest.predicate = NSPredicate(format: "userId == %@ OR ownerId == %@", userId, userId)
        let plans = ((try? context.fetch(planRequest)) ?? []).map { $0.toTravelPlan() }

        let categoryRequest = PlanCategoryEntity.fetchRequest()
        categoryRequest.predicate = NSPredicate(format: "userId == %@", userId)
        let categories = ((try? context.fetch(categoryRequest)) ?? []).map { $0.toCategory() }

        return sharedRecords(travelPlans: plans, categories: categories, userId: userId)
    }

    private static let pendingKey = "AccountDeletionPendingSharedCleanup_v1"
    /// これだけ試しても片付かなければ諦める（権限が無いなど、何度やっても通らない場合）
    private static let maxAttempts = 5

    /// 共有レコードを片付け始める。終わらなかった分は覚えておき、次の起動で続ける
    static func start(_ records: SharedRecords) {
        guard !records.isEmpty, !CoreDataManager.isEmptyDataMode else { return }
        savePending(records)
        Task { await runPending() }
    }

    /// アプリの起動時に呼ぶ。前回の退会で片付けきれなかった分があれば続ける
    static func resumeIfNeeded() {
        guard loadPending() != nil else { return }
        Task { await runPending() }
    }

    private static func runPending() async {
        guard var records = loadPending() else { return }
        records.attempts += 1
        // 先に回数を書く。途中でアプリが終わっても、いつまでも繰り返さない
        savePending(records)

        let remaining = await remove(records)
        if remaining.isEmpty || remaining.attempts >= maxAttempts {
            UserDefaults.standard.removeObject(forKey: pendingKey)
        } else {
            savePending(remaining)
        }
    }

    /// 1件ずつ片付ける。戻り値は片付けられなかった分
    private static func remove(_ records: SharedRecords) async -> SharedRecords {
        let cloud = CloudKitService.shared
        let userId = records.userId
        var remaining = records
        remaining.ownedTravelPlanIds = []
        remaining.joinedTravelPlanIds = []
        remaining.ownedCategoryIds = []
        remaining.joinedCategoryIds = []

        for planId in records.ownedTravelPlanIds {
            do {
                try await cloud.deleteSharedTravelPlan(planId: planId)
            } catch {
                remaining.ownedTravelPlanIds.append(planId)
            }
        }

        for planId in records.joinedTravelPlanIds {
            do {
                try await cloud.removeSharedMember(planId: planId, userId: userId)
            } catch {
                remaining.joinedTravelPlanIds.append(planId)
            }
        }

        for categoryId in records.ownedCategoryIds {
            do {
                try await removeOwnedCategory(categoryId: categoryId)
            } catch {
                remaining.ownedCategoryIds.append(categoryId)
            }
        }

        for categoryId in records.joinedCategoryIds {
            do {
                guard var record = try await cloud.fetchSharedCategory(categoryId: categoryId) else { continue }
                if record.ownerId == userId {
                    try await removeOwnedCategory(categoryId: categoryId)
                } else if record.sharedWith.contains(userId) {
                    record.sharedWith.removeAll { $0 == userId }
                    record.updatedAt = Date()
                    try await cloud.publishSharedCategory(record)
                }
            } catch {
                remaining.joinedCategoryIds.append(categoryId)
            }
        }

        return remaining
    }

    /// 持ち主としてカテゴリの共有を消す。
    /// カテゴリを先に消す（予定を先に消すと、その間に同期した友達の端末で
    /// 「誰かが予定を消した」とみなされ、友達の手元の予定まで消える。`SharedCategoryService.stopSharing`）
    private static func removeOwnedCategory(categoryId: String) async throws {
        let cloud = CloudKitService.shared
        // 予定の一覧は先に取っておく。取れなかったときは何も消さずに、次の起動でやり直す
        let plans = try await cloud.fetchSharedPlans(categoryId: categoryId)
        try await cloud.deleteSharedCategory(categoryId: categoryId)
        for plan in plans {
            try await cloud.deleteSharedPlan(planId: plan.id)
        }
    }

    private static func loadPending() -> SharedRecords? {
        guard let data = UserDefaults.standard.data(forKey: pendingKey) else { return nil }
        return try? JSONDecoder().decode(SharedRecords.self, from: data)
    }

    private static func savePending(_ records: SharedRecords) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: pendingKey)
    }

    // MARK: - 端末の中に残るもの

    /// 写真のファイルと、端末の中の控えを消す。**Core Data を消す前に呼ぶ**（ファイル名を読むため）。
    ///
    /// アルバムとフォトマップの写真は `AlbumManager.deleteAllData` が消す。
    /// iCloud に預けた写真（`PhotoAssetEntity`）は `deleteAllUserData` がまとめて消すので、
    /// ここでは端末のファイルだけを消す
    static func removeLocalFiles(userId: String, context: NSManagedObjectContext) {
        var fileNames: [String] = []

        let planRequest = TravelPlanEntity.fetchRequest()
        planRequest.predicate = NSPredicate(format: "userId == %@ OR ownerId == %@", userId, userId)
        for entity in (try? context.fetch(planRequest)) ?? [] {
            if let fileName = entity.localImageFileName { fileNames.append(fileName) }
            if let planId = entity.id { SharedPlanBaseStore.remove(planId: planId) }
        }

        for entity in (try? VisitedPlaceEntity.fetchByUser(userId: userId, context: context)) ?? [] {
            if let fileName = entity.localPhotoFileName { fileNames.append(fileName) }
        }

        for entity in (try? PlanEntity.fetchByUser(userId: userId, context: context)) ?? [] {
            if let fileName = entity.localImageFileName { fileNames.append(fileName) }
            if let planId = entity.id { PlanShareBaseStore.remove(planId: planId) }
        }

        let categoryRequest = PlanCategoryEntity.fetchRequest()
        categoryRequest.predicate = NSPredicate(format: "userId == %@", userId)
        for entity in (try? context.fetch(categoryRequest)) ?? [] {
            if let categoryId = entity.id { PlanShareBaseStore.removeCategoryTags(categoryId: categoryId) }
        }

        let documents = FileManager.documentsDirectory()
        for fileName in fileNames where !fileName.isEmpty {
            try? FileManager.default.removeItem(at: documents.appendingPathComponent(fileName))
        }

        TravelPlanBackupStore.remove()
    }

    /// 予約済みの通知・ウィジェット・ライブアクティビティから、消したデータを外す
    static func clearDeviceTraces() {
        guard !CoreDataManager.isEmptyDataMode else { return }

        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()

        WidgetDataStore.save(.empty)
        WidgetCenter.shared.reloadAllTimelines()
        TravelLiveActivity.sync(with: .empty)
    }
}
