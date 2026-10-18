import Testing
import Foundation
@testable import GoTravel

/// 割り勘（3.1）。誰がいくら払い、いくら分を使ったかから、受け渡しを出す
struct TripSplitTests {

    private let start = Date(timeIntervalSince1970: 1_790_000_000)

    private func plan(items: [ScheduleItem] = [], shared: [String] = [], companions: [TripCompanion] = [],
                      expenses: [TripExpense] = []) -> TravelPlan {
        TravelPlan(title: "沖縄", startDate: start, endDate: start.addingTimeInterval(86_400 * 2), destination: "沖縄",
                   userId: "me",
                   daySchedules: [DaySchedule(dayNumber: 1, date: start, scheduleItems: items)],
                   isShared: !shared.isEmpty, sharedWith: shared,
                   split: TripSplit(companions: companions, expenses: expenses))
    }

    @Test("運転した人を外した費用と、全員の費用から、受け渡しを出す")
    func transfers() {
        let sakura = TripCompanion(id: "c-sakura", name: "さくら")
        let dad = TripCompanion(id: "c-dad", name: "父")
        let p = plan(items: [
            // 自分が払ったレンタカー 12,000円。運転した父の分は無し → 自分とさくらで 6,000円ずつ
            ScheduleItem(time: start, title: "レンタカー", cost: 12_000, paidBy: "me", splitWith: ["me", "c-sakura"]),
            // さくらが払った水族館 9,000円（全員）→ 3,000円ずつ
            ScheduleItem(time: start, title: "水族館", cost: 9_000, paidBy: "c-sakura"),
        ], companions: [sakura, dad])
        let members = TripSplitLedger.members(of: p, myUserId: "me")
        #expect(members == ["me", "c-sakura", "c-dad"])
        let entries = TripSplitLedger.entries(of: p, myUserId: "me")
        let balances = TripSplitLedger.balances(entries: entries, settlements: p.split.expenses, members: members)
        // 自分: 12,000 払い、6,000 + 3,000 分 → +3,000 / さくら: 9,000 払い、6,000 + 3,000 分 → 0 / 父: 3,000 分 → -3,000
        #expect(balances.map(\.net) == [3_000, 0, -3_000])
        #expect(TripSplitLedger.transfers(from: balances) == [.init(from: "c-dad", to: "me", amount: 3_000)])
    }

    @Test("実際に使った金額を優先する")
    func prefersActual() {
        let p = plan(items: [ScheduleItem(time: start, title: "夕食", cost: 10_000, actualCost: 8_000)],
                     companions: [TripCompanion(id: "c-a", name: "A")])
        let entries = TripSplitLedger.entries(of: p, myUserId: "me")
        #expect(entries.map(\.amount) == [8_000])
        // 共有していない旅行では、払った人が無ければ自分
        #expect(entries.first?.paidBy == "me")
        let balances = TripSplitLedger.balances(entries: entries, settlements: [], members: ["me", "c-a"])
        #expect(TripSplitLedger.transfers(from: balances) == [.init(from: "c-a", to: "me", amount: 4_000)])
    }

    @Test("共有している旅行では、払った人が無い費用は精算に入れない")
    func unassignedInSharedPlan() {
        let p = plan(items: [ScheduleItem(time: start, title: "宿", cost: 20_000)], shared: ["me", "u2"])
        let members = TripSplitLedger.members(of: p, myUserId: "me")
        let entries = TripSplitLedger.entries(of: p, myUserId: "me")
        #expect(TripSplitLedger.unassigned(entries, members: members).count == 1)
        let balances = TripSplitLedger.balances(entries: entries, settlements: [], members: members)
        #expect(TripSplitLedger.transfers(from: balances).isEmpty)
    }

    @Test("済ませた精算を記録すると、その受け渡しは消える。支出は合計に入る")
    func settlementsAndExpenses() {
        let water = TripExpense(title: "水", amount: 300, date: start, paidBy: "me")
        let p = plan(shared: ["me", "u2", "u3"], expenses: [water])
        let members = TripSplitLedger.members(of: p, myUserId: "me")
        let entries = TripSplitLedger.entries(of: p, myUserId: "me")
        #expect(entries.first?.dayNumber == 1)
        var balances = TripSplitLedger.balances(entries: entries, settlements: [], members: members)
        let before = TripSplitLedger.transfers(from: balances)
        #expect(before.map(\.amount) == [100, 100])

        let settled = before.map { TripExpense.settlement(from: $0.from, to: $0.to, amount: $0.amount, date: start) }
        balances = TripSplitLedger.balances(entries: entries, settlements: settled, members: members)
        #expect(TripSplitLedger.transfers(from: balances).isEmpty)
        // 精算は費用に数えない
        var withSettlement = p
        withSettlement.split.expenses += settled
        #expect(TripSplitLedger.entries(of: withSettlement, myUserId: "me").count == 1)
    }

    @Test("割り切れない金額は円で四捨五入し、受け渡しの回数をなるべく減らす")
    func rounding() {
        let p = plan(items: [ScheduleItem(time: start, title: "タクシー", cost: 1_000, paidBy: "me")],
                     shared: ["me", "u2", "u3"])
        let members = TripSplitLedger.members(of: p, myUserId: "me")
        let balances = TripSplitLedger.balances(entries: TripSplitLedger.entries(of: p, myUserId: "me"),
                                                settlements: [], members: members)
        let transfers = TripSplitLedger.transfers(from: balances)
        #expect(transfers.count == 2)
        #expect(transfers.allSatisfy { $0.to == "me" && $0.amount == 333 })
    }

    @Test("保存の形を行き来しても変わらない。何も無ければ書かない")
    func encoding() {
        #expect(TripSplit.encode(TripSplit()) == nil)
        let split = TripSplit(companions: [TripCompanion(id: "c-1", name: "父")],
                              expenses: [TripExpense(id: "e", title: "水", amount: 150, date: start, paidBy: "me",
                                                     splitWith: ["me", "c-1"])])
        #expect(TripSplit.decode(TripSplit.encode(split)) == split)
        #expect(TripSplit.decode(nil) == TripSplit())

        // 旅行の JSON（書き出し・バックアップ）にも載る
        let p = plan(companions: split.companions, expenses: split.expenses)
        let data = try! JSONEncoder().encode(p)
        let decoded = try! JSONDecoder().decode(TravelPlan.self, from: data)
        #expect(decoded.split == split)
    }

    @Test("共有した旅行で、相手が足した支出と自分が足した同行者が、どちらも残る")
    func sharedMerge() {
        var base = plan(shared: ["me", "u2"])
        base.updatedAt = start
        var local = base
        local.split.companions = [TripCompanion(id: "c-kid", name: "こども")]
        local.updatedAt = start.addingTimeInterval(10)
        var remote = base
        remote.split.expenses = [TripExpense(id: "e1", title: "水", amount: 200, date: start, paidBy: "u2")]
        remote.updatedAt = start.addingTimeInterval(20)

        let decision = SharedPlanMerge.decide(local: local, remote: remote, base: base, myUserId: "me")
        let merged = decision.takenPlan ?? decision.pushedPlan
        #expect(merged?.split.companions.map(\.id) == ["c-kid"])
        #expect(merged?.split.expenses.map(\.id) == ["e1"])
    }
}
