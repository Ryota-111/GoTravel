import Foundation
import SwiftUI

// MARK: - Packing Item
struct PackingItem: Identifiable, Codable {
    var id: String
    var name: String
    var isChecked: Bool

    init(id: String = UUID().uuidString, name: String, isChecked: Bool = false) {
        self.id = id
        self.name = name
        self.isChecked = isChecked
    }
}

struct TravelPlan: Identifiable, Codable {
    var id: String?
    var title: String
    var startDate: Date
    var endDate: Date
    var destination: String
    var latitude: Double?
    var longitude: Double?
    var localImageFileName: String?
    var cardColor: Color?
    var createdAt: Date
    var userId: String?
    var daySchedules: [DaySchedule]
    var packingItems: [PackingItem]
    var reservations: [Reservation]

    // Sharing properties
    var isShared: Bool
    var shareCode: String?
    var sharedWith: [String] // Array of user IDs
    var ownerId: String? // Original creator's ID
    var lastEditedBy: String?
    var updatedAt: Date

    /// 費用を何人で割るか。nil なら人数から自動で決める（`splitCount(defaultingTo:)`）
    var customSplitCount: Int?

    enum CodingKeys: String, CodingKey {
        case id, title, startDate, endDate, destination, latitude, longitude, localImageFileName, cardColorHex, createdAt, userId, daySchedules, packingItems
        case reservations
        case isShared, shareCode, sharedWith, ownerId, lastEditedBy, updatedAt, customSplitCount
    }

