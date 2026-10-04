import Foundation
import SwiftUI

// MARK: - Packing Item
/// 旅行につく「名前とチェック」だけのリスト項目。
///
/// 持ち物・お土産・やりたいことは、どれも同じ形をしている。
/// 別々の入れ物を作らず、1つの配列に混ぜて `kind` で分ける。
///
/// **こうすると CloudKit のスキーマ変更が要らない。**
/// `TravelPlanEntity.packingItemsData` は JSON を詰めた Binary なので、
/// この構造体に項目を足しても保存先は増えない。
/// 新しい配列を足すと Binary 属性が増え、本番への deploy が必要になる。
struct PackingItem: Identifiable, Codable {

    enum Kind: String, Codable, CaseIterable, Identifiable {
        case packing
        case souvenir
        case wish

        var id: String { rawValue }

        var title: String {
            switch self {
            case .packing:  return "持ち物"
            case .souvenir: return "お土産"
            case .wish:     return "やりたいこと"
            }
        }

        var addPlaceholder: String {
            switch self {
            case .packing:  return "持ち物を追加"
            case .souvenir: return "買うものを追加"
            case .wish:     return "やりたいことを追加"
            }
        }

        var emptyIcon: String {
            switch self {
            case .packing:  return "bag"
            case .souvenir: return "gift"
            case .wish:     return "star"
            }
        }

        var emptyMessage: String {
            switch self {
            case .packing:  return "忘れ物を防ぐために、持ち物を書き出しておきましょう"
            case .souvenir: return "誰に何を買うか決めておくと、お店で迷いません"
            case .wish:     return "行く前にやりたいことを並べておくと、予定を立てやすくなります"
            }
        }

        /// 済んだときの言い方。持ち物は「入れた」、お土産は「買った」
        var doneLabel: String {
            switch self {
            case .packing:  return "準備完了"
            case .souvenir: return "買い終えました"
            case .wish:     return "ぜんぶ叶いました"
            }
        }

        /// 補足を入れる欄を出すか。お土産は「誰に」を書けると実用的
        var usesNote: Bool { self == .souvenir }

        var notePlaceholder: String { "誰に・メモ" }

        /// 同行者と分け合うリストか。
        ///
        /// やりたいことは**みんなで出し合いたい**ので共有する。
        /// 持ち物は各自が自分のぶんを持つ（充電器は全員それぞれ要る）ので個人のもの。
        /// お土産は同行者へのぶんを書くことがあり、本人に見えると台無しになる。
        var isSharedWithMembers: Bool { self == .wish }

        /// 共有中の旅行で、このリストの立ち位置を一言で説明する
        var sharingNote: String {
            isSharedWithMembers
                ? "同行者にも見えます。みんなで書き足せます"
                : "自分だけに見えます。同行者には共有されません"
        }
    }

    var id: String
    var name: String
    var isChecked: Bool
    var kind: Kind
    /// 一言の補足。お土産の「誰に」に使う
    var note: String?

    /// この項目の持ち主。
    ///
    /// `nil` は「みんなのもの」。やりたいことと、共有を始める前からあった
    /// 古い項目がこれにあたる。
    /// 値が入っているものは**その人だけのもの**で、共有レコードには載らない
    /// （`CloudKitService.publishSharedTravelPlan` が落とす）。
    var ownerId: String?

    /// 自分に見えてよい項目か
    func isVisible(to userId: String?) -> Bool {
        guard let ownerId else { return true }
        return ownerId == userId
    }

    init(id: String = UUID().uuidString,
         name: String,
         isChecked: Bool = false,
         kind: Kind = .packing,
         note: String? = nil,
         ownerId: String? = nil) {
        self.id = id
        self.name = name
        self.isChecked = isChecked
        self.kind = kind
        self.note = note
        self.ownerId = ownerId
    }

    enum CodingKeys: String, CodingKey {
        case id, name, isChecked, kind, note, ownerId
    }

    /// `kind` と `note` を足す前に保存されたデータには、そのキーが無い。
    /// 既定で読めるようにしておかないと、既存の持ち物が全部消える
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        isChecked = try container.decodeIfPresent(Bool.self, forKey: .isChecked) ?? false
        kind = try container.decodeIfPresent(Kind.self, forKey: .kind) ?? .packing
        note = try container.decodeIfPresent(String.self, forKey: .note)
        // 持ち主を持たせる前の項目は「みんなのもの」として扱う。
        // 既に同行者に見えていたものを、後から隠すほうが混乱する
        ownerId = try container.decodeIfPresent(String.self, forKey: .ownerId)
    }
}

