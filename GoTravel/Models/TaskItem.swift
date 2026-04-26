import Foundation
import SwiftUI

struct TaskItem: Identifiable, Codable {
    var id: String = UUID().uuidString
    var title: String
    var priority: Priority
    var dueDate: Date?
    var isCompleted: Bool = false
    var createdAt: Date = Date()

    enum Priority: String, Codable, CaseIterable {
        case high = "高"
        case medium = "中"
        case low = "低"

        var displayName: String { rawValue }

        var color: Color {
            switch self {
            case .high:   return .red
            case .medium: return .orange
            case .low:    return .blue
            }
        }

        var icon: String {
            switch self {
            case .high:   return "exclamationmark.3"
            case .medium: return "exclamationmark.2"
            case .low:    return "exclamationmark"
            }
        }

        var sortOrder: Int {
            switch self {
            case .high:   return 0
            case .medium: return 1
            case .low:    return 2
            }
        }
    }
}
