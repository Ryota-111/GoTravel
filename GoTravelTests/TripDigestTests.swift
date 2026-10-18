import Testing
import AVFoundation
import UIKit
@testable import GoTravel

/// 旅のダイジェスト動画（Travory Pro）。どれを選ぶか・何と書くか、つないだ動画の長さ
@MainActor
struct TripDigestTests {

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .current
        return c
    }

    /// 1日目の朝9時を起点にした、その日の時刻
    private func at(_ plan: TravelPlan, day: Int, hour: Int, minute: Int = 0) -> Date {
        let start = calendar.startOfDay(for: plan.date(forDay: day))
        return calendar.date(byAdding: .minute, value: hour * 60 + minute, to: start)!
    }

    @Test("1時間に1つ選び、動画があれば動画を、同じ種類なら先に撮ったほうを選ぶ")
    func hourly() {
        let plan = TravelBookletTests.sampleTrip()
        let sources = [
            TripDigest.Source(id: "p1", date: at(plan, day: 1, hour: 10, minute: 5), isVideo: false, duration: 0),
            TripDigest.Source(id: "v1", date: at(plan, day: 1, hour: 10, minute: 40), isVideo: true, duration: 6),
            TripDigest.Source(id: "p2", date: at(plan, day: 1, hour: 12, minute: 30), isVideo: false, duration: 0),
            TripDigest.Source(id: "p3", date: at(plan, day: 1, hour: 12, minute: 10), isVideo: false, duration: 0),
            TripDigest.Source(id: "d2", date: at(plan, day: 2, hour: 9), isVideo: false, duration: 0),
        ]
        let day1 = TripDigest.clips(plan: plan, sources: sources, scope: .day(1), calendar: calendar)
        #expect(day1.map(\.sourceId) == ["v1", "p3"])
        #expect(day1.first?.timeText == "10:00")  // 1時間刻み
        let trip = TripDigest.clips(plan: plan, sources: sources, scope: .trip, calendar: calendar)
        #expect(trip.map(\.sourceId) == ["v1", "p3", "d2"])
        #expect(trip.last?.dayNumber == 2)
        #expect(TripDigest.duration(of: trip) == 6)
    }

    @Test("自分で選び直した写真は、その時間のコマに必ず使う")
    func pinned() {
        let plan = TravelBookletTests.sampleTrip()
        let sources = [
            TripDigest.Source(id: "video", date: at(plan, day: 1, hour: 10, minute: 5), isVideo: true, duration: 5),
            TripDigest.Source(id: "photo", date: at(plan, day: 1, hour: 10, minute: 50), isVideo: false, duration: 0),
        ]
        #expect(TripDigest.clips(plan: plan, sources: sources, scope: .day(1), calendar: calendar).map(\.sourceId) == ["video"])
        #expect(TripDigest.clips(plan: plan, sources: sources, scope: .day(1), pinned: ["photo"], calendar: calendar)
            .map(\.sourceId) == ["photo"])
    }

    @Test("自分で入れた文字は場所の名前の代わりに出し、空なら文字を出さない")
    func captions() {
        let plan = TravelBookletTests.sampleTrip()
        let nearShuri = TripDigest.Source(id: "a", date: at(plan, day: 1, hour: 14), isVideo: false, duration: 0,
                                          latitude: 26.2175, longitude: 127.7195)
        let original = TripDigest.clips(plan: plan, sources: [nearShuri], scope: .day(1), calendar: calendar)
        #expect(original.first?.placeName != nil)
        let custom = TripDigest.clips(plan: plan, sources: [nearShuri], scope: .day(1),
                                      captions: ["a": " みんなで乾杯 "], calendar: calendar)
        #expect(custom.first?.placeName == "みんなで乾杯")
        let hidden = TripDigest.clips(plan: plan, sources: [nearShuri], scope: .day(1),
                                      captions: ["a": ""], calendar: calendar)
        #expect(hidden.first?.placeName == nil)
    }

    @Test("多すぎるときは、1日の中でまんべんなく間引く")
    func thinning() {
        let plan = TravelBookletTests.sampleTrip()
        let sources = (0..<24).map { TripDigest.Source(id: "h\($0)", date: at(plan, day: 1, hour: $0), isVideo: false, duration: 0) }
        let day = TripDigest.clips(plan: plan, sources: sources, scope: .day(1), calendar: calendar)
        #expect(day.count == TripDigest.maxClipsPerDay)
        #expect(day.first?.sourceId == "h0")
        let trip = TripDigest.clips(plan: plan, sources: sources, scope: .trip, calendar: calendar)
        #expect(trip.count == TripDigest.maxClipsPerDayInTrip)
    }

    @Test("撮った場所が日程の予定から 800m 以内なら、予定の名前を入れる")
    func placeNames() {
        let plan = TravelBookletTests.sampleTrip()
        let nearShuri = TripDigest.Source(id: "a", date: at(plan, day: 1, hour: 14), isVideo: false, duration: 0,
                                          latitude: 26.2175, longitude: 127.7195)
        let far = TripDigest.Source(id: "b", date: at(plan, day: 1, hour: 15), isVideo: false, duration: 0,
                                    latitude: 26.30, longitude: 127.80)
        let noLocation = TripDigest.Source(id: "c", date: at(plan, day: 1, hour: 16), isVideo: false, duration: 0)
        #expect(TripDigest.placeName(near: nearShuri, plan: plan, dayNumber: 1) == "首里城")
        #expect(TripDigest.placeName(near: far, plan: plan, dayNumber: 1) == nil)
        #expect(TripDigest.placeName(near: noLocation, plan: plan, dayNumber: 1) == nil)
    }

    @Test("足した写真は、1時間に1つの決まりや上限に関係なく、決めた時刻に入る。旅行全体にも入る")
    func added() {
        let plan = TravelBookletTests.sampleTrip()
        let sources = [
            TripDigest.Source(id: "p1", date: at(plan, day: 1, hour: 10), isVideo: false, duration: 0),
            TripDigest.Source(id: "p2", date: at(plan, day: 1, hour: 10, minute: 30), isVideo: false, duration: 0),
        ]
        // 同じ10時に、旅行の外で保存した写真を足す（p2 も時刻を変えて足したもの）
        let added = [
            TripDigest.Added(sourceId: "line", date: at(plan, day: 1, hour: 10, minute: 0).addingTimeInterval(1)),
            TripDigest.Added(sourceId: "p2", date: at(plan, day: 1, hour: 15)),
        ]
        let day = TripDigest.clips(plan: plan, sources: sources, scope: .day(1), added: added, calendar: calendar)
        #expect(day.map(\.sourceId) == ["p1", "line", "p2"])
        #expect(day.map(\.isAdded) == [false, true, true])
        #expect(day.last?.timeText == "15:00")
        let trip = TripDigest.clips(plan: plan, sources: sources, scope: .trip, added: added, calendar: calendar)
        #expect(trip.map(\.sourceId) == ["p1", "line", "p2"])
    }

    @Test("外した時間は、同じ時間の別の写真が代わりに入らず、まるごと無くなる。足した写真は入る")
    func excludedHours() {
        let plan = TravelBookletTests.sampleTrip()
        let sources = [
            TripDigest.Source(id: "a", date: at(plan, day: 1, hour: 10), isVideo: false, duration: 0),
            TripDigest.Source(id: "b", date: at(plan, day: 1, hour: 10, minute: 40), isVideo: false, duration: 0),
            TripDigest.Source(id: "c", date: at(plan, day: 1, hour: 11), isVideo: false, duration: 0),
        ]
        let key = TripDigest.hourKey(at(plan, day: 1, hour: 10, minute: 15), calendar: calendar)
        #expect(TripDigest.hourKey(at(plan, day: 1, hour: 10), calendar: calendar) == key)
        let clips = TripDigest.clips(plan: plan, sources: sources, scope: .day(1), excludedHours: [key], calendar: calendar)
        #expect(clips.map(\.sourceId) == ["c"])
        let withAdded = TripDigest.clips(plan: plan, sources: sources, scope: .day(1),
                                         added: [TripDigest.Added(sourceId: "x", date: at(plan, day: 1, hour: 10, minute: 5))],
                                         excludedHours: [key], calendar: calendar)
        #expect(withAdded.map(\.sourceId) == ["x", "c"])
    }

    @Test("足した写真の時刻：撮った日時がその日なら、その時刻。違えば近くの予定の時刻。どちらも無ければ決めない")
    func addedDate() {
        let plan = TravelBookletTests.sampleTrip()
        let sameDay = TripDigest.Source(id: "a", date: at(plan, day: 1, hour: 13, minute: 20), isVideo: false, duration: 0)
        #expect(TripDigest.addedDate(for: sameDay, plan: plan, dayNumber: 1, calendar: calendar) == sameDay.date)

        // 保存した日（旅行のあと）になっているが、首里城の近くで撮った写真
        let later = Date(timeIntervalSince1970: 1_800_000_000)
        let nearShuri = TripDigest.Source(id: "b", date: later, isVideo: false, duration: 0,
                                          latitude: 26.2175, longitude: 127.7195)
        let shuri = plan.daySchedules[0].scheduleItems.first { $0.title == "首里城" }!
        let expected = calendar.date(bySettingHour: calendar.component(.hour, from: shuri.time),
                                     minute: calendar.component(.minute, from: shuri.time), second: 0,
                                     of: calendar.startOfDay(for: plan.date(forDay: 1)))
        #expect(TripDigest.addedDate(for: nearShuri, plan: plan, dayNumber: 1, calendar: calendar) == expected)

        let unknown = TripDigest.Source(id: "c", date: later, isVideo: false, duration: 0)
        #expect(TripDigest.addedDate(for: unknown, plan: plan, dayNumber: 1, calendar: calendar) == nil)
    }

    @Test("写真を2秒ずつつないで、縦長の動画ができる")
    func compose() async throws {
        let colors: [UIColor] = [.systemTeal, .systemOrange, .systemPink]
        let images = colors.map { color in
            UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 900)).image { ctx in
                color.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 1200, height: 900))
                UIColor.white.setFill(); ctx.fill(CGRect(x: 500, y: 350, width: 200, height: 200))
            }
        }
        let items = images.enumerated().map { index, image in
            TripDigestComposer.Item(media: .image(image),
                                    clip: TripDigest.Clip(sourceId: "\(index)", dayNumber: 1, date: Date(),
                                                          timeText: "1\(index):00", placeName: index == 1 ? "首里城" : nil))
        }
        let url = try await TripDigestComposer.compose(items, title: "沖縄旅行", subtitle: "Day 1・9月21日(月)",
                                                       fileName: "digest-test.mp4")
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        #expect(abs(duration - 6) < 0.2)
        // 無料のときは、最後に1秒の印が入る
        let withMark = try await TripDigestComposer.compose(items, title: "沖縄旅行", subtitle: "Day 1",
                                                            fileName: "digest-test-mark.mp4", endCard: true)
        #expect(abs(try await AVURLAsset(url: withMark).load(.duration).seconds - 7) < 0.2)
        let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
        let size = try await track.load(.naturalSize)
        #expect(size == TripDigestComposer.renderSize)
        // 見た目を確かめるために、最初と2つ目のコマを画像にして残す
        let generator = AVAssetImageGenerator(asset: asset)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        for second in [1.0, 3.0] {
            let (image, _) = try await generator.image(at: CMTime(seconds: second, preferredTimescale: 600))
            let out = FileManager.default.temporaryDirectory.appendingPathComponent("digest-\(Int(second)).png")
            try UIImage(cgImage: image).pngData()?.write(to: out)
            print("DIGEST \(out.path)")
        }
    }

    @Test("文字は左下・真ん中・右上に置け、長い場所の名前も省略しない", arguments: TripDigestComposer.TextPosition.allCases)
    func overlayPositions(position: TripDigestComposer.TextPosition) throws {
        let clip = TripDigest.Clip(sourceId: "a", dayNumber: 2, date: Date(), timeText: "14:05",
                                   placeName: "沖縄美ら海水族館 黒潮の海 大水槽の前のカフェ")  // 長くても1行に収める
        let overlay = try #require(TripDigestComposer.overlayImage(for: clip, title: "沖縄旅行", subtitle: "Day 2・9月22日(火)",
                                                                   position: position))
        #expect(overlay.extent.size == TripDigestComposer.renderSize)
        // 見た目を確かめるために、色の上に重ねた画像を残す
        let base = CIImage(color: CIColor(red: 0.3, green: 0.6, blue: 0.7)).cropped(to: overlay.extent)
        let context = CIContext()
        let cg = try #require(context.createCGImage(overlay.composited(over: base), from: overlay.extent))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("overlay-\(position.rawValue).png")
        try UIImage(cgImage: cg).pngData()?.write(to: url)
        print("OVERLAY \(url.path)")
    }
}

