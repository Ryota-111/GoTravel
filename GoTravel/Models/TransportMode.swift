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
        if let chosen = transportToNextMode { return chosen }
        // 乗り物の予約の「出発」の予定（出発と到着の2件で出したもの）は、到着までその乗り物に乗っているので、
        // 選んでいなくても線をその乗り物にする（3.8、ご要望から）
        if isDepartureLeg, let move { return move.transportMode }
        return nil
    }

    /// 乗り物の予約から作った「出発」の予定か
    var isDepartureLeg: Bool {
        move != nil && reservationPart == ReservationPart.departure.rawValue
    }

    /// 時間軸の線の乗り物が予定そのものから決まっていて、「外す」が効かないか
    /// （「移動」の予定と、乗り物を選んでいない「出発」の予定）
    var hasFixedTimelineTransport: Bool {
        isSingleMove || (isDepartureLeg && transportToNextMode == nil)
    }

    /// 線に添える時間。「移動」の予定は乗っている時間（出発 → 到着）、
    /// それ以外は終わりの時刻があるときだけ、終わり〜次の始まり（滞在の時間が混ざるため）。
    /// 時間未定の予定（3.4）が絡む区間は、時刻が並ぶ位置でしかないので出さない
    func timelineTransportDuration(to next: ScheduleItem?) -> TimeInterval? {
        // 乗り物の予約の出発から到着までは、乗っている時間（3.8）
        if isDepartureLeg, let next, let reservationId, next.reservationId == reservationId,
           next.reservationPart == ReservationPart.arrival.rawValue {
            let ride = next.time.timeIntervalSince(time)
            return ride > 0 ? ride : nil
        }
        guard let next, let endTime, !hasUndecidedTime else { return nil }
        if isSingleMove { return endTime.timeIntervalSince(time) }
        guard !next.hasUndecidedTime else { return nil }
        return next.time.timeIntervalSince(endTime)
    }
}
