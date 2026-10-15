import Testing
import Foundation
@testable import GoTravel

/// カレンダーに入れる（3.0）。入れる中身と、直す・消すの判断が正しいこと
struct CalendarExportTests {

    private let japan = TimeZone(identifier: "Asia/Tokyo")!
    private let paris = TimeZone(identifier: "Europe/Paris")!

    private func at(_ day: Int, _ hour: Int, _ minute: Int = 0, in zone: TimeZone) -> Date {
        ScheduleClock.calendar(in: zone).date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    private func trip(days: [DaySchedule] = [], reservations: [Reservation] = []) -> TravelPlan {
        TravelPlan(id: "trip-1", title: "パリ旅行", startDate: at(10, 0, in: japan), endDate: at(12, 0, in: japan),
                   destination: "パリ", daySchedules: days, reservations: reservations)
    }

    // MARK: - 旅行計画

    @Test("旅行の期間は終日の予定で、端末の暦の同じ日になる")
    func tripIsAllDay() {
        let drafts = CalendarEventBuilder.drafts(for: trip(), options: .init())
        let tripDraft = drafts.first { $0.key == "trip" }
        #expect(tripDraft?.isAllDay == true)
        #expect(tripDraft?.title == "✈️ パリ旅行")
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: tripDraft!.start)
        #expect(parts.day == 10 && parts.month == 10)
        #expect(Calendar.current.dateComponents([.day], from: tripDraft!.end).day == 12)
    }

    @Test("日程の予定は、その日・その時間帯の時刻で入り、終わりの時刻も入る")
    func scheduleItem() {
        let item = ScheduleItem(id: "a", time: at(1, 15, in: paris), title: "ルーヴル美術館", location: "ルーヴル",
                                timeZoneIdentifier: "Europe/Paris", endTime: at(1, 17, 30, in: paris))
        let plan = trip(days: [DaySchedule(dayNumber: 2, date: at(11, 0, in: japan), scheduleItems: [item])])
        let draft = CalendarEventBuilder.drafts(for: plan, options: .init()).first { $0.key == "item:a" }

        #expect(draft?.start == at(11, 15, in: paris))
        #expect(draft?.end == at(11, 17, 30, in: paris))
        #expect(draft?.timeZone?.identifier == "Europe/Paris")
        #expect(draft?.isAllDay == false)
        #expect(draft?.notes?.contains("Travory") == true)
    }

    @Test("前日にずらした予定は、前の日に入る")
    func dayShiftedItem() {
        var item = ScheduleItem(id: "a", time: at(1, 17, in: paris), title: "前夜祭", timeZoneIdentifier: "Europe/Paris")
        item.dayShift = -1
        let plan = trip(days: [DaySchedule(dayNumber: 2, date: at(11, 0, in: japan), scheduleItems: [item])])
        let draft = CalendarEventBuilder.drafts(for: plan, options: .init()).first { $0.key == "item:a" }
        #expect(draft?.start == at(10, 17, in: paris))
    }

    @Test("日程に入れてある予約は2重に入れない。時刻の無い予約は入れない")
    func reservationsNotDuplicated() {
        let flight = Reservation(id: "r1", kind: .flight, title: "羽田 → パリ", date: at(10, 10, in: japan),
                                 confirmationNumber: "ABC123", transportNumber: "NH215",
                                 departurePlace: "羽田空港", arrivalDate: at(10, 16, in: paris),
                                 timeZoneIdentifier: "Asia/Tokyo", arrivalTimeZoneIdentifier: "Europe/Paris")
        let hotel = Reservation(id: "r2", kind: .hotel, title: "ホテル", date: at(10, 18, in: paris),
                                timeZoneIdentifier: "Europe/Paris", endDate: at(12, 11, in: paris))
        let noDate = Reservation(id: "r3", kind: .restaurant, title: "日時未定")
        let linked = ScheduleItem(time: at(10, 18, in: paris), title: "ホテル", reservationId: "r2",
                                  timeZoneIdentifier: "Europe/Paris")
        let plan = trip(days: [DaySchedule(dayNumber: 1, date: at(10, 0, in: japan), scheduleItems: [linked])],
                        reservations: [flight, hotel, noDate])

        let keys = CalendarEventBuilder.drafts(for: plan, options: .init()).map(\.key)
        #expect(keys.contains("reservation:r1"))
        #expect(!keys.contains("reservation:r2"))
        #expect(!keys.contains("reservation:r3"))

        let flightDraft = CalendarEventBuilder.draft(for: flight)
        #expect(flightDraft?.end == at(10, 16, in: paris))
        #expect(flightDraft?.location == "羽田空港")
        #expect(flightDraft?.notes?.contains("便名：NH215") == true)
        #expect(flightDraft?.notes?.contains("ABC123") == true)
    }

