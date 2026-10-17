import Testing
import Foundation
import PDFKit
@testable import GoTravel

/// 旅のしおり（PDF・Travory Pro）。ページ割りと、渡す相手に見せないものが入らないこと
@MainActor
struct TravelBookletTests {

    private let start = Date(timeIntervalSince1970: 1_790_000_000)

    /// 那覇の2日間。1日目は場所つきの予定が多く、ページが分かれる
    static func sampleTrip(start: Date = Date(timeIntervalSince1970: 1_790_000_000)) -> TravelPlan {
        func item(_ hour: Int, _ title: String, _ lat: Double? = nil, _ lon: Double? = nil,
                  cost: Double? = nil, notes: String? = nil, location: String? = nil) -> ScheduleItem {
            ScheduleItem(time: start.addingTimeInterval(Double(hour) * 3600), title: title, location: location,
                         notes: notes, latitude: lat, longitude: lon, cost: cost)
        }
        let day1 = DaySchedule(dayNumber: 1, date: start, scheduleItems: [
            item(0, "羽田空港 出発", 35.549, 139.779, cost: 18000, location: "羽田空港"),
            item(3, "那覇空港 到着", 26.206, 127.646, location: "那覇空港"),
            item(4, "沖縄そばでお昼", 26.214, 127.679, cost: 1200, notes: "ソーキそばを食べる"),
            item(5, "首里城", 26.217, 127.719, cost: 400, location: "首里城公園"),
            item(7, "国際通りで買い物", 26.215, 127.689, cost: 3000),
            item(8, "ホテルにチェックイン", 26.212, 127.680, cost: 12000, notes: "駐車場あり。フロントは24時間"),
            item(9, "夕ごはん", 26.213, 127.684, cost: 4000),
            item(11, "夜の散歩"),
        ])
        let day2 = DaySchedule(dayNumber: 2, date: start.addingTimeInterval(86_400), scheduleItems: [
            item(25, "美ら海水族館", 26.694, 127.878, cost: 2180),
            item(29, "古宇利島", 26.705, 128.023),
        ])
        var plan = TravelPlan(title: "沖縄旅行", startDate: start, endDate: start.addingTimeInterval(86_400),
                              destination: "沖縄", daySchedules: [day1, day2],
                              packingItems: [
                                PackingItem(name: "充電器", kind: .packing, ownerId: "me"),
                                PackingItem(name: "日焼け止め", kind: .packing, ownerId: "me"),
                                PackingItem(name: "相手の持ち物", kind: .packing, ownerId: "friend"),
                                PackingItem(name: "ちんすこう", kind: .souvenir, note: "会社に"),
                                PackingItem(name: "サプライズのお土産", kind: .souvenir, ownerId: "me"),
                              ])
        plan.memos = [TripMemo(title: "集合", body: "羽田 第1ターミナル 6:30"),
                      TripMemo(title: "自分だけ", body: "見せないメモ", isPrivate: true)]
        return plan
    }

    @Test("表紙・日程（予定が多い日は分かれる）・持ち物・費用・メモの順に並ぶ")
    func pages() {
        let plan = Self.sampleTrip()
        let pages = TravelBooklet.pages(for: plan, options: .init(), userId: "me")
        #expect(pages.first == .cover)
        let days = pages.compactMap { page -> (Int, Bool, Bool)? in
            if case let .day(n, _, map, cont) = page { return (n, map, cont) }
            return nil
        }
        #expect(days.count == 3)            // 1日目は2ページに分かれる
        #expect(days[0] == (1, true, false))
        #expect(days[1] == (1, false, true)) // 2ページ目は地図なし
        #expect(days[2] == (2, true, false))
        #expect(pages.contains(.costs))
        #expect(pages.last == .memo(id: plan.memos[0].id))
        #expect(!pages.contains(.memo(id: plan.memos[1].id)))  // 自分だけのメモは入らない
    }

    @Test("持ち物は自分のものだけ、お土産は「みんなに見せる」品だけ")
    func privacy() {
        let plan = Self.sampleTrip()
        #expect(TravelBooklet.packingItems(of: plan, userId: "me").map(\.name) == ["充電器", "日焼け止め"])
        #expect(TravelBooklet.souvenirItems(of: plan).map(\.name) == ["ちんすこう"])
    }

    @Test("外したものは入らない。何も無ければ0ページ")
    func options() {
        let plan = Self.sampleTrip()
        var options = TravelBooklet.Options()
        options.includesMaps = false
        options.includesCosts = false
        options.includesMemos = false
        let pages = TravelBooklet.pages(for: plan, options: options, userId: "me")
        #expect(!pages.contains(.costs))
        #expect(pages.allSatisfy { if case let .day(_, _, map, _) = $0 { return !map } else { return true } })

        let empty = TravelPlan(title: "空", startDate: start, endDate: start, destination: "")
        var none = TravelBooklet.Options()
        none.includesCover = false
        #expect(TravelBooklet.pages(for: empty, options: none, userId: "me").isEmpty)
    }

    @Test("ファイル名に使えない文字を置き換える")
    func fileName() {
        var plan = Self.sampleTrip()
        plan.title = "大阪/京都 2泊"
        #expect(TravelBooklet.fileName(for: plan) == "大阪-京都 2泊のしおり.pdf")
    }

    @Test("3つのデザインで PDF が作れ、ページ数が合う", arguments: TravelBooklet.Style.allCases)
    func render(style: TravelBooklet.Style) async throws {
        let plan = Self.sampleTrip()
        let output = try await TravelBookletRenderer.render(plan: plan, options: .init(), style: style,
                                                            theme: ThemePreset(type: .originalColor), userId: "me")
        let document = try #require(PDFDocument(url: output.url))
        #expect(document.pageCount == output.pageCount)
        #expect(document.page(at: 0)?.string?.contains("沖縄旅行") == true)
        // 見た目を確かめるために控えを残す
        let keep = FileManager.default.temporaryDirectory.appendingPathComponent("booklet-\(style.rawValue).pdf")
        try? FileManager.default.removeItem(at: keep)
        try FileManager.default.copyItem(at: output.url, to: keep)
        print("BOOKLET \(keep.path)")
    }
}
