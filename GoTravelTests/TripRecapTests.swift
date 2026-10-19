import Testing
import SwiftUI
@testable import GoTravel

/// 旅が終わったあとの案内（Travory Pro）。案内を出す時期
@MainActor
struct TripRecapTests {

    @Test("終わってから7日以内で、閉じていない、いちばん最近の旅行を案内する")
    func prompt() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        func trip(_ id: String, endedDaysAgo: Int) -> TravelPlan {
            var plan = TravelBookletTests.sampleTrip(start: now.addingTimeInterval(Double(-endedDaysAgo - 1) * 86_400))
            plan.id = id
            plan.endDate = now.addingTimeInterval(Double(-endedDaysAgo) * 86_400)
            return plan
        }
        let plans = [trip("old", endedDaysAgo: 10), trip("recent", endedDaysAgo: 1), trip("older", endedDaysAgo: 3),
                     trip("today", endedDaysAgo: 0)]
        #expect(TripRecapPrompt.plan(in: plans, dismissed: [], now: now, calendar: calendar)?.id == "recent")
        #expect(TripRecapPrompt.plan(in: plans, dismissed: ["recent"], now: now, calendar: calendar)?.id == "older")
        #expect(TripRecapPrompt.plan(in: plans, dismissed: ["recent", "older"], now: now, calendar: calendar) == nil)
    }
}
