import Foundation
import SwiftUI

struct TravelPlan: Identifiable, Codable {
    var id: String?
    var title: String
    var startDate: Date
    var endDate: Date
    var destination: String
    var localImageFileName: String?
    var cardColor: Color?
    var createdAt: Date
    var userId: String?
    var daySchedules: [DaySchedule]

    enum CodingKeys: String, CodingKey {
        case id, title, startDate, endDate, destination, localImageFileName, cardColorHex, createdAt, userId, daySchedules
    }

    var cardColorHex: String? {
        guard let color = cardColor else { return nil }
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r*255), Int(g*255), Int(b*255))
    }

    init(id: String? = nil,
         title: String,
         startDate: Date,
         endDate: Date,
         destination: String,
         localImageFileName: String? = nil,
         cardColor: Color? = nil,
         createdAt: Date = Date(),
         userId: String? = nil,
         daySchedules: [DaySchedule] = []) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.destination = destination
        self.localImageFileName = localImageFileName
        self.cardColor = cardColor
        self.createdAt = createdAt
        self.userId = userId
        self.daySchedules = daySchedules
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decode(Date.self, forKey: .endDate)
        destination = try container.decode(String.self, forKey: .destination)
        localImageFileName = try container.decodeIfPresent(String.self, forKey: .localImageFileName)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        daySchedules = try container.decodeIfPresent([DaySchedule].self, forKey: .daySchedules) ?? []

        if let hex = try container.decodeIfPresent(String.self, forKey: .cardColorHex) {
            cardColor = Color(hex: hex)
        } else {
            cardColor = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(endDate, forKey: .endDate)
        try container.encode(destination, forKey: .destination)
        try container.encodeIfPresent(localImageFileName, forKey: .localImageFileName)
        try container.encodeIfPresent(cardColorHex, forKey: .cardColorHex)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(userId, forKey: .userId)
        try container.encode(daySchedules, forKey: .daySchedules)
    }
}
