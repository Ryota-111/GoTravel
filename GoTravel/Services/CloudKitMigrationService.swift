import Foundation
import CoreData
import UIKit

/// CloudKitの既存データをCore Dataに移行するサービス
final class CloudKitMigrationService {

    static let shared = CloudKitMigrationService()

    private let cloudKitService = CloudKitService.shared
    private let context = CoreDataManager.shared.viewContext

    private let migrationKey = "hasCompletedCloudKitMigration_v1"

    private init() {}

    // MARK: - Migration Status

    /// 移行が完了しているかチェック
    var hasMigrated: Bool {
        return UserDefaults.standard.bool(forKey: migrationKey)
    }

    /// 移行完了フラグをセット
    private func markMigrationComplete() {
        UserDefaults.standard.set(true, forKey: migrationKey)
    }

    /// 移行フラグをリセット（テスト用）
    func resetMigrationFlag() {
        UserDefaults.standard.removeObject(forKey: migrationKey)
    }

    // MARK: - Migration Process

    /// 全データをCloudKitからCore Dataに移行
    func migrateAllData(userId: String) async throws {
        // 空データモードでは走らせない。中身は空なのに「移行済み」の印だけが
        // 端末に残り、実データでの移行が二度と走らなくなる
        guard !CoreDataManager.isEmptyDataMode else { return }
        guard !hasMigrated else {
            return
        }


        do {
            // TravelPlanを移行
            let travelPlanIds = try await migrateTravelPlans(userId: userId)

            // Planを移行
            let planIds = try await migratePlans(userId: userId)

            // VisitedPlaceを移行
            let placeIds = try await migrateVisitedPlaces(userId: userId)

            // 移行完了をマーク
            markMigrationComplete()

            // 移行元を片付ける。これをしないと、アプリを消して入れ直したときに
            // 移行がもう一度走ってしまう（下の説明を参照）
            await deleteMigratedSources(
                userId: userId,
                travelPlanIds: travelPlanIds,
                planIds: planIds,
                placeIds: placeIds
            )

        } catch {
            throw error
        }
    }

    // MARK: - 移行元の後片付け

    /// 移行が済んだ旧レコードをCloudKitから消す。
    ///
    /// **削除した旅行計画が、アプリを入れ直すと復活する不具合の対処。**
    ///
    /// 移行済みの印は `UserDefaults` にあり、アプリを削除すると一緒に消える。
    /// 入れ直すと移行がもう一度走り、旧レコードに残っていた
    /// 「移行後に削除した計画」まで Core Data に書き戻されていた。
    /// 削除は Core Data 側にしか反映されておらず、旧レコードは残ったままだったため。
    ///
    /// 印の置き場所を変えるだけでは直らない。入れ直した直後は印の同期が
    /// 終わっておらず、印が降りてくる前に移行が走る余地が残る。
    /// **移行元そのものを消せば、何度走っても復活しない。**
    ///
    /// 移行後のデータは Core Data にあり、そちらは
    /// `NSPersistentCloudKitContainer` が別のレコード型で同期している。
    /// 入れ直しても、そこから正しく（削除も反映された状態で）戻ってくる。
    ///
    /// 消すのは **Core Data に在ることを確かめたものだけ。** 移行の途中で
    /// 失敗していた場合に、移行元だけ消えてデータが消滅するのを防ぐ
    private func deleteMigratedSources(userId: String,
                                       travelPlanIds: [String],
                                       planIds: [String],
                                       placeIds: [String]) async {
        let confirmedTravelPlans = await confirmedInCoreData(travelPlanIds) {
            try TravelPlanEntity.fetchById(id: $0, context: $1) != nil
        }
        let confirmedPlans = await confirmedInCoreData(planIds) {
            try PlanEntity.fetchById(id: $0, context: $1) != nil
        }
        let confirmedPlaces = await confirmedInCoreData(placeIds) {
            try VisitedPlaceEntity.fetchById(id: $0, context: $1) != nil
        }

        // 1件ずつ消す。まとめて消して途中で失敗すると、どこまで消えたか分からなくなる。
        // 消し損ねても実害は「次に入れ直したときにまた移行が走る」だけなので、
        // 失敗は握りつぶして次へ進む
        for id in confirmedTravelPlans {
            try? await cloudKitService.deleteTravelPlan(planId: id)
        }
        for id in confirmedPlans {
            try? await cloudKitService.deletePlan(planId: id)
        }
        for id in confirmedPlaces {
            try? await cloudKitService.deleteVisitedPlace(placeId: id)
        }
    }

    /// Core Data に実際に入っているものだけを残す
    private func confirmedInCoreData(
        _ ids: [String],
        _ exists: @escaping (String, NSManagedObjectContext) throws -> Bool
    ) async -> [String] {
        await context.perform {
            ids.filter { (try? exists($0, self.context)) == true }
        }
    }

