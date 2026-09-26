import Testing
import Foundation
@testable import GoTravel

/// 日程の各日の一番上に出すもの（期間のある予約・固定した予定）。
///
/// 何泊目・何日目を間違えると、ホテルを出る日に「3泊目」と出るなど、旅行中の判断を誤らせる
struct DayPinsTests {

    private let tokyo = TimeZone(identifier: "Asia/Tokyo")!

    private func date(_ day: Int, _ hour: Int) -> Date {
        ScheduleClock.calendar(in: tokyo).date(
            from: DateComponents(year: 2026, month: 10, day: day, hour: hour)
        )!
    }

    /// 10/6〜10/9 の4日間の旅行
    private func plan(with reservations: [Reservation] = [], items: [ScheduleItem] = []) -> TravelPlan {
        var plan = TravelPlan(title: "沖縄", startDate: date(6, 0), endDate: date(9, 0), destination: "沖縄")
        plan.reservations = reservations
        plan.daySchedules = [DaySchedule(dayNumber: 1, date: date(6, 0), scheduleItems: items)]
        return plan
    }

    private func reservation(_ kind: Reservation.Kind, _ title: String,
                             start: Date?, end: Date?, pins: Bool? = true) -> Reservation {
        Reservation(kind: kind, title: title, date: start,
                    timeZoneIdentifier: tokyo.identifier, endDate: end, pinsDuringPeriod: pins)
    }

    private func details(_ trip: TravelPlan, day: Int) -> [String] {
        trip.pinnedReservations(onDay: day).map(\.detail)
    }

    // MARK: - 宿泊

    @Test("3泊の宿は、チェックイン・2泊目・3泊目・チェックアウトの順に出る")
    func hotelThreeNights() {
        let trip = plan(with: [reservation(.hotel, "ハレクラニ", start: date(6, 15), end: date(9, 11))])

        #expect(details(trip, day: 1) == ["チェックイン 15:00・1泊目 / 全3泊"])
        #expect(details(trip, day: 2) == ["2泊目 / 全3泊"])
        #expect(details(trip, day: 3) == ["3泊目 / 全3泊"])
        #expect(details(trip, day: 4) == ["チェックアウト 11:00"])
    }

    @Test("宿を移る日は、出る宿が先・入る宿が後に並ぶ")
    func switchingHotels() {
        let trip = plan(with: [
            reservation(.hotel, "那覇のホテル", start: date(7, 15), end: date(8, 10)),
            reservation(.hotel, "恩納村のホテル", start: date(6, 15), end: date(7, 11))
        ])

        #expect(trip.pinnedReservations(onDay: 2).map(\.name) == ["恩納村のホテル", "那覇のホテル"])
    }

    /// 以前からある宿の予約は、チェックアウトを持っていない
    @Test("チェックアウトが無い宿は、チェックインの日だけ出る")
    func hotelWithoutEnd() {
        let trip = plan(with: [reservation(.hotel, "ホテル", start: date(6, 15), end: nil)])

        #expect(details(trip, day: 1) == ["チェックイン 15:00"])
        #expect(details(trip, day: 2).isEmpty)
    }

    @Test("旅行の前日から泊まっている宿も、1日目に出る")
    func hotelBeforeTrip() {
        let trip = plan(with: [reservation(.hotel, "前泊", start: date(5, 20), end: date(7, 10))])

        #expect(details(trip, day: 1) == ["2泊目 / 全2泊"])
        #expect(details(trip, day: 2) == ["チェックアウト 10:00"])
    }

    // MARK: - 宿泊以外

    @Test("レンタカーは日数で数え、受け取り・返却と出る")
    func rentalCarCountsDays() {
        let trip = plan(with: [reservation(.rentalCar, "OTS", start: date(6, 10), end: date(8, 17))])

        #expect(details(trip, day: 1) == ["受け取り 10:00・1日目 / 全3日"])
        #expect(details(trip, day: 2) == ["2日目 / 全3日"])
        #expect(details(trip, day: 3) == ["返却 17:00"])
    }

    /// 勝手に出すと、控えただけの予約で一番上が埋まってしまう
    @Test("どの種類も、選ばなければ出さない")
    func notPinnedByDefault() {
        let trip = plan(with: [
            reservation(.hotel, "ホテル", start: date(6, 15), end: date(8, 11), pins: nil),
            reservation(.rentalCar, "OTS", start: date(6, 10), end: date(8, 17), pins: nil)
        ])

        #expect(details(trip, day: 1).isEmpty)
        #expect(details(trip, day: 2).isEmpty)
    }

    @Test("チケットも、選べば期間中に出る")
    func ticketCanBePinned() {
        let trip = plan(with: [reservation(.ticket, "フリーパス", start: date(6, 9), end: date(7, 18))])

        #expect(details(trip, day: 1) == ["開始 09:00・1日目 / 全2日"])
        #expect(details(trip, day: 2) == ["終了 18:00"])
    }

    @Test("飛行機は期間を持たないので出さない")
    func flightHasNoPeriod() {
        let trip = plan(with: [Reservation(kind: .flight, title: "ANA", date: date(6, 10), pinsDuringPeriod: true)])

        #expect(details(trip, day: 1).isEmpty)
    }

    // MARK: - 固定した予定

    @Test("固定した予定は上に出て、時刻の並びからは外れる")
    func pinnedItemsLeaveTimeline() {
        let meeting = ScheduleItem(time: date(6, 8), title: "集合：那覇空港 2F", isPinned: true)
        let breakfast = ScheduleItem(time: date(6, 9), title: "朝食")
        let trip = plan(items: [breakfast, meeting])

        #expect(trip.pinnedScheduleItems(onDay: 1).map(\.title) == ["集合：那覇空港 2F"])
        #expect(trip.timelineScheduleItems(onDay: 1).map(\.title) == ["朝食"])
    }
}
