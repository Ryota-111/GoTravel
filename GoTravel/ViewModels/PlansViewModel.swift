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
        listener = FirestoreService.shared.observePlans { [weak self] result in
            switch result {
            case .success(let plans):
                DispatchQueue.main.async {
                    self?.plans = plans
                }
            case .failure(_):
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
        FirestoreService.shared.savePlan(plan) { result in
            switch result {
            case .success(let savedPlan):
                NotificationService.shared.schedulePlanNotifications(for: savedPlan)
            case .failure(_):
                break
            }
        }
    }

    func update(_ plan: Plan) {
        FirestoreService.shared.savePlan(plan) { result in
            switch result {
            case .success(let updatedPlan):
                NotificationService.shared.schedulePlanNotifications(for: updatedPlan)
            case .failure(_):
                break
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
            if error != nil {
            } else {
            }
        }
    }
}
