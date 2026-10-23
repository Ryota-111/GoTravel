import Foundation
import SwiftUI

struct DaySchedule: Identifiable, Codable, Equatable {
    var id: String = UUID().uuidString
    var dayNumber: Int // 1, 2, 3...
    var date: Date
    var scheduleItems: [ScheduleItem]
    /// この日の時間帯（"Europe/Paris" など）。新しい予定はこの時計で入れ始める。
    ///
    /// 何ヶ国も回る旅行で、Day 1〜3 はロンドン、Day 4〜 はパリ、のように決める（3.0）。
    /// 無い日は今までどおり（目的地か端末の時計）。日程の JSON の中なので Deploy は要らない。
    /// 2.9 以前の人が共有した旅行を書き換えると消えるが、初期値にしか使わないので困らない
    var timeZoneIdentifier: String?

    init(id: String = UUID().uuidString, dayNumber: Int, date: Date, scheduleItems: [ScheduleItem] = [],
         timeZoneIdentifier: String? = nil) {
        self.id = id
        self.dayNumber = dayNumber
        self.date = date
        self.scheduleItems = scheduleItems
        self.timeZoneIdentifier = timeZoneIdentifier
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

    /// 共有した旅行で、この予定に参加する人（ユーザーID）。**空（nil）なら全員。**
    ///
    /// 出発地の違うメンバーが現地で集まる旅行で、それぞれの移動を分けて見たいという要望から
    /// （`docs/設計_メンバーごとの時間軸.md`）。旧バージョンが編集すると消えて全員の予定に戻る
    var participantIds: [String]?

    /// 外貨で入れたときの元の金額とレート。`cost` / `actualCost` はこれを円に直したもの。
    /// 円で入れた予定は nil（`ForeignCost.swift`）
    var foreignCost: ForeignCost?

    /// 予約から作った予定のうち、どの部分か（"main" / "departure" / "arrival"）。
    /// 飛行機は出発と到着の2件になるので、予約を直したときにどちらへ反映するかを決めるのに使う。
    /// 2.9 より前に作った予定には無い（時刻の順で当てる。`ReservationItinerarySync.swift`）
    var reservationPart: String?

    /// 費用のメモ（「2人分」「駐車場代込み」など）。金額の横に出す（ご要望から）
    var costNote: String?

    /// 終わる時刻（任意）。`time` と同じ時計で読む。
    /// 予定と予定の間にどれだけ移動の時間があるかが分かるように（ご要望から）
    var endTime: Date?

    /// 終わる時刻を読む時計（"Asia/Qatar" など）。**無ければ始まりと同じ時計**（`timeZoneIdentifier`）。
    ///
    /// 「パリ 15:00 発 → ドーハ 23:00 着」のように、時差をまたぐ移動を1つの予定で入れると、
    /// 着く時刻まで出発地の時計で読まれていた（ご要望から、3.1）。JSON の中の項目なので、
    /// CloudKit のスキーマ変更は要らない
    var endTimeZoneIdentifier: String?

    /// 場所の住所（地図で選んだときのもの）。場所の名前の下に出す。
    ///
    /// 2.9 までは保存しておらず、予定を開き直すと緯度・経度だけから場所を作り直して
    /// その「住所」を出していた。住所を持たない場所では iOS が端末の地域の国名を返すため、
    /// 「現在地の国名が出る」と報告された。無い予定は、開いたときに緯度・経度から引き直す
    var address: String?

    /// その日（`DaySchedule`）から何日ずれた時刻か。-1 なら「前日」。無い・0 ならその日。
    ///
    /// 日本時間で入れた予定を、同じ瞬間の現地の時刻に直すと日付をまたぐことがある
    /// （日本 9:00 → ロサンゼルス前日 17:00）。予定を勝手に別の日へ動かすと見失うので、
    /// その日に残したまま「前日 17:00」と出す（3.0、`docs/設計_3.0.md`）
    var dayShift: Int?

    /// 割り勘（3.1）：この費用を払った人（ユーザーID か同行者の id）。
    /// 無ければ、共有していない旅行では自分、共有している旅行では決まっていない（`TripSplitLedger`）
    var paidBy: String?
    /// 割り勘（3.1）：割り勘する人。**空（nil）なら全員。** 「運転した人は払わない」ときに外す
    var splitWith: [String]?
    /// 割り勘（3.1）：人ごとに決めた金額（円）。決めていない人は、残りを同じ額ずつ分ける。nil なら均等
    var splitAmounts: [String: Double]?

    enum CodingKeys: String, CodingKey {
        case id, time, title, location, notes, latitude, longitude, cost, actualCost, mapURL, linkURL, reservationId, timeZoneIdentifier, isPinned, participantIds, foreignCost, reservationPart, costNote, endTime, endTimeZoneIdentifier, address, dayShift
        case paidBy, splitWith, splitAmounts
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
         isPinned: Bool? = nil,
         participantIds: [String]? = nil,
         foreignCost: ForeignCost? = nil,
         reservationPart: String? = nil,
         costNote: String? = nil,
         endTime: Date? = nil,
         endTimeZoneIdentifier: String? = nil,
         address: String? = nil,
         dayShift: Int? = nil,
         paidBy: String? = nil,
         splitWith: [String]? = nil) {
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
        self.participantIds = participantIds
        self.foreignCost = foreignCost
        self.reservationPart = reservationPart
        self.costNote = costNote
        self.endTime = endTime
        self.endTimeZoneIdentifier = endTimeZoneIdentifier
        self.address = address
        self.dayShift = dayShift
        self.paidBy = paidBy
        self.splitWith = splitWith
    }
}
