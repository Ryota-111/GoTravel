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

/// 旅行のメモを何枚も（3.0）
struct TripMemosTests {

    private static let base = Date(timeIntervalSince1970: 1_700_000_000)

    private func plan(memos: [TripMemo], legacy: String? = nil, updatedAt seconds: TimeInterval,
                      title: String = "沖縄旅行") -> TravelPlan {
        TravelPlan(id: "plan-1", title: title, startDate: Self.base, endDate: Self.base.addingTimeInterval(86_400),
                   destination: "沖縄", userId: "owner", isShared: true, shareCode: "TRAVEL-TESTCODE",
                   sharedWith: ["owner", "me"], ownerId: "owner",
                   updatedAt: Self.base.addingTimeInterval(seconds), memo: legacy, memos: memos)
    }

    private func memo(_ id: String, _ body: String, private isPrivate: Bool = false) -> TripMemo {
        TripMemo(id: id, title: id, body: body, isPrivate: isPrivate,
                 createdAt: Self.base, updatedAt: Self.base)
    }

    private func merged(local: TravelPlan, remote: TravelPlan, base: TravelPlan?) -> TravelPlan? {
        let decision = SharedPlanMerge.decide(local: local, remote: remote, base: base, myUserId: "me")
        return decision.takenPlan ?? decision.pushedPlan
    }

    @Test("2.9 の1枚のメモは、どの端末でも同じ id・同じ日時の共有メモ1枚になる")
    func legacyMigration() {
        let a = TripMemoLegacy.reconcile(memos: [], legacy: "集合は那覇空港")
        let b = TripMemoLegacy.reconcile(memos: [], legacy: "集合は那覇空港")
        #expect(a == b)
        #expect(a.first?.id == TripMemo.legacyId)
        #expect(a.first?.isPrivate == false)
        #expect(TripMemoLegacy.reconcile(memos: [], legacy: "  ").isEmpty)
    }

    @Test("2.9 の人が書き換えたら、1枚目の共有メモに反映する。自分だけのメモは触らない")
    func legacyEdit() {
        let memos = [memo("mine", "秘密", private: true), memo("shared", "集合は那覇空港")]
        let updated = TripMemoLegacy.reconcile(memos: memos, legacy: "集合は那覇空港 10時")
        #expect(updated.first { $0.id == "shared" }?.body == "集合は那覇空港 10時")
        #expect(updated.first { $0.id == "mine" }?.body == "秘密")
        #expect(TripMemoLegacy.legacyText(of: updated) == "集合は那覇空港 10時")
    }

    @Test("メモの一覧は保存して読み直せる。2.9 の形（memo だけ）のデータも読める")
    func codable() throws {
        let original = plan(memos: [memo("a", "共有"), memo("b", "自分", private: true)], updatedAt: 0)
        let decoded = try JSONDecoder().decode(TravelPlan.self, from: JSONEncoder().encode(original))
        #expect(decoded.memos == original.memos)
        #expect(decoded.memo == "共有")

        let old = #"{"title":"旅","startDate":0,"endDate":0,"destination":"沖縄","createdAt":0,"memo":"古いメモ"}"#
        let legacy = try JSONDecoder().decode(TravelPlan.self, from: Data(old.utf8))
        #expect(legacy.memos.map(\.body) == ["古いメモ"])
    }

    @Test("共有した旅行で、相手が足したメモと、自分が直したメモの両方が残り、自分だけのメモも消えない")
    func mergeKeepsBoth() {
        let base = plan(memos: [memo("a", "集合")], updatedAt: 0)
        let local = plan(memos: [memo("a", "集合 10時"), memo("p", "自分用", private: true)], updatedAt: 10)
        let remote = plan(memos: [memo("a", "集合"), memo("b", "駐車場は P2")], updatedAt: 20)

        let result = merged(local: local, remote: remote, base: base)
        #expect(result?.memos.first { $0.id == "a" }?.body == "集合 10時")
        #expect(result?.memos.contains { $0.id == "b" } == true)
        #expect(result?.memos.first { $0.id == "p" }?.isPrivate == true)
    }

    @Test("初めて取り込むとき・前回の内容が無いときも、自分だけのメモは消えない")
    func privateMemosSurviveWithoutBase() {
        let local = plan(memos: [memo("p", "自分用", private: true)], updatedAt: 0)
        let remote = plan(memos: [memo("a", "集合")], updatedAt: 20)
        let result = merged(local: local, remote: remote, base: nil)
        #expect(result?.memos.contains { $0.id == "p" } == true)
        #expect(result?.memos.contains { $0.id == "a" } == true)
    }

    @Test("自分だけのメモを直しただけなら、相手へ送るものは無い")
    func privateEditIsNotShared() {
        let a = plan(memos: [memo("a", "集合"), memo("p", "自分用", private: true)], updatedAt: 0)
        let b = plan(memos: [memo("a", "集合"), memo("p", "自分用（直した）", private: true)], updatedAt: 0)
        #expect(a.isSharedContentEqual(to: b))
        #expect(!a.isContentEqual(to: b))
    }
}
