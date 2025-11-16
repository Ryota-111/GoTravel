import SwiftUI
import Foundation
import Combine

final class PlansViewModel: ObservableObject {
    @Published var plans: [Plan] = []
    private var refreshTask: Task<Void, Never>?

    init() {
        // CloudKitからのデータ取得は各Viewで明示的に呼び出す
    }

    deinit {
        refreshTask?.cancel()
    }

    // CloudKitからデータを取得（userIdが必要）
    func refreshFromCloudKit(userId: String? = nil) {
        print("🟠 [PlansViewModel] Starting CloudKit refresh")
        print("🟠 [PlansViewModel] - userId: \(userId ?? "nil")")
        refreshTask?.cancel()

        refreshTask = Task { @MainActor in
            guard let userId = userId else {
                print("❌ [PlansViewModel] userId is nil, cannot fetch")
                return
            }

            do {
                print("🟠 [PlansViewModel] Fetching from CloudKit...")
                let results = try await CloudKitService.shared.fetchPlans(userId: userId)
                print("✅ [PlansViewModel] Fetched \(results.count) plans from CloudKit")

                self.plans = results
            } catch {
                print("❌ [PlansViewModel] Failed to fetch from CloudKit: \(error)")
                print("❌ [PlansViewModel] Error details: \(error.localizedDescription)")
                self.plans = []
            }
        }
    }

    @MainActor
    func add(_ plan: Plan, userId: String) {
        // 即座にローカルリストに追加（UI更新）
        plans.append(plan)
        print("✅ [PlansViewModel] Added plan to local list immediately")

        // バックグラウンドでCloudKitに保存
        Task {
            do {
                let savedPlan = try await CloudKitService.shared.savePlan(plan, userId: userId)
                print("✅ [PlansViewModel] Plan saved to CloudKit")
                NotificationService.shared.schedulePlanNotifications(for: savedPlan)

                // CloudKitから返された最新のプランでローカルを更新
                await MainActor.run {
                    if let index = self.plans.firstIndex(where: { $0.id == plan.id }) {
                        self.plans[index] = savedPlan
                    }
                }
            } catch {
                print("❌ [PlansViewModel] Failed to add plan to CloudKit: \(error)")
                // エラーの場合、ローカルから削除
                await MainActor.run {
                    self.plans.removeAll { $0.id == plan.id }
                }
            }
        }
    }

    @MainActor
    func update(_ plan: Plan, userId: String) {
        // 即座にローカルリストを更新（UI更新）
        if let index = plans.firstIndex(where: { $0.id == plan.id }) {
            plans[index] = plan
        }
        print("✅ [PlansViewModel] Updated plan in local list immediately")

        // バックグラウンドでCloudKitに保存
        Task {
            do {
                let updatedPlan = try await CloudKitService.shared.savePlan(plan, userId: userId)
                print("✅ [PlansViewModel] Plan updated in CloudKit")
                NotificationService.shared.schedulePlanNotifications(for: updatedPlan)

                // CloudKitから返された最新のプランでローカルを更新
                await MainActor.run {
                    if let index = self.plans.firstIndex(where: { $0.id == plan.id }) {
                        self.plans[index] = updatedPlan
                    }
                }
            } catch {
                print("❌ [PlansViewModel] Failed to update plan in CloudKit: \(error)")
            }
        }
    }

    func delete(at offsets: IndexSet, userId: String? = nil) {
        for index in offsets {
           let plan = plans[index]
           deletePlan(plan, userId: userId)
        }
    }

    @MainActor
    func deletePlan(_ plan: Plan, userId: String? = nil) {
        NotificationService.shared.cancelPlanNotifications(for: plan.id)

        // 即座にローカルリストから削除（UI更新）
        plans.removeAll { $0.id == plan.id }
        print("✅ [PlansViewModel] Removed plan from local list immediately")

        // バックグラウンドでCloudKitから削除
        Task {
            do {
                try await CloudKitService.shared.deletePlan(planId: plan.id)
                print("✅ [PlansViewModel] Plan deleted from CloudKit")
            } catch {
                print("❌ [PlansViewModel] Failed to delete plan from CloudKit: \(error)")
                // エラーの場合、削除をロールバック
                if let userId = userId {
                    self.refreshFromCloudKit(userId: userId)
                }
            }
        }
    }
}
