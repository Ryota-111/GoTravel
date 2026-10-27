import Testing
import Foundation
import CoreLocation
@testable import GoTravel

/// 旅行の「行きたい場所」（3.1）。場所保存から写し、共有した相手の追加を消さないこと
struct WishPlaceTests {

    private static let base = Date(timeIntervalSince1970: 1_700_000_000)

    private func plan(_ wishes: [WishPlace], updatedAt seconds: TimeInterval) -> TravelPlan {
        TravelPlan(id: "plan-1", title: "京都", startDate: Self.base, endDate: Self.base.addingTimeInterval(86_400),
                   destination: "京都", userId: "owner", isShared: true, shareCode: "TRAVEL-TESTCODE",
                   sharedWith: ["owner", "me"], ownerId: "owner",
                   updatedAt: Self.base.addingTimeInterval(seconds), wishPlaces: wishes)
    }

    private func wish(_ id: String, _ name: String, lat: Double = 35.0, lon: Double = 135.7) -> WishPlace {
        WishPlace(id: id, name: name, latitude: lat, longitude: lon, addedAt: Self.base)
    }

    @Test("場所保存から写す。同じ場所は二度足さない")
    func addFromSavedPlaces() {
        let cafe = VisitedPlace(id: "p1", title: "喫茶ソワレ", notes: "ゼリーポンチ", latitude: 35.004, longitude: 135.769,
                                address: "京都市下京区", linkURL: "https://example.com", categoryId: "cafe")
        var trip = plan([], updatedAt: 0)
        #expect(trip.addWishPlaces([cafe], addedBy: "me") == 1)
        #expect(trip.addWishPlaces([cafe], addedBy: "me") == 0)
        #expect(trip.wishPlaces.count == 1)
        let added = trip.wishPlaces[0]
        #expect(added.name == "喫茶ソワレ")
        #expect(added.note == "ゼリーポンチ")
        #expect(added.categoryId == "cafe")
        #expect(added.sourcePlaceId == "p1")
        #expect(added.addedBy == "me")
        #expect(trip.hasWishPlace(from: cafe))
    }

    @Test("保存の JSON を行き来できる。空なら欄を作らない")
    func encodeDecode() throws {
        let wishes = [wish("a", "伏見稲荷"), wish("b", "錦市場")]
        #expect(WishPlace.decode(WishPlace.encode(wishes)) == wishes)
        #expect(WishPlace.encode([]) == nil)
        #expect(WishPlace.decode(nil).isEmpty)

        let trip = plan(wishes, updatedAt: 0)
        let decoded = try JSONDecoder().decode(TravelPlan.self, from: JSONEncoder().encode(trip))
        #expect(decoded.wishPlaces == wishes)
        #expect(!trip.isContentEqual(to: plan([], updatedAt: 0)))
    }

    @Test("今いる場所から近い順。場所が分からなければ足した順")
    func sortByDistance() {
        let far = WishPlace(id: "far", name: "嵐山", latitude: 35.009, longitude: 135.667, addedAt: Self.base.addingTimeInterval(10))
        let near = WishPlace(id: "near", name: "祇園", latitude: 35.003, longitude: 135.775, addedAt: Self.base)
        let kyotoStation = CLLocationCoordinate2D(latitude: 34.985, longitude: 135.758)
        #expect(WishPlace.sorted([far, near], near: kyotoStation).map(\.id) == ["near", "far"])
        #expect(WishPlace.sorted([near, far], near: nil).map(\.id) == ["far", "near"])
        #expect(WishPlace.distanceText(342) == "340m")
        #expect(WishPlace.distanceText(1_234) == "1.2km")
        #expect(WishPlace.distanceText(23_600) == "24km")
    }

    @Test("共有した旅行：相手が足した場所と、自分が足した場所の両方を残す。外したものは戻さない")
    func mergeKeepsBothSides() {
        let shrine = wish("a", "伏見稲荷")
        let market = wish("b", "錦市場")
        let temple = wish("c", "清水寺")
        let base = plan([shrine, market], updatedAt: 0)
        // 自分は清水寺を足し、相手は錦市場を外した
        let local = plan([shrine, market, temple], updatedAt: 20)
        let remote = plan([shrine], updatedAt: 10)

        let decision = SharedPlanMerge.decide(local: local, remote: remote, base: base, myUserId: "me")
        let merged = decision.takenPlan ?? decision.pushedPlan
        #expect(Set(merged?.wishPlaces.map(\.id) ?? []) == ["a", "c"])
    }
}
