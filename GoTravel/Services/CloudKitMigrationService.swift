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
        guard !hasMigrated else {
            return
        }


        do {
            // TravelPlanを移行
            try await migrateTravelPlans(userId: userId)

            // Planを移行
            try await migratePlans(userId: userId)

            // VisitedPlaceを移行
            try await migrateVisitedPlaces(userId: userId)

            // 移行完了をマーク
            markMigrationComplete()


        } catch {
            throw error
        }
    }

    // MARK: - TravelPlan Migration

    /// TravelPlanをCloudKitからCore Dataに移行
    private func migrateTravelPlans(userId: String) async throws {

        // CloudKitから既存データを取得
        let results = try await cloudKitService.fetchTravelPlans(userId: userId)

        guard !results.isEmpty else {
            return
        }

        // Core Dataに保存
        await context.perform {
            for (plan, image) in results {

                // 既存のエンティティをチェック
                guard let planId = plan.id else { continue }

                do {
                    if let existingEntity = try TravelPlanEntity.fetchById(id: planId, context: self.context) {
                        continue
                    }
                } catch {
                }

                // 画像をローカルファイルに保存
                var updatedPlan = plan
                if let image = image, updatedPlan.localImageFileName == nil {
                    let fileName = "travel_plan_\(UUID().uuidString).jpg"
                    if let imageData = image.jpegData(compressionQuality: 0.7) {
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
    }

    // MARK: - Plan Migration

    /// PlanをCloudKitからCore Dataに移行
    private func migratePlans(userId: String) async throws {

        // CloudKitから既存データを取得
        let plans = try await cloudKitService.fetchPlans(userId: userId)

        guard !plans.isEmpty else {
            return
        }

        // Core Dataに保存
        await context.perform {
            for plan in plans {

                // 既存のエンティティをチェック
                do {
                    if let existingEntity = try PlanEntity.fetchById(id: plan.id, context: self.context) {
                        continue
                    }
                } catch {
                }

                _ = PlanEntity.create(from: plan, context: self.context)
            }

            // 保存
            CoreDataManager.shared.saveContext()
        }
    }

    // MARK: - VisitedPlace Migration

    /// VisitedPlaceをCloudKitからCore Dataに移行
    private func migrateVisitedPlaces(userId: String) async throws {

        // CloudKitから既存データを取得
        let results = try await cloudKitService.fetchVisitedPlaces(userId: userId)

        guard !results.isEmpty else {
            return
        }

        // Core Dataに保存
        await context.perform {
            for (place, image) in results {

                // 既存のエンティティをチェック
                guard let placeId = place.id else { continue }

                do {
                    if let existingEntity = try VisitedPlaceEntity.fetchById(id: placeId, context: self.context) {
                        continue
                    }
                } catch {
                }

                // 画像をローカルファイルに保存
                var updatedPlace = place
                if let image = image, updatedPlace.localPhotoFileName == nil {
                    let fileName = "visited_place_\(UUID().uuidString).jpg"
                    if let imageData = image.jpegData(compressionQuality: 0.7) {
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
    }

    // MARK: - Manual Migration (for testing)

    /// 特定のTravelPlanを手動で移行（テスト用）
    func migrateSingleTravelPlan(_ plan: TravelPlan, image: UIImage?) async {
        await context.perform {
            var updatedPlan = plan

            // 画像をローカルファイルに保存
            if let image = image {
                let fileName = "travel_plan_\(UUID().uuidString).jpg"
                if let imageData = image.jpegData(compressionQuality: 0.7) {
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
