import Testing
import Foundation
@testable import GoTravel

/// 天気の予報を覚えておく（3.0）。WeatherKit の問い合わせ回数を減らすため
struct WeatherCacheTests {

    @Test("同じ目的地（約1km以内）・同じ日程なら同じ鍵。日程が違えば別の鍵")
    func cacheKey() {
        let start = Date(timeIntervalSince1970: 1_790_000_000)
        let end = start.addingTimeInterval(2 * 86_400)
        let a = WeatherService.cacheKey(latitude: 21.30691, longitude: -157.85834, startDate: start, endDate: end)
        let b = WeatherService.cacheKey(latitude: 21.30812, longitude: -157.85599, startDate: start, endDate: end)
        let c = WeatherService.cacheKey(latitude: 21.30691, longitude: -157.85834, startDate: start, endDate: end.addingTimeInterval(86_400))
        #expect(a == b)
        #expect(a != c)
    }

    @Test("覚えた予報は1時間")
    func lifetime() {
        #expect(WeatherService.forecastLifetime == 3600)
    }

    @Test("更新時刻は、今日なら時刻だけ、別の日なら日付も出す")
    func updatedText() {
        let now = Date()
        #expect(!TravelPlanDetailView.weatherUpdatedText(now, now: now).contains("/"))
        #expect(TravelPlanDetailView.weatherUpdatedText(now.addingTimeInterval(-2 * 86_400), now: now).contains("/"))
    }
}
