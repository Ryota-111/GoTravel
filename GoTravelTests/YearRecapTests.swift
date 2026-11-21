import Testing
import Foundation
@testable import GoTravel

/// 年末の「◯年の旅をふり返る」（3.8）
struct YearRecapTests {

    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return c
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    @Test("12月はその年、1月15日までは前の年。それ以外は出さない")
    func season() {
        #expect(YearRecap.year(on: date(2026, 12, 1), calendar: calendar) == 2026)
        #expect(YearRecap.year(on: date(2027, 1, 15), calendar: calendar) == 2026)
        #expect(YearRecap.year(on: date(2027, 1, 16), calendar: calendar) == nil)
        #expect(YearRecap.year(on: date(2026, 11, 30), calendar: calendar) == nil)
    }

    @Test("その年に出発した旅行があり、閉じていなければ出す")
    func showsOnlyWithTripsAndUntilDismissed() throws {
        let defaults = try #require(UserDefaults(suiteName: "YearRecapTests"))
        defaults.removePersistentDomain(forName: "YearRecapTests")
        let trip = TravelPlan(title: "沖縄", startDate: date(2026, 10, 6), endDate: date(2026, 10, 9), destination: "沖縄")
        let oldTrip = TravelPlan(title: "京都", startDate: date(2025, 5, 1), endDate: date(2025, 5, 2), destination: "京都")

        #expect(YearRecap.yearToShow(plans: [trip], now: date(2026, 12, 10), calendar: calendar, defaults: defaults) == 2026)
        #expect(YearRecap.yearToShow(plans: [oldTrip], now: date(2026, 12, 10), calendar: calendar, defaults: defaults) == nil)
        YearRecap.dismiss(2026, defaults: defaults)
        #expect(YearRecap.yearToShow(plans: [trip], now: date(2026, 12, 10), calendar: calendar, defaults: defaults) == nil)
    }
}
