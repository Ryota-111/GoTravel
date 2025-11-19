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
        refreshTask?.cancel()

        refreshTask = Task { @MainActor in
            guard let userId = userId else {
                return
            }

            do {
                let results = try await CloudKitService.shared.fetchPlans(userId: userId)
                self.plans = results
            } catch {
                self.plans = []
            }
        }
    }

    @MainActor
    func add(_ plan: Plan, userId: String) {
        print("🟢 [PlansViewModel] add() called")
        print("🟢 [PlansViewModel] - plan.id: \(plan.id)")
        print("🟢 [PlansViewModel] - plan.title: \(plan.title)")
        print("🟢 [PlansViewModel] - userId: \(userId)")

        plans.append(plan)
        print("🟢 [PlansViewModel] - plan added to local array, plans.count: \(plans.count)")

        Task {
            do {
                print("🟢 [PlansViewModel] - calling CloudKitService.savePlan()")
                let savedPlan = try await CloudKitService.shared.savePlan(plan, userId: userId)
                print("✅ [PlansViewModel] - CloudKit save SUCCESS")

                NotificationService.shared.schedulePlanNotifications(for: savedPlan)

                await MainActor.run {
                    if let index = self.plans.firstIndex(where: { $0.id == plan.id }) {
                        self.plans[index] = savedPlan
                        print("✅ [PlansViewModel] - Updated plan in array at index \(index)")
                    }
                }
            } catch {
                print("❌ [PlansViewModel] - CloudKit save FAILED: \(error)")
                print("❌ [PlansViewModel] - Error description: \(error.localizedDescription)")
                await MainActor.run {
                    self.plans.removeAll { $0.id == plan.id }
                    print("❌ [PlansViewModel] - Removed plan from local array, plans.count: \(self.plans.count)")
                }
            }
        }
    }

    @MainActor
    func update(_ plan: Plan, userId: String) {
        if let index = plans.firstIndex(where: { $0.id == plan.id }) {
            plans[index] = plan
        }

        Task {
            do {
                let updatedPlan = try await CloudKitService.shared.savePlan(plan, userId: userId)
                NotificationService.shared.schedulePlanNotifications(for: updatedPlan)

                await MainActor.run {
                    if let index = self.plans.firstIndex(where: { $0.id == plan.id }) {
                        self.plans[index] = updatedPlan
                    }
                }
            } catch {
                // エラー時は何もしない（ローカルは既に更新済み）
            }
        }
    }

    func delete(at offsets: IndexSet, userId: String? = nil) {
        for index in offsets {
           let plan = plans[index]
           Task {
               await deletePlan(plan, userId: userId)
           }
        }
    }

    @MainActor
    func deletePlan(_ plan: Plan, userId: String? = nil) async {
        NotificationService.shared.cancelPlanNotifications(for: plan.id)

        // 即座にローカルリストから削除（UI更新）
        plans.removeAll { $0.id == plan.id }

        // CloudKitから削除（完了するまで待つ）
        do {
            try await CloudKitService.shared.deletePlan(planId: plan.id)
        } catch {
            // エラーの場合、削除をロールバック
            if let userId = userId {
                self.refreshFromCloudKit(userId: userId)
            } else {
                self.plans.append(plan)
            }
        }
    }
}
