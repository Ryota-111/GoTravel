import Testing
import Foundation
@testable import GoTravel

/// 時間軸の線に出す手段と時間（3.8、ご報告から）
struct TimelineTransportTests {

    private func date(_ hour: Int, _ minute: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar.date(from: DateComponents(year: 2026, month: 12, day: 1, hour: hour, minute: minute))!
    }

    @Test("「移動」の予定は、その乗り物と、乗っている時間（出発 → 到着）を出す")
    func moveShowsRideTime() {
        var train = ScheduleItem(time: date(10), title: "梅田 → 京都", endTime: date(10, 45))
        train.move = ScheduleMove(mode: .train, from: MovePlace(name: "梅田"), to: MovePlace(name: "京都"))
        // 次の予定までの手段を選んでいても、移動の予定の線は移動そのもの
        train.transportToNext = TransportMode.walk.rawValue
        let next = ScheduleItem(time: date(12), title: "清水寺")

        #expect(train.timelineTransportMode == .train)
        #expect(train.timelineTransportDuration(to: next) == TimeInterval(45 * 60))
    }

    @Test("ふつうの予定は、今までどおり終わり〜次の始まり")
    func plainItemShowsGap() {
        var lunch = ScheduleItem(time: date(11), title: "昼ごはん", endTime: date(12))
        lunch.transportToNext = TransportMode.train.rawValue
        let next = ScheduleItem(time: date(12, 30), title: "清水寺")

        #expect(lunch.timelineTransportMode == .train)
        #expect(lunch.timelineTransportDuration(to: next) == TimeInterval(30 * 60))
    }

    @Test("到着の時刻が無い「移動」は、時間を出さない")
    func moveWithoutArrival() {
        var bus = ScheduleItem(time: date(10), title: "バス")
        bus.move = ScheduleMove(mode: .bus)
        #expect(bus.timelineTransportMode == .bus)
        #expect(bus.timelineTransportDuration(to: ScheduleItem(time: date(12), title: "次")) == nil)
    }
}
