import Testing
import Foundation
import CloudKit
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

    private func records(_ userId: String, owned: [String] = [], joined: [String] = [], attempts: Int = 0)
        -> AccountDeletionCleanup.SharedRecords {
        var records = AccountDeletionCleanup.SharedRecords(userId: userId)
        records.ownedTravelPlanIds = owned
        records.joinedTravelPlanIds = joined
        records.attempts = attempts
        return records
    }

    @Test("前の退会の分が残っているところへ足しても、前の分を消さない")
    func mergeKeepsEarlierRecords() {
        let pending = [records("me", owned: ["a"], attempts: 3)]

        let sameUser = AccountDeletionCleanup.merged(pending, adding: records("me", owned: ["a", "b"], joined: ["c"]))
        #expect(sameUser == [records("me", owned: ["a", "b"], joined: ["c"])])

        let otherUser = AccountDeletionCleanup.merged(pending, adding: records("you", owned: ["x"]))
        #expect(otherUser == [records("me", owned: ["a"], attempts: 3), records("you", owned: ["x"])])
    }

    @Test("片付いたものだけを控えから外す。片付けている間に足された分は残す")
    func settleRemovesOnlyFinished() {
        let tried = records("me", owned: ["a", "b"])
        // 片付けている間に "c" が足された
        let pending = [records("me", owned: ["a", "b", "c"]), records("you", owned: ["x"])]

        let after = AccountDeletionCleanup.settled(pending, tried: tried, remaining: records("me", owned: ["b"]),
                                                   countsAsAttempt: false)
        #expect(after == [records("me", owned: ["b", "c"]), records("you", owned: ["x"])])

        let done = AccountDeletionCleanup.settled([tried], tried: tried, remaining: records("me"), countsAsAttempt: false)
        #expect(done.isEmpty)
    }

    @Test("通信できなかっただけの回は数えない。それ以外の失敗は5回で諦める")
    func attemptsCountOnlyRealFailures() {
        let tried = records("me", owned: ["a"], attempts: AccountDeletionCleanup.maxAttempts - 1)

        let offline = AccountDeletionCleanup.settled([tried], tried: tried, remaining: tried, countsAsAttempt: false)
        #expect(offline == [tried])

        let refused = AccountDeletionCleanup.settled([tried], tried: tried, remaining: tried, countsAsAttempt: true)
        #expect(refused.isEmpty)

        #expect(AccountDeletionCleanup.isTemporary(URLError(.notConnectedToInternet)))
        #expect(AccountDeletionCleanup.isTemporary(CKError(.networkUnavailable)))
        #expect(!AccountDeletionCleanup.isTemporary(CKError(.permissionFailure)))
    }
}
