import Foundation

/// 予定の通知を1本ずつ表したもの。
///
/// 以前は種別ごとに決め打ちの組み合わせを丸ごと入れるか消すかしかできず、
/// しかも**入切の状態をどこにも保存していなかった**。
/// 予約が残っているかどうかで入切を判断していたため、
/// 通知が鳴り終わると勝手に「切」になり、予定を編集すると切ったはずの通知が戻っていた。
///
/// ここを予定が持つ設定にして、鳴らすものを選べるようにする
enum PlanReminder: String, Codable, CaseIterable, Identifiable {
    /// 1週間前の朝9時
    case oneWeekBefore
    /// 前日の夜19時
    case eveningBefore
    /// 当日の朝9時
    case morningOfDay
    /// 開始時刻の1時間前
    case oneHourBefore
    /// 開始時刻の30分前
    case thirtyMinutesBefore
    /// 開始時刻の10分前
    case tenMinutesBefore
    /// 開始時刻ちょうど
    case atStart

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .oneWeekBefore:       return "1週間前（朝9時）"
        case .eveningBefore:       return "前日の夜（19時）"
        case .morningOfDay:        return "当日の朝（9時）"
        case .oneHourBefore:       return "1時間前"
        case .thirtyMinutesBefore: return "30分前"
        case .tenMinutesBefore:    return "10分前"
        case .atStart:             return "開始時刻ちょうど"
        }
    }

    /// 開始時刻を基準にするもの。時刻を持たない予定では選べない
    var requiresTime: Bool {
        switch self {
        case .oneWeekBefore, .eveningBefore, .morningOfDay:
            return false
        case .oneHourBefore, .thirtyMinutesBefore, .tenMinutesBefore, .atStart:
            return true
        }
    }

    // MARK: - 種別ごとの選択肢と既定値

    /// その予定で選べる通知。`allCases` の並び（早い順）を保つ
    static func options(for planType: PlanType, hasTime: Bool) -> [PlanReminder] {
        switch planType {
        case .outing:
            // おでかけは日単位。開始時刻を持たないので、時刻基準のものは出さない
            return [.oneWeekBefore, .eveningBefore, .morningOfDay]
        case .daily:
            let dayBased: [PlanReminder] = [.eveningBefore, .morningOfDay]
            guard hasTime else { return dayBased }
            return dayBased + [.oneHourBefore, .thirtyMinutesBefore, .tenMinutesBefore, .atStart]
        case .anniversary:
            // 記念日は時刻を持たない
            return [.oneWeekBefore, .eveningBefore, .morningOfDay]
        }
    }

    /// 何も設定されていない予定に使う既定値。
    /// **これまでの動作と同じ組み合わせにしてある。**
    /// 設定を足したことで、既存の予定の鳴り方が変わってしまわないようにする
    static func defaults(for planType: PlanType, hasTime: Bool) -> [PlanReminder] {
        switch planType {
        case .outing:
            return [.eveningBefore]
        case .daily:
            guard hasTime else { return [.eveningBefore, .morningOfDay] }
            return [.eveningBefore, .morningOfDay, .oneHourBefore, .tenMinutesBefore]
        case .anniversary:
            return [.oneWeekBefore, .morningOfDay]
        }
    }
}

// MARK: - 通知を出す日時と文言

extension PlanReminder {

    /// この通知が鳴る日時。時刻基準なのに予定が時刻を持たなければ nil
    func fireDate(for plan: Plan, calendar: Calendar = .current) -> Date? {
        switch self {
        case .oneWeekBefore:
            return date(daysBefore: 7, hour: 9, from: plan.startDate, calendar: calendar)
        case .eveningBefore:
            return date(daysBefore: 1, hour: 19, from: plan.startDate, calendar: calendar)
        case .morningOfDay:
            return date(daysBefore: 0, hour: 9, from: plan.startDate, calendar: calendar)
        case .oneHourBefore:
            return startDateTime(for: plan, calendar: calendar)
                .flatMap { calendar.date(byAdding: .minute, value: -60, to: $0) }
        case .thirtyMinutesBefore:
            return startDateTime(for: plan, calendar: calendar)
                .flatMap { calendar.date(byAdding: .minute, value: -30, to: $0) }
        case .tenMinutesBefore:
            return startDateTime(for: plan, calendar: calendar)
                .flatMap { calendar.date(byAdding: .minute, value: -10, to: $0) }
        case .atStart:
            return startDateTime(for: plan, calendar: calendar)
        }
    }

    private func date(daysBefore: Int, hour: Int, from date: Date, calendar: Calendar) -> Date? {
        guard let shifted = calendar.date(byAdding: .day, value: -daysBefore, to: date) else { return nil }

        var components = calendar.dateComponents([.year, .month, .day], from: shifted)
        components.hour = hour
        components.minute = 0
        components.second = 0
        return calendar.date(from: components)
    }

    /// 予定日の日付と、開始時刻の時分を組み合わせた日時。
    /// `time` は作られた日の日付を持ったままなので、日付側は必ず `startDate` を使う
    private func startDateTime(for plan: Plan, calendar: Calendar) -> Date? {
        guard let time = plan.time else { return nil }

        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        var components = calendar.dateComponents([.year, .month, .day], from: plan.startDate)
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        components.second = 0
        return calendar.date(from: components)
    }

    func notificationTitle(for plan: Plan) -> String {
        switch self {
        case .oneWeekBefore:
            return plan.planType == .anniversary ? "記念日が1週間後です" : "予定が1週間後です"
        case .eveningBefore:
            return plan.planType == .outing ? "おでかけが明日です" : "予定が明日です"
        case .morningOfDay:
            return plan.planType == .anniversary ? "今日は記念日です" : "今日の予定"
        case .oneHourBefore:
            return "予定が1時間後です"
        case .thirtyMinutesBefore:
            return "予定が30分後です"
        case .tenMinutesBefore:
            return "予定が10分後です"
        case .atStart:
            return "予定の時間です"
        }
    }

    func notificationBody(for plan: Plan) -> String {
        switch self {
        case .oneWeekBefore:
            return plan.planType == .anniversary
                ? plan.title
                : "\(plan.title)が1週間後です。"
        case .eveningBefore:
            return plan.planType == .outing
                ? "\(plan.title)が明日です。楽しみですね！"
                : "\(plan.title)が明日です。準備をお忘れなく！"
        case .morningOfDay:
            if plan.planType == .anniversary {
                return plan.title
            }
            if let timeText = plan.timeRangeText {
                return "今日\(timeText)に「\(plan.title)」の予定があります。"
            }
            return "今日「\(plan.title)」の予定があります。"
        case .oneHourBefore:
            return "\(plan.title)が1時間後に始まります。"
        case .thirtyMinutesBefore:
            return "\(plan.title)が30分後に始まります。"
        case .tenMinutesBefore:
            return "\(plan.title)が10分後に始まります。準備してください！"
        case .atStart:
            return "\(plan.title)の時間です。"
        }
    }
}

// MARK: - Plan

extension Plan {

    /// 実際に鳴らす通知。
    /// 設定していない予定（`nil`）は既定の組み合わせ、空配列は「通知しない」
    var effectiveReminders: [PlanReminder] {
        let selected = reminders ?? PlanReminder.defaults(for: planType, hasTime: time != nil)

        // 時刻を消したあとに時刻基準の通知だけ残る、といった食い違いを起こさない
        let allowed = PlanReminder.options(for: planType, hasTime: time != nil)
        return allowed.filter { selected.contains($0) }
    }

    var hasReminders: Bool { !effectiveReminders.isEmpty }
}
