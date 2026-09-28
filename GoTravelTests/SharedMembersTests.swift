import Testing
import Foundation
@testable import GoTravel

/// 共有した旅行の、メンバーの名前と「参加する人」。
///
/// ここを誤ると、自分の移動が自分の時間軸から消えたり、
/// あとから参加した人が集合の予定から漏れたりする
struct SharedMembersTests {

    private let members = ["owner", "me", "friend"]

    private func item(_ title: String, participants: [String]? = nil) -> ScheduleItem {
        ScheduleItem(time: Date(timeIntervalSince1970: 1_700_000_000), title: title, participantIds: participants)
    }

    // MARK: - 名前

    @Test("名前が付いていればそれを、無ければ「自分」「メンバー3」と出す")
    func displayNames() {
        let names = ["owner": "父"]

        #expect(SharedMembers.displayName(of: "owner", names: names, members: members, myUserId: "me") == "父")
        #expect(SharedMembers.displayName(of: "me", names: names, members: members, myUserId: "me") == "自分")
        #expect(SharedMembers.displayName(of: "friend", names: names, members: members, myUserId: "me") == "メンバー3")
    }

    @Test("空白だけの名前は、付いていない扱い")
    func blankNameFallsBack() {
        #expect(SharedMembers.displayName(of: "owner", names: ["owner": "  "], members: members, myUserId: "me") == "メンバー1")
    }

    // MARK: - 参加する人

    /// 全員を並べて持つと、あとから参加した人がその予定から漏れる
    @Test("誰も選ばない・全員を選んだなら、全員の予定（nil）として持つ")
    func normalizesEveryone() {
        #expect(SharedMembers.normalizedParticipants([], members: members) == nil)
        #expect(SharedMembers.normalizedParticipants(Set(members), members: members) == nil)
        #expect(SharedMembers.normalizedParticipants(["friend", "me"], members: members) == ["me", "friend"])
    }

    @Test("自分の時間軸には、全員の予定と自分の予定だけが出る")
    func memberTimeline() {
        var plan = TravelPlan(title: "沖縄", startDate: Date(timeIntervalSince1970: 1_700_000_000),
                              endDate: Date(timeIntervalSince1970: 1_700_086_400), destination: "沖縄")
        plan.daySchedules = [DaySchedule(dayNumber: 1, date: plan.startDate, scheduleItems: [
            item("羽田から出発", participants: ["me"]),
            item("伊丹から出発", participants: ["friend"]),
            item("那覇空港で集合")
        ])]

        #expect(Set(plan.timelineScheduleItems(onDay: 1, for: "me").map(\.title)) == ["那覇空港で集合", "羽田から出発"])
        #expect(plan.timelineScheduleItems(onDay: 1).count == 3)
    }

    @Test("全員のものでない予定にだけ、参加する人の名前を添える")
    func participantLabel() {
        let names = ["owner": "父", "friend": "さくら"]

        #expect(SharedMembers.participantLabel(of: item("集合"), names: names, members: members, myUserId: "me") == nil)
        #expect(SharedMembers.participantLabel(of: item("移動", participants: ["friend", "owner"]),
                                               names: names, members: members, myUserId: "me") == "さくら・父")
    }
}
