import Testing
import Foundation
@testable import GoTravel

/// おでかけの予定表の「移動」と「時間未定」（3.5）
struct PlanScheduleMoveAndUndecidedTests {

    private let day = Calendar.current.date(from: DateComponents(year: 2026, month: 12, day: 5))!

    private func at(_ hour: Int, _ minute: Int, _ second: Int = 0) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: second, of: day)!
    }

    private func item(_ id: String, _ hour: Int, _ minute: Int, undecided: Bool = false) -> PlanScheduleItem {
        var item = PlanScheduleItem(id: id, time: at(hour, minute), title: id)
        item.isTimeUndecided = undecided ? true : nil
        return item
    }

    @Test("時間未定の予定は、選んだ予定のすぐ後ろに入り、その分の秒に置かれる")
    func insertAfterAnchor() {
        let items = [item("朝ごはん", 8, 0), item("水族館", 10, 0), item("昼ごはん", 12, 0)]
        let placed = PlanScheduleUndecided.inserting(item("お土産", 0, 0), after: "水族館", into: items)
        #expect(placed.map(\.id) == ["朝ごはん", "水族館", "お土産", "昼ごはん"])
        let souvenir = placed.first { $0.id == "お土産" }!
        #expect(souvenir.time == at(10, 0, 1))
        #expect(souvenir.hasUndecidedTime)
        // 並べ直しても同じ順
        #expect(placed.sorted(by: PlanScheduleItem.chronologically).map(\.id) == placed.map(\.id))
    }

    @Test("いちばん前に入れると、最初の予定の1分前の分に置かれる。続けて入れた未定は1秒ずつずれる")
    func insertAtFront() {
        let items = [item("水族館", 10, 0)]
        var placed = PlanScheduleUndecided.inserting(item("A", 0, 0), after: nil, into: items)
        placed = PlanScheduleUndecided.inserting(item("B", 0, 0), after: "A", into: placed.filter { $0.id != "B" })
        #expect(placed.map(\.id) == ["A", "B", "水族館"])
        #expect(placed[0].time == at(9, 59, 1))
        #expect(placed[1].time == at(9, 59, 2))
    }

    @Test("その日が全部「時間未定」でも、作った時刻ではなく選んだ並びのまま")
    func allUndecidedKeepsChosenOrder() {
        // 作った時刻がばらばら（新しい予定の時刻は、作った時の時刻から始まる）
        var a = item("A", 14, 23, undecided: true)
        a.time = at(14, 23, 1)
        var b = item("B", 15, 10, undecided: true)
        b.time = at(15, 10, 2)
        let front = PlanScheduleUndecided.inserting(item("C", 16, 0), after: nil, into: [a, b])
        #expect(front.map(\.id) == ["C", "A", "B"])
        #expect(front.sorted(by: PlanScheduleItem.chronologically).map(\.id) == ["C", "A", "B"])

        let middle = PlanScheduleUndecided.inserting(item("C", 16, 0), after: "A", into: [a, b])
        #expect(middle.sorted(by: PlanScheduleItem.chronologically).map(\.id) == ["A", "C", "B"])
    }

    @Test("同じ分なら、時刻のある予定が先。未定どうしは秒の順")
    func ordering() {
        var undecided = item("未定", 10, 0, undecided: true)
        undecided.time = at(10, 0, 1)
        let decided = item("決まり", 10, 0)
        #expect(PlanScheduleItem.chronologically(decided, undecided))
        #expect(!PlanScheduleItem.chronologically(undecided, decided))
    }

    @Test("直す画面の「入れる位置」は、今のすぐ前の予定")
    func anchor() {
        var undecided = item("お土産", 10, 0, undecided: true)
        undecided.time = at(10, 0, 1)
        let items = [item("昼ごはん", 12, 0), undecided, item("水族館", 10, 0)]
        #expect(PlanScheduleUndecided.anchorID(of: "お土産", in: items) == "水族館")
        #expect(PlanScheduleUndecided.anchorID(of: "水族館", in: items) == nil)
    }

    @Test("移動：名前を入れなければ「梅田 → 京都」が名前になり、場所は外れる")
    func applyMove() {
        var schedule = item("x", 9, 0)
        schedule.placeId = "place-1"
        schedule.apply(move: ScheduleMove(mode: .train, line: "阪急 特急", from: MovePlace(name: "梅田"), to: MovePlace(name: "京都")),
                       title: "  ")
        #expect(schedule.title == "梅田 → 京都")
        #expect(schedule.hasDefaultMoveTitle)
        #expect(schedule.placeId == nil)
        #expect(schedule.isMove)
    }

    @Test("新しい項目は古いデータにも入れられ、無い古いデータも読める")
    func codable() throws {
        var schedule = item("x", 9, 0, undecided: true)
        schedule.move = ScheduleMove(mode: .bus, from: MovePlace(name: "駅"))
        let decoded = try JSONDecoder().decode(PlanScheduleItem.self, from: JSONEncoder().encode(schedule))
        #expect(decoded == schedule)

        let old = #"{"id":"a","time":0,"title":"古い予定"}"#.data(using: .utf8)!
        let legacy = try JSONDecoder().decode(PlanScheduleItem.self, from: old)
        #expect(legacy.move == nil)
        #expect(!legacy.hasUndecidedTime)
    }
}
