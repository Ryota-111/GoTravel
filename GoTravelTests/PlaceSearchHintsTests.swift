import Testing
import Foundation
import MapKit
@testable import GoTravel

/// 場所を探すときに優先する範囲（3.4。「韓国の住所で探せなかった」というご意見から）
@MainActor
struct PlaceSearchHintsTests {

    private func center(_ query: String) -> (Double, Double)? {
        PlaceSearchHints.hintedRegion(for: query).map { ($0.center.latitude, $0.center.longitude) }
    }

    @Test("日本語・韓国語・英語の町の名前から、その町のあたりを探す")
    func cities() {
        #expect(center("ソウル特別市中区乙支路30")?.0 == 37.566)
        #expect(center("부산광역시 해운대구")?.0 == 35.180)
        #expect(center("30 Eulji-ro, Jung-gu, Seoul")?.0 == 37.566)
        #expect(center("台北市信義区信義路五段7号")?.0 == 25.048)
        #expect(center("臺中市")?.0 == 24.148)
    }

    @Test("町の名前が無くても、ハングルなら韓国のあたりを探す")
    func hangulMeansKorea() {
        #expect(center("사직로 161")?.0 == 36.400)
    }

    @Test("日本の場所には何も足さない（これまでどおり、映している地図のあたりで探す）")
    func japanHasNoHint() {
        #expect(center("通天閣") == nil)
        #expect(center("東京都千代田区丸の内1-9-1") == nil)
    }

    @Test("旅行中の行き先は、映している地図より先に探す。これからの旅行は後ろに足す")
    func tripOrder() {
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        var ongoing = TravelPlan(title: "ソウル", startDate: now.addingTimeInterval(-86_400),
                                 endDate: now.addingTimeInterval(86_400), destination: "ソウル")
        ongoing.latitude = 37.5; ongoing.longitude = 127.0
        var upcoming = TravelPlan(title: "台北", startDate: now.addingTimeInterval(30 * 86_400),
                                  endDate: now.addingTimeInterval(32 * 86_400), destination: "台北")
        upcoming.latitude = 25.0; upcoming.longitude = 121.5
        let tokyo = CLLocationCoordinate2D(latitude: 35.68, longitude: 139.76)

        let regions = PlaceSearchHints.regions(for: "スターバックス", trips: [upcoming, ongoing], around: tokyo, now: now)
        #expect(regions.map(\.center.latitude) == [37.5, 35.68, 25.0])
    }
}
