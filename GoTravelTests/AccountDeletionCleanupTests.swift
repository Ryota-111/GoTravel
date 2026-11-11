import Testing
import Foundation
@testable import GoTravel

/// 退会のときに、パブリックDBの共有レコードをどう片付けるかの振り分け。
///
/// ここを誤ると、他の人の旅行計画を消したり、自分の計画が共有コードで読めるまま残ったりする
struct AccountDeletionCleanupTests {

    private func plan(_ id: String, shared: Bool, ownerId: String?) -> TravelPlan {
        TravelPlan(id: id, title: id, startDate: Date(), endDate: Date(), destination: "",
                   userId: "me", isShared: shared, ownerId: ownerId)
    }

    @Test("自分が持ち主の共有は消す側、参加していた共有は外す側に入る")
    func sortsOwnedAndJoined() {
        let records = AccountDeletionCleanup.sharedRecords(
            travelPlans: [plan("mine", shared: true, ownerId: "me"),
                          plan("theirs", shared: true, ownerId: "friend")],
            categories: [PlanCategory(id: "c-mine", name: "家族", isShared: true, ownerId: "me"),
                         PlanCategory(id: "c-theirs", name: "友達", isShared: true, ownerId: "friend")],
            userId: "me")

        #expect(records.ownedTravelPlanIds == ["mine"])
        #expect(records.joinedTravelPlanIds == ["theirs"])
        #expect(records.ownedCategoryIds == ["c-mine"])
        #expect(records.joinedCategoryIds == ["c-theirs"])
        #expect(records.userId == "me")
    }

    @Test("共有していないものは入らない（一度共有してやめた計画に ownerId が残っていても）")
    func skipsUnshared() {
        let records = AccountDeletionCleanup.sharedRecords(
            travelPlans: [plan("private", shared: false, ownerId: nil),
                          plan("stopped", shared: false, ownerId: "me")],
            categories: [PlanCategory(id: "c", name: "自分の")],
            userId: "me")

        #expect(records.isEmpty)
    }

    @Test("持ち主の分からない共有は、消す側に入れない（外す側で、持ち主を確かめてから扱う）")
    func unknownOwnerIsNotDeleted() {
        let records = AccountDeletionCleanup.sharedRecords(
            travelPlans: [plan("legacy", shared: true, ownerId: nil)],
            categories: [PlanCategory(id: "c-legacy", name: "古い共有", isShared: true)],
            userId: "me")

        #expect(records.ownedTravelPlanIds.isEmpty)
        #expect(records.joinedTravelPlanIds == ["legacy"])
        #expect(records.ownedCategoryIds.isEmpty)
        #expect(records.joinedCategoryIds == ["c-legacy"])
    }

    @Test("次の起動で続きができるように、そのまま保存して読み戻せる")
    func roundTrips() throws {
        var records = AccountDeletionCleanup.SharedRecords(userId: "me")
        records.ownedTravelPlanIds = ["a"]
        records.joinedCategoryIds = ["b"]
        records.attempts = 2

        let data = try JSONEncoder().encode(records)
        #expect(try JSONDecoder().decode(AccountDeletionCleanup.SharedRecords.self, from: data) == records)
    }
}