extension TravelPlan {
    /// リストの項目を、渡した順に並べ直す（持ち物・お土産・やりたいことのどれか1つ）。
    ///
    /// 3つのリストは1つの配列に混ざって入っているので、渡した項目が入っていた位置だけを
    /// 新しい順で埋め直す。ほかのリストの項目や、ほかの人だけに見える項目の位置は動かさない
    mutating func reorderPackingItems(orderedIds: [String]) {
        let wanted = Set(orderedIds)
        let byId = Dictionary(packingItems.filter { wanted.contains($0.id) }.map { ($0.id, $0) },
                              uniquingKeysWith: { first, _ in first })
        let ordered = orderedIds.compactMap { byId[$0] }
        guard ordered.count == byId.count else { return }

        var next = ordered.makeIterator()
        packingItems = packingItems.map { item in
            wanted.contains(item.id) ? (next.next() ?? item) : item
        }
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

    /// 旅行のメモ帳（自由な文章1枚）。共有した旅行では全員が見て書ける。
    /// まとまった文章を残したい、というご要望から（`docs/設計_旅行のメモ帳.md`）
    var memo: String?

    /// 共有メンバーの表示名（ユーザーID → 名前）。**パブリックDBから読んだときだけ入る。**
    ///
    /// 保存（Core Data・JSON）には載せない。名前は共有レコードが正で、端末には
    /// `SharedMemberNameStore` が控えを持つ。各自が自分の分だけを書く
    var memberNames: [String: String] = [:]

    /// 共有レコードに載っているヘッダー写真の版と、取ってきた写真のファイル。
    /// **パブリックDBから読んだときだけ入る**（保存には載せない。`SharedCoverPhoto`）
    var sharedCoverVersion: String? = nil
    var sharedCoverFileURL: URL? = nil

    enum CodingKeys: String, CodingKey {
        case id, title, startDate, endDate, destination, latitude, longitude, localImageFileName, cardColorHex, createdAt, userId, daySchedules, packingItems
        case reservations
        case isShared, shareCode, sharedWith, ownerId, lastEditedBy, updatedAt, customSplitCount
        case memo
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
         customSplitCount: Int? = nil,
         memo: String? = nil) {
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
        self.memo = memo
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
        memo = try container.decodeIfPresent(String.self, forKey: .memo)

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
        try container.encodeIfPresent(memo, forKey: .memo)
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

    /// 中身が同じか。**更新時刻と最終編集者は見ない。**
    ///
    /// 「保存されたが何も変わっていない」を見分けるために使う。
    /// これを更新時刻の判断に使わないと、画面を開いて閉じただけで
    /// 手元が「新しい」ことになり、共有相手の編集を取り込めなくなる。
    ///
    /// `TravelPlan` は `Equatable` ではない（`Color` を持つため）ので、
    /// 比べる必要のあるものだけを並べている。**項目を足したらここにも足すこと。**
    /// 漏れると、その項目を直しても相手に伝わらない
    func isContentEqual(to other: TravelPlan) -> Bool {
        title == other.title
            && startDate == other.startDate
            && endDate == other.endDate
            && destination == other.destination
            && latitude == other.latitude
            && longitude == other.longitude
            && localImageFileName == other.localImageFileName
            && cardColorHex == other.cardColorHex
            && customSplitCount == other.customSplitCount
            && memo == other.memo
            && isShared == other.isShared
            && shareCode == other.shareCode
            && sharedWith == other.sharedWith
            && ownerId == other.ownerId
            && daySchedules == other.daySchedules
            && reservations == other.reservations
            && packingItems.count == other.packingItems.count
            && zip(packingItems, other.packingItems).allSatisfy { lhs, rhs in
                lhs.id == rhs.id
                    && lhs.name == rhs.name
                    && lhs.isChecked == rhs.isChecked
                    && lhs.kind == rhs.kind
                    && lhs.note == rhs.note
                    && lhs.ownerId == rhs.ownerId
            }
    }

    /// 同行者と共有している部分だけを比べる。
    ///
    /// 持ち主のいる持ち物・お土産と写真のファイル名は各自のもので、
    /// パブリックDBには載せていない（`CloudKitService.applySharedPlanFields`）。
    /// ここが違うだけなら相手へ送るものは無い。
    /// 並び順は端末ごとに違ってよいので、共有の持ち物は id 順にそろえて比べる
    func isSharedContentEqual(to other: TravelPlan) -> Bool {
        func sharedPart(of plan: TravelPlan) -> TravelPlan {
            var copy = plan
            copy.localImageFileName = nil
            copy.packingItems = plan.packingItems
                .filter { $0.ownerId == nil }
                .sorted { $0.id < $1.id }
            return copy
        }
        return sharedPart(of: self).isContentEqual(to: sharedPart(of: other))
    }

    /// その日付が旅行の何日目か。範囲外なら nil。
    /// 予約の日時から、行程のどの日に置くかを決めるのに使う
    func dayNumber(forDate date: Date) -> Int? {
        dayNumber(forDate: date, in: .current)
    }

    /// その時計で見たときに、旅行の何日目か。範囲外なら nil。
    ///
    /// パリの 23:00 は日本では翌朝なので、どの時計で日付を読むかで何日目かが変わる。
    /// 予約や予定は、それぞれの時計で読んだ日付で置く
    func dayNumber(forDate date: Date, in timeZone: TimeZone) -> Int? {
        guard let number = unclampedDayNumber(forDate: date, in: timeZone) else { return nil }
        return (1...dayCount).contains(number) ? number : nil
    }

    /// 旅行の期間から外れていても数える「何日目」（前日なら 0、翌日なら dayCount + 1）。
    /// 旅行の前日にチェックインする宿のように、期間をまたぐものを扱うのに使う
    func unclampedDayNumber(forDate date: Date, in timeZone: TimeZone) -> Int? {
        // 旅行の初日は日本で入れたものとして日付を読む（予定の時刻と同じ考え方）。
        // 端末の暦で読むと、海外にいるときだけ初日が前の日にずれることがある
        let startDay = ScheduleClock.calendar(in: ScheduleClock.legacyTimeZone)
            .dateComponents([.year, .month, .day], from: startDate)
        let targetDay = ScheduleClock.calendar(in: timeZone).dateComponents([.year, .month, .day], from: date)

        let utc = ScheduleClock.calendar(in: TimeZone(identifier: "UTC")!)
        guard let start = utc.date(from: startDay),
              let target = utc.date(from: targetDay),
              let diff = utc.dateComponents([.day], from: start, to: target).day else { return nil }
        return diff + 1
    }

    /// その日のタイムスケジュールに予定を足す
    mutating func addScheduleItem(_ item: ScheduleItem, onDay dayNumber: Int) {
        if let dayIndex = daySchedules.firstIndex(where: { $0.dayNumber == dayNumber }) {
            daySchedules[dayIndex].scheduleItems.append(item)
        } else {
            daySchedules.append(
                DaySchedule(dayNumber: dayNumber,
                            date: date(forDay: dayNumber),
                            scheduleItems: [item])
            )
            daySchedules.sort { $0.dayNumber < $1.dayNumber }
        }
    }

    // MARK: - 予約と行程の連動
    //
    // 「行程にも追加する」で作った予定は `reservationId` を持つ。
    // 名前や時刻ではなく id で辿るので、手で書いた同名の予定を巻き込まない。

    /// その予約から作られた予定が行程にあるか
    func hasScheduleItems(forReservation reservationId: String) -> Bool {
        daySchedules.contains { day in
            day.scheduleItems.contains { $0.reservationId == reservationId }
        }
    }

    /// その予約から作られた予定を、行程から全部消す。
    /// トグルを外したときと、予約そのものを消したときに使う
    mutating func removeScheduleItems(forReservation reservationId: String) {
        for index in daySchedules.indices {
            daySchedules[index].scheduleItems.removeAll { $0.reservationId == reservationId }
        }
    }

    /// その予約から作られた予定（時刻順）
    func scheduleItems(forReservation reservationId: String) -> [ScheduleItem] {
        daySchedules
            .flatMap(\.scheduleItems)
            .filter { $0.reservationId == reservationId }
            .sorted { $0.time < $1.time }
    }

    /// 行程の予定で金額を直したとき、元の予約の費用も揃える。
    ///
    /// 予約の費用は「その予約から作った予定の金額の合計」とする。
    /// 飛行機の到着の予定に金額を入れた場合も、2重に数えずに済む
    mutating func syncReservationCost(fromScheduleItemsOf reservationId: String) {
        guard let index = reservations.firstIndex(where: { $0.id == reservationId }) else { return }
        let items = scheduleItems(forReservation: reservationId)
        let costs = items.compactMap(\.cost)
        reservations[index].cost = costs.isEmpty ? nil : costs.reduce(0, +)

        // 外貨で入れていれば、予約の側も同じ通貨で持つ（通貨が混ざっていたら円だけにする）
        let foreign = items.compactMap(\.foreignCost).filter { $0.amount != nil }
        if let first = foreign.first, foreign.allSatisfy({ $0.currencyCode == first.currencyCode }) {
            reservations[index].foreignCost = ForeignCost(currencyCode: first.currencyCode, rate: first.rate,
                                                          amount: foreign.compactMap(\.amount).reduce(0, +))
        } else {
            reservations[index].foreignCost = nil
        }
    }

    /// 費用が入っていて、行程には出ていない予約。
    /// 行程に出ている予約の費用は予定の金額として数えるので、ここには入れない（2重に数えない）
    var reservationsWithCostOutsideItinerary: [Reservation] {
        reservations.filter { ($0.cost ?? 0) > 0 && !hasScheduleItems(forReservation: $0.id) }
    }

    /// 予算（予定の金額）の合計。行程の予定と、行程に出ていない予約の費用を足す
    var totalPlannedCost: Double {
        daySchedulesInRange.flatMap(\.scheduleItems).compactMap(\.cost).reduce(0, +)
            + reservationsWithCostOutsideItinerary.compactMap(\.cost).reduce(0, +)
    }

    /// 種類ごとのリスト。
    ///
    /// 持ち物・お土産・やりたいことは `packingItems` に混ざって入っている。
    /// **「持ち物」を出したい場所では必ずこれを通すこと。**
    /// `packingItems` をそのまま数えると、お土産とやりたいことまで
    /// 持ち物として数えてしまう
    func items(of kind: PackingItem.Kind) -> [PackingItem] {
        packingItems.filter { $0.kind == kind }
    }

    /// 旅行の日数（出発日と帰宅日を含む）
    var dayCount: Int {
        let days = Calendar.current.dayDifference(from: startDate, to: endDate)
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

    /// 日程を変えたとき、予定をどう動かすか。
    ///
    /// **アプリには決められない。** 出発日をずらしたとき、
    /// 「12/25 に取ったホテルは 12/25 のままにしたい」人と、
    /// 「2日目に入れた予定は2日目のまま動かしたい」人の両方がいる。
    /// 期間の長さなどから推測すると、必ずどちらかを裏切るので、保存前に選んでもらう
    enum ScheduleShift {
        /// 予定の日付を守る。日番号のほうを振り直す
        case keepDates
        /// 日番号を守る。予定は旅行ごと動く
        case keepDayNumbers
    }

    /// 日程を変えたあと、予定を置き直す
    mutating func realignDaySchedules(previousStartDate: Date, shift: ScheduleShift) {
        guard shift == .keepDates else {
            realignDayScheduleDates()
            return
        }

        let calendar = Calendar.current
        let newStart = calendar.startOfDay(for: startDate)

        for index in daySchedules.indices {
            let oldDate = calendar.date(byAdding: .day,
                                        value: daySchedules[index].dayNumber - 1,
                                        to: calendar.startOfDay(for: previousStartDate)) ?? newStart
            let diff = calendar.dateComponents([.day], from: newStart, to: oldDate).day ?? 0
            let newNumber = diff + 1

            daySchedules[index].dayNumber = newNumber
            daySchedules[index].date = date(forDay: newNumber)
        }

        // 範囲から外れた日（日番号が0以下）も消さない。期間を戻せば復活する
        daySchedules.sort { $0.dayNumber < $1.dayNumber }
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
        let length = Calendar.current.dayDifference(from: startDate, to: endDate)
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
        let shift = Calendar.current.dayDifference(from: startDate, to: newStartDate)
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
