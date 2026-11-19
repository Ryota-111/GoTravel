import Foundation

// MARK: - 予定と予定の間の移動手段（3.2）
//
// 「行程の時間と時間の間に移動手段のマーク（徒歩、電車、バス、飛行機、車、タクシー、船）が
// あったら嬉しい」というご要望から。前の予定に「次の予定までの移動手段」として持たせる。
//
// 予定には文字列（rawValue）で持つ。enum のまま持つと、後の版で手段を増やしたとき、
// 古い版が知らない値を読めずに予定ごと読み込めなくなるため

enum TransportMode: String, CaseIterable, Identifiable {
    case walk
    case train
    case bus
    case car
    case taxi
    case plane
    case ship

    var id: String { rawValue }

    var title: String {
        switch self {
        case .walk: return "徒歩"
        case .train: return "電車"
        case .bus: return "バス"
        case .car: return "車"
        case .taxi: return "タクシー"
        case .plane: return "飛行機"
        case .ship: return "船"
        }
    }

    var systemImage: String {
        switch self {
        case .walk: return "figure.walk"
        case .train: return "tram.fill"
        case .bus: return "bus.fill"
        case .car: return "car.fill"
        case .taxi: return "car.side.fill"
        case .plane: return "airplane"
        case .ship: return "ferry.fill"
        }
    }

    /// 予定に入っている文字列から。知らない値（新しい版で増えた手段）は nil
    init?(storedValue: String?) {
        guard let storedValue else { return nil }
        self.init(rawValue: storedValue)
    }
}

extension ScheduleItem {
    /// 次の予定までの移動手段
    var transportToNextMode: TransportMode? { TransportMode(storedValue: transportToNext) }
}

extension PlanScheduleItem {
    /// 次の予定までの移動手段
    var transportToNextMode: TransportMode? { TransportMode(storedValue: transportToNext) }
}

extension ScheduleItem {
    /// 時間軸で、この予定の点から次の予定の点までの線に出す手段（3.8）。
    ///
    /// 「移動」の予定（足す・直す画面の「移動」で入れたもの）は、線がその移動そのものなので、その乗り物を出す。
    /// 3.7 までは「次の予定までの移動手段」を出していて、電車の移動に「電車」を選ぶと、
    /// 着いてから次の予定までの時間が電車の時間として出ていた（ご報告から）
    var timelineTransportMode: TransportMode? {
        if isSingleMove, let move { return move.transportMode }
        return transportToNextMode
    }

    /// 線に添える時間。「移動」の予定は乗っている時間（出発 → 到着）、
    /// それ以外は終わりの時刻があるときだけ、終わり〜次の始まり（滞在の時間が混ざるため）。
    /// 時間未定の予定（3.4）が絡む区間は、時刻が並ぶ位置でしかないので出さない
    func timelineTransportDuration(to next: ScheduleItem?) -> TimeInterval? {
        guard let next, let endTime, !hasUndecidedTime else { return nil }
        if isSingleMove { return endTime.timeIntervalSince(time) }
        guard !next.hasUndecidedTime else { return nil }
        return next.time.timeIntervalSince(endTime)
    }
}
