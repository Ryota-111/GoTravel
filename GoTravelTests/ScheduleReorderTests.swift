import Testing
import Foundation
@testable import GoTravel

/// 行程と日程の並び替え・移動手段・予定の地図の番号（3.2）。
///
/// 並び替えで時刻や日付を取り違えると、当日の行動そのものを誤らせる
struct ScheduleReorderTests {

    private let tokyo = TimeZone(identifier: "Asia/Tokyo")!

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        ScheduleClock.calendar(in: tokyo).date(
            from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute)
        )!
    }

    private func item(_ id: String, day: Int, _ hour: Int, end: Int? = nil) -> ScheduleItem {
        ScheduleItem(id: id, time: date(day, hour), title: id,
                     timeZoneIdentifier: tokyo.identifier,
                     endTime: end.map { date(day, $0) })
    }

    /// 11/3〜11/4 の2日間。1日目は A(9時)・B(11〜12時)・C(14時)、2日目は D(10時)
    private func plan() -> TravelPlan {
        var plan = TravelPlan(title: "京都", startDate: date(3, 0), endDate: date(4, 0), destination: "京都")
        plan.daySchedules = [
            DaySchedule(dayNumber: 1, date: date(3, 0),
                        scheduleItems: [item("A", day: 3, 9), item("B", day: 3, 11, end: 12), item("C", day: 3, 14)]),
            DaySchedule(dayNumber: 2, date: date(4, 0), scheduleItems: [item("D", day: 4, 10)],
                        timeZoneIdentifier: "Asia/Tokyo"),
        ]
        return plan
    }

    private func titles(_ plan: TravelPlan, day: Int) -> [String] {
        plan.timelineScheduleItems(onDay: day).map(\.title)
    }

    @Test("時刻の枠はそのままで中身が入れ替わり、終わりの時刻は長さを保って動く")
    func reorderItems() {
        let reordered = plan().reorderingItems(onDay: 1, from: ["A", "B", "C"], to: ["B", "A", "C"])
        #expect(titles(reordered, day: 1) == ["B", "A", "C"])

        let items = reordered.daySchedules[0].scheduleItems
        let b = items.first { $0.id == "B" }!
        let a = items.first { $0.id == "A" }!
        #expect(b.time == date(3, 9))
        #expect(b.endTime == date(3, 10))
        #expect(a.time == date(3, 11))
        #expect(items.first { $0.id == "C" }!.time == date(3, 14))
    }

    @Test("同じ順や、id の合わない並びは何もしない")
    func reorderItemsNoop() {
        let original = plan()
        #expect(titles(original.reorderingItems(onDay: 1, from: ["A", "B", "C"], to: ["A", "B", "C"]), day: 1) == ["A", "B", "C"])
        #expect(titles(original.reorderingItems(onDay: 1, from: ["A", "B", "C"], to: ["A", "B", "X"]), day: 1) == ["A", "B", "C"])
    }

    @Test("日にちを入れ替えると、予定は時:分を保ったまま相手の日付へ移り、日付と何日目は残る")
    func reorderDays() {
        let swapped = plan().reorderingDays([2, 1])
        #expect(titles(swapped, day: 1) == ["D"])
        #expect(titles(swapped, day: 2) == ["A", "B", "C"])

        let day1 = swapped.daySchedules.first { $0.dayNumber == 1 }!
        let day2 = swapped.daySchedules.first { $0.dayNumber == 2 }!
        #expect(day1.date == date(3, 0))
        #expect(day1.scheduleItems.first?.time == date(3, 10))
        #expect(day1.timeZoneIdentifier == "Asia/Tokyo")
        #expect(day2.scheduleItems.first { $0.id == "B" }?.endTime == date(4, 12))
        #expect(day2.timeZoneIdentifier == nil)
    }

    @Test("移動手段は文字で持ち、知らない値は無いものとして読む")
    func transportMode() throws {
        var a = item("A", day: 3, 9)
        a.transportToNext = TransportMode.train.rawValue
        let decoded = try JSONDecoder().decode(ScheduleItem.self, from: JSONEncoder().encode(a))
        #expect(decoded.transportToNextMode == .train)

        a.transportToNext = "hoverboard"
        #expect(a.transportToNextMode == nil)
    }

    @Test("予定の地図の番号は、何日目・時刻の順に最初に行く順で、行程に無い場所には付けない")
    func planPlaceOrder() {
        let cafe = PlannedPlace(id: "cafe", name: "カフェ", latitude: 35, longitude: 135)
        let temple = PlannedPlace(id: "temple", name: "お寺", latitude: 35.1, longitude: 135.1)
        let shop = PlannedPlace(id: "shop", name: "お店", latitude: 35.2, longitude: 135.2)
        let plan = Plan(id: "p", title: "おでかけ", startDate: date(3, 0), endDate: date(3, 0),
                        places: [cafe, temple, shop],
                        scheduleItems: [
                            PlanScheduleItem(time: date(3, 15), title: "お茶", placeId: "cafe"),
                            PlanScheduleItem(time: date(3, 10), title: "参拝", placeId: "temple"),
                            PlanScheduleItem(time: date(3, 17), title: "もう一度", placeId: "temple"),
                        ])
        #expect(plan.placeOrder == ["temple": 1, "cafe": 2])
        #expect(plan.placesInVisitOrder.map(\.id) == ["temple", "cafe"])
    }
}
