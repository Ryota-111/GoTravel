import Testing
import Foundation
@testable import GoTravel

/// 共有された旅行計画の突き合わせ。
///
/// **ここが壊れると、同行者の編集で自分の入力が消える。**
/// 実機2台と iCloud アカウントが無いと確かめられなかった判断を、
/// 純粋関数に切り出したことで手元だけで検証できるようにしている。
struct SharedPlanMergeTests {

    // MARK: - 下ごしらえ

    /// 基準の時刻。テストの中で「10秒後」のように相対で使う
    private static let base = Date(timeIntervalSince1970: 1_700_000_000)

    private func t(_ seconds: TimeInterval) -> Date {
        Self.base.addingTimeInterval(seconds)
    }

    private func makePlan(id: String = "plan-1",
                          title: String = "沖縄旅行",
                          userId: String? = "owner",
                          ownerId: String? = "owner",
                          updatedAt: Date,
                          packingItems: [PackingItem] = []) -> TravelPlan {
        TravelPlan(
            id: id,
            title: title,
            startDate: Self.base,
            endDate: Self.base.addingTimeInterval(86_400),
            destination: "沖縄",
            userId: userId,
            packingItems: packingItems,
            isShared: true,
            shareCode: "TRAVEL-TESTCODE",
            sharedWith: ["owner", "me"],
            ownerId: ownerId,
            updatedAt: updatedAt
        )
    }

    // MARK: - どちらを採るか

    @Test("手元に無い共有計画は取り込む")
    func takesRemoteWhenLocalIsMissing() {
        let remote = makePlan(updatedAt: t(0))

        let decision = SharedPlanMerge.decide(local: nil, remote: remote, myUserId: "me")

        #expect(decision.takenPlan != nil)
    }

    @Test("相手のほうが新しければ取り込む")
    func takesRemoteWhenNewer() {
        let local = makePlan(updatedAt: t(0))
        let remote = makePlan(title: "沖縄旅行（改）", updatedAt: t(10))

        let decision = SharedPlanMerge.decide(local: local, remote: remote, myUserId: "me")

        #expect(decision.takenPlan?.title == "沖縄旅行（改）")
    }

    @Test("手元のほうが新しければ相手へ送る")
    func pushesLocalWhenNewer() {
        let local = makePlan(title: "手元の変更", updatedAt: t(10))
        let remote = makePlan(updatedAt: t(0))

        let decision = SharedPlanMerge.decide(local: local, remote: remote, myUserId: "me")

        #expect(decision.pushedPlan?.title == "手元の変更")
    }

    /// 開いて閉じただけで更新時刻が進んでいた頃、ここが常に「送る」に倒れ、
    /// 相手の編集を古い内容で上書きしていた
    @Test("更新時刻が同じなら何もしない")
    func doesNothingWhenSameTimestamp() {
        let local = makePlan(updatedAt: t(5))
        let remote = makePlan(updatedAt: t(5))

        let decision = SharedPlanMerge.decide(local: local, remote: remote, myUserId: "me")

        #expect(decision.isDoNothing)
    }

    // MARK: - 取り込んだときに何が残るか

    /// 持ち物とお土産は各自のもので、パブリックDBには載せていない。
    /// 降りてきた内容でそのまま置き換えると、自分の持ち物が毎回消える
    @Test("自分だけの持ち物は、取り込みで消えない")
    func keepsMyPersonalItems() {
        let local = makePlan(updatedAt: t(0), packingItems: [
            PackingItem(name: "充電器", kind: .packing, ownerId: "me"),
            PackingItem(name: "温泉に入る", kind: .wish, ownerId: nil)
        ])
        let remote = makePlan(updatedAt: t(10), packingItems: [
            PackingItem(name: "温泉に入る", kind: .wish, ownerId: nil),
            PackingItem(name: "名物を食べる", kind: .wish, ownerId: nil)
        ])

        let merged = try! #require(
            SharedPlanMerge.decide(local: local, remote: remote, myUserId: "me").takenPlan
        )

        #expect(merged.packingItems.contains { $0.name == "充電器" })
        #expect(merged.packingItems.contains { $0.name == "名物を食べる" })
    }

    /// 同行者の持ち物が降りてくることはない想定だが、
    /// 万一載っていても自分の一覧には混ぜない
    @Test("他人の持ち物は取り込まない")
    func doesNotAdoptOtherMembersItems() {
        let local = makePlan(updatedAt: t(0))
        let remote = makePlan(updatedAt: t(10), packingItems: [
            PackingItem(name: "相手の歯ブラシ", kind: .packing, ownerId: "owner")
        ])

        let merged = try! #require(
            SharedPlanMerge.decide(local: local, remote: remote, myUserId: "me").takenPlan
        )

        #expect(merged.packingItems.isEmpty)
    }

    /// 手元の行は端末ユーザーの userId で持つ。
    /// ここが相手のIDのままだと、取り込めているのに一覧へ出てこない
    @Test("取り込んだ計画は自分の userId になる")
    func adoptsLocalUserId() {
        let remote = makePlan(userId: "owner", updatedAt: t(0))

        let merged = try! #require(
            SharedPlanMerge.decide(local: nil, remote: remote, myUserId: "me").takenPlan
        )

        #expect(merged.userId == "me")
    }

    /// userId を付け替えても、本当の持ち主は変わってはいけない。
    /// ここが崩れると共有の停止や削除の権限がおかしくなる
    @Test("取り込んでも ownerId は持ち主のまま")
    func keepsOriginalOwner() {
        let remote = makePlan(userId: "owner", ownerId: "owner", updatedAt: t(0))

        let merged = try! #require(
            SharedPlanMerge.decide(local: nil, remote: remote, myUserId: "me").takenPlan
        )

        #expect(merged.ownerId == "owner")
    }

    @Test("共有コードと参加メンバーは取り込みで失われない")
    func keepsSharingInfo() {
        let remote = makePlan(updatedAt: t(0))

        let merged = try! #require(
            SharedPlanMerge.decide(local: nil, remote: remote, myUserId: "me").takenPlan
        )

        #expect(merged.isShared)
        #expect(merged.shareCode == "TRAVEL-TESTCODE")
        #expect(merged.sharedWith.contains("me"))
    }

    // MARK: - 繰り返しても落ち着くか

    /// 同じ結果を2回通しても答えが変わらないこと。
    /// ここが崩れると、引っぱるたびに取り込みと送信を往復して終わらない
    @Test("取り込んだ直後にもう一度突き合わせると、何もしない")
    func settlesAfterOnePass() {
        let local = makePlan(updatedAt: t(0))
        let remote = makePlan(title: "相手の変更", updatedAt: t(10))

        let merged = try! #require(
            SharedPlanMerge.decide(local: local, remote: remote, myUserId: "me").takenPlan
        )
        let second = SharedPlanMerge.decide(local: merged, remote: remote, myUserId: "me")

        #expect(second.isDoNothing)
    }
}
