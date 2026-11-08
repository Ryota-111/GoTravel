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
}
