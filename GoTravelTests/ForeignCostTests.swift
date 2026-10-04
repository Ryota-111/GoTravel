import Testing
import Foundation
@testable import GoTravel

/// 外貨の費用。円の金額はいつも「外貨 × 旅行のレート」になっていること
struct ForeignCostTests {

    private let tokyo = TimeZone(identifier: "Asia/Tokyo")!

    private func date(_ day: Int, _ hour: Int) -> Date {
        ScheduleClock.calendar(in: tokyo).date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
    }

    private func plan(items: [ScheduleItem] = [], reservations: [Reservation] = []) -> TravelPlan {
        var plan = TravelPlan(title: "ハワイ", startDate: date(6, 0), endDate: date(8, 0), destination: "ホノルル")
        plan.daySchedules = [DaySchedule(dayNumber: 1, date: date(6, 0), scheduleItems: items)]
        plan.reservations = reservations
        return plan
    }

    @Test("外貨はレートを掛けて円にする。レートが無ければ円は空")
    func convertsWithRate() {
        #expect(ForeignCost(currencyCode: "USD", rate: 150.5, amount: 12.5).yenAmount == 1881)   // 1881.25 → 1881
        #expect(ForeignCost(currencyCode: "USD", rate: nil, amount: 12.5).yenAmount == nil)
    }

    @Test("入力欄：円ならそのまま、外貨なら元の金額とレートを持ち、円に直した金額も出す")
    func costInputResult() {
        var input = CostInput()
        input.amountText = "12,000"
        #expect(input.result.cost == 12000)
        #expect(input.result.foreign == nil)

        input.currencyCode = "USD"
        input.amountText = "100"
        input.actualText = "８０"          // 全角でも読む
        input.rateText = "150"
        let result = input.result
        #expect(result.cost == 15000)
        #expect(result.actualCost == 12000)
        #expect(result.foreign == ForeignCost(currencyCode: "USD", rate: 150, amount: 100, actualAmount: 80))
    }

    @Test("保存されている外貨の費用は、外貨のまま入力欄に戻る")
    func costInputRoundTrip() {
        let foreign = ForeignCost(currencyCode: "EUR", rate: 162, amount: 9.5)
        let input = CostInput(cost: 1539, foreign: foreign)
        #expect(input.currencyCode == "EUR")
        #expect(input.amountText == "9.5")
        #expect(input.rateText == "162")
    }

    @Test("旅行のレートを変えると、同じ通貨の予定と予約がすべて円に直し直される。ほかの通貨は変わらない")
    func setExchangeRateUpdatesWholeTrip() {
        var trip = plan(
            items: [
                ScheduleItem(time: date(6, 12), title: "ランチ", cost: 3000, actualCost: 2700,
                             foreignCost: ForeignCost(currencyCode: "USD", rate: 150, amount: 20, actualAmount: 18)),
                ScheduleItem(time: date(6, 18), title: "ソウルの夕食", cost: 1100,
                             foreignCost: ForeignCost(currencyCode: "KRW", rate: 0.11, amount: 10000)),
                ScheduleItem(time: date(6, 20), title: "おみやげ", cost: 2000)
            ],
            reservations: [Reservation(kind: .ticket, title: "博物館", cost: 4500,
                                       foreignCost: ForeignCost(currencyCode: "USD", rate: 150, amount: 30))]
        )

        trip.setExchangeRate(140, for: "USD")

        let items = trip.daySchedules[0].scheduleItems
        #expect(items[0].cost == 2800)
        #expect(items[0].actualCost == 2520)
        #expect(items[0].foreignCost?.rate == 140)
        #expect(items[1].cost == 1100)            // ウォンは変わらない
        #expect(items[2].cost == 2000)            // 円の予定も変わらない
        #expect(trip.reservations[0].cost == 4200)
        #expect(trip.exchangeRate(for: "USD") == 140)
    }

    @Test("レートが未入力の通貨も、使っている通貨として出る（予算の画面で入れてもらうため）")
    func listsCurrenciesWithoutRate() {
        let trip = plan(items: [ScheduleItem(time: date(6, 12), title: "ランチ",
                                             foreignCost: ForeignCost(currencyCode: "THB", rate: nil, amount: 300))])
        #expect(trip.exchangeRates.keys.contains("THB"))
        #expect(trip.exchangeRate(for: "THB") == nil)
        #expect(trip.totalPlannedCost == 0)       // レートが無いあいだは合計に入らない
    }

    @Test("予約を行程にも追加すると、外貨の金額も予定に引き継がれる")
    func reservationForeignCostGoesToItinerary() {
        var trip = plan()
        let hotel = Reservation(kind: .hotel, title: "ホテル", date: date(6, 15),
                                timeZoneIdentifier: tokyo.identifier, cost: 30000,
                                foreignCost: ForeignCost(currencyCode: "USD", rate: 150, amount: 200))
        trip.reservations = [hotel]
        trip.syncScheduleItems(for: hotel, isOn: true)

        let item = trip.scheduleItems(forReservation: hotel.id).first
        #expect(item?.foreignCost?.amount == 200)
        #expect(item?.cost == 30000)
        #expect(trip.totalPlannedCost == 30000)   // 2重に数えない
    }

    @Test("通貨の表示は通貨の決まりに合わせる（ウォンは小数なし）")
    func formatsCurrency() {
        #expect(CurrencyCatalog.format(15000, code: "KRW").contains("15,000"))
        #expect(CurrencyCatalog.format(9.5, code: "EUR").contains("9.50"))
    }
}