    // MARK: - TravelPlan Migration

    /// TravelPlanをCloudKitからCore Dataに移行。
    /// 戻り値は移行元を消してよいID（自分が持ち主のものだけ）
    @discardableResult
    private func migrateTravelPlans(userId: String) async throws -> [String] {

        // CloudKitから既存データを取得
        let results = try await cloudKitService.fetchTravelPlans(userId: userId)

        guard !results.isEmpty else {
            return []
        }

        // 共有されて見えているだけの計画は、持ち主が別にいる。
        // 移行元を消すと相手の計画を消すことになるので、自分のものだけ返す
        let ownedIds = results.compactMap { (plan, _) -> String? in
            guard let id = plan.id, plan.userId == userId else { return nil }
            return id
        }

        // Core Dataに保存
        await context.perform {
            for (plan, image) in results {

                // 既存のエンティティをチェック
                guard let planId = plan.id else { continue }

                do {
                    if (try TravelPlanEntity.fetchById(id: planId, context: self.context)) != nil {
                        continue
                    }
                } catch {
                }

                // 画像をローカルファイルに保存
                var updatedPlan = plan
                if let image = image, updatedPlan.localImageFileName == nil {
                    let fileName = "travel_plan_\(UUID().uuidString).jpg"
                    if let imageData = image.storedPhotoData() {
                        do {
                            try FileManager.saveImageDataToDocuments(data: imageData, named: fileName)
                            updatedPlan.localImageFileName = fileName
                        } catch {
                        }
                    }
                }

                // Core Dataエンティティを作成
                _ = TravelPlanEntity.create(from: updatedPlan, context: self.context)
            }

            // 保存
            CoreDataManager.shared.saveContext()
        }

        return ownedIds
    }

    // MARK: - Plan Migration

    /// PlanをCloudKitからCore Dataに移行。
    /// 戻り値は移行元を消してよいID
    @discardableResult
    private func migratePlans(userId: String) async throws -> [String] {

        // CloudKitから既存データを取得
        let plans = try await cloudKitService.fetchPlans(userId: userId)

        guard !plans.isEmpty else {
            return []
        }

        // Core Dataに保存
        await context.perform {
            for plan in plans {

                // 既存のエンティティをチェック
                do {
                    if (try PlanEntity.fetchById(id: plan.id, context: self.context)) != nil {
                        continue
                    }
                } catch {
                }

                _ = PlanEntity.create(from: plan, context: self.context)
            }

            // 保存
            CoreDataManager.shared.saveContext()
        }

        return plans.map { $0.id }
    }

    // MARK: - VisitedPlace Migration

    /// VisitedPlaceをCloudKitからCore Dataに移行。
    /// 戻り値は移行元を消してよいID
    @discardableResult
    private func migrateVisitedPlaces(userId: String) async throws -> [String] {

        // CloudKitから既存データを取得
        let results = try await cloudKitService.fetchVisitedPlaces(userId: userId)

        guard !results.isEmpty else {
            return []
        }

        // Core Dataに保存
        await context.perform {
            for (place, image) in results {

                // 既存のエンティティをチェック
                guard let placeId = place.id else { continue }

                do {
                    if (try VisitedPlaceEntity.fetchById(id: placeId, context: self.context)) != nil {
                        continue
                    }
                } catch {
                }

                // 画像をローカルファイルに保存
                var updatedPlace = place
                if let image = image, updatedPlace.localPhotoFileName == nil {
                    let fileName = "visited_place_\(UUID().uuidString).jpg"
                    if let imageData = image.storedPhotoData() {
                        do {
                            try FileManager.saveImageDataToDocuments(data: imageData, named: fileName)
                            updatedPlace.localPhotoFileName = fileName
                        } catch {
                        }
                    }
                }

                // Core Dataエンティティを作成
                _ = VisitedPlaceEntity.create(from: updatedPlace, context: self.context)
            }

            // 保存
            CoreDataManager.shared.saveContext()
        }

        return results.compactMap { $0.place.id }
    }

    // MARK: - Manual Migration (for testing)

    /// 特定のTravelPlanを手動で移行（テスト用）
    func migrateSingleTravelPlan(_ plan: TravelPlan, image: UIImage?) async {
        await context.perform {
            var updatedPlan = plan

            // 画像をローカルファイルに保存
            if let image = image {
                let fileName = "travel_plan_\(UUID().uuidString).jpg"
                if let imageData = image.storedPhotoData() {
                    do {
                        try FileManager.saveImageDataToDocuments(data: imageData, named: fileName)
                        updatedPlan.localImageFileName = fileName
                    } catch {
                    }
                }
            }

            _ = TravelPlanEntity.create(from: updatedPlan, context: self.context)
            CoreDataManager.shared.saveContext()
        }
    }
}
