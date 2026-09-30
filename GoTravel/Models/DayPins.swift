import Foundation

// MARK: - その日の一番上に出すもの
//
// 「複数日にわたる予定（滞在先）を、一日の一番上に表示したい」という要望から。
// 一番上に出すのは2種類。
//
// - **期間のある予約**（宿、レンタカー、周遊パスなど）: 期間中の各日に出す。
//   時刻の決まった予定ではないので、タイムスケジュールの予定としては増やさない。
//   予約から表示のたびに組み立てるので、予約を書き換えれば追従する
// - **固定した予定**（「集合場所：那覇空港 2F」など）: その日ずっと気にしたいもの。
//   時刻の並びから外して上に出す
//
// 予定を何日にもまたがらせることはしない。予定は1日ごとに持つ作りで、
// 並べ替えや共有のマージにも響くため。何日にもまたがるものは予約に寄せる

/// その日に関係する、期間のある予約
struct ReservationOnDay: Identifiable, Equatable {

    enum Phase: Equatable {
        /// 始まる日（チェックイン・受け取り）。期間が分かっていれば `total` が入る
        case start(time: String, total: Int?)
        /// 途中の日
        case middle(index: Int, total: Int)
        /// 終わる日（チェックアウト・返却）
        case end(time: String)
    }

    let reservation: Reservation
    let phase: Phase

    var id: String { "\(reservation.id)-\(phase)" }

    var name: String {
        let title = reservation.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? reservation.kind.label : title
    }

    var icon: String { reservation.kind.icon }

    /// 宿は「泊」、それ以外は「日」で数える
    private var unit: String { reservation.kind == .hotel ? "泊" : "日" }

    /// 「チェックイン 15:00・1泊目 / 全3泊」「返却 17:00」のような添え書き
    var detail: String {
        let kind = reservation.kind
        switch phase {
        case .start(let time, let total):
            guard let total, total > 0 else { return "\(kind.startLabel) \(time)" }
            return "\(kind.startLabel) \(time)・1\(unit)目 / 全\(total)\(unit)"
        case .middle(let index, let total):
            return "\(index)\(unit)目 / 全\(total)\(unit)"
        case .end(let time):
            return "\(kind.endLabel) \(time)"
        }
    }

    /// 同じ日に重なったときの並び（朝に終わるもの → 途中のもの → 始まるもの）
    fileprivate var order: Int {
        switch phase {
        case .end: return 0
        case .middle: return 1
        case .start: return 2
        }
    }
}

extension Reservation {

    /// 日程の一番上に出すか。選んだものだけ出す（初期値はどの種類でも出さない）。
    /// 勝手に出すと、控えただけの予約で一番上が埋まってしまう
    var showsOnEveryDay: Bool {
        kind.usesPeriod && pinsDuringPeriod == true
    }

    /// 期間の長さ。宿は泊数、それ以外は日数。始まりと終わりがそろっていないときは nil
    var periodCount: Int? {
        guard kind.usesPeriod, let start = date, let end = endDate else { return nil }
        let clock = ScheduleClock.calendar(in: dateTimeZone)
        let days = clock.dateComponents([.day],
                                        from: clock.startOfDay(for: start),
                                        to: clock.startOfDay(for: end)).day ?? 0
        let count = kind == .hotel ? days : days + 1
        return count > 0 ? count : nil
    }

    /// 一覧や書き出しに出す日時。
    /// 期間があれば「10月6日(火) 15:00 〜 10月9日(金) 11:00・3泊」
    var dateLineText: String? {
        guard let date else { return nil }
        let format = "M月d日(E) HH:mm"
        let start = ScheduleClock.text(date, format: format, in: dateTimeZone)
        guard let end = endDate, let count = periodCount else { return start }
        let unit = kind == .hotel ? "泊" : "日間"
        return "\(start) 〜 \(ScheduleClock.text(end, format: format, in: dateTimeZone))・\(count)\(unit)"
    }
}

extension TravelPlan {

    /// その日の一番上に出す予約。終わるもの → 途中のもの → 始まるもの の順
    func pinnedReservations(onDay dayNumber: Int) -> [ReservationOnDay] {
        reservations
            .filter(\.showsOnEveryDay)
            .compactMap { entry(for: $0, onDay: dayNumber) }
            .sorted { $0.order < $1.order }
    }

    /// その日の一番上に固定した予定。
    /// - Parameter member: 共有した旅行で、この人の時間軸だけを見るとき。nil なら全員
    func pinnedScheduleItems(onDay dayNumber: Int, for member: String? = nil) -> [ScheduleItem] {
        scheduleItems(onDay: dayNumber)
            .filter { $0.isPinned == true && SharedMembers.includes($0, member: member) }
            .sorted(by: ScheduleItem.chronologically)
    }

    /// その日の、時刻の並びに出す予定（固定したものを除く）。
    /// - Parameter member: 共有した旅行で、この人の時間軸だけを見るとき。nil なら全員
    func timelineScheduleItems(onDay dayNumber: Int, for member: String? = nil) -> [ScheduleItem] {
        scheduleItems(onDay: dayNumber)
            .filter { $0.isPinned != true && SharedMembers.includes($0, member: member) }
            .sorted(by: ScheduleItem.chronologically)
    }

    private func scheduleItems(onDay dayNumber: Int) -> [ScheduleItem] {
        daySchedules.first { $0.dayNumber == dayNumber }?.scheduleItems ?? []
    }

    private func entry(for reservation: Reservation, onDay dayNumber: Int) -> ReservationOnDay? {
        guard let start = reservation.date else { return nil }

        // 予約の時計で日付を読む。パリの宿の 23:00 チェックインは、パリのその日
        let zone = reservation.dateTimeZone
        guard let startDay = unclampedDayNumber(forDate: start, in: zone) else { return nil }
        let endDay = reservation.endDate.flatMap { unclampedDayNumber(forDate: $0, in: zone) }
        let total = reservation.periodCount

        if dayNumber == startDay {
            return ReservationOnDay(reservation: reservation,
                                    phase: .start(time: ScheduleClock.timeText(start, in: zone), total: total))
        }

        guard let total, let endDay, let end = reservation.endDate else { return nil }

        if dayNumber > startDay && dayNumber < endDay {
            return ReservationOnDay(reservation: reservation,
                                    phase: .middle(index: dayNumber - startDay + 1, total: total))
        }
        if dayNumber == endDay {
            return ReservationOnDay(reservation: reservation,
                                    phase: .end(time: ScheduleClock.timeText(end, in: zone)))
        }
        return nil
    }
}
