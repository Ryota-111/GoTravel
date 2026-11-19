import Testing
import Foundation
@testable import GoTravel

/// 予定の複製（3.8、ご要望から）
struct ScheduleDuplicateTests {

    private let tokyo = TimeZone(identifier: "Asia/Tokyo")!

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tokyo
        return calendar.date(from: DateComponents(year: 2026, month: 12, day: day, hour: hour, minute: minute))!
    }

    private func plan() -> TravelPlan {
        var plan = TravelPlan(title: "旅行", startDate: date(1, 0), endDate: date(3, 0), destination: "沖縄")
        plan.daySchedules = [
            DaySchedule(dayNumber: 1, date: date(1, 0), scheduleItems: [
                ScheduleItem(id: "a", time: date(1, 10), title: "首里城", location: "首里城", notes: "チケットは現地で",
                             cost: 400, timeZoneIdentifier: tokyo.identifier),
                ScheduleItem(id: "b", time: date(1, 15), title: "ホテル チェックイン", reservationId: "r1",
                             timeZoneIdentifier: tokyo.identifier, reservationPart: ReservationPart.main.rawValue)
            ]),
            DaySchedule(dayNumber: 2, date: date(2, 0), scheduleItems: [
                ScheduleItem(id: "c", time: date(2, 9), title: "朝ごはん", timeZoneIdentifier: tokyo.identifier)
            ])
        ]
        return plan
    }

    @Test("同じ日に複製すると、元のすぐ後ろに中身の同じ別の予定が入る")
    func sameDay() throws {
        let result = try #require(plan().duplicatingItem("a", toDay: 1))
        let items = result.plan.daySchedules[0].scheduleItems
        #expect(items.map(\.id) == ["a", result.newId, "b"])
        #expect(result.newId != "a")
        #expect(items[1].title == "首里城")
        #expect(items[1].location == "首里城")
        #expect(items[1].notes == "チケットは現地で")
        #expect(items[1].cost == 400)
        #expect(items[1].time == date(1, 10))
    }

    @Test("ほかの日に複製すると、時:分はそのままで日付だけその日になる。元の予定は残る")
    func otherDay() throws {
        let result = try #require(plan().duplicatingItem("a", toDay: 2))
        #expect(result.plan.daySchedules[0].scheduleItems.map(\.id) == ["a", "b"])
        let copy = try #require(result.plan.daySchedules[1].scheduleItems.first { $0.id == result.newId })
        #expect(copy.time == date(2, 10))
    }

    @Test("予約から作った予定を複製すると、予約とのつながりは外れる（予約を直しても一緒に動かない）")
    func detachesReservation() throws {
        let result = try #require(plan().duplicatingItem("b", toDay: 2))
        let copy = try #require(result.plan.daySchedules[1].scheduleItems.first { $0.id == result.newId })
        #expect(copy.reservationId == nil)
        #expect(copy.reservationPart == nil)
        #expect(copy.title == "ホテル チェックイン")
        #expect(result.plan.daySchedules[0].scheduleItems[1].reservationId == "r1")
    }

    @Test("見つからない予定や日なら何もしない")
    func missing() {
        #expect(plan().duplicatingItem("x", toDay: 1) == nil)
        #expect(plan().duplicatingItem("a", toDay: 9) == nil)
    }
}
