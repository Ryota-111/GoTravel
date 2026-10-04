import Testing
import Foundation
@testable import GoTravel

/// 予定の終了時刻
struct ScheduleEndTimeTests {

    private let tokyo = TimeZone(identifier: "Asia/Tokyo")!
    private let paris = TimeZone(identifier: "Europe/Paris")!

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0, in zone: TimeZone) -> Date {
        ScheduleClock.calendar(in: zone).date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    @Test("終わりは始まりと同じ日の時:分になる（ピッカーが別の日を持っていても）")
    func endIsOnStartDay() {
        let start = date(6, 10, in: tokyo)
        let pickedOnAnotherDay = date(2, 11, 30, in: tokyo)
        let end = ScheduleItem.endTime(hourAndMinuteOf: pickedOnAnotherDay, after: start, in: tokyo)
        #expect(end == date(6, 11, 30, in: tokyo))
    }

    @Test("始まりより前の時刻（23:00〜1:00）は翌日とみなす")
    func overnightEndIsNextDay() {
        let start = date(6, 23, in: tokyo)
        let end = ScheduleItem.endTime(hourAndMinuteOf: date(6, 1, in: tokyo), after: start, in: tokyo)
        #expect(end == date(7, 1, in: tokyo))
    }

    @Test("現地時間の予定は、現地の時計で時:分を合わせる")
    func usesItemClock() {
        let start = date(6, 15, in: paris)
        let end = ScheduleItem.endTime(hourAndMinuteOf: date(6, 17, in: paris), after: start, in: paris)
        let item = ScheduleItem(time: start, title: "ルーヴル", timeZoneIdentifier: paris.identifier, endTime: end)
        #expect(item.timeRangeText == "15:00〜17:00")
    }

    @Test("終わりが無ければ、始まりだけを出す")
    func noEndTime() {
        let item = ScheduleItem(time: date(6, 9, in: tokyo), title: "朝食", timeZoneIdentifier: tokyo.identifier)
        #expect(item.timeRangeText == "09:00")
        #expect(item.endTimeText == nil)
    }
}
