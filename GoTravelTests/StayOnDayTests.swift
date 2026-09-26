import Testing
import Foundation
@testable import GoTravel

/// 滞在先を、その日の一番上に出すための計算。
///
/// 何泊目かを間違えると、ホテルを出る日に「3泊目」と出るなど、旅行中の判断を誤らせる
struct StayOnDayTests {

    private let tokyo = TimeZone(identifier: "Asia/Tokyo")!

    private func date(_ day: Int, _ hour: Int) -> Date {
        ScheduleClock.calendar(in: tokyo).date(
            from: DateComponents(year: 2026, month: 10, day: day, hour: hour)
        )!
    }

    /// 10/6〜10/9 の4日間の旅行
    private func plan(with reservations: [Reservation]) -> TravelPlan {
        var plan = TravelPlan(title: "沖縄", startDate: date(6, 0), endDate: date(9, 0), destination: "沖縄")
        plan.reservations = reservations
        return plan
    }

    private func hotel(_ title: String, checkIn: Date?, checkOut: Date?) -> Reservation {
        Reservation(kind: .hotel, title: title, date: checkIn,
                    timeZoneIdentifier: tokyo.identifier, checkOutDate: checkOut)
    }

    @Test("3泊の宿は、チェックイン・2泊目・3泊目・チェックアウトの順に出る")
    func threeNights() {
        let trip = plan(with: [hotel("ハレクラニ", checkIn: date(6, 15), checkOut: date(9, 11))])

        #expect(trip.stays(onDay: 1).map(\.detail) == ["チェックイン 15:00・1泊目 / 全3泊"])
        #expect(trip.stays(onDay: 2).map(\.detail) == ["2泊目 / 全3泊"])
        #expect(trip.stays(onDay: 3).map(\.detail) == ["3泊目 / 全3泊"])
        #expect(trip.stays(onDay: 4).map(\.detail) == ["チェックアウト 11:00"])
    }

    @Test("宿を移る日は、出る宿が先・入る宿が後に並ぶ")
    func switchingHotels() {
        let trip = plan(with: [
            hotel("那覇のホテル", checkIn: date(7, 15), checkOut: date(8, 10)),
            hotel("恩納村のホテル", checkIn: date(6, 15), checkOut: date(7, 11))
        ])

        #expect(trip.stays(onDay: 2).map(\.name) == ["恩納村のホテル", "那覇のホテル"])
    }

    /// 以前からある宿の予約は、チェックアウトを持っていない
    @Test("チェックアウトが無い宿は、チェックインの日だけ出る")
    func withoutCheckOut() {
        let trip = plan(with: [hotel("ホテル", checkIn: date(6, 15), checkOut: nil)])

        #expect(trip.stays(onDay: 1).map(\.detail) == ["チェックイン 15:00"])
        #expect(trip.stays(onDay: 2).isEmpty)
    }

    @Test("旅行の前日から泊まっている宿も、1日目に出る")
    func checkInBeforeTrip() {
        let trip = plan(with: [hotel("前泊", checkIn: date(5, 20), checkOut: date(7, 10))])

        #expect(trip.stays(onDay: 1).map(\.detail) == ["2泊目 / 全2泊"])
        #expect(trip.stays(onDay: 2).map(\.detail) == ["チェックアウト 10:00"])
    }

    @Test("宿泊以外の予約は出さない")
    func ignoresOtherKinds() {
        let trip = plan(with: [Reservation(kind: .restaurant, title: "夕食", date: date(6, 19))])

        #expect(trip.stays(onDay: 1).isEmpty)
    }
}
