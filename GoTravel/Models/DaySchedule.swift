import Foundation
import SwiftUI

struct DaySchedule: Identifiable, Codable, Equatable {
    var id: String = UUID().uuidString
    var dayNumber: Int // 1, 2, 3...
    var date: Date
    var scheduleItems: [ScheduleItem]

    init(id: String = UUID().uuidString, dayNumber: Int, date: Date, scheduleItems: [ScheduleItem] = []) {
        self.id = id
        self.dayNumber = dayNumber
        self.date = date
        self.scheduleItems = scheduleItems
    }
}

struct ScheduleItem: Identifiable, Codable, Equatable {
    var id: String = UUID().uuidString
    var time: Date
    var title: String
    var location: String?
    var notes: String?
    var latitude: Double?
    var longitude: Double?
    /// 予定していた金額
    var cost: Double?
    /// 実際に使った金額。未入力なら nil（0円で使ったのと区別する）
    var actualCost: Double?
    var mapURL: String?
    var linkURL: String?

    enum CodingKeys: String, CodingKey {
        case id, time, title, location, notes, latitude, longitude, cost, actualCost, mapURL, linkURL
    }

    init(id: String = UUID().uuidString,
         time: Date,
         title: String,
         location: String? = nil,
         notes: String? = nil,
         latitude: Double? = nil,
         longitude: Double? = nil,
         cost: Double? = nil,
         actualCost: Double? = nil,
         mapURL: String? = nil,
         linkURL: String? = nil) {
        self.id = id
        self.time = time
        self.title = title
        self.location = location
        self.notes = notes
        self.latitude = latitude
        self.longitude = longitude
        self.cost = cost
        self.actualCost = actualCost
        self.mapURL = mapURL
        self.linkURL = linkURL
    }
}
