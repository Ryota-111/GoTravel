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

        // 共有ぶんに違いが無いので、取り込むものも送るものも無い
        let decision = SharedPlanMerge.decide(local: local, remote: remote, myUserId: "me")

        #expect(decision.takenPlan?.packingItems.isEmpty ?? true)
        #expect(decision.pushedPlan == nil)
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

    // MARK: - 同時に編集したとき
    //
    // ここが共有でいちばん怖いところ。
    // 計画まるごとを更新時刻で比べて置き換えていると、
    // 別々の場所を触っただけで片方の編集が黙って消える。

    private func makeItem(id: String, title: String, hour: Int) -> ScheduleItem {
        ScheduleItem(id: id,
                     time: Self.base.addingTimeInterval(TimeInterval(hour * 3600)),
                     title: title)
    }

    private func makeDay(_ items: [ScheduleItem]) -> DaySchedule {
        DaySchedule(dayNumber: 1, date: Self.base, scheduleItems: items)
    }

    @Test("相手が足した予定と、自分が足した予定の両方が残る")
    func keepsBothAddedScheduleItems() {
        // 前回そろえたときは「朝ごはん」だけだった
        let original = makeItem(id: "item-A", title: "朝ごはん", hour: 8)
        var base = makePlan(updatedAt: t(0))
        base.daySchedules = [makeDay([original])]

        // 自分は「水族館」を足した
        var local = makePlan(updatedAt: t(5))
        local.daySchedules = [makeDay([original, makeItem(id: "item-B", title: "水族館", hour: 10)])]

        // 相手は「夕食」を足して、先に公開した
        var remote = makePlan(updatedAt: t(10))
        remote.daySchedules = [makeDay([original, makeItem(id: "item-C", title: "夕食", hour: 18)])]

        let merged = try! #require(
            SharedPlanMerge.decide(local: local, remote: remote, base: base, myUserId: "me").takenPlan
        )
        let titles = merged.daySchedules.flatMap { $0.scheduleItems }.map(\.title)

        #expect(titles.contains("夕食"))      // 相手のぶん
        #expect(titles.contains("水族館"))    // 自分のぶん（いまは消える）
    }

    @Test("相手が足した予約と、自分が足した予約の両方が残る")
    func keepsBothAddedReservations() {
        let base = makePlan(updatedAt: t(0))   // 前回はどちらも空だった

        var local = makePlan(updatedAt: t(5))
        local.reservations = [Reservation(id: "res-A", kind: .hotel, title: "〇〇ホテル")]

        var remote = makePlan(updatedAt: t(10))
        remote.reservations = [Reservation(id: "res-B", kind: .flight, title: "ANA123")]

        let merged = try! #require(
            SharedPlanMerge.decide(local: local, remote: remote, base: base, myUserId: "me").takenPlan
        )
        let titles = merged.reservations.map(\.title)

        #expect(titles.contains("ANA123"))      // 相手のぶん
        #expect(titles.contains("〇〇ホテル"))  // 自分のぶん（いまは消える）
    }

    @Test("相手が消した予定は、取り込んでも復活しない")
    func doesNotResurrectDeletedItems() {
        let kept = makeItem(id: "item-A", title: "朝ごはん", hour: 8)
        let removed = makeItem(id: "item-B", title: "水族館", hour: 10)

        // 前回そろえたときは2件あった
        var base = makePlan(updatedAt: t(0))
        base.daySchedules = [makeDay([kept, removed])]

        // 手元にはまだ2件ある
        var local = makePlan(updatedAt: t(5))
        local.daySchedules = [makeDay([kept, removed])]

        // 相手が「水族館」を消して公開した
        var remote = makePlan(updatedAt: t(10))
        remote.daySchedules = [makeDay([kept])]

        let merged = try! #require(
            SharedPlanMerge.decide(local: local, remote: remote, base: base, myUserId: "me").takenPlan
        )
        let titles = merged.daySchedules.flatMap { $0.scheduleItems }.map(\.title)

        #expect(!titles.contains("水族館"))
    }

    // MARK: - 送る側（手元のほうが新しいとき）
    //
    // 2.6 で「共有した計画を後から変えても、相手には最初の内容のまま」と
    // 報告があった件。手元が新しいと計画まるごとを送っていたため、
    // 参加者が自分の持ち物にチェックを入れただけで、古い日程が
    // オーナーの編集を上書きしていた。

    @Test("自分の持ち物を触っただけなら、相手の予定を古い内容で上書きしない")
    func personalChangeDoesNotOverwriteRemote() {
        let original = makeItem(id: "item-A", title: "朝ごはん", hour: 8)
        let added = makeItem(id: "item-B", title: "水族館", hour: 10)

        var base = makePlan(updatedAt: t(0))
        base.daySchedules = [makeDay([original])]

        // オーナーが「水族館」を足して公開した
        var remote = makePlan(updatedAt: t(10))
        remote.daySchedules = [makeDay([original, added])]

        // 参加者はまだ取り込んでいないまま、自分の持ち物にチェックを入れた
        var local = makePlan(updatedAt: t(20), packingItems: [
            PackingItem(name: "充電器", isChecked: true, kind: .packing, ownerId: "me")
        ])
        local.daySchedules = [makeDay([original])]

        let decision = SharedPlanMerge.decide(local: local, remote: remote, base: base, myUserId: "me")
        let titles = decision.takenPlan?.daySchedules.flatMap { $0.scheduleItems }.map(\.title) ?? []

        #expect(decision.pushedPlan == nil)   // 共有ぶんは何も変えていないので送らない
        #expect(titles.contains("水族館"))     // オーナーの追加を取り込む
    }

    @Test("手元が新しくても、相手が足した予定を消さずに送る")
    func pushKeepsRemoteAdditions() {
        let original = makeItem(id: "item-A", title: "朝ごはん", hour: 8)

        var base = makePlan(updatedAt: t(0))
        base.daySchedules = [makeDay([original])]

        var remote = makePlan(updatedAt: t(10))
        remote.daySchedules = [makeDay([original, makeItem(id: "item-C", title: "夕食", hour: 18)])]

        var local = makePlan(updatedAt: t(20))
        local.daySchedules = [makeDay([original, makeItem(id: "item-B", title: "水族館", hour: 10)])]

        let decision = SharedPlanMerge.decide(local: local, remote: remote, base: base, myUserId: "me")
        let pushed = decision.pushedPlan?.daySchedules.flatMap { $0.scheduleItems }.map(\.title) ?? []
        let taken = decision.takenPlan?.daySchedules.flatMap { $0.scheduleItems }.map(\.title) ?? []

        #expect(pushed.contains("夕食"))
        #expect(pushed.contains("水族館"))
        #expect(taken.contains("夕食"))       // 手元にも相手のぶんが入る
    }

    /// 送信に失敗して手元にだけ残った変更が、相手の新しい更新で消えないこと。
    /// 取り込んだあとに送り返さないと、相手には永久に届かない
    @Test("相手が新しくても、手元にしかない変更は送り返す")
    func pushesBackUnsentLocalChanges() {
        let original = makeItem(id: "item-A", title: "朝ごはん", hour: 8)

        var base = makePlan(updatedAt: t(0))
        base.daySchedules = [makeDay([original])]

        var local = makePlan(updatedAt: t(5))
        local.daySchedules = [makeDay([original, makeItem(id: "item-B", title: "水族館", hour: 10)])]

        var remote = makePlan(updatedAt: t(10))
        remote.daySchedules = [makeDay([original, makeItem(id: "item-C", title: "夕食", hour: 18)])]

        let pushed = try! #require(
            SharedPlanMerge.decide(local: local, remote: remote, base: base, myUserId: "me").pushedPlan
        )
        let titles = pushed.daySchedules.flatMap { $0.scheduleItems }.map(\.title)

        #expect(titles.contains("水族館"))
        #expect(titles.contains("夕食"))
        // 相手に「新しい」と判断してもらえないと取り込まれない
        #expect(pushed.updatedAt > remote.updatedAt)
    }

    /// 後から参加した人が、オーナーの古い手元で外されないこと
    @Test("手元が新しくても、相手側で増えたメンバーを外さない")
    func pushKeepsNewMembers() {
        var base = makePlan(updatedAt: t(0))
        base.sharedWith = ["owner"]

        var remote = makePlan(updatedAt: t(10))
        remote.sharedWith = ["owner", "friend"]

        var local = makePlan(title: "沖縄旅行（改）", updatedAt: t(20))
        local.sharedWith = ["owner"]

        let pushed = try! #require(
            SharedPlanMerge.decide(local: local, remote: remote, base: base, myUserId: "owner").pushedPlan
        )

        #expect(pushed.title == "沖縄旅行（改）")
        #expect(pushed.sharedWith.contains("friend"))
    }

    @Test("送り返した直後にもう一度突き合わせると、何もしない")
    func settlesAfterPushBack() {
        let original = makeItem(id: "item-A", title: "朝ごはん", hour: 8)

        var base = makePlan(updatedAt: t(0))
        base.daySchedules = [makeDay([original])]

        var local = makePlan(updatedAt: t(5))
        local.daySchedules = [makeDay([original, makeItem(id: "item-B", title: "水族館", hour: 10)])]

        var remote = makePlan(updatedAt: t(10))
        remote.daySchedules = [makeDay([original, makeItem(id: "item-C", title: "夕食", hour: 18)])]

        let pushed = try! #require(
            SharedPlanMerge.decide(local: local, remote: remote, base: base, myUserId: "me").pushedPlan
        )
        // 送ったものが相手の最新になり、前回の基準にもなる
        let second = SharedPlanMerge.decide(local: pushed, remote: pushed, base: pushed, myUserId: "me")

        #expect(second.isDoNothing)
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
