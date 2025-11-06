import Foundation
import Combine
import FirebaseFirestore

final class TravelPlanViewModel: ObservableObject {
    @Published var travelPlans: [TravelPlan] = []
    private var listener: ListenerRegistration?

    init() {
        startListening()
    }

    deinit {
        stopListening()
    }

    func startListening() {
        listener = FirestoreService.shared.observeTravelPlans { [weak self] result in
            switch result {
            case .success(let plans):
                DispatchQueue.main.async {
                    self?.travelPlans = plans
                }
            case .failure(_):
                DispatchQueue.main.async {
                    self?.travelPlans = []
                }
            }
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    func add(_ plan: TravelPlan) {
        FirestoreService.shared.saveTravelPlan(plan) { result in
            switch result {
            case .success(let savedPlan):
                NotificationService.shared.scheduleTravelPlanNotifications(for: savedPlan)
            case .failure(_):
                break
            }
        }
    }

    func update(_ plan: TravelPlan) {
        FirestoreService.shared.saveTravelPlan(plan) { result in
            switch result {
            case .success(let updatedPlan):
                NotificationService.shared.scheduleTravelPlanNotifications(for: updatedPlan)
            case .failure(_):
                break
            }
        }
    }

    func delete(_ plan: TravelPlan) {
        if let planId = plan.id {
            NotificationService.shared.cancelTravelPlanNotifications(for: planId)
        }

        FirestoreService.shared.deleteTravelPlan(plan) { error in
            if error != nil {
            } else {
            }
        }
    }

    // MARK: - Sharing Methods
    func updateShareCode(planId: String, shareCode: String) {
        guard var plan = travelPlans.first(where: { $0.id == planId }) else { return }
        plan.isShared = true
        plan.shareCode = shareCode
        plan.ownerId = plan.userId
        plan.updatedAt = Date()
        update(plan)
    }

    func joinPlanByShareCode(_ shareCode: String, completion: @escaping (Result<TravelPlan, Error>) -> Void) {

        // First, find the plan by share code
        FirestoreService.shared.findTravelPlanByShareCode(shareCode) { result in
            switch result {
            case .success(let plan):
                guard let planId = plan.id else {
                    completion(.failure(APIClientError.parseError))
                    return
                }

                // Join the plan
                FirestoreService.shared.joinTravelPlan(planId: planId) { joinResult in
                    switch joinResult {
                    case .success(let joinedPlan):
                        completion(.success(joinedPlan))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
