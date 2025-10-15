import Foundation
import SwiftUI

// MARK: - Plan Type
enum PlanType: String, Codable {
    case outing
    case daily
}

struct Plan: Identifiable, Codable {
    var id: String = UUID().uuidString
    var title: String
    var startDate: Date
    var endDate: Date
    var places: [PlannedPlace]
    var cardColor: Color?
    var localImageFileName: String?
    var userId: String?
    var createdAt: Date
    var planType: PlanType = .outing
    var time: Date?
    var description: String?
    var linkURL: String?

    enum CodingKeys: String, CodingKey {
        case id, title, startDate, endDate, places, cardColorHex, localImageFileName, userId, createdAt
        case planType, time, description, linkURL
    }

    var cardColorHex: String? {
        guard let color = cardColor else { return nil }
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r*255), Int(g*255), Int(b*255))
    }

    init(id: String = UUID().uuidString,
         title: String,
         startDate: Date,
         endDate: Date,
         places: [PlannedPlace],
         cardColor: Color? = nil,
         localImageFileName: String? = nil,
         userId: String? = nil,
         createdAt: Date = Date(),
         planType: PlanType = .outing,
         time: Date? = nil,
         description: String? = nil,
         linkURL: String? = nil) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.places = places
        self.cardColor = cardColor
        self.localImageFileName = localImageFileName
        self.userId = userId
        self.createdAt = createdAt
        self.planType = planType
        self.time = time
        self.description = description
        self.linkURL = linkURL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        title = try container.decode(String.self, forKey: .title)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decode(Date.self, forKey: .endDate)
        places = try container.decode([PlannedPlace].self, forKey: .places)
        localImageFileName = try container.decodeIfPresent(String.self, forKey: .localImageFileName)
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        planType = try container.decodeIfPresent(PlanType.self, forKey: .planType) ?? .outing
        time = try container.decodeIfPresent(Date.self, forKey: .time)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        linkURL = try container.decodeIfPresent(String.self, forKey: .linkURL)
        if let hex = try container.decodeIfPresent(String.self, forKey: .cardColorHex) {
            cardColor = Color(hex: hex)
        } else {
            cardColor = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(endDate, forKey: .endDate)
        try container.encode(places, forKey: .places)
        try container.encodeIfPresent(cardColorHex, forKey: .cardColorHex)
        try container.encodeIfPresent(localImageFileName, forKey: .localImageFileName)
        try container.encodeIfPresent(userId, forKey: .userId)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(planType, forKey: .planType)
        try container.encodeIfPresent(time, forKey: .time)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(linkURL, forKey: .linkURL)
    }
}

extension Color {
    init?(hex: String) {
        let r, g, b: CGFloat
        if hex.hasPrefix("#") {
            let start = hex.index(hex.startIndex, offsetBy: 1)
            let hexColor = String(hex[start...])
            if hexColor.count == 6 {
                let scanner = Scanner(string: hexColor)
                var hexNumber: UInt64 = 0
                if scanner.scanHexInt64(&hexNumber) {
                    r = CGFloat((hexNumber & 0xff0000) >> 16) / 255
                    g = CGFloat((hexNumber & 0x00ff00) >> 8) / 255
                    b = CGFloat(hexNumber & 0x0000ff) / 255
                    self.init(red: r, green: g, blue: b)
                    return
                }
            }
        }
        return nil
    }

    func toHex() -> String? {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r*255), Int(g*255), Int(b*255))
    }
}
