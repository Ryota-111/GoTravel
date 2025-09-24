import Foundation

struct Plan: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var startDate: Date
    var endDate: Date
    var places: [PlannedPlace]
    var createdAt: Date = Date()
}