/// 作った動画を残しておく（旅行と範囲ごとに最新の1本）
struct TripDigestLibraryTests {
    @Test("同じ旅行・同じ範囲で作り直すと置き換わり、新しい順に並ぶ")
    func saveAndReplace() throws {
        let planId = "test-\(UUID().uuidString)"
        func temp(_ text: String) throws -> URL {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mp4")
            try Data(text.utf8).write(to: url)
            return url
        }
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        try TripDigestLibrary.save(try temp("1"), planId: planId, scopeId: "trip", title: "旅行全体", now: now)
        try TripDigestLibrary.save(try temp("2"), planId: planId, scopeId: "day1", title: "Day 1", now: now.addingTimeInterval(10))
        try TripDigestLibrary.save(try temp("3"), planId: planId, scopeId: "trip", title: "旅行全体", now: now.addingTimeInterval(20))
        let entries = TripDigestLibrary.entries(planId: planId)
        #expect(entries.map(\.scopeId) == ["trip", "day1"])
        let trip = try #require(TripDigestLibrary.entry(planId: planId, scopeId: "trip"))
        #expect(try String(contentsOf: TripDigestLibrary.url(of: trip), encoding: .utf8) == "3")
        for entry in entries { TripDigestLibrary.remove(entry) }
        #expect(TripDigestLibrary.entries(planId: planId).isEmpty)
    }
}
