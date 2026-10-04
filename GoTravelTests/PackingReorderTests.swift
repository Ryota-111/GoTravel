import Testing
import Foundation
@testable import GoTravel

/// リストの並び替え。3つのリストが1つの配列に混ざっているので、ほかの項目を動かさないこと
struct PackingReorderTests {

    private func trip(_ items: [PackingItem]) -> TravelPlan {
        var plan = TravelPlan(title: "旅", startDate: Date(), endDate: Date(), destination: "沖縄")
        plan.packingItems = items
        return plan
    }

    @Test("渡した順に並び、ほかのリスト（お土産）の項目の位置は動かない")
    func reordersWithinKindOnly() {
        let a = PackingItem(name: "充電器", isChecked: false, kind: .packing)
        let gift = PackingItem(name: "ちんすこう", isChecked: false, kind: .souvenir)
        let b = PackingItem(name: "水着", isChecked: false, kind: .packing)
        let c = PackingItem(name: "日焼け止め", isChecked: false, kind: .packing)
        var plan = trip([a, gift, b, c])

        plan.reorderPackingItems(orderedIds: [c.id, a.id, b.id])

        #expect(plan.packingItems.map(\.name) == ["日焼け止め", "ちんすこう", "充電器", "水着"])
        #expect(plan.items(of: .packing).map(\.name) == ["日焼け止め", "充電器", "水着"])
    }

    @Test("ほかの人だけに見える項目は、並び替えに含めなければ位置が変わらない")
    func keepsOthersItemsInPlace() {
        let mine1 = PackingItem(name: "カメラ", isChecked: false, kind: .packing, ownerId: "me")
        let theirs = PackingItem(name: "相手の傘", isChecked: false, kind: .packing, ownerId: "you")
        let mine2 = PackingItem(name: "財布", isChecked: false, kind: .packing, ownerId: "me")
        var plan = trip([mine1, theirs, mine2])

        plan.reorderPackingItems(orderedIds: [mine2.id, mine1.id])

        #expect(plan.packingItems.map(\.name) == ["財布", "相手の傘", "カメラ"])
    }

    @Test("知らない項目が混ざっていたら、何も変えない（途中で消えた項目など）")
    func ignoresUnknownIds() {
        let a = PackingItem(name: "充電器", isChecked: false, kind: .packing)
        let b = PackingItem(name: "水着", isChecked: false, kind: .packing)
        var plan = trip([a, b])
        plan.reorderPackingItems(orderedIds: [b.id, "消えた項目", a.id])
        #expect(plan.packingItems.map(\.name) == ["水着", "充電器"])
    }
}
