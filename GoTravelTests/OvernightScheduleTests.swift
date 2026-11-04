import Testing
import Foundation
@testable import GoTravel

/// 日をまたぐ予定（夜行便・夜行バス）。終わりが翌日だと分かるように出し、着く日の一番上にも出す（3.3）
struct OvernightScheduleTests {

    private let tokyo = TimeZone(identifier: "Asia/Tokyo")!
    private let paris = TimeZone(identifier: "Europe/Paris")!
    private let honolulu = TimeZone(identifier: "Pacific/Honolulu")!

    /// その時計での 2026/10/10 hh:mm
    private func date(_ hour: Int, _ minute: Int = 0, in zone: TimeZone) -> Date {
        ScheduleClock.calendar(in: zone).date(
            from: DateComponents(year: 2026, month: 10, day: 10, hour: hour, minute: minute)
        )!
    }

    /// 始まりと、終わりの時:分から予定を作る（終わりが始まりより前なら翌日。入力欄と同じ決め方）
    private func item(_ start: Int, _ startMinute: Int = 0, to end: Int, _ endMinute: Int = 0,
                      in zone: TimeZone, endZone: TimeZone? = nil, dayShift: Int? = nil) -> ScheduleItem {
        let startTime = date(start, startMinute, in: zone)
        let endTime = ScheduleItem.endTime(hourAndMinuteOf: date(end, endMinute, in: endZone ?? zone),
                                           after: startTime, in: zone, endZone: endZone)
        return ScheduleItem(time: startTime, title: "移動", timeZoneIdentifier: zone.identifier,
                            endTime: endTime, endTimeZoneIdentifier: endZone?.identifier, dayShift: dayShift)
    }

    @Test("夜行便の朝の到着は「翌 08:00」と出す")
    func nextMorningShowsNextDay() {
        let flight = item(22, to: 8, in: tokyo)
        #expect(flight.endDayOffset == 1)
        #expect(flight.endTimeText == "翌 08:00")
        #expect(flight.continuesIntoNextDay)
    }

    @Test("その日の夜の続きは、これまでどおり「25:00」")
    func lateNightKeepsHourStyle() {
        let party = item(23, to: 1, in: tokyo)
        #expect(party.endTimeText == "25:00")
        #expect(!party.continuesIntoNextDay)
    }

    @Test("24:30 に始まる短い予定は、翌朝の予定表に出さない")
    func lateNightStartIsNotCarried() {
        // 24:30 は、その日の 0:30 に dayShift 1 を付けて入れる
        let checkIn = item(0, 30, to: 2, in: tokyo, dayShift: 1)
        #expect(checkIn.endTimeText == "26:00")
        #expect(!checkIn.continuesIntoNextDay)
    }

    @Test("朝 6 時前に着く夜行バスも、長い移動なので翌朝に出す")
    func overnightBusIsCarried() {
        let bus = item(23, to: 5, 30, in: tokyo)
        #expect(bus.endTimeText == "29:30")
        #expect(bus.continuesIntoNextDay)
    }

    @Test("時差をまたぐ便は、着いた先の日付で数える")
    func crossesTimeZones() {
        // パリ 22:00 発 → 羽田 翌日 17:00 着
        let toTokyo = item(22, to: 17, in: paris, endZone: tokyo)
        #expect(toTokyo.endTimeText == "翌 17:00")
        #expect(toTokyo.continuesIntoNextDay)

        // 羽田 22:00 発 → ホノルル 同じ日の 10:00 着（日付は戻る）
        let toHonolulu = item(22, to: 10, in: tokyo, endZone: honolulu)
        #expect(toHonolulu.endDayOffset == 0)
        #expect(toHonolulu.endTimeText == "10:00")
        #expect(!toHonolulu.continuesIntoNextDay)
    }

    @Test("着く日の一番上に、前の日の夜行便が出る")
    func arrivingItemsOnNextDay() {
        let flight = item(22, to: 8, in: tokyo)
        let dinner = ScheduleItem(time: date(19, in: tokyo), title: "夕食", timeZoneIdentifier: tokyo.identifier)
        var plan = TravelPlan(title: "パリ", startDate: date(0, in: tokyo),
                              endDate: date(0, in: tokyo).addingTimeInterval(86_400 * 3), destination: "パリ")
        plan.daySchedules = [DaySchedule(dayNumber: 1, date: date(0, in: tokyo), scheduleItems: [dinner, flight])]

        #expect(plan.arrivingScheduleItems(onDay: 2).map(\.id) == [flight.id])
        #expect(plan.arrivingScheduleItems(onDay: 1).isEmpty)
        #expect(plan.arrivingScheduleItems(onDay: 3).isEmpty)
    }
}
