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
        #expect(day1.first?.timeText == "10:40")
        let trip = TripDigest.clips(plan: plan, sources: sources, scope: .trip, calendar: calendar)
        #expect(trip.map(\.sourceId) == ["v1", "p3", "d2"])
        #expect(trip.last?.dayNumber == 2)
        #expect(TripDigest.duration(of: trip) == 6)
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
}
