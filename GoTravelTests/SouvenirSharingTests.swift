import Testing
import Foundation
@testable import GoTravel

/// お土産を同行者と共有する（3.0）。「みんな」のお土産は同行者に届き、「自分だけ」は届かない
struct SouvenirSharingTests {

    private static let base = Date(timeIntervalSince1970: 1_790_000_000)

    private func plan(_ items: [PackingItem], updatedAt seconds: TimeInterval) -> TravelPlan {
        TravelPlan(id: "p", title: "家族旅行", startDate: Self.base, endDate: Self.base.addingTimeInterval(86_400),
                   destination: "沖縄", userId: "me", packingItems: items, isShared: true,
                   shareCode: "TRAVEL-TEST", sharedWith: ["owner", "me"], ownerId: "owner",
                   updatedAt: Self.base.addingTimeInterval(seconds))
    }

    @Test("どのリストも「みんなの」と「自分の」の欄に分かれ、担当を付けられるのは持ち物だけ（3.7）")
    func kinds() {
        for kind in PackingItem.Kind.allCases {
            #expect(kind.sharedSectionTitle != kind.privateSectionTitle)
        }
        #expect(PackingItem.Kind.packing.sharedSectionTitle == "みんなで持っていく物")
        #expect(PackingItem.Kind.packing.usesAssignee)
        #expect(!PackingItem.Kind.souvenir.usesAssignee)
        #expect(!PackingItem.Kind.wish.usesAssignee)
    }

    @Test("「みんな」のお土産は相手が足したものも届き、「自分だけ」のお土産は消えない")
    func merge() {
        let shared = PackingItem(id: "s", name: "ちんすこう", kind: .souvenir)
        let mine = PackingItem(id: "m", name: "母へのサプライズ", kind: .souvenir, ownerId: "me")
        let theirs = PackingItem(id: "t", name: "紅いもタルト", kind: .souvenir)
        let base = plan([shared], updatedAt: 0)
        let local = plan([shared, mine], updatedAt: 10)
        let remote = plan([shared, theirs], updatedAt: 20)

        let decision = SharedPlanMerge.decide(local: local, remote: remote, base: base, myUserId: "me")
        let merged = decision.takenPlan ?? decision.pushedPlan
        #expect(Set(merged?.packingItems.map(\.id) ?? []) == ["s", "m", "t"])
        // 「自分だけ」は共有の比べ合いに入らない（相手に送るものは無い）
        #expect(plan([shared, theirs], updatedAt: 0).isSharedContentEqual(to: plan([shared, theirs, mine], updatedAt: 0)))
    }

    @Test("同行者の「自分だけ」のお土産は、自分には見えない")
    func visibility() {
        let others = PackingItem(name: "あなたへのお土産", kind: .souvenir, ownerId: "owner")
        #expect(!others.isVisible(to: "me"))
        #expect(PackingItem(name: "ちんすこう", kind: .souvenir).isVisible(to: "me"))
    }
}
