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
