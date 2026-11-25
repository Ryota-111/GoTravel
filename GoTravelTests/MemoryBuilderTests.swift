import Testing
import Foundation
@testable import GoTravel

/// 旅の思い出をつくる（3.8）：自動で作る中身
struct MemoryBuilderTests {

    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return c
    }()

    private func date(_ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0, year: Int = 2026) -> Date {
        calendar.date(from: DateComponents(year: year, month: m, day: d, hour: h, minute: min))!
    }

    @Test("期間・日数・緯度経度の書き方")
    func texts() {
        #expect(MemoryBuilder.dateRangeText(start: date(11, 15), end: date(11, 17), calendar: calendar) == "2026.11.15 – 11.17")
        #expect(MemoryBuilder.dateRangeText(start: date(12, 30), end: date(1, 2, year: 2027), calendar: calendar)
                == "2026.12.30 – 2027.01.02")
        #expect(MemoryBuilder.dateRangeText(start: date(11, 15), end: date(11, 15, 18), calendar: calendar) == "2026.11.15")
        #expect(MemoryBuilder.dayCountText(1) == "1 DAY")
        #expect(MemoryBuilder.dayCountText(3) == "3 DAYS")
        #expect(MemoryBuilder.coordinateText(latitude: 26.2124, longitude: 127.6792) == "26.2124° N  ·  127.6792° E")
        #expect(MemoryBuilder.coordinateText(latitude: -33.8688, longitude: -151.2093) == "33.8688° S  ·  151.2093° W")
        #expect(MemoryBuilder.coordinateText(latitude: nil, longitude: 1) == nil)
    }

    @Test("英語の地名の後ろの「Prefecture」などを外す")
    func cleanedPlaceName() {
        #expect(TripPhotoLibrary.cleaned("Okinawa Prefecture") == "Okinawa")
        #expect(TripPhotoLibrary.cleaned("Paris") == "Paris")
    }

    @Test("写真は時間の区切りごとに、いちばんきれいな1枚を選ぶ（撮った順のまま）")
    func bestSpread() {
        let candidates = (0..<8).map { TripPhotoCandidate(id: "p\($0)", date: date(11, 15, 9 + $0), isVideo: false,
                                                          score: [0.1, 0.9, 0.2, 0.3, 0.8, 0.1, 0.0, 0.5][$0]) }
        let picked = TripPhotoLibrary.best(candidates, count: 4)
        #expect(picked.map(\.id) == ["p1", "p3", "p4", "p7"])
        #expect(TripPhotoLibrary.best(candidates, count: 4, excluding: ["p1"]).first?.id == "p0")
    }

    @Test("日記は日ごとのページ。近い時刻の予定の名前を一言に入れる。写真の無い日は予定だけ")
    func diaryPages() {
        var plan = TravelPlan(title: "沖縄", startDate: date(11, 15, 0), endDate: date(11, 16, 0), destination: "沖縄")
        plan.daySchedules = [
            DaySchedule(dayNumber: 1, date: date(11, 15, 0), scheduleItems: [
                ScheduleItem(time: date(11, 15, 11, 30), title: "沖縄そば"),
                ScheduleItem(time: date(11, 15, 18, 0), title: "夕日")
            ]),
            DaySchedule(dayNumber: 2, date: date(11, 16, 0), scheduleItems: [
                ScheduleItem(time: date(11, 16, 10, 0), title: "水族館")
            ])
        ]
        let candidates = [
            TripPhotoCandidate(id: "a", date: date(11, 15, 11, 50), isVideo: false, score: 0.5),
            TripPhotoCandidate(id: "b", date: date(11, 15, 14, 0), isVideo: false, score: 0.5)
        ]
        let pages = MemoryBuilder.diaryPages(plan: plan, candidates: candidates, calendar: calendar)
        #expect(pages.count == 2)
        #expect(pages[0].entries.map(\.text) == ["沖縄そば", ""])   // 14:00 は予定から2時間以上離れている
        #expect(pages[0].entries.first?.photo?.assetId == "a")
        #expect(pages[1].entries.map(\.text) == ["水族館"])
        #expect(pages[1].entries.first?.photo == nil)
    }

    @Test("作ったものは保存して読み直せる")
    func storeRoundTrip() {
        var project = MemoryProject(planId: "test-\(UUID().uuidString)", kind: .poster, templateId: "poster.editorial", aspect: .feed)
        project.title = "Okinawa"
        project.photos = [MemoryPhoto(assetId: "x", offset: CGSize(width: 10, height: -4), scale: 1.5)]
        MemoryStore.save(project)
        let loaded = MemoryStore.load(planId: project.planId, kind: .poster)
        #expect(loaded?.title == "Okinawa")
        #expect(loaded?.photos.first?.scale == 1.5)
        MemoryStore.delete(planId: project.planId, kind: .poster)
        #expect(MemoryStore.load(planId: project.planId, kind: .poster) == nil)
    }
}
