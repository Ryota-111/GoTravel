import Foundation

// MARK: - カレンダーに入れる予定（3.0）
//
// 旅行計画・予定を、iPhone のカレンダーに入れる形にする。
// 「旅行の予定を Google カレンダーに反映させたい」というご要望から（2026年10月）。
// iPhone に Google アカウントを入れていれば、書き出す先に Google のカレンダーを選べる。
//
// ここは EventKit に触らない純粋な組み立てだけを置き、テストで確かめる。
// 書き込み・直し・消しは `CalendarExportService`

/// カレンダーに入れる1件
struct CalendarEventDraft: Equatable {
    /// Travory の中での目印（"trip" / "item:<id>" / "reservation:<id>"）。
    /// 入れた予定と突き合わせて、直す・消すのに使う
    let key: String
    var title: String
    var start: Date
    var end: Date
    var isAllDay: Bool
    /// 時刻を読む時計。海外の予定もその土地の時刻で入る。終日の予定は nil
    var timeZone: TimeZone?
    var location: String?
    var latitude: Double?
    var longitude: Double?
    var notes: String?
    var url: URL?
}

/// 旅行計画で、何をカレンダーに入れるか
struct CalendarExportOptions: Codable, Equatable {
    /// 旅行の期間（終日の予定）
    var includesTrip = true
    /// 日程の予定
    var includesSchedule = true
    /// 予約（日程に入れていないもの）
    var includesReservations = true
}

enum CalendarEventBuilder {

    /// 終わりの時刻が無い予定の長さ
    static let defaultDuration: TimeInterval = 60 * 60

    // MARK: 旅行計画

    static func drafts(for plan: TravelPlan, options: CalendarExportOptions) -> [CalendarEventDraft] {
        var drafts: [CalendarEventDraft] = []

        if options.includesTrip {
            drafts.append(CalendarEventDraft(
                key: "trip",
                title: "✈️ \(plan.title)",
                start: localDay(of: plan.startDate),
                end: localDay(of: plan.endDate),
                isAllDay: true,
                location: plan.destination.isEmpty ? nil : plan.destination,
                latitude: plan.latitude,
                longitude: plan.longitude,
                notes: footer
            ))
        }

        // 日程に入っている予約は、日程の予定として入る。予約からも入れると2重になる
        var reservationsInSchedule = Set<String>()

        if options.includesSchedule {
            // 旅行の日付は日本で入れたものとして読む（ウィジェットと同じ考え方）
            let tripCalendar = ScheduleClock.calendar(in: ScheduleClock.legacyTimeZone)
            for day in plan.daySchedules {
                let dayDate = tripCalendar.date(byAdding: .day, value: day.dayNumber - 1, to: plan.startDate) ?? day.date
                let dayParts = tripCalendar.dateComponents([.year, .month, .day], from: dayDate)
                for item in day.scheduleItems {
                    if let reservationId = item.reservationId { reservationsInSchedule.insert(reservationId) }
                    drafts.append(draft(for: item, onDay: dayParts))
                }
            }
        }

        if options.includesReservations {
            for reservation in plan.reservations where !reservationsInSchedule.contains(reservation.id) {
                if let draft = draft(for: reservation) { drafts.append(draft) }
            }
        }
        return drafts
    }

    static func draft(for item: ScheduleItem, onDay day: DateComponents) -> CalendarEventDraft {
        let start = item.occurrence(onDay: day)
        // 終わりの時刻は始まりと同じ日の時:分で持っている（`ScheduleItem.endTime`）。
        // 始まりからの長さにして、日のずれ（前日など）があってもそのまま足す
        let duration = item.endTime.map { $0.timeIntervalSince(item.time) }.flatMap { $0 > 0 ? $0 : nil }
        return CalendarEventDraft(
            key: "item:\(item.id)",
            title: item.title,
            start: start,
            end: start.addingTimeInterval(duration ?? defaultDuration),
            isAllDay: false,
            timeZone: item.timeZone,
            location: joinedLocation(item.location, item.address),
            latitude: item.latitude,
            longitude: item.longitude,
            notes: joinedNotes(item.notes),
            url: item.linkURL.flatMap(URL.init(string:))
        )
    }

