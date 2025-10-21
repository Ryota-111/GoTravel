import SwiftUI
import Foundation
import Combine
import FirebaseFirestore

final class PlansViewModel: ObservableObject {
    @Published var plans: [Plan] = []
    private var listener: ListenerRegistration?

    init() {
        startListening()
    }

    deinit {
        stopListening()
    }

    func startListening() {
        print("PlansViewModel: リスナーを開始")
        listener = FirestoreService.shared.observePlans { [weak self] result in
            switch result {
            case .success(let plans):
                print("PlansViewModel: \(plans.count)件の予定を取得")
                DispatchQueue.main.async {
                    self?.plans = plans
                    print("PlansViewModel: UIを更新 - \(plans.count)件")
                }
            case .failure(let error):
                print("PlansViewModel: 取得失敗 - \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.plans = []
                }
            }
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    func add(_ plan: Plan) {
        print("PlansViewModel: 保存開始 - \(plan.title)")
        FirestoreService.shared.savePlan(plan) { result in
            switch result {
            case .success(let savedPlan):
                print("PlansViewModel: 保存成功 - \(savedPlan.title), ID: \(savedPlan.id)")
                NotificationService.shared.schedulePlanNotifications(for: savedPlan)
            case .failure(let error):
                print("PlansViewModel: 保存失敗 - \(error.localizedDescription)")
            }
        }
    }

    func update(_ plan: Plan) {
        print("PlansViewModel: 更新開始 - \(plan.title)")
        FirestoreService.shared.savePlan(plan) { result in
            switch result {
            case .success(let updatedPlan):
                print("PlansViewModel: 更新成功 - \(updatedPlan.title)")
                NotificationService.shared.schedulePlanNotifications(for: updatedPlan)
            case .failure(let error):
                print("PlansViewModel: 更新失敗 - \(error.localizedDescription)")
            }
        }
    }

    func delete(at offsets: IndexSet) {
        for index in offsets {
           let plan = plans[index]
           deletePlan(plan)
        }
    }

    func deletePlan(_ plan: Plan) {
        NotificationService.shared.cancelPlanNotifications(for: plan.id)
        FirestoreService.shared.deletePlan(plan) { error in
            if let error = error {
                print("PlansViewModel: 削除失敗 - \(error.localizedDescription)")
            } else {
                print("PlansViewModel: 削除成功 - \(plan.title)")
            }
        }
    }
}
