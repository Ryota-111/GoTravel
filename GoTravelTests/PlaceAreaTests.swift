import Testing
import Foundation
@testable import GoTravel

/// 保存した場所を県で分ける（3.1）。住所の県を先に使い、無ければ緯度・経度から調べた結果
struct PlaceAreaTests {

    private func region(_ lat: Double, _ lon: Double) -> TripRegion? {
        switch (Int(lat), Int(lon)) {
        case (26, 127): return TripRegion(countryCode: "JP", prefectureName: "沖縄県")
        case (48, 2): return TripRegion(countryCode: "FR", prefectureName: nil)
        default: return nil
        }
    }

    @Test("住所に県があればそれ、無ければ緯度・経度から。日本の外は海外、まだ分からなければ不明")
    func area() {
        let kyoto = VisitedPlace(title: "伏見稲荷", latitude: 34.97, longitude: 135.77, address: "京都府京都市伏見区")
        let tokyo = VisitedPlace(title: "東京タワー", latitude: 35.66, longitude: 139.74, address: "東京都港区")
        let naha = VisitedPlace(title: "国際通り", latitude: 26.21, longitude: 127.68)
        let paris = VisitedPlace(title: "ルーヴル", latitude: 48.86, longitude: 2.33)
        let somewhere = VisitedPlace(title: "どこか", latitude: 40.0, longitude: 140.0)
        #expect(PlaceArea.of(kyoto, region: region) == .prefecture(.kyoto))
        #expect(PlaceArea.of(tokyo, region: region) == .prefecture(.tokyo))
        #expect(PlaceArea.of(naha, region: region) == .prefecture(.okinawa))
        #expect(PlaceArea.of(paris, region: region) == .abroad)
        #expect(PlaceArea.of(somewhere, region: region) == .unknown)

        let counts = PlaceArea.counts(of: [naha, kyoto, tokyo, paris, kyoto, somewhere], region: region)
        #expect(counts.map(\.area) == [.prefecture(.tokyo), .prefecture(.kyoto), .prefecture(.okinawa), .abroad, .unknown])
        #expect(counts[1].count == 2)
        #expect(PlaceArea.needsLookup([kyoto, naha, somewhere], region: region).map(\.title) == ["どこか"])
    }
}
