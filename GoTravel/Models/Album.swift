import Foundation
import SwiftUI

// MARK: - Album Model
struct Album: Identifiable, Codable, Equatable {
    var id: String = UUID().uuidString
    var title: String
    var photoFileNames: [String]
    var coverColor: Color?
    var icon: String
    var createdAt: Date
    var updatedAt: Date
    var travelPlanId: String? // TravelPlanとの関連付け
    var isDefaultAlbum: Bool // 固定アルバムかどうか

    enum CodingKeys: String, CodingKey {
        case id, title, photoFileNames, coverColorHex, icon, createdAt, updatedAt, travelPlanId, isDefaultAlbum
    }

    var coverColorHex: String? {
        guard let color = coverColor else { return nil }
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r*255), Int(g*255), Int(b*255))
    }

    init(id: String = UUID().uuidString,
         title: String,
         photoFileNames: [String] = [],
         coverColor: Color? = nil,
         icon: String = "photo.on.rectangle.angled",
         createdAt: Date = Date(),
         updatedAt: Date = Date(),
         travelPlanId: String? = nil,
         isDefaultAlbum: Bool = false) {
        self.id = id
        self.title = title
        self.photoFileNames = photoFileNames
        self.coverColor = coverColor
        self.icon = icon
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.travelPlanId = travelPlanId
        self.isDefaultAlbum = isDefaultAlbum
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        photoFileNames = try container.decode([String].self, forKey: .photoFileNames)
        icon = try container.decode(String.self, forKey: .icon)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        travelPlanId = try container.decodeIfPresent(String.self, forKey: .travelPlanId)
        isDefaultAlbum = try container.decodeIfPresent(Bool.self, forKey: .isDefaultAlbum) ?? false

        if let hex = try container.decodeIfPresent(String.self, forKey: .coverColorHex) {
            coverColor = Color(hex: hex)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(photoFileNames, forKey: .photoFileNames)
        try container.encode(icon, forKey: .icon)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(travelPlanId, forKey: .travelPlanId)
        try container.encode(isDefaultAlbum, forKey: .isDefaultAlbum)

        if let hex = coverColorHex {
            try container.encode(hex, forKey: .coverColorHex)
        }
    }
}

// MARK: - Predefined Album Types
enum AlbumType {
    case japan
    case travel
    case family
    case landscape
    case food
    case custom

    var title: String {
        switch self {
        case .japan: return "日本全国フォトマップ"
        case .travel: return "旅行"
        case .family: return "家族"
        case .landscape: return "風景"
        case .food: return "グルメ"
        case .custom: return "カスタム"
        }
    }

    var icon: String {
        switch self {
        case .japan: return "map.fill"
        case .travel: return "airplane"
        case .family: return "person.3.fill"
        case .landscape: return "mountain.2.fill"
        case .food: return "fork.knife"
        case .custom: return "photo.on.rectangle.angled"
        }
    }

    var coverColor: Color {
        switch self {
        case .japan: return .blue
        case .travel: return .orange
        case .family: return .pink
        case .landscape: return .green
        case .food: return .red
        case .custom: return .purple
        }
    }
}