    @Test("入れるものを選べる")
    func options() {
        let item = ScheduleItem(id: "a", time: at(1, 9, in: japan), title: "朝食")
        let plan = trip(days: [DaySchedule(dayNumber: 1, date: at(10, 0, in: japan), scheduleItems: [item])])
        var options = CalendarExportOptions()
        options.includesTrip = false
        #expect(CalendarEventBuilder.drafts(for: plan, options: options).map(\.key) == ["item:a"])
        options.includesSchedule = false
        #expect(CalendarEventBuilder.drafts(for: plan, options: options).isEmpty)
    }

    // MARK: - 予定

    @Test("時刻のある予定は時刻つき、無い予定は終日")
    func plans() {
        let calendar = ScheduleClock.calendar(in: japan)
        let timed = Plan(id: "p", title: "歯医者", startDate: at(15, 0, in: japan), endDate: at(15, 0, in: japan),
                         places: [], planType: .daily, time: at(1, 14, in: japan), endTime: at(1, 15, in: japan))
        let draft = CalendarEventBuilder.drafts(for: timed, calendar: calendar).first
        #expect(draft?.start == at(15, 14, in: japan))
        #expect(draft?.end == at(15, 15, in: japan))
        #expect(draft?.isAllDay == false)

        let allDay = Plan(id: "q", title: "キャンプ", startDate: at(15, 0, in: japan), endDate: at(16, 0, in: japan),
                          places: [PlannedPlace(name: "ふもとっぱら", latitude: 35.4, longitude: 138.5)],
                          scheduleItems: [PlanScheduleItem(id: "s", time: at(15, 10, in: japan), title: "到着")])
        let drafts = CalendarEventBuilder.drafts(for: allDay, calendar: calendar)
        #expect(drafts.first?.isAllDay == true)
        #expect(drafts.first?.location == "ふもとっぱら")
        #expect(drafts.map(\.key) == ["plan", "item:s"])
    }

    // MARK: - 直す・消す

    private func draft(_ key: String) -> CalendarEventDraft {
        CalendarEventDraft(key: key, title: key, start: Date(), end: Date(), isAllDay: false)
    }

    @Test("新しい項目は入れ、入れてある項目は直し、消えた項目は消す")
    func syncPlan() {
        var link = CalendarExportState.Link()
        link.events = ["trip": "E1", "item:old": "E2"]
        let plan = CalendarSyncPlan.make(drafts: [draft("trip"), draft("item:new")], link: link) { _ in true }
        #expect(plan.creates.map(\.key) == ["item:new"])
        #expect(plan.updates.map(\.id) == ["E1"])
        #expect(plan.deletes.map(\.key) == ["item:old"])
        #expect(plan.forgotten.isEmpty)
    }

    @Test("カレンダーの側で消された予定は、もう入れない")
    func respectsRemovedEvents() {
        var link = CalendarExportState.Link()
        link.events = ["trip": "E1"]
        let first = CalendarSyncPlan.make(drafts: [draft("trip")], link: link) { _ in false }
        #expect(first.forgotten == ["trip"])
        #expect(first.creates.isEmpty)

        link.events = [:]
        link.removedKeys = ["trip"]
        let second = CalendarSyncPlan.make(drafts: [draft("trip")], link: link) { _ in false }
        #expect(second.creates.isEmpty)
    }

