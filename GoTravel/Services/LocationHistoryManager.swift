import Foundation
import Combine

class LocationHistoryManager: ObservableObject {
    static let shared = LocationHistoryManager()

    @Published var history: [LocationHistoryItem] = []

    private let key = "LocationSearchHistory"
    private let maxCount = 30

    struct LocationHistoryItem: Identifiable, Codable {
        var id: String = UUID().uuidString
        var name: String
        var address: String?
        var latitude: Double
        var longitude: Double
        var savedAt: Date = Date()
    }

    private init() { load() }

    func add(name: String, address: String?, latitude: Double, longitude: Double) {
        history.removeAll { $0.name == name }
        let item = LocationHistoryItem(name: name, address: address, latitude: latitude, longitude: longitude)
        history.insert(item, at: 0)
        if history.count > maxCount { history = Array(history.prefix(maxCount)) }
        save()
    }

    func delete(_ item: LocationHistoryItem) {
        history.removeAll { $0.id == item.id }
        save()
    }

    func clear() {
        history.removeAll()
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([LocationHistoryItem].self, from: data) {
            history = decoded
        }
    }
}
