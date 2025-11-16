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

    func add(_ plan: Plan, userId: String) {
        // CloudKitに保存
        Task {
            do {
                let savedPlan = try await CloudKitService.shared.savePlan(plan, userId: userId)
                NotificationService.shared.schedulePlanNotifications(for: savedPlan)
                // 保存後にリストを更新
                await MainActor.run {
                    self.refreshFromCloudKit(userId: userId)
                }
            } catch {
                print("❌ [PlansViewModel] Failed to add plan to CloudKit: \(error)")
            }
        }
    }

    func update(_ plan: Plan, userId: String) {
        // CloudKitに保存
        Task {
            do {
                let updatedPlan = try await CloudKitService.shared.savePlan(plan, userId: userId)
                NotificationService.shared.schedulePlanNotifications(for: updatedPlan)
                // 更新後にリストを更新
                await MainActor.run {
                    self.refreshFromCloudKit(userId: userId)
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

    func deletePlan(_ plan: Plan, userId: String? = nil) {
        NotificationService.shared.cancelPlanNotifications(for: plan.id)

        // CloudKitから削除
        Task {
            do {
                try await CloudKitService.shared.deletePlan(planId: plan.id)
                // 削除後にリストを更新
                if let userId = userId {
                    await MainActor.run {
                        self.refreshFromCloudKit(userId: userId)
                    }
                }
            } catch {
                print("❌ [PlansViewModel] Failed to delete plan from CloudKit: \(error)")
            }
        }
    }
}