    @Test("覚え書きは保存して読み直せる")
    func storeRoundTrip() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("calendar-\(UUID().uuidString).json")
        var state = CalendarExportState()
        state.calendarIdentifier = "cal"
        state.links["travel:1"] = .init(options: .init(includesTrip: false), events: ["trip": "E"], removedKeys: ["x"])
        CalendarExportStore.save(state, to: url)
        #expect(CalendarExportStore.load(from: url) == state)
    }

    // MARK: - .ics

    @Test(".ics は決まりどおりに書く（終日の終わりは次の日、文字は逃がす、長い行は折り返す）")
    func ics() {
        let allDay = CalendarEventDraft(key: "trip", title: "旅行; 2泊, 3日", start: at(10, 0, in: .current),
                                        end: at(12, 0, in: .current), isAllDay: true,
                                        notes: String(repeating: "あ", count: 60))
        let timed = CalendarEventDraft(key: "item:a", title: "朝食", start: at(10, 9, in: japan),
                                       end: at(10, 10, in: japan), isAllDay: false, timeZone: japan)
        let text = CalendarICS.document([allDay, timed], uidPrefix: "travel-1", now: at(1, 0, in: japan))

        #expect(text.components(separatedBy: "BEGIN:VEVENT").count == 3)
        #expect(text.contains("DTSTART;VALUE=DATE:20261010"))
        #expect(text.contains("DTEND;VALUE=DATE:20261013"))
        #expect(text.contains("SUMMARY:旅行\\; 2泊\\, 3日"))
        #expect(text.contains("DTSTART:20261010T000000Z"))
        #expect(text.contains("UID:travel-1-item:a@travory"))
        for line in text.components(separatedBy: "\r\n") {
            #expect(line.utf8.count <= 75)
        }
    }

    // MARK: - カレンダーの予定を並べる

    @Test("iPhone のカレンダーの予定は、かかっている日すべてに出る。終日の終わりの 0:00 の日には出ない")
    func externalEventDays() {
        let calendar = ScheduleClock.calendar(in: japan)
        func event(_ start: Date, _ end: Date, allDay: Bool = false) -> ExternalCalendarEvent {
            ExternalCalendarEvent(id: "e", title: "会議", start: start, end: end, isAllDay: allDay,
                                  location: nil, calendarName: "仕事（iCloud）", color: nil)
        }
        let meeting = event(at(10, 9, in: japan), at(10, 10, in: japan))
        #expect(meeting.occurs(on: at(10, 0, in: japan), calendar: calendar))
        #expect(!meeting.occurs(on: at(11, 0, in: japan), calendar: calendar))

        // 10日〜11日の終日（終わりは 12日 0:00）
        let trip = event(at(10, 0, in: japan), at(12, 0, in: japan), allDay: true)
        #expect(trip.occurs(on: at(10, 0, in: japan), calendar: calendar))
        #expect(trip.occurs(on: at(11, 0, in: japan), calendar: calendar))
        #expect(!trip.occurs(on: at(12, 0, in: japan), calendar: calendar))

        // 日をまたぐ予定（10日 23:00〜11日 1:00）は両方の日に出る
        let night = event(at(10, 23, in: japan), at(11, 1, in: japan))
        #expect(night.occurs(on: at(11, 0, in: japan), calendar: calendar))

        // 長さの無い予定も、その日に出る
        let reminder = event(at(10, 0, in: japan), at(10, 0, in: japan))
        #expect(reminder.occurs(on: at(10, 0, in: japan), calendar: calendar))
    }

    @Test("同じ日の同じ予定が別のカレンダーにもあれば1つにする（祝日を2か所で購読しているとき）")
    func removesDuplicateHolidays() {
        func holiday(_ id: String, calendar: String, title: String = "スポーツの日") -> ExternalCalendarEvent {
            ExternalCalendarEvent(id: id, calendarId: calendar, title: title, start: at(12, 0, in: japan),
                                  end: at(13, 0, in: japan), isAllDay: true, location: nil,
                                  calendarName: calendar, color: nil)
        }
        let events = [holiday("a", calendar: "Gmail"), holiday("b", calendar: "Subscribed"),
                      holiday("c", calendar: "Gmail", title: "会議")]
        #expect(CalendarExportService.removingDuplicates(events).map(\.id) == ["a", "c"])
    }
}
