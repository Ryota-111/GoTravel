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
        print("🔄 [PlansViewModel] refreshFromCloudKit called")
        refreshTask?.cancel()

        refreshTask = Task { @MainActor in
            guard let userId = userId else {
                print("❌ [PlansViewModel] userId is nil")
                return
            }

            do {
                let results = try await CloudKitService.shared.fetchPlans(userId: userId)
                print("✅ [PlansViewModel] Fetched \(results.count) plans")
                self.plans = results
            } catch {
                print("❌ [PlansViewModel] Fetch error: \(error)")
                self.plans = []
            }
        }
    }

    @MainActor
    func add(_ plan: Plan, userId: String) {
        plans.append(plan)
        print("➕ [PlansViewModel] Added plan locally, count: \(plans.count)")

        Task {
            do {
                let savedPlan = try await CloudKitService.shared.savePlan(plan, userId: userId)
                print("✅ [PlansViewModel] Saved to CloudKit")
                NotificationService.shared.schedulePlanNotifications(for: savedPlan)

                await MainActor.run {
                    if let index = self.plans.firstIndex(where: { $0.id == plan.id }) {
                        self.plans[index] = savedPlan
                    }
                }
            } catch {
                print("❌ [PlansViewModel] CloudKit save error: \(error)")
                await MainActor.run {
                    self.plans.removeAll { $0.id == plan.id }
                }
            }
        }
    }

    @MainActor
    func update(_ plan: Plan, userId: String) {
        if let index = plans.firstIndex(where: { $0.id == plan.id }) {
            plans[index] = plan
        }
        print("📝 [PlansViewModel] Updated plan locally, count: \(plans.count)")

        Task {
            do {
                let updatedPlan = try await CloudKitService.shared.savePlan(plan, userId: userId)
                print("✅ [PlansViewModel] Updated in CloudKit")
                NotificationService.shared.schedulePlanNotifications(for: updatedPlan)

                await MainActor.run {
                    if let index = self.plans.firstIndex(where: { $0.id == plan.id }) {
                        self.plans[index] = updatedPlan
                    }
                }
            } catch {
                print("❌ [PlansViewModel] CloudKit update error: \(error)")
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
        print("🗑️ [PlansViewModel] DELETE START - Plan: \(plan.title), ID: \(plan.id)")
        print("🗑️ [PlansViewModel] Before delete - plans.count: \(plans.count)")

        NotificationService.shared.cancelPlanNotifications(for: plan.id)

        // 即座にローカルリストから削除（UI更新）
        plans.removeAll { $0.id == plan.id }
        print("🗑️ [PlansViewModel] Removed from local - plans.count: \(plans.count)")

        // CloudKitから削除（完了するまで待つ）
        do {
            print("🗑️ [PlansViewModel] Deleting from CloudKit...")
            try await CloudKitService.shared.deletePlan(planId: plan.id)
            print("✅ [PlansViewModel] CloudKit deletion SUCCESS - final count: \(plans.count)")
        } catch {
            print("❌ [PlansViewModel] CloudKit deletion FAILED: \(error)")
            // エラーの場合、削除をロールバック
            if let userId = userId {
                print("🔄 [PlansViewModel] Rolling back - refreshing from CloudKit")
                self.refreshFromCloudKit(userId: userId)
            } else {
                print("🔄 [PlansViewModel] Rolling back - re-adding plan")
                self.plans.append(plan)
                print("🔄 [PlansViewModel] After rollback - plans.count: \(plans.count)")
            }
        }
        print("🗑️ [PlansViewModel] DELETE END - final count: \(plans.count)")
    }
}
