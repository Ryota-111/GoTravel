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

    /// この予定を作った予約の id。
    ///
    /// 予約から「行程にも追加する」で作られたものだけが値を持つ。
    /// 手で書いた予定は nil。
    ///
    /// これがあるおかげで、予約側のトグルを外したときや予約を消したときに
    /// **その予約から作った予定だけ**を消せる。
    /// 名前や時刻での照合だと、手で書いた同名の予定まで巻き込む。
    ///
    /// `daySchedulesData` は JSON なので、増やしても CloudKit のスキーマは変わらない。
    /// 省略可能なので、この項目を持たない古いデータもそのまま読める
    var reservationId: String?

    enum CodingKeys: String, CodingKey {
        case id, time, title, location, notes, latitude, longitude, cost, actualCost, mapURL, linkURL, reservationId
    }

    /// 書き出しや共有カードに出す金額。
    ///
    /// **旅行が終わったあとに残したいのは、予定額ではなく実際に使った額。**
    /// 実績が入っていればそちらを、まだ無ければ予算を出す。
    /// 出発前は予算しか無いので今までどおりに見え、
    /// 記録を付けた項目から順に実績へ入れ替わる
    var displayCost: Double? {
        actualCost ?? cost
    }

    /// 出している金額が実績かどうか。見出しの言い回しを変えるのに使う
    var isShowingActualCost: Bool {
        actualCost != nil
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
         linkURL: String? = nil,
         reservationId: String? = nil) {
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
        self.reservationId = reservationId
    }
}
