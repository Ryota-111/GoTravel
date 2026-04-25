import Foundation
import Combine

struct CustomPlaceCategory: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var icon: String
    var isDefault: Bool = false

    static let defaults: [CustomPlaceCategory] = [
        CustomPlaceCategory(id: "hotel",       name: "ホテル",     icon: "bed.double.fill",  isDefault: true),
        CustomPlaceCategory(id: "restaurant",  name: "レストラン", icon: "fork.knife",       isDefault: true),
        CustomPlaceCategory(id: "sightseeing", name: "風景",       icon: "mountain.2.fill",  isDefault: true)
    ]
}

class PlaceCategoryManager: ObservableObject {
    static let shared = PlaceCategoryManager()

    @Published var categories: [CustomPlaceCategory] {
        didSet { save() }
    }

    private let key = "custom_place_categories_v1"

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode([CustomPlaceCategory].self, from: data) {
            var merged = CustomPlaceCategory.defaults
            let custom = saved.filter { !$0.isDefault }
            merged.append(contentsOf: custom)
            self.categories = merged
        } else {
            self.categories = CustomPlaceCategory.defaults
        }
    }

    func add(_ category: CustomPlaceCategory) {
        categories.append(category)
    }

    func delete(_ category: CustomPlaceCategory) {
        guard !category.isDefault else { return }
        categories.removeAll { $0.id == category.id }
    }

    func category(for id: String) -> CustomPlaceCategory {
        categories.first { $0.id == id }
            ?? CustomPlaceCategory(id: id, name: id, icon: "mappin.circle.fill")
    }

    private func save() {
        let data = try? JSONEncoder().encode(categories)
        UserDefaults.standard.set(data, forKey: key)
    }
}
