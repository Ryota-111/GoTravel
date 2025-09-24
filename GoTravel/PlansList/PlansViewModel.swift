import SwiftUI
import Foundation
import Combine

final class PlansViewModel: ObservableObject {
    @Published var plans: [Plan] = []

    private let defaultsKey = "plans_v1"

    init() {
        load()
    }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return }
        if let decoded = try? JSONDecoder().decode([Plan].self, from: data) {
            self.plans = decoded
        }
    }

    func save() {
        if let encoded = try? JSONEncoder().encode(plans) {
            UserDefaults.standard.set(encoded, forKey: defaultsKey)
        }
    }

    func add(_ plan: Plan) {
        plans.insert(plan, at: 0)
        save()
    }

    func update(_ plan: Plan) {
        if let idx = plans.firstIndex(where: { $0.id == plan.id }) {
            plans[idx] = plan
            save()
        }
    }

    func delete(at offsets: IndexSet) {
        plans.remove(atOffsets: offsets)
        save()
    }

    func move(from source: IndexSet, to destination: Int) {
        plans.move(fromOffsets: source, toOffset: destination)
        save()
    }
}
