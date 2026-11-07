import Foundation

// MARK: - 「移動」の予定（3.4）
//
// 「バスに乗る時間や、どのバスに乗るかを予定表に入れたい」「移動の時は駅の名前（発着点）を入れたい」
// というご意見から（`docs/設計_移動と時間未定.md`）。
//
// 予定1件に、乗り物・出発地・到着地・便や系統を持たせる。時刻は今までどおり、
// 始まり（`time`）が出発、終わり（`endTime`）が到着。
//
// **予定の `location`・位置・住所には出発地を入れる。** 地図のピン・「案内」・古い版の表示が
// そのまま効くようにするため。名前を入れなければ「梅田 → 京都」を名前にする（古い版でも中身が分かる）

/// 移動の発着地。地図で選んだときは位置と住所を持つ
struct MovePlace: Codable, Equatable {
    var name: String
    var address: String?
    var latitude: Double?
    var longitude: Double?

    var hasCoordinate: Bool { latitude != nil && longitude != nil }
}

struct ScheduleMove: Codable, Equatable {
    /// 乗り物（`TransportMode` の rawValue）。文字列で持つ理由は `TransportMode` の説明を参照
    var mode: String
    /// 便名・系統・列車名（「阪急バス 12系統」「のぞみ21号」「ANA123」）
    var line: String?
    /// のりば・番線（「3番のりば」「14番線」）
    var platform: String?
    /// 座席（「7号車 3D」「12A」）
    var seat: String?
    var from: MovePlace?
    var to: MovePlace?

    init(mode: TransportMode = .train, line: String? = nil, platform: String? = nil, seat: String? = nil,
         from: MovePlace? = nil, to: MovePlace? = nil) {
        self.mode = mode.rawValue
        self.line = Self.cleaned(line)
        self.platform = Self.cleaned(platform)
        self.seat = Self.cleaned(seat)
        self.from = from.flatMap { Self.cleaned($0.name) == nil ? nil : $0 }
        self.to = to.flatMap { Self.cleaned($0.name) == nil ? nil : $0 }
    }

    /// 乗り物。知らない値（新しい版で増えた手段）は電車として扱う
    var transportMode: TransportMode { TransportMode(storedValue: mode) ?? .train }

    /// 「梅田 → 京都」。片方だけなら「梅田 →」「→ 京都」。どちらも無ければ nil
    var routeText: String? {
        let fromName = Self.cleaned(from?.name)
        let toName = Self.cleaned(to?.name)
        switch (fromName, toName) {
        case let (from?, to?): return "\(from) → \(to)"
        case let (from?, nil): return "\(from) →"
        case let (nil, to?): return "→ \(to)"
        default: return nil
        }
    }

    /// 名前を入れなかったときの名前。発着地が無ければ「バスで移動」
    var defaultTitle: String {
        routeText ?? "\(transportMode.title)で移動"
    }

    /// 「阪急バス 12系統 · 3番のりば · 座席 7号車 3D」。何も無ければ nil
    var detailText: String? {
        let parts = [Self.cleaned(line), Self.cleaned(platform), Self.cleaned(seat).map { "座席 \($0)" }].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// 出発地と到着地を入れ替えたもの（帰りの移動を作るときなど）
    var swapped: ScheduleMove {
        var copy = self
        copy.from = to
        copy.to = from
        return copy
    }

    /// 「案内」で向かう先。出発前に乗り場へ向かうので出発地。位置が無ければ到着地
    var navigationPlace: MovePlace? {
        if let from, from.hasCoordinate { return from }
        if let to, to.hasCoordinate { return to }
        return nil
    }

    private static func cleaned(_ text: String?) -> String? {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

extension ScheduleItem {
    /// 乗り物・便の情報を持つ予定か（移動の1件と、乗り物の予約の出発・到着の両方）
    var isMove: Bool { move != nil }

    /// 乗り物の予約から作った「出発」「到着」の予定か。場所はそれぞれの1か所で、乗り物・便だけを添えて出す
    var isRouteLeg: Bool {
        move != nil && (reservationPart == ReservationPart.departure.rawValue || reservationPart == ReservationPart.arrival.rawValue)
    }

    /// 出発地 → 到着地を1件で持つ「移動」の予定か（足す・直す画面の「移動」で入れたもの）
    var isSingleMove: Bool { move != nil && !isRouteLeg }

    /// 移動の中身を入れる。名前を空にしたら「梅田 → 京都」を名前にし、
    /// 予定の場所には出発地を入れる（地図・案内・古い版の表示のため）
    mutating func apply(move newMove: ScheduleMove, title enteredTitle: String) {
        move = newMove
        let trimmed = enteredTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        title = trimmed.isEmpty ? newMove.defaultTitle : trimmed
        location = newMove.from?.name ?? newMove.to?.name
        let anchor = newMove.from ?? newMove.to
        latitude = anchor?.latitude
        longitude = anchor?.longitude
        address = anchor?.address
    }

    /// 名前が自動で付けたもの（「梅田 → 京都」）のままか。日程の行で発着地を2度出さないのに使う
    var hasDefaultMoveTitle: Bool {
        guard let move else { return false }
        return title == move.defaultTitle
    }
}