    /// 時刻の無い予約（予約番号だけ控えた宿など）は入れない。置く日時が決まらないため
    static func draft(for reservation: Reservation) -> CalendarEventDraft? {
        guard let date = reservation.date else { return nil }
        let kind = reservation.kind

        let end: Date
        let location: String?
        if kind.usesRoute {
            end = reservation.arrivalDate.flatMap { $0 > date ? $0 : nil } ?? date.addingTimeInterval(defaultDuration)
            location = reservation.departurePlace ?? reservation.departureLocation?.name
        } else {
            end = reservation.endDate.flatMap { $0 > date ? $0 : nil } ?? date.addingTimeInterval(defaultDuration)
            location = joinedLocation(reservation.location?.name, reservation.location?.address)
        }

        var lines: [String] = []
        if let number = reservation.transportNumber?.trimmed, !number.isEmpty { lines.append("便名：\(number)") }
        if let seat = reservation.seat?.trimmed, !seat.isEmpty { lines.append("座席：\(seat)") }
        if let terminal = reservation.terminal?.trimmed, !terminal.isEmpty { lines.append("ターミナル：\(terminal)") }
        if let notes = reservation.itineraryNotes { lines.append(notes) }

        let place = kind.usesRoute ? reservation.departureLocation : reservation.location
        return CalendarEventDraft(
            key: "reservation:\(reservation.id)",
            title: reservation.title,
            start: date,
            end: end,
            isAllDay: false,
            timeZone: reservation.dateTimeZone,
            location: location,
            latitude: place?.latitude,
            longitude: place?.longitude,
            notes: joinedNotes(lines.isEmpty ? nil : lines.joined(separator: "\n")),
            url: reservation.linkURL.flatMap(URL.init(string:))
        )
    }

    // MARK: おでかけ・日常の予定

    static func drafts(for plan: Plan, calendar: Calendar = .current) -> [CalendarEventDraft] {
        var drafts: [CalendarEventDraft] = []
        let main: CalendarEventDraft
        if let time = plan.time {
            let start = combine(day: plan.startDate, time: time, calendar: calendar)
            var end = plan.endTime.map { combine(day: plan.startDate, time: $0, calendar: calendar) }
                ?? start.addingTimeInterval(defaultDuration)
            if end <= start { end = start.addingTimeInterval(defaultDuration) }
            main = CalendarEventDraft(key: "plan", title: plan.title, start: start, end: end, isAllDay: false,
                                      timeZone: calendar.timeZone)
        } else {
            main = CalendarEventDraft(key: "plan", title: plan.title, start: plan.startDate, end: plan.endDate,
                                      isAllDay: true)
        }
        var mainDraft = main
        let place = plan.places.first
        mainDraft.location = place.map { joinedLocation($0.name, $0.address) } ?? nil
        mainDraft.latitude = place?.latitude
        mainDraft.longitude = place?.longitude
        mainDraft.notes = joinedNotes(plan.description)
        mainDraft.url = plan.linkURL.flatMap(URL.init(string:))
        drafts.append(mainDraft)

        // おでかけのスケジュール（日時を持っている）
        for item in plan.scheduleItems {
            let linked = item.placeId.flatMap { id in plan.places.first { $0.id == id } }
            drafts.append(CalendarEventDraft(
                key: "item:\(item.id)",
                title: item.title,
                start: item.time,
                end: item.time.addingTimeInterval(defaultDuration),
                isAllDay: false,
                timeZone: calendar.timeZone,
                location: linked.map { joinedLocation($0.name, $0.address) } ?? nil,
                latitude: linked?.latitude,
                longitude: linked?.longitude,
                notes: joinedNotes(item.note)
            ))
        }
        return drafts
    }

    // MARK: 部品

    /// 予定の説明の最後に添える一言。カレンダーで見たときに、どこで直せばいいかが分かるように
    static let footer = "Travory から入れた予定です。直すときは Travory で直してください。"

    private static func joinedNotes(_ notes: String?) -> String {
        guard let notes = notes?.trimmed, !notes.isEmpty else { return footer }
        return notes + "\n\n" + footer
    }

    private static func joinedLocation(_ name: String?, _ address: String?) -> String? {
        let parts = [name?.trimmed, address?.trimmed].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: "\n")
    }

    /// 旅行の日付（日本で入れたもの）を、この端末の暦の同じ日の 0:00 にする。
    /// 終日の予定は時計を持たないので、海外で開いても日付がずれないように
    static func localDay(of date: Date, calendar: Calendar = .current) -> Date {
        let parts = ScheduleClock.calendar(in: ScheduleClock.legacyTimeZone).dateComponents([.year, .month, .day], from: date)
        return calendar.date(from: parts) ?? date
    }

    /// 日付と時:分を合わせる
    private static func combine(day: Date, time: Date, calendar: Calendar) -> Date {
        let hm = calendar.dateComponents([.hour, .minute], from: time)
        return calendar.date(bySettingHour: hm.hour ?? 0, minute: hm.minute ?? 0, second: 0, of: day) ?? day
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
