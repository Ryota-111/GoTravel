import Testing
import Foundation
@testable import GoTravel

/// 旅行のメモ帳。共有した旅行で、ほかの人の書き込みを古い内容で消さないこと
struct TripMemoTests {

    private static let base = Date(timeIntervalSince1970: 1_700_000_000)

    private func plan(memo: String?, updatedAt seconds: TimeInterval, title: String = "沖縄旅行") -> TravelPlan {
        TravelPlan(id: "plan-1", title: title, startDate: Self.base, endDate: Self.base.addingTimeInterval(86_400),
                   destination: "沖縄", userId: "owner", isShared: true, shareCode: "TRAVEL-TESTCODE",
                   sharedWith: ["owner", "me"], ownerId: "owner",
                   updatedAt: Self.base.addingTimeInterval(seconds), memo: memo)
    }

    private func merged(local: TravelPlan, remote: TravelPlan, base: TravelPlan) -> TravelPlan? {
        let decision = SharedPlanMerge.decide(local: local, remote: remote, base: base, myUserId: "me")
        return decision.takenPlan ?? decision.pushedPlan
    }

    @Test("相手だけがメモを書き換えていれば、手元が新しくても相手のメモを採る")
    func takesRemoteMemoWhenOnlyRemoteChanged() {
        let base = plan(memo: "集合は那覇空港", updatedAt: 0)
        let local = plan(memo: "集合は那覇空港", updatedAt: 20, title: "沖縄旅行（手元で改名）")
        let remote = plan(memo: "集合は那覇空港\n駐車場は P2", updatedAt: 10)

        let result = merged(local: local, remote: remote, base: base)
        #expect(result?.memo == "集合は那覇空港\n駐車場は P2")
        #expect(result?.title == "沖縄旅行（手元で改名）")
    }

    @Test("自分だけがメモを書き換えていれば、相手が新しくても自分のメモを残す")
    func keepsLocalMemoWhenOnlyLocalChanged() {
        let base = plan(memo: nil, updatedAt: 0)
        let local = plan(memo: "持ち物：日焼け止め", updatedAt: 10)
        let remote = plan(memo: nil, updatedAt: 20, title: "沖縄旅行（相手が改名）")

        let result = merged(local: local, remote: remote, base: base)
        #expect(result?.memo == "持ち物：日焼け止め")
    }

    @Test("メモは保存して読み直しても残り、無い前のデータも読める")
    func codable() throws {
        let original = plan(memo: "メモ", updatedAt: 0)
        let decoded = try JSONDecoder().decode(TravelPlan.self, from: JSONEncoder().encode(original))
        #expect(decoded.memo == "メモ")
        #expect(original.isContentEqual(to: decoded))
        #expect(!original.isContentEqual(to: plan(memo: "別のメモ", updatedAt: 0)))
    }
}
