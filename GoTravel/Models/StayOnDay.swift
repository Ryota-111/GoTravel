import Foundation

/// その日に泊まっている宿。旅行計画の日程で、その日の予定の一番上に出す。
///
/// 「複数日にわたる予定（滞在先）を、一日の一番上に表示したい」という要望から。
/// 宿は時刻の決まった予定ではないので、タイムスケジュールの予定としては増やさない。
/// 予約（宿泊）のチェックイン・チェックアウトから、表示するたびに組み立てる。
/// 予約を書き換えれば、各日の表示もそのまま追従する
struct StayOnDay: Identifiable, Equatable {

    enum Phase: Equatable {
        /// チェックインする日。何泊か分かっていれば `totalNights` が入る
        case checkIn(time: String, totalNights: Int?)
        /// 泊まっている途中の日（2泊目以降）
        case night(index: Int, totalNights: Int)
        /// チェックアウトする日
        case checkOut(time: String)
    }

    let reservation: Reservation
    let phase: Phase

    var id: String { "\(reservation.id)-\(phase)" }

    var name: String {
        let title = reservation.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "宿泊" : title
    }

    /// 「チェックイン 15:00・1泊目 / 全3泊」のような添え書き
    var detail: String {
        switch phase {
        case .checkIn(let time, let totalNights):
            guard let totalNights, totalNights > 0 else { return "チェックイン \(time)" }
            return "チェックイン \(time)・1泊目 / 全\(totalNights)泊"
        case .night(let index, let totalNights):
            return "\(index)泊目 / 全\(totalNights)泊"
        case .checkOut(let time):
            return "チェックアウト \(time)"
        }
    }

    /// 同じ日に宿が2つ重なったときの並び（朝に出る宿 → 泊まっている宿 → 夕方に入る宿）
    fileprivate var order: Int {
        switch phase {
        case .checkOut: return 0
        case .night: return 1
        case .checkIn: return 2
        }
    }
}

extension TravelPlan {

    /// その日に関係する宿。チェックアウト → 滞在中 → チェックイン の順
    func stays(onDay dayNumber: Int) -> [StayOnDay] {
        reservations
            .compactMap { stay(of: $0, onDay: dayNumber) }
            .sorted { $0.order < $1.order }
    }

    private func stay(of reservation: Reservation, onDay dayNumber: Int) -> StayOnDay? {
        guard reservation.kind == .hotel, let checkIn = reservation.date else { return nil }

        // 宿の時計で日付を読む。パリの宿の 23:00 チェックインは、パリのその日
        let zone = reservation.dateTimeZone
        guard let checkInDay = unclampedDayNumber(forDate: checkIn, in: zone) else { return nil }
        let checkOutDay = reservation.checkOutDate.flatMap { unclampedDayNumber(forDate: $0, in: zone) }

        // 泊数。チェックアウトが無い・チェックインより前なら分からない扱い
        let totalNights = checkOutDay.map { $0 - checkInDay }.flatMap { $0 > 0 ? $0 : nil }

        if dayNumber == checkInDay {
            return StayOnDay(reservation: reservation,
                             phase: .checkIn(time: ScheduleClock.timeText(checkIn, in: zone),
                                             totalNights: totalNights))
        }

        guard let totalNights, let checkOutDay, let checkOut = reservation.checkOutDate else { return nil }

        if dayNumber > checkInDay && dayNumber < checkOutDay {
            return StayOnDay(reservation: reservation,
                             phase: .night(index: dayNumber - checkInDay + 1, totalNights: totalNights))
        }
        if dayNumber == checkOutDay {
            return StayOnDay(reservation: reservation,
                             phase: .checkOut(time: ScheduleClock.timeText(checkOut, in: zone)))
        }
        return nil
    }
}

extension Reservation {

    /// 泊数。宿泊でチェックイン・チェックアウトがそろっているときだけ
    var nights: Int? {
        guard kind == .hotel, let checkIn = date, let checkOut = checkOutDate else { return nil }
        let clock = ScheduleClock.calendar(in: dateTimeZone)
        let count = clock.dateComponents([.day],
                                         from: clock.startOfDay(for: checkIn),
                                         to: clock.startOfDay(for: checkOut)).day ?? 0
        return count > 0 ? count : nil
    }

    /// 一覧や書き出しに出す日時。
    /// 宿泊でチェックアウトがあれば「10月6日(火) 15:00 〜 10月9日(金) 11:00・3泊」
    var dateLineText: String? {
        guard let date else { return nil }
        let format = "M月d日(E) HH:mm"
        let start = ScheduleClock.text(date, format: format, in: dateTimeZone)
        guard let checkOut = checkOutDate, let nights else { return start }
        let end = ScheduleClock.text(checkOut, format: format, in: dateTimeZone)
        return "\(start) 〜 \(end)・\(nights)泊"
    }
}
