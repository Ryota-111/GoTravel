import Testing
import Foundation
@testable import GoTravel

/// 旅行ごとの「計算する通貨」（3.1）。円の旅行は今までどおり、ユーロの旅行はユーロで計算すること
struct TripCurrencyTests {

    private static let start = Date(timeIntervalSince1970: 1_790_000_000)

    private func trip(items: [ScheduleItem] = [], reservations: [Reservation] = [], split: TripSplit = TripSplit()) -> TravelPlan {
        TravelPlan(id: "t", title: "パリ", startDate: Self.start, endDate: Self.start.addingTimeInterval(86_400),
                   destination: "パリ", daySchedules: [DaySchedule(dayNumber: 1, date: Self.start, scheduleItems: items)],
                   reservations: reservations, split: split)
    }

    @Test("ふだんは円。円以外にしたときだけ JSON に入り、円に戻すと消える")
    func defaultIsYen() throws {
        var plan = trip()
        #expect(plan.currencyCode == "JPY")
        #expect(plan.usesYen)
        #expect(TripSplit.encode(plan.split) == nil)
        plan.currencyCode = "EUR"
        let decoded = TripSplit.decode(TripSplit.encode(plan.split))
        #expect(decoded.currencyCode == "EUR")
        #expect(decoded.companions.isEmpty)
        plan.currencyCode = "JPY"
        #expect(plan.split.currencyCode == nil)
    }

    @Test("金額の書き方：円は今までどおり ¥、ユーロはセントまで")
    func money() {
        #expect(CurrencyCatalog.money(12_000, code: "JPY") == "¥12,000")
        #expect(CurrencyCatalog.money(9.5, code: "EUR").contains("9.50"))
        #expect(CurrencyCatalog.minimumUnit(of: "EUR") == 0.01)
        #expect(CurrencyCatalog.minimumUnit(of: "KRW") == 1)
        #expect(CurrencyCatalog.round(10.006, code: "EUR") == 10.01)
        #expect(ForeignCost.converted(10, rate: 0.0063, into: "EUR") == 0.06)
        #expect(ForeignCost.converted(10, rate: 152.4, into: "JPY") == 1_524)
    }

    @Test("円 → ユーロ：円で入れた金額は円の外貨として残し、ユーロに直す。ドルのレートも付け替える")
    func changeYenToEuro() {
        let lunch = ScheduleItem(time: Self.start, title: "昼", cost: 3_200, actualCost: 3_000)
        var dinner = ScheduleItem(time: Self.start, title: "夜")
        dinner.foreignCost = ForeignCost(currencyCode: "USD", rate: 150, amount: 20)
        dinner.cost = 3_000
        var cafe = ScheduleItem(time: Self.start, title: "カフェ")
        cafe.foreignCost = ForeignCost(currencyCode: "EUR", rate: 160, amount: 4.5)
        cafe.cost = 720
        let hotel = Reservation(kind: .hotel, cost: 32_000)
        let water = TripExpense(title: "水", amount: 160, date: Self.start)
        var plan = trip(items: [lunch, dinner, cafe], reservations: [hotel], split: TripSplit(expenses: [water]))
        #expect(plan.hasAnyAmount)

        plan.changeCurrency(to: "EUR", rate: 160)   // 1 EUR = 160 円
        #expect(plan.currencyCode == "EUR")
        let items = plan.daySchedules[0].scheduleItems
        #expect(items[0].foreignCost?.currencyCode == "JPY")
        #expect(items[0].foreignCost?.amount == 3_200)
        #expect(items[0].cost == 20)
        #expect(items[0].actualCost == 18.75)
        // 1 USD = 150 円 → 0.9375 EUR
        #expect(items[1].foreignCost?.rate == 0.9375)
        #expect(items[1].cost == 18.75)
        // ユーロで入れていたものは、そのままユーロの金額に
        #expect(items[2].foreignCost == nil)
        #expect(items[2].cost == 4.5)
        #expect(plan.reservations[0].cost == 200)
        #expect(plan.split.expenses[0].amount == 1)
        #expect(plan.money(20).contains("20.00"))

        // 精算はセント単位
        let transfers = TripSplitLedger.transfers(
            from: [.init(member: "a", paid: 10, share: 3.335, net: 6.665), .init(member: "b", paid: 0, share: 6.665, net: -6.665)],
            unit: CurrencyCatalog.minimumUnit(of: "EUR"))
        #expect(transfers.first?.amount == 6.67)
    }

    @Test("金額の入っていない旅行は、レート無しで変えられる")
    func changeEmptyTrip() {
        var plan = trip()
        #expect(!plan.hasAnyAmount)
        plan.changeCurrency(to: "USD", rate: nil)
        #expect(plan.currencyCode == "USD")
    }

    @Test("旅の記録の金額は、いちばん多い通貨の旅行だけを足す")
    func statsCurrency() {
        var a = trip(); a.currencyCode = "EUR"
        var b = trip(); b.currencyCode = "EUR"
        let c = trip()
        #expect(TripStats.spendCurrency(of: [a, b, c]) == "EUR")
        #expect(TripStats.spendCurrency(of: [a, c]) == "JPY")
        #expect(TripStats.spend(of: c, in: "EUR") == 0)
    }
}
