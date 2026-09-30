import Testing
import Foundation
@testable import GoTravel

/// 予約の費用。行程の予定の金額と同じものとして扱い、予算で2重に数えない
struct ReservationCostTests {

    private let tokyo = TimeZone(identifier: "Asia/Tokyo")!

    private func date(_ day: Int, _ hour: Int) -> Date {
        ScheduleClock.calendar(in: tokyo).date(
            from: DateComponents(year: 2026, month: 10, day: day, hour: hour)
        )!
    }

    /// 10/6〜10/8 の3日間
    private func plan() -> TravelPlan {
        var plan = TravelPlan(title: "沖縄", startDate: date(6, 0), endDate: date(8, 0), destination: "沖縄")
        plan.daySchedules = (1...3).map { DaySchedule(dayNumber: $0, date: date(5 + $0, 0), scheduleItems: []) }
        return plan
    }

    // MARK: - 行程との連動

    @Test("行程にも追加すると、費用は1件目の予定にだけ入る（飛行機の到着には入れない）")
    func costGoesToFirstItineraryItem() {
        var plan = plan()
        let flight = Reservation(kind: .flight, date: date(6, 10), transportNumber: "NH991",
                                 arrivalDate: date(6, 13), timeZoneIdentifier: tokyo.identifier,
                                 arrivalTimeZoneIdentifier: tokyo.identifier, cost: 30000)
        plan.reservations = [flight]
        plan.syncScheduleItems(for: flight, isOn: true)

        let items = plan.scheduleItems(forReservation: flight.id)
        #expect(items.map(\.cost) == [30000, nil])
        #expect(plan.totalPlannedCost == 30000)
    }

    @Test("行程に出ていない予約の費用も、予算の合計に入る")
    func costOutsideItineraryCounts() {
        var plan = plan()
        plan.reservations = [Reservation(kind: .hotel, title: "宿", cost: 20000)]
        plan.daySchedules[0].scheduleItems = [ScheduleItem(time: date(6, 12), title: "昼食", cost: 1500)]
        #expect(plan.reservationsWithCostOutsideItinerary.count == 1)
        #expect(plan.totalPlannedCost == 21500)
    }

    @Test("行程の予定で金額を直すと、予約の費用も揃う")
    func editingItineraryCostUpdatesReservation() {
        var plan = plan()
        let hotel = Reservation(kind: .hotel, title: "宿", date: date(6, 15),
                                timeZoneIdentifier: tokyo.identifier, cost: 20000)
        plan.reservations = [hotel]
        plan.syncScheduleItems(for: hotel, isOn: true)

        // 予定の側で 18000 に直す
        for day in plan.daySchedules.indices {
            for item in plan.daySchedules[day].scheduleItems.indices
            where plan.daySchedules[day].scheduleItems[item].reservationId == hotel.id {
                plan.daySchedules[day].scheduleItems[item].cost = 18000
            }
        }
        plan.syncReservationCost(fromScheduleItemsOf: hotel.id)

        #expect(plan.reservations[0].cost == 18000)
        #expect(plan.totalPlannedCost == 18000)
    }

    @Test("予約を保存し直しても、行程で入れた実績の金額は消えない")
    func resyncKeepsActualCost() {
        var plan = plan()
        var hotel = Reservation(kind: .hotel, title: "宿", date: date(6, 15),
                                timeZoneIdentifier: tokyo.identifier, cost: 20000)
        plan.reservations = [hotel]
        plan.syncScheduleItems(for: hotel, isOn: true)
        plan.daySchedules[0].scheduleItems[0].actualCost = 19500

        hotel.title = "宿（改名）"
        plan.syncScheduleItems(for: hotel, isOn: true)

        let items = plan.scheduleItems(forReservation: hotel.id)
        #expect(items.count == 1)
        #expect(items[0].actualCost == 19500)
        #expect(items[0].title == "宿（改名）")
    }

    // MARK: - メールの金額

    @Test("支払いの合計を読む。小計や1枚あたりの値段は拾わない")
    func readsPaidAmount() {
        let text = """
        丸型5号 ¥4,500(税込) × 1
        小計:¥4,500(税込)
        合計金額:￥6,000(税込)
        """
        #expect(ReservationEmailParser.paidAmount(in: text) == 6000)
    }

    @Test("ラベルの次の行にある金額も読む。円表記も読む")
    func readsAmountOnNextLine() {
        #expect(ReservationEmailParser.paidAmount(in: "お支払い金額\n￥2,600") == 2600)
        #expect(ReservationEmailParser.paidAmount(in: "合計 12,300円") == 12300)
    }

    @Test("ラベルの無い金額・円以外の金額は読まない")
    func ignoresUnlabeledOrForeignAmounts() {
        #expect(ReservationEmailParser.paidAmount(in: "大人 ¥9,900 ×1枚") == nil)
        #expect(ReservationEmailParser.paidAmount(in: "Total: $120.00") == nil)
        #expect(ReservationEmailParser.paidAmount(in: "Subtotal ¥5,000") == nil)
    }

    @Test("往復の航空券では、金額は1件目にだけ入る")
    func roundTripCostOnFirstOnly() {
        let text = """
        予約番号：ABC123
        往路 2026年10月6日 JL915 羽田 10:00 → 那覇 12:40
        復路 2026年10月8日 JL920 那覇 13:30 → 羽田 16:00
        お支払い金額：¥48,000
        """
        let drafts = ReservationEmailParser.parse(text)
        #expect(drafts.count == 2)
        #expect(drafts.first?.cost == 48000)
        #expect(drafts.last?.cost == nil)
    }

    // MARK: - 選んだ種類で読む

    @Test("種類を選んでいれば、文面から当てずにその種類として読む")
    func chosenKindWins() {
        // ケーキの受け取り（文面からは「その他」）を、チケットとして読ませる
        let text = """
        ご注文ありがとうございます。
        受付ID： 123456
        受取り日
        2026-10-03(金)
        受取り時間
        20:30~21:00
        """
        #expect(ReservationEmailParser.parse(text).first?.kind == .other)
        let chosen = ReservationEmailParser.parse(text, kind: .ticket)
        #expect(chosen.first?.kind == .ticket)
        #expect(chosen.first?.confirmationNumber == "123456")
    }
}

extension ReservationCostTests {
    @Test("クーポンやポイントを引いた後の金額を、引く前の合計より先に使う")
    func prefersDiscountedTotal() {
        let text = """
        料金合計
        32,000円
        Pontaポイント利用料
        -3,270円
        割引後料金合計
        25,530円
        """
        #expect(ReservationEmailParser.paidAmount(in: text) == 25530)
    }

    @Test("合計が無い航空券は、運賃を使う")
    func fallsBackToFare() {
        #expect(ReservationEmailParser.paidAmount(in: "□ 運賃額等\n12,890円") == 12890)
    }
}
