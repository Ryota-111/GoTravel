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
    var travelPlanId: String?
    var isDefaultAlbum: Bool
    /// アルバムの種別。日本全国フォトマップの判定にタイトル文字列を使わないために保持する
    var type: AlbumType
    var userId: String?

    /// 日本全国フォトマップかどうか（専用画面へ遷移する判定に使う）
    var isJapanPhotoMap: Bool { type == .japan }

    enum CodingKeys: String, CodingKey {
        case id, title, photoFileNames, coverColorHex, icon, createdAt, updatedAt, travelPlanId, isDefaultAlbum, type, userId
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
         isDefaultAlbum: Bool = false,
         type: AlbumType = .custom,
         userId: String? = nil) {
        self.id = id
        self.title = title
        self.photoFileNames = photoFileNames
        self.coverColor = coverColor
        self.icon = icon
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.travelPlanId = travelPlanId
        self.isDefaultAlbum = isDefaultAlbum
        self.type = type
        self.userId = userId
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
        userId = try container.decodeIfPresent(String.self, forKey: .userId)

        // 種別を持たない旧データはタイトルから復元する（移行時のみの互換処理）
        if let rawType = try container.decodeIfPresent(String.self, forKey: .type),
           let decodedType = AlbumType(rawValue: rawType) {
            type = decodedType
        } else {
            type = title == AlbumType.japan.title ? .japan : .custom
        }

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
        try container.encode(type.rawValue, forKey: .type)
        try container.encodeIfPresent(userId, forKey: .userId)

        if let hex = coverColorHex {
            try container.encode(hex, forKey: .coverColorHex)
        }
    }
}

// MARK: - Predefined Album Types
enum AlbumType: String, Codable, CaseIterable {
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
        let themeManager = ThemeManager.shared
        switch self {
        case .japan: return themeManager.currentTheme.japan
        case .travel: return themeManager.currentTheme.travel
        case .family: return themeManager.currentTheme.family
        case .landscape: return themeManager.currentTheme.landscape
        case .food: return themeManager.currentTheme.food
        case .custom: return themeManager.currentTheme.custom
        }
    }

    /// 種別選択UIで使う固定色。テーマに依存しないため、
    /// 白黒テーマでも種別ごとの区別がつく
    var defaultCoverColor: Color {
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

// MARK: - Deterministic Color Palette
extension Album {
    /// 旅行計画に色が設定されていない場合の代替色を決める共通処理。
    /// String.hashValue は実行ごとに変わるため使わず、文字から安定した値を作る
    static func fallbackColor(forKey key: String) -> Color {
        let palette: [Color] = [
            .blue, .purple, .pink, .orange, .teal,
            .indigo, Color(red: 0.2, green: 0.65, blue: 0.4),
            Color(red: 0.85, green: 0.35, blue: 0.25)
        ]
        var hash: UInt64 = 5381
        for byte in key.utf8 {
            hash = hash &* 33 &+ UInt64(byte)
        }
        return palette[Int(hash % UInt64(palette.count))]
    }

    /// 旅行計画のカードカラーを、白に近すぎる場合は安定した代替色に置き換えて返す
    static func resolvedPlanColor(for plan: TravelPlan) -> Color {
        let fallback = fallbackColor(forKey: plan.id ?? plan.title)

        guard let color = plan.cardColor else { return fallback }

        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else { return fallback }

        // 知覚輝度 > 0.85 は白に近すぎるためパレットを使用
        let brightness = 0.299 * r + 0.587 * g + 0.114 * b
        return brightness < 0.85 ? color : fallback
    }
}
