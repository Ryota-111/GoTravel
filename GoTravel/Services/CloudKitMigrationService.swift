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
        print("✅ [Migration] Migration marked as complete")
    }

    /// 移行フラグをリセット（テスト用）
    func resetMigrationFlag() {
        UserDefaults.standard.removeObject(forKey: migrationKey)
        print("⚠️ [Migration] Migration flag reset")
    }

    // MARK: - Migration Process

    /// 全データをCloudKitからCore Dataに移行
    func migrateAllData(userId: String) async throws {
        guard !hasMigrated else {
            print("ℹ️ [Migration] Migration already completed, skipping")
            return
        }

        print("🔄 [Migration] Starting CloudKit to Core Data migration...")
        print("🔄 [Migration] UserId: \(userId)")

        do {
            // TravelPlanを移行
            try await migrateTravelPlans(userId: userId)

            // Planを移行
            try await migratePlans(userId: userId)

            // VisitedPlaceを移行
            try await migrateVisitedPlaces(userId: userId)

            // 移行完了をマーク
            markMigrationComplete()

            print("✅ [Migration] Migration completed successfully!")

        } catch {
            print("❌ [Migration] Migration failed: \(error)")
            throw error
        }
    }

    // MARK: - TravelPlan Migration

    /// TravelPlanをCloudKitからCore Dataに移行
    private func migrateTravelPlans(userId: String) async throws {
        print("🔄 [Migration] Migrating TravelPlans...")

        // CloudKitから既存データを取得
        let results = try await cloudKitService.fetchTravelPlans(userId: userId)
        print("🔄 [Migration] Found \(results.count) TravelPlans in CloudKit")

        guard !results.isEmpty else {
            print("ℹ️ [Migration] No TravelPlans to migrate")
            return
        }

        // Core Dataに保存
        await context.perform {
            for (plan, image) in results {
                print("🔄 [Migration] - Migrating TravelPlan: \(plan.title)")

                // 既存のエンティティをチェック
                guard let planId = plan.id else { continue }

                do {
                    if let existingEntity = try TravelPlanEntity.fetchById(id: planId, context: self.context) {
                        print("  ℹ️ Plan already exists in Core Data, skipping: \(plan.title)")
                        continue
                    }
                } catch {
                    print("  ⚠️ Error checking existing entity: \(error)")
                }

                // 画像をローカルファイルに保存
                var updatedPlan = plan
                if let image = image, updatedPlan.localImageFileName == nil {
                    let fileName = "travel_plan_\(UUID().uuidString).jpg"
                    if let imageData = image.jpegData(compressionQuality: 0.7) {
                        do {
                            try FileManager.saveImageDataToDocuments(data: imageData, named: fileName)
                            updatedPlan.localImageFileName = fileName
                            print("  ✅ Image saved locally: \(fileName)")
                        } catch {
                            print("  ❌ Failed to save image: \(error)")
                        }
                    }
                }

                // Core Dataエンティティを作成
                _ = TravelPlanEntity.create(from: updatedPlan, context: self.context)
            }

            // 保存
            CoreDataManager.shared.saveContext()
            print("✅ [Migration] TravelPlans migrated to Core Data")
        }
    }

    // MARK: - Plan Migration

    /// PlanをCloudKitからCore Dataに移行
    private func migratePlans(userId: String) async throws {
        print("🔄 [Migration] Migrating Plans...")

        // CloudKitから既存データを取得
        let plans = try await cloudKitService.fetchPlans(userId: userId)
        print("🔄 [Migration] Found \(plans.count) Plans in CloudKit")

        guard !plans.isEmpty else {
            print("ℹ️ [Migration] No Plans to migrate")
            return
        }

        // Core Dataに保存
        await context.perform {
            for plan in plans {
                print("🔄 [Migration] - Migrating Plan: \(plan.title)")

                // 既存のエンティティをチェック
                do {
                    if let existingEntity = try PlanEntity.fetchById(id: plan.id, context: self.context) {
                        print("  ℹ️ Plan already exists in Core Data, skipping: \(plan.title)")
                        continue
                    }
                } catch {
                    print("  ⚠️ Error checking existing entity: \(error)")
                }

                _ = PlanEntity.create(from: plan, context: self.context)
            }

            // 保存
            CoreDataManager.shared.saveContext()
            print("✅ [Migration] Plans migrated to Core Data")
        }
    }

    // MARK: - VisitedPlace Migration

    /// VisitedPlaceをCloudKitからCore Dataに移行
    private func migrateVisitedPlaces(userId: String) async throws {
        print("🔄 [Migration] Migrating VisitedPlaces...")

        // CloudKitから既存データを取得
        let results = try await cloudKitService.fetchVisitedPlaces(userId: userId)
        print("🔄 [Migration] Found \(results.count) VisitedPlaces in CloudKit")

        guard !results.isEmpty else {
            print("ℹ️ [Migration] No VisitedPlaces to migrate")
            return
        }

        // Core Dataに保存
        await context.perform {
            for (place, image) in results {
                print("🔄 [Migration] - Migrating VisitedPlace: \(place.title)")

                // 既存のエンティティをチェック
                guard let placeId = place.id else { continue }

                do {
                    if let existingEntity = try VisitedPlaceEntity.fetchById(id: placeId, context: self.context) {
                        print("  ℹ️ Place already exists in Core Data, skipping: \(place.title)")
                        continue
                    }
                } catch {
                    print("  ⚠️ Error checking existing entity: \(error)")
                }

                // 画像をローカルファイルに保存
                var updatedPlace = place
                if let image = image, updatedPlace.localPhotoFileName == nil {
                    let fileName = "visited_place_\(UUID().uuidString).jpg"
                    if let imageData = image.jpegData(compressionQuality: 0.7) {
                        do {
                            try FileManager.saveImageDataToDocuments(data: imageData, named: fileName)
                            updatedPlace.localPhotoFileName = fileName
                            print("  ✅ Image saved locally: \(fileName)")
                        } catch {
                            print("  ❌ Failed to save image: \(error)")
                        }
                    }
                }

                // Core Dataエンティティを作成
                _ = VisitedPlaceEntity.create(from: updatedPlace, context: self.context)
            }

            // 保存
            CoreDataManager.shared.saveContext()
            print("✅ [Migration] VisitedPlaces migrated to Core Data")
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
                        print("❌ Failed to save image: \(error)")
                    }
                }
            }

            _ = TravelPlanEntity.create(from: updatedPlan, context: self.context)
            CoreDataManager.shared.saveContext()
            print("✅ Migrated single TravelPlan: \(plan.title)")
        }
    }
}
