import Testing
import Foundation
@testable import GoTravel

/// 評価を頼む場面（3.8）：フォトマップの写真が3枚になったとき、旅行が終わった次の日だけ
struct ReviewTimingTests {

    private let calendar = Calendar.current

    private func day(_ offset: Int, from base: Date) -> Date {
        calendar.date(byAdding: .day, value: offset, to: base)!
    }

    @Test("フォトマップは3枚から")
    func photoMapCount() {
        #expect(!ReviewRequestManager.reachedPhotoMapCount(2))
        #expect(ReviewRequestManager.reachedPhotoMapCount(3))
    }

    @Test("昨日終わった旅行だけ。今日終わる・一昨日終わった・もう頼んだ旅行は除く")
    func dayAfterTrip() {
        let now = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!
        var ended = TravelPlan(title: "沖縄", startDate: day(-4, from: now), endDate: day(-1, from: now), destination: "沖縄")
        ended.id = "ended"
        var today = TravelPlan(title: "京都", startDate: day(-2, from: now), endDate: now, destination: "京都")
        today.id = "today"
        var older = TravelPlan(title: "札幌", startDate: day(-5, from: now), endDate: day(-2, from: now), destination: "札幌")
        older.id = "older"

        #expect(ReviewRequestManager.tripEndedYesterday([today, older, ended], now: now, excluding: [])?.id == "ended")
        #expect(ReviewRequestManager.tripEndedYesterday([today, older, ended], now: now, excluding: ["ended"]) == nil)
    }
}
