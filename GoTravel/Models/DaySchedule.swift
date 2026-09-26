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

    /// `time` の時:分を、どこの時計で読むか（"Europe/Paris" など）。
    ///
    /// 端末の時計で読んでいたため、日本で「パリ 15:00」と入れた予定が
    /// パリに着くと 8:00 と出ていた。入れたときの時間帯を覚えておき、
    /// 端末がどこにあっても入れたとおりに出す。
    /// 無い予定（2.7 より前に入れたもの）は日本時間とみなす（`ScheduleClock.legacyTimeZone`）。
    ///
    /// JSON の中の項目なので、CloudKit のスキーマ変更は要らない
    var timeZoneIdentifier: String?

    /// その日の一番上に固定するか（「集合場所：那覇空港 2F」のように、その日ずっと気にしたいもの）。
    /// 固定したものは時刻の並びから外して上に出す。無い予定は固定していない扱い
    var isPinned: Bool?

    enum CodingKeys: String, CodingKey {
        case id, time, title, location, notes, latitude, longitude, cost, actualCost, mapURL, linkURL, reservationId, timeZoneIdentifier, isPinned
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
         reservationId: String? = nil,
         timeZoneIdentifier: String? = nil,
         isPinned: Bool? = nil) {
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
        self.timeZoneIdentifier = timeZoneIdentifier
        self.isPinned = isPinned
    }
}
