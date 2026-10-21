import Testing
import Foundation
@testable import GoTravel

/// 旅の統計（3.1）。終わった旅行だけを、期間ごとに数える
struct TripStatsTests {

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    private func trip(_ title: String, _ start: Date, days: Int, lat: Double, lon: Double, cost: Double = 0) -> TravelPlan {
        TravelPlan(title: title, startDate: start, endDate: start.addingTimeInterval(Double(days - 1) * 86_400),
                   destination: title, latitude: lat, longitude: lon,
                   daySchedules: [DaySchedule(dayNumber: 1, date: start, scheduleItems: cost > 0
                                              ? [ScheduleItem(time: start, title: "宿", cost: cost)] : [])])
    }

    /// 那覇・札幌・ホノルルの3か所だけ分かっている
    private func region(_ lat: Double, _ lon: Double) -> TripRegion? {
        switch (Int(lat), Int(lon)) {
        case (26, 127): return TripRegion(countryCode: "JP", prefectureName: "沖縄県")
        case (43, 141): return TripRegion(countryCode: "JP", prefectureName: "北海道")
        case (21, -157): return TripRegion(countryCode: "US", prefectureName: nil)
        default: return nil
        }
    }

    @Test("終わった旅行だけを数え、県・国・金額・いちばんを出す")
    func summary() {
        let now = date(2026, 10, 19)
        let plans = [
            trip("沖縄", date(2026, 3, 20), days: 3, lat: 26.2, lon: 127.6, cost: 50_000),
            trip("沖縄ふたたび", date(2026, 8, 10), days: 4, lat: 26.3, lon: 127.7, cost: 80_000),
            trip("北海道", date(2025, 8, 1), days: 6, lat: 43.0, lon: 141.3, cost: 120_000),
            trip("ハワイ", date(2025, 12, 28), days: 5, lat: 21.3, lon: -157.8),
            // これからの旅行は数えない
            trip("京都", date(2026, 11, 1), days: 2, lat: 35.0, lon: 135.7, cost: 30_000),
        ]
        let all = TripStats.summary(plans: plans, places: [], outings: [], region: region,
                                    period: .all, now: now, calendar: calendar)
        #expect(all.tripCount == 4)
        #expect(all.dayCount == 18)
        #expect(all.spend == 250_000)
        #expect(all.prefectures == [.okinawa, .hokkaido])
        #expect(all.countries == ["JP", "US"])
        #expect(all.longest?.title == "北海道")
        #expect(all.mostSpent?.title == "北海道")
        #expect(all.topPrefecture?.prefecture == .okinawa)
        #expect(all.topPrefecture?.trips == 2)
        #expect(all.busyMonths.first == 8)

        let thisYear = TripStats.summary(plans: plans, places: [], outings: [], region: region,
                                         period: .year(2026), now: now, calendar: calendar)
        #expect(thisYear.tripCount == 2)
        #expect(thisYear.prefectures == [.okinawa])
        #expect(TripStats.years(of: plans, now: now, calendar: calendar) == [2026, 2025])

        let rows = TripStats.yearRows(plans: plans, now: now, calendar: calendar)
        #expect(rows.map(\.year) == [2025, 2026])
        #expect(rows.map(\.trips) == [2, 2])
        #expect(rows.last?.spend == 130_000)
    }

    @Test("フォトマップの県は「これまで全部」に入れる。保存した場所は都道府県に数えない")
    func photoMapAndPlaces() {
        let now = date(2026, 10, 19)
        let place = VisitedPlace(title: "美ら海", latitude: 26.69, longitude: 127.87, createdAt: date(2026, 5, 1),
                                 categoryId: "sightseeing")
        let all = TripStats.summary(plans: [], places: [place], outings: [], photoMapPrefectures: [.kyoto],
                                    region: region, period: .all, now: now, calendar: calendar)
        #expect(all.prefectures == [.kyoto])
        #expect(all.placeCount == 1)
        let year = TripStats.summary(plans: [], places: [place], outings: [], photoMapPrefectures: [.kyoto],
                                     region: region, period: .year(2026), now: now, calendar: calendar)
        #expect(year.prefectures.isEmpty)
    }

    @Test("旅行から保存した場所は、年が明けてから保存しても、その旅行の年に数える")
    func placeYearFollowsTrip() {
        let now = date(2026, 10, 19)
        var kobe = trip("神戸", date(2025, 12, 24), days: 2, lat: 0, lon: 0)
        kobe.id = "kobe"
        kobe.latitude = nil; kobe.longitude = nil
        let place = VisitedPlace(title: "北野異人館", latitude: 26.2, longitude: 127.6, createdAt: date(2026, 1, 5),
                                 travelPlanId: "kobe")
        #expect(TripStats.visitDate(of: place, plans: [kobe]) == kobe.startDate)
        let y2025 = TripStats.summary(plans: [kobe], places: [place], outings: [], region: region,
                                      period: .year(2025), now: now, calendar: calendar)
        #expect(y2025.placeCount == 1)
        let y2026 = TripStats.summary(plans: [kobe], places: [place], outings: [], region: region,
                                      period: .year(2026), now: now, calendar: calendar)
        #expect(y2026.placeCount == 0)
        // 目的地の場所が空の終わった旅行は、引き直す対象
        #expect(TripStats.tripsMissingDestination([kobe], now: now).count == 1)
    }

    @Test("県の名前から都道府県を引く。日本の外は県にしない")
    func regionPrefecture() {
        #expect(TripRegion(countryCode: "JP", prefectureName: "東京都").prefecture == .tokyo)
        #expect(TripRegion(countryCode: "US", prefectureName: "東京都").prefecture == nil)
        #expect(TripRegionResolver.key(26.2134, 127.6791) == TripRegionResolver.key(26.2101, 127.6812))
    }
}
