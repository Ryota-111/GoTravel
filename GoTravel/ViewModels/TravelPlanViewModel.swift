import Foundation
import Combine
import UIKit

final class TravelPlanViewModel: ObservableObject {
    @Published var travelPlans: [TravelPlan] = []
    @Published var planImages: [String: UIImage] = [:] // planId: image
    private var refreshTask: Task<Void, Never>?

    init() {
        // CloudKitからのデータ取得は各Viewで明示的に呼び出す
    }

    deinit {
        refreshTask?.cancel()
    }

    // CloudKitからデータを取得（userIdが必要）
    func refreshFromCloudKit(userId: String? = nil) {
        print("🟣 [TravelPlanViewModel] Starting CloudKit refresh")
        print("🟣 [TravelPlanViewModel] - userId: \(userId ?? "nil")")
        refreshTask?.cancel()

        refreshTask = Task { @MainActor in
            guard let userId = userId else {
                print("❌ [TravelPlanViewModel] userId is nil, cannot fetch")
                return
            }

            do {
                print("🟣 [TravelPlanViewModel] Fetching from CloudKit...")
                let results = try await CloudKitService.shared.fetchTravelPlans(userId: userId)
                print("✅ [TravelPlanViewModel] Fetched \(results.count) travel plans from CloudKit")

                // TravelPlanと画像を分離
                self.travelPlans = results.map { $0.plan }

                // 画像をキャッシュ
                var imageCount = 0
                for result in results {
                    if let image = result.image, let planId = result.plan.id {
                        self.planImages[planId] = image
                        imageCount += 1
                    }
                }
                print("✅ [TravelPlanViewModel] Cached \(imageCount) images")
            } catch {
                print("❌ [TravelPlanViewModel] Failed to fetch from CloudKit: \(error)")
                print("❌ [TravelPlanViewModel] Error details: \(error.localizedDescription)")
                self.travelPlans = []
            }
        }
    }

    // 特定のTravelPlanの画像を取得
    func loadImage(for planId: String) async -> UIImage? {
        // キャッシュをチェック
        if let cached = planImages[planId] {
            return cached
        }

        // CloudKitから取得
        do {
            let image = try await CloudKitService.shared.fetchTravelPlanImage(planId: planId)
            await MainActor.run {
                if let image = image {
                    self.planImages[planId] = image
                }
            }
            return image
        } catch {
            print("❌ [TravelPlanViewModel] Failed to load image: \(error)")
            return nil
        }
    }

    @MainActor
    func add(_ plan: TravelPlan, userId: String, image: UIImage? = nil) {
        // 即座にローカルリストに追加（UI更新）
        travelPlans.append(plan)
        if let image = image, let planId = plan.id {
            planImages[planId] = image
        }
        print("✅ [TravelPlanViewModel] Added plan to local list immediately")

        // バックグラウンドでCloudKitに保存
        Task {
            do {
                let savedPlan = try await CloudKitService.shared.saveTravelPlan(plan, userId: userId, image: image)
                print("✅ [TravelPlanViewModel] Plan saved to CloudKit")
                NotificationService.shared.scheduleTravelPlanNotifications(for: savedPlan)

                // CloudKitから返された最新のプランでローカルを更新
                await MainActor.run {
                    if let index = self.travelPlans.firstIndex(where: { $0.id == plan.id }) {
                        self.travelPlans[index] = savedPlan
                    }
                }
            } catch {
                print("❌ [TravelPlanViewModel] Failed to add plan to CloudKit: \(error)")
                // エラーの場合、ローカルから削除
                await MainActor.run {
                    self.travelPlans.removeAll { $0.id == plan.id }
                    if let planId = plan.id {
                        self.planImages.removeValue(forKey: planId)
                    }
                }
            }
        }
    }

    @MainActor
    func update(_ plan: TravelPlan, userId: String, image: UIImage? = nil) {
        // 即座にローカルリストを更新（UI更新）
        if let index = travelPlans.firstIndex(where: { $0.id == plan.id }) {
            travelPlans[index] = plan
        }
        if let image = image, let planId = plan.id {
            planImages[planId] = image
        }
        print("✅ [TravelPlanViewModel] Updated plan in local list immediately")

        // バックグラウンドでCloudKitに保存
        Task {
            do {
                let updatedPlan = try await CloudKitService.shared.saveTravelPlan(plan, userId: userId, image: image)
                print("✅ [TravelPlanViewModel] Plan updated in CloudKit")
                NotificationService.shared.scheduleTravelPlanNotifications(for: updatedPlan)

                // CloudKitから返された最新のプランでローカルを更新
                await MainActor.run {
                    if let index = self.travelPlans.firstIndex(where: { $0.id == plan.id }) {
                        self.travelPlans[index] = updatedPlan
                    }
                }
            } catch {
                print("❌ [TravelPlanViewModel] Failed to update plan in CloudKit: \(error)")
            }
        }
    }

    @MainActor
    func delete(_ plan: TravelPlan, userId: String? = nil) {
        if let planId = plan.id {
            NotificationService.shared.cancelTravelPlanNotifications(for: planId)
        }

        // 即座にローカルリストから削除（UI更新）
        travelPlans.removeAll { $0.id == plan.id }
        if let planId = plan.id {
            planImages.removeValue(forKey: planId)
        }
        print("✅ [TravelPlanViewModel] Removed plan from local list immediately")

        // バックグラウンドでCloudKitから削除
        Task {
            do {
                if let planId = plan.id {
                    try await CloudKitService.shared.deleteTravelPlan(planId: planId)
                    print("✅ [TravelPlanViewModel] Plan deleted from CloudKit")
                }
            } catch {
                print("❌ [TravelPlanViewModel] Failed to delete plan from CloudKit: \(error)")
                // エラーの場合、削除をロールバック
                if let userId = userId {
                    self.refreshFromCloudKit(userId: userId)
                }
            }
        }
    }

    // MARK: - Sharing Methods
    func updateShareCode(planId: String, shareCode: String, userId: String) {
        guard var plan = travelPlans.first(where: { $0.id == planId }) else { return }
        plan.isShared = true
        plan.shareCode = shareCode
        plan.ownerId = plan.userId
        plan.updatedAt = Date()
        update(plan, userId: userId)
    }

    func joinPlanByShareCode(_ shareCode: String, userId: String, completion: @escaping (Result<TravelPlan, Error>) -> Void) {
        // CloudKitで共有プランを検索
        Task {
            do {
                guard var plan = try await CloudKitService.shared.findTravelPlanByShareCode(shareCode) else {
                    await MainActor.run {
                        completion(.failure(APIClientError.notFound))
                    }
                    return
                }

                // 現在のユーザーをsharedWith配列に追加
                if !plan.sharedWith.contains(userId) {
                    plan.sharedWith.append(userId)
                    plan.updatedAt = Date()

                    // 更新を保存（プランのownerIdを使用）
                    let updatedPlan = try await CloudKitService.shared.saveTravelPlan(plan, userId: plan.userId ?? userId)

                    await MainActor.run {
                        completion(.success(updatedPlan))
                        // リストを更新
                        self.refreshFromCloudKit(userId: userId)
                    }
                } else {
                    await MainActor.run {
                        completion(.success(plan))
                    }
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
}
