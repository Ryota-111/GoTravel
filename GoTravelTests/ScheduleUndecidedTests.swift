import Testing
import Foundation
@testable import GoTravel

/// 「時間未定」の予定（3.4。`docs/設計_移動と時間未定.md`）。
///
/// 未定の予定は時刻を「並ぶ位置」としてだけ持つ。位置がずれると、決めた順と違う順に並ぶ
struct ScheduleUndecidedTests {

    private let tokyo = TimeZone(identifier: "Asia/Tokyo")!

    private func date(_ hour: Int, _ minute: Int = 0, second: Int = 0, day: Int = 3) -> Date {
        ScheduleClock.calendar(in: tokyo).date(
            from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute, second: second)
        )!
    }

    private func timed(_ id: String, _ hour: Int, end: Int? = nil) -> ScheduleItem {
        ScheduleItem(id: id, time: date(hour), title: id, timeZoneIdentifier: tokyo.identifier, endTime: end.map { date($0) })
    }

    private func undecided(_ id: String) -> ScheduleItem {
        var item = ScheduleItem(id: id, time: date(23), title: id, timeZoneIdentifier: tokyo.identifier)
        item.isTimeUndecided = true
        return item
    }

    private func order(_ items: [ScheduleItem]) -> [String] {
        items.filter { $0.isPinned != true }.sorted(by: ScheduleItem.chronologically).map(\.id)
    }

    /// A(9時)・B(11時)・C(14時)
    private var day: [ScheduleItem] { [timed("A", 9), timed("B", 11), timed("C", 14)] }

    // MARK: - 入れる

    @Test("指定した予定のすぐ後ろに入り、前の予定と同じ分の1秒目に置かれる")
    func insertAfter() {
        let items = ScheduleUndecided.inserting(undecided("U"), after: "A", into: day)
        #expect(order(items) == ["A", "U", "B", "C"])
        let u = items.first { $0.id == "U" }!
        #expect(u.time == date(9, second: 1))
        #expect(u.hasUndecidedTime)
        #expect(u.timeText == "未定")
    }

    @Test("いちばん前に入れると、最初の予定の1分前の分に置かれる")
    func insertFirst() {
        let items = ScheduleUndecided.inserting(undecided("U"), after: nil, into: day)
        #expect(order(items) == ["U", "A", "B", "C"])
        #expect(items.first { $0.id == "U" }!.time == date(8, 59, second: 1))
    }

    @Test("いちばん後ろ・予定が無い日にも入れられる")
    func insertLastAndEmpty() {
        #expect(order(ScheduleUndecided.inserting(undecided("U"), after: "C", into: day)) == ["A", "B", "C", "U"])
        let alone = ScheduleUndecided.inserting(undecided("U"), after: nil, into: [])
        #expect(order(alone) == ["U"])
    }

    @Test("未定が続くときは、入れた順に1秒ずつずれて並ぶ")
    func consecutive() {
        var items = ScheduleUndecided.inserting(undecided("U1"), after: "A", into: day)
        items = ScheduleUndecided.inserting(undecided("U2"), after: "U1", into: items)
        items = ScheduleUndecided.inserting(undecided("U0"), after: "A", into: items)
        #expect(order(items) == ["A", "U0", "U1", "U2", "B", "C"])
    }

    @Test("同じ分なら、時刻のある予定を先に並べる")
    func timedFirstAtSameMinute() {
        var u = undecided("U")
        u.time = date(11)
        #expect(order([u, timed("B", 11)]) == ["B", "U"])
    }

    @Test("未定の予定は終わりの時刻と日のずれを出さない")
    func noEndOrShiftLabel() {
        var item = timed("X", 23, end: 1)
        item.dayShift = 1
        item.isTimeUndecided = true
        #expect(item.endTimeText == nil)
        #expect(item.dayShiftLabel == nil)
        #expect(item.timeRangeText == "未定")
    }

    @Test("直す画面の「どこに入れるか」の初期値は、すぐ前の予定")
    func anchor() {
        let items = ScheduleUndecided.inserting(undecided("U"), after: "B", into: day)
        #expect(ScheduleUndecided.anchorID(of: "U", in: items) == "B")
        #expect(ScheduleUndecided.anchorID(of: "A", in: items) == nil)
    }

    @Test("時間を決めるときは、秒を落として前の予定と同じ分から始める")
    func startingTime() {
        let items = ScheduleUndecided.inserting(undecided("U"), after: "B", into: day)
        #expect(ScheduleUndecided.startingTime(for: items.first { $0.id == "U" }!) == date(11))
    }

    @Test("固定した予定（一番上に出すもの）は並びに入れず、そのまま残す")
    func pinnedUntouched() {
        var pinned = timed("P", 8)
        pinned.isPinned = true
        let items = ScheduleUndecided.inserting(undecided("U"), after: nil, into: day + [pinned])
        #expect(items.first { $0.id == "P" }!.time == date(8))
        #expect(order(items) == ["U", "A", "B", "C"])
    }

    // MARK: - 並べ替え

    private func plan(_ items: [ScheduleItem]) -> TravelPlan {
        var plan = TravelPlan(title: "京都", startDate: date(0), endDate: date(0, day: 4), destination: "京都")
        plan.daySchedules = [DaySchedule(dayNumber: 1, date: date(0), scheduleItems: items)]
        return plan
    }

    @Test("未定の予定を動かすと、時刻のある予定の時刻は変わらず、未定の予定だけ新しい位置に付く")
    func reorderUndecided() {
        let items = ScheduleUndecided.inserting(undecided("U"), after: "A", into: day)
        let reordered = plan(items).reorderingItems(onDay: 1, from: ["A", "U", "B", "C"], to: ["A", "B", "C", "U"])
        let result = reordered.daySchedules[0].scheduleItems
        #expect(order(result) == ["A", "B", "C", "U"])
        #expect(result.first { $0.id == "A" }!.time == date(9))
        #expect(result.first { $0.id == "B" }!.time == date(11))
        #expect(result.first { $0.id == "C" }!.time == date(14))
        #expect(result.first { $0.id == "U" }!.hasUndecidedTime)
    }

    @Test("時刻のある予定どうしを入れ替えても、未定の予定はすぐ前の予定に付いていく")
    func reorderTimedAroundUndecided() {
        let items = ScheduleUndecided.inserting(undecided("U"), after: "A", into: day)
        // B を先頭へ。並びは B, A, U, C（U は A のあとのまま）
        let reordered = plan(items).reorderingItems(onDay: 1, from: ["A", "U", "B", "C"], to: ["B", "A", "U", "C"])
        let result = reordered.daySchedules[0].scheduleItems
        #expect(order(result) == ["B", "A", "U", "C"])
        // 時刻の枠は入れ替わる（B が 9時、A が 11時）
        #expect(result.first { $0.id == "B" }!.time == date(9))
        #expect(result.first { $0.id == "A" }!.time == date(11))
        #expect(result.first { $0.id == "U" }!.time == date(11, second: 1))
    }

    @Test("未定の予定をいちばん前に動かせる")
    func reorderToFront() {
        let items = ScheduleUndecided.inserting(undecided("U"), after: "C", into: day)
        let reordered = plan(items).reorderingItems(onDay: 1, from: ["A", "B", "C", "U"], to: ["U", "A", "B", "C"])
        #expect(order(reordered.daySchedules[0].scheduleItems) == ["U", "A", "B", "C"])
    }

    // MARK: - 時刻を使うところ

    @Test("カレンダーには、その日の終日の予定として入れる")
    func calendarAllDay() {
        let item = ScheduleUndecided.inserting(undecided("U"), after: "A", into: day).first { $0.id == "U" }!
        let draft = CalendarEventBuilder.draft(for: item, onDay: DateComponents(year: 2026, month: 11, day: 3))
        #expect(draft.isAllDay)
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: draft.start)
        #expect(parts.month == 11 && parts.day == 3)
    }

    @Test("古い形（未定の印が無い予定）は時刻のある予定として読む")
    func oldData() throws {
        let old = #"{"id":"x","time":0,"title":"浅草寺"}"#
        let item = try JSONDecoder().decode(ScheduleItem.self, from: Data(old.utf8))
        #expect(!item.hasUndecidedTime)
    }
}
