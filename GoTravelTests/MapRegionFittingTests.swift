import Testing
import Foundation
import CoreLocation
import MapKit
@testable import GoTravel

/// 地図の表示範囲。
///
/// 日付変更線をまたぐ旅行（羽田 → ハワイ）で、真ん中が大西洋になり、
/// ピンも線も映らない場所が出ていた
struct MapRegionFittingTests {

    private let haneda = CLLocationCoordinate2D(latitude: 35.55, longitude: 139.78)
    private let honolulu = CLLocationCoordinate2D(latitude: 21.32, longitude: -157.92)
    private let naha = CLLocationCoordinate2D(latitude: 26.21, longitude: 127.65)

    @Test("羽田とホノルルは、太平洋の側で囲む")
    func crossesDateLine() throws {
        let region = try #require(MapRegionFitting.region(fitting: [haneda, honolulu]))

        // 真ん中は日付変更線の近く（東経170度あたり）。大西洋（−9度）ではない
        #expect(region.center.longitude > 160 && region.center.longitude < 180)
        // 幅は太平洋側の約62度。反対回りの約298度ではない
        #expect(region.span.longitudeDelta < 100)
    }

    @Test("日付変更線をまたがない旅行は、今までどおり真ん中で囲む")
    func sameSideOfDateLine() throws {
        let region = try #require(MapRegionFitting.region(fitting: [haneda, naha]))

        #expect(abs(region.center.longitude - (139.78 + 127.65) / 2) < 0.001)
        #expect(abs(region.span.longitudeDelta - (139.78 - 127.65) * 1.5) < 0.001)
    }

    @Test("1か所だけなら、その場所を中心に最小の幅で出す")
    func singlePoint() throws {
        let region = try #require(MapRegionFitting.region(fitting: [honolulu], minimumSpan: 0.01))

        #expect(abs(region.center.longitude - (-157.92)) < 0.001)
        #expect(region.span.longitudeDelta == 0.01)
    }

    @Test("地点が無ければ範囲を決めない")
    func empty() {
        #expect(MapRegionFitting.region(fitting: []) == nil)
    }
}