    /// 実際に割り勘に使う人数。
    /// 共有していれば参加人数、していなければ1人を既定とし、
    /// 手動で設定されていればそれを優先する（参加していない同行者がいるため）
    var splitCount: Int {
        if let customSplitCount, customSplitCount > 0 {
            return customSplitCount
        }
        return isShared ? max(sharedWith.count, 1) : 1
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
         latitude: Double? = nil,
         longitude: Double? = nil,
         localImageFileName: String? = nil,
         cardColor: Color? = nil,
         createdAt: Date = Date(),
         userId: String? = nil,
         daySchedules: [DaySchedule] = [],
         packingItems: [PackingItem] = [],
         reservations: [Reservation] = [],
         isShared: Bool = false,
         shareCode: String? = nil,
         sharedWith: [String] = [],
         ownerId: String? = nil,
         lastEditedBy: String? = nil,
         updatedAt: Date = Date(),
         customSplitCount: Int? = nil) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.destination = destination
        self.latitude = latitude
        self.longitude = longitude
        self.localImageFileName = localImageFileName
        self.cardColor = cardColor
        self.createdAt = createdAt
        self.userId = userId
        self.daySchedules = daySchedules
        self.packingItems = packingItems
        self.reservations = reservations
        self.isShared = isShared
        self.shareCode = shareCode
        self.sharedWith = sharedWith
        self.ownerId = ownerId
        self.lastEditedBy = lastEditedBy
        self.updatedAt = updatedAt
        self.customSplitCount = customSplitCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decode(Date.self, forKey: .endDate)
        destination = try container.decode(String.self, forKey: .destination)
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        localImageFileName = try container.decodeIfPresent(String.self, forKey: .localImageFileName)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        daySchedules = try container.decodeIfPresent([DaySchedule].self, forKey: .daySchedules) ?? []
        packingItems = try container.decodeIfPresent([PackingItem].self, forKey: .packingItems) ?? []
        reservations = try container.decodeIfPresent([Reservation].self, forKey: .reservations) ?? []
        isShared = try container.decodeIfPresent(Bool.self, forKey: .isShared) ?? false
        shareCode = try container.decodeIfPresent(String.self, forKey: .shareCode)
        sharedWith = try container.decodeIfPresent([String].self, forKey: .sharedWith) ?? []
        ownerId = try container.decodeIfPresent(String.self, forKey: .ownerId)
        lastEditedBy = try container.decodeIfPresent(String.self, forKey: .lastEditedBy)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        customSplitCount = try container.decodeIfPresent(Int.self, forKey: .customSplitCount)

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
        try container.encodeIfPresent(latitude, forKey: .latitude)
        try container.encodeIfPresent(longitude, forKey: .longitude)
        try container.encodeIfPresent(localImageFileName, forKey: .localImageFileName)
        try container.encodeIfPresent(cardColorHex, forKey: .cardColorHex)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(userId, forKey: .userId)
        try container.encode(daySchedules, forKey: .daySchedules)
        try container.encode(packingItems, forKey: .packingItems)
        try container.encode(reservations, forKey: .reservations)
        try container.encode(isShared, forKey: .isShared)
        try container.encodeIfPresent(shareCode, forKey: .shareCode)
        try container.encode(sharedWith, forKey: .sharedWith)
        try container.encodeIfPresent(ownerId, forKey: .ownerId)
        try container.encodeIfPresent(lastEditedBy, forKey: .lastEditedBy)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(customSplitCount, forKey: .customSplitCount)
    }

    // Helper methods
    /// このプランの持ち主かどうか。
    ///
    /// 参加者のローカルコピーは userId が自分のIDに書き換えられる
    /// （FetchedResultsController の条件に合わせるため）。
    /// そのため共有中のプランを userId で判定すると、参加者を持ち主と誤認する。
    /// 誤認したまま削除するとパブリックDBの共有レコードごと消え、
    /// 他のメンバーが誰も参加できなくなるため、判断できない場合は false を返す。
    func isOwner(userId: String) -> Bool {
        if let ownerId {
            return ownerId == userId
        }

        // ownerId は共有時に設定される。無いのは一度も共有していないプラン
        return !isShared && self.userId == userId
    }

    func isSharedWithUser(userId: String) -> Bool {
        return sharedWith.contains(userId) || isOwner(userId: userId)
    }

    /// 何日目が何月何日か。
    ///
    /// `DaySchedule` も自分で日付を持っているが、そちらは信用しないこと。
    /// 出発日を変えても古い日付が残るため、タイムスケジュールや画像の
    /// 書き出しに変更前の日付が出てしまう（問い合わせで発覚）。
    /// **表示・書き出しは必ずこれを使う。**
    func date(forDay dayNumber: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: dayNumber - 1, to: startDate) ?? startDate
    }

    /// 旅行の日数（出発日と帰宅日を含む）
    var dayCount: Int {
        let days = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        return max(days + 1, 1)
    }

    /// 旅行期間の中に収まっている日程だけ。
    ///
    /// 日数を縮めると、範囲外になった日の予定が画面から消える一方で
    /// 書き出しやウィジェットには出てしまい、食い違っていた。
    /// **予定を集計・表示・書き出しするときは必ずこれを使う。**
    ///
    /// 範囲外の日を消さないのは、期間を戻せばそのまま復活させるため。
    /// 日数を縮めただけで予定が消えるほうが怖い
    var daySchedulesInRange: [DaySchedule] {
        daySchedules
            .filter { $0.dayNumber >= 1 && $0.dayNumber <= dayCount }
            .sorted { $0.dayNumber < $1.dayNumber }
    }

    /// 旅行期間から外れてしまう日程（予定が入っているものだけ）。
    /// 日数を縮める前の確認に使う
    func daySchedulesOutOfRange(forDayCount newDayCount: Int) -> [DaySchedule] {
        daySchedules
            .filter { $0.dayNumber > newDayCount && !$0.scheduleItems.isEmpty }
            .sorted { $0.dayNumber < $1.dayNumber }
    }

    /// 保存してある日付を出発日に合わせ直す。
    /// 表示は `date(forDay:)` を使うので見た目には影響しないが、
    /// 保存された値がずれたままなのは事故のもとなので、日付を変えたら呼ぶ
    mutating func realignDayScheduleDates() {
        for index in daySchedules.indices {
            daySchedules[index].date = date(forDay: daySchedules[index].dayNumber)
        }
    }

    /// この計画をもとに新しい計画を作る。
    ///
    /// 毎年の帰省や定番の旅行で、前回の行程を土台にしたいという要望から。
    /// 日数は元のままで出発日だけ動かし、予定は日番号ごとにそのままずらす。
    ///
    /// 引き継がないものが3つある。
    /// ・実際に使った金額 … 前回の実績なので持ち込まない（予算は引き継ぐ）
    /// ・共有の状態 … 別の旅行なので、共有し直してもらう
    /// ・持ち物のチェック … 外した状態から始める
    ///
    /// カバー写真は呼び出し側でファイルごと複製すること。
    /// ファイル名だけ引き継ぐと、片方を削除したときもう片方の写真も消える
    func duplicated(title newTitle: String,
                    startDate newStartDate: Date,
                    includeSchedule: Bool,
                    includePacking: Bool,
                    includeReservations: Bool) -> TravelPlan {
        var copy = self
        copy.id = UUID().uuidString
        copy.title = newTitle
        copy.createdAt = Date()
        copy.updatedAt = Date()

        // 日数は変えずに、出発日だけ動かす
        let length = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        copy.startDate = newStartDate
        copy.endDate = Calendar.current.date(byAdding: .day, value: length, to: newStartDate) ?? newStartDate

        copy.isShared = false
        copy.shareCode = nil
        copy.sharedWith = []
        copy.ownerId = nil
        copy.lastEditedBy = nil
        copy.localImageFileName = nil

        copy.daySchedules = includeSchedule
            ? daySchedulesInRange.map { day in
                var newDay = day
                newDay.id = UUID().uuidString
                newDay.scheduleItems = day.scheduleItems.map { item in
                    var newItem = item
                    newItem.id = UUID().uuidString
                    newItem.actualCost = nil
                    return newItem
                }
                return newDay
            }
            : []

        copy.packingItems = includePacking
            ? packingItems.map { PackingItem(name: $0.name, isChecked: false) }
            : []

        // 予約の日時も旅行と同じ日数だけずらす。
        // 前回の日付のまま残ると、いつの予約なのか分からなくなる
        let shift = Calendar.current.dateComponents([.day], from: startDate, to: newStartDate).day ?? 0
        copy.reservations = includeReservations
            ? reservations.map { reservation in
                var newReservation = reservation
                newReservation.id = UUID().uuidString
                if let date = reservation.date {
                    newReservation.date = Calendar.current.date(byAdding: .day, value: shift, to: date)
                }
                return newReservation
            }
            : []

        copy.realignDayScheduleDates()
        return copy
    }

    static func generateShareCode() -> String {
        let prefix = "TRAVEL"
        // O と I は 0・1 と見間違えて手入力で写し間違えるため含めない
        let randomString = String((0..<8).map { _ in "ABCDEFGHJKLMNPQRSTUVWXYZ0123456789".randomElement()! })
        return "\(prefix)-\(randomString)"
    }
}
