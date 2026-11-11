import Testing
import Foundation
@testable import GoTravel

/// スクリーンショットから場所を読むお試し（3.5）
struct PlaceScreenshotTrialTests {

    @Test("最初の3回だけ使えて、それ以降は数が増えない")
    func usesUpThreeTimes() throws {
        let name = "PlaceScreenshotTrialTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }

        #expect(PlaceScreenshotTrial.remaining(in: defaults) == 3)
        #expect(PlaceScreenshotTrial.consume(in: defaults))
        #expect(PlaceScreenshotTrial.consume(in: defaults))
        #expect(PlaceScreenshotTrial.remaining(in: defaults) == 1)
        #expect(PlaceScreenshotTrial.consume(in: defaults))
        #expect(PlaceScreenshotTrial.remaining(in: defaults) == 0)
        #expect(!PlaceScreenshotTrial.consume(in: defaults))
        #expect(defaults.integer(forKey: PlaceScreenshotTrial.storageKey) == 3)
    }

    @Test("同じ共有のスクリーンショットを開き直しても、お試しの回数は減らない")
    func sameItemOnce() throws {
        let name = "PlaceScreenshotTrialTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }

        #expect(PlaceScreenshotTrial.consume(item: "a.jpg", in: defaults))
        #expect(PlaceScreenshotTrial.consume(item: "a.jpg", in: defaults))
        #expect(PlaceScreenshotTrial.remaining(in: defaults) == 2)
        #expect(PlaceScreenshotTrial.consume(item: "b.jpg", in: defaults))
        #expect(PlaceScreenshotTrial.consume(in: defaults))
        #expect(PlaceScreenshotTrial.remaining(in: defaults) == 0)
        // 使い切っても、前に読んだものはまた読める
        #expect(PlaceScreenshotTrial.consume(item: "a.jpg", in: defaults))
        #expect(!PlaceScreenshotTrial.consume(item: "c.jpg", in: defaults))
    }
}
