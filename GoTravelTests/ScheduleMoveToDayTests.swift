import Testing
import Foundation
@testable import GoTravel

/// 予定を別の日へ移す（3.5、ご要望から）。
///
/// 「1日目に行けなかった場所を2日目に回す」。時刻や日付を取り違えると、当日の行動を誤らせる
struct ScheduleMoveToDayTests {

    private let tokyo = TimeZone(identifier: "Asia/Tokyo")!

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0, _ second: Int = 0) -> Date {
        ScheduleClock.calendar(in: tokyo).date(
            from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute, second: second)
        )!
    }

    private func item(_ id: String, day: Int, _ hour: Int, end: Int? = nil) -> ScheduleItem {
        ScheduleItem(id: id, time: date(day, hour), title: id,
                     timeZoneIdentifier: tokyo.identifier,
                     endTime: end.map { date(day, $0) })
    }

    /// 11/3〜11/5 の3日間。1日目は A(9時)・B(11〜12時)・C(14時)、2日目は D(10時)・E(15時)、3日目は空
    private func plan() -> TravelPlan {
        var plan = TravelPlan(title: "京都", startDate: date(3, 0), endDate: date(5, 0), destination: "京都")
        plan.daySchedules = [
            DaySchedule(dayNumber: 1, date: date(3, 0),
                        scheduleItems: [item("A", day: 3, 9), item("B", day: 3, 11, end: 12), item("C", day: 3, 14)]),
            DaySchedule(dayNumber: 2, date: date(4, 0), scheduleItems: [item("D", day: 4, 10), item("E", day: 4, 15)]),
            DaySchedule(dayNumber: 3, date: date(5, 0), scheduleItems: []),
        ]
        return plan
    }

    private func titles(_ plan: TravelPlan, day: Int) -> [String] {
        plan.timelineScheduleItems(onDay: day).map(\.title)
    }

    @Test("時:分はそのままで日付だけ移り、移した日の時刻の順に並ぶ。終わりの時刻も一緒に動く")
    func moveKeepsTimeOfDay() throws {
        let moved = plan().movingItems(["B"], toDay: 2)
        #expect(titles(moved, day: 1) == ["A", "C"])
        #expect(titles(moved, day: 2) == ["D", "B", "E"])

        let b = try #require(moved.daySchedules[1].scheduleItems.first { $0.id == "B" })
        #expect(b.time == date(4, 11))
        #expect(b.endTime == date(4, 12))
    }

    @Test("まとめて移せる。何日も先へも、前の日へも移せる")
    func moveSeveral() {
        let forward = plan().movingItems(["A", "C"], toDay: 3)
        #expect(titles(forward, day: 1) == ["B"])
        #expect(titles(forward, day: 3) == ["A", "C"])
        #expect(forward.daySchedules[2].scheduleItems.first { $0.id == "C" }?.time == date(5, 14))

        let back = plan().movingItems(["E"], toDay: 1)
        #expect(titles(back, day: 1) == ["A", "B", "C", "E"])
        #expect(back.daySchedules[0].scheduleItems.first { $0.id == "E" }?.time == date(3, 15))
    }

    @Test("移す日と同じ日の予定や、無い日は何もしない")
    func noop() {
        let original = plan()
        #expect(titles(original.movingItems(["D"], toDay: 2), day: 2) == ["D", "E"])
        #expect(titles(original.movingItems(["A"], toDay: 9), day: 1) == ["A", "B", "C"])
    }

    @Test("予約から作った予定は動かさない（出発と到着の片方だけ動くと予約と食い違う）")
    func reservationItemsStay() {
        var original = plan()
        original.daySchedules[0].scheduleItems[0].reservationId = "flight"
        let moved = original.movingItems(["A", "C"], toDay: 2)
        #expect(titles(moved, day: 1) == ["A", "B"])
        #expect(titles(moved, day: 2) == ["D", "C", "E"])
    }

    @Test("時間未定の予定は、移した日の並びで位置を付け直し、未定のまま")
    func undecidedItem() throws {
        var original = plan()
        // C を未定にする（B のすぐ後ろ：11時台の1秒目）
        original.daySchedules[0].scheduleItems[2].isTimeUndecided = true
        original.daySchedules[0].scheduleItems[2].time = date(3, 11, 0, 1)

        let moved = original.movingItems(["C"], toDay: 2)
        #expect(titles(moved, day: 2) == ["D", "C", "E"])
        let c = try #require(moved.daySchedules[1].scheduleItems.first { $0.id == "C" })
        #expect(c.hasUndecidedTime)
        // すぐ前の D（10:00）と同じ分の1秒目
        #expect(c.time == date(4, 10, 0, 1))
    }
}
