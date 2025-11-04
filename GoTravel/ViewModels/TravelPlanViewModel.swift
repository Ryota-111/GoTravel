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
        print("TravelPlanViewModel: リスナーを開始")
        listener = FirestoreService.shared.observeTravelPlans { [weak self] result in
            switch result {
            case .success(let plans):
                print("TravelPlanViewModel: \(plans.count)件の旅行計画を取得")
                DispatchQueue.main.async {
                    self?.travelPlans = plans
                    print("TravelPlanViewModel: UIを更新 - \(plans.count)件")
                }
            case .failure(let error):
                print("TravelPlanViewModel: 取得失敗 - \(error.localizedDescription)")
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
        print("TravelPlanViewModel: 保存開始 - \(plan.title)")
        FirestoreService.shared.saveTravelPlan(plan) { result in
            switch result {
            case .success(let savedPlan):
                print("TravelPlanViewModel: 保存成功 - \(savedPlan.title), ID: \(savedPlan.id ?? "なし")")
                NotificationService.shared.scheduleTravelPlanNotifications(for: savedPlan)
            case .failure(let error):
                print("TravelPlanViewModel: 保存失敗 - \(error.localizedDescription)")
            }
        }
    }

    func update(_ plan: TravelPlan) {
        print("TravelPlanViewModel: 更新開始 - \(plan.title)")
        FirestoreService.shared.saveTravelPlan(plan) { result in
            switch result {
            case .success(let updatedPlan):
                print("TravelPlanViewModel: 更新成功 - \(updatedPlan.title)")
                NotificationService.shared.scheduleTravelPlanNotifications(for: updatedPlan)
            case .failure(let error):
                print("TravelPlanViewModel: 更新失敗 - \(error.localizedDescription)")
            }
        }
    }

    func delete(_ plan: TravelPlan) {
        if let planId = plan.id {
            NotificationService.shared.cancelTravelPlanNotifications(for: planId)
        }

        FirestoreService.shared.deleteTravelPlan(plan) { error in
            if let error = error {
                print("Failed to delete travel plan:", error.localizedDescription)
            } else {
                print("Travel plan deleted successfully")
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
        print("TravelPlanViewModel: 共有コードで参加開始 - \(shareCode)")

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
                        print("TravelPlanViewModel: 参加成功 - \(joinedPlan.title)")
                        completion(.success(joinedPlan))
                    case .failure(let error):
                        print("TravelPlanViewModel: 参加失敗 - \(error.localizedDescription)")
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                print("TravelPlanViewModel: プラン検索失敗 - \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
}
