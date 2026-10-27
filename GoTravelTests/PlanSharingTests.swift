import Testing
import Foundation
@testable import GoTravel

/// カテゴリ（カレンダー）と、カテゴリごとの共有（3.0）。同行者の編集で自分の入力が消えないこと
struct PlanSharingTests {

    private static let base = Date(timeIntervalSince1970: 1_790_000_000)

    private func plan(title: String = "BBQ", updatedAt seconds: TimeInterval?, places: [PlannedPlace] = [],
                      tagIDs: [String] = [], isCompleted: Bool = false) -> Plan {
        var plan = Plan(id: "p1", title: title, startDate: Self.base, endDate: Self.base, places: places,
                        userId: "owner", createdAt: Self.base, planType: .outing, tagIDs: tagIDs)
        plan.isCompleted = isCompleted
        return plan.withSharing(categoryId: "family", lastEditedBy: nil,
                                updatedAt: seconds.map { Self.base.addingTimeInterval($0) })
    }

    private func place(_ id: String) -> PlannedPlace {
        PlannedPlace(id: id, name: id, latitude: 35, longitude: 139)
    }

    // MARK: - カテゴリの選び方

    @Test("「すべて」は全部、「自分用」はカテゴリ無し、カテゴリはそのカテゴリだけを出す")
    func selection() {
        #expect(PlanCategorySelection.all.includes(categoryId: "family"))
        #expect(PlanCategorySelection.all.includes(categoryId: nil))
        #expect(PlanCategorySelection.personal.includes(categoryId: nil))
        #expect(!PlanCategorySelection.personal.includes(categoryId: "family"))
        #expect(PlanCategorySelection.category("family").includes(categoryId: "family"))
        #expect(!PlanCategorySelection.category("family").includes(categoryId: nil))
        // 旅行計画と iPhone の予定は「すべて」と「自分用」だけ
        #expect(PlanCategorySelection.all.showsUncategorized)
        #expect(!PlanCategorySelection.category("family").showsUncategorized)
        // 新しい予定は、見ているカテゴリに入る（「すべて」なら自分用）
        #expect(PlanCategorySelection.all.categoryIdForNewPlan == nil)
        #expect(PlanCategorySelection.category("family").categoryIdForNewPlan == "family")
    }

    @Test("見ているカテゴリは保存して読み直せる")
    func selectionStorage() {
        for value in [PlanCategorySelection.all, .personal, .category("abc")] {
            #expect(PlanCategorySelection(storageKey: value.storageKey) == value)
        }
        #expect(PlanCategorySelection(storageKey: "壊れた値") == .all)
    }

    // MARK: - 共有

    @Test("共有コードは PLAN- と、見間違えない8文字")
    func shareCode() {
        let code = Plan.generateShareCode()
        #expect(code.hasPrefix("PLAN-"))
        #expect(code.count == 13)
        #expect(!code.dropFirst(5).contains("O") && !code.dropFirst(5).contains("I"))
    }

    @Test("参加の画面は PLAN- のコードを受け付け、前置きの無い8桁は旅行計画とみなす")
    func normalizeCode() {
        #expect(JoinTravelPlanView.normalizeShareCode("plan-abcd1234") == "PLAN-ABCD1234")
        #expect(JoinTravelPlanView.normalizeShareCode("PLANABCD1234") == "PLAN-ABCD1234")
        #expect(JoinTravelPlanView.normalizeShareCode("abcd1234") == "TRAVEL-ABCD1234")
    }

    @Test("済みの印・通知は自分だけのもの。タグは共有したカテゴリでは、みんなで持つ")
    func personalAndSharedFields() {
        let a = plan(updatedAt: 0)
        #expect(a.isSharedContentEqual(to: plan(updatedAt: 0, isCompleted: true)))
        #expect(!a.isSharedContentEqual(to: plan(updatedAt: 0, tagIDs: ["outdoor"])))
        #expect(!a.isSharedContentEqual(to: plan(title: "BBQ（雨天決行）", updatedAt: 0)))
    }

    @Test("参加して届いた予定は、自分の予定として取り込み、タグはそのまま、済みの印は空から始まる")
    func adoptOnJoin() {
        let remote = plan(updatedAt: 10, tagIDs: ["outdoor"], isCompleted: true)
        let taken = PlanShareMerge.decide(local: nil, remote: remote, base: nil, myUserId: "me").takenPlan
        #expect(taken?.userId == "me")
        #expect(taken?.tagIDs == ["outdoor"])
        #expect(taken?.isCompleted == false)
        #expect(taken?.categoryId == "family")
    }

    @Test("相手が題名とタグを、自分が行き先とタグを変えたら、全部残り、相手へも送る")
    func mergesBothEdits() {
        let base = plan(updatedAt: 0, places: [place("a")], tagIDs: ["outdoor"])
        let local = plan(updatedAt: 20, places: [place("a"), place("b")], tagIDs: ["outdoor", "mine"])
        let remote = plan(title: "BBQ（集合 10時）", updatedAt: 10, places: [place("a")], tagIDs: ["outdoor", "theirs"])

        let decision = PlanShareMerge.decide(local: local, remote: remote, base: base, myUserId: "me")
        let merged = decision.takenPlan ?? decision.pushedPlan
        #expect(merged?.title == "BBQ（集合 10時）")
        #expect(merged?.places.map(\.id) == ["a", "b"])
        #expect(Set(merged?.tagIDs ?? []) == ["outdoor", "mine", "theirs"])
        #expect(decision.pushedPlan != nil)
    }

    @Test("同じ内容なら何もしない。自分だけの項目が違っても何もしない")
    func doNothing() {
        let remote = plan(updatedAt: 10)
        let local = plan(updatedAt: 10, isCompleted: true)
        #expect(PlanShareMerge.decide(local: local, remote: remote, base: remote, myUserId: "me") == .doNothing)
    }

    @Test("カテゴリのタグは、相手が足したタグと自分が足したタグの両方を残し、消したタグは消す")
    func categoryTagsMerge() {
        let base = [PlanTag(id: "a", name: "外"), PlanTag(id: "b", name: "中")]
        let local = [PlanTag(id: "a", name: "外"), PlanTag(id: "b", name: "中"), PlanTag(id: "mine", name: "私")]
        let remote = [PlanTag(id: "a", name: "アウトドア"), PlanTag(id: "theirs", name: "相手")]   // b を消して、a を改名
        let merged = SharedCategoryRecord.mergedTags(local: local, remote: remote, base: base)
        #expect(Set(merged.map(\.id)) == ["a", "theirs", "mine"])
        #expect(merged.first { $0.id == "a" }?.name == "アウトドア")
    }

    // MARK: - 保存

    @Test("カテゴリは保存して読み直せ、持たない前のデータも読める")
    func codable() throws {
        let original = plan(updatedAt: 5)
        #expect(try JSONDecoder().decode(Plan.self, from: JSONEncoder().encode(original)) == original)
        let old = #"{"id":"x","title":"歯医者","startDate":0,"endDate":0,"places":[]}"#
        #expect(try JSONDecoder().decode(Plan.self, from: Data(old.utf8)).categoryId == nil)

        let tag = PlanTag(id: "t", name: "外", colorHex: "#FF0000", order: 1, categoryId: "family")
        #expect(try JSONDecoder().decode(PlanTag.self, from: JSONEncoder().encode(tag)) == tag)
        let oldTag = #"{"id":"t","name":"仕事","order":0}"#
        #expect(try JSONDecoder().decode(PlanTag.self, from: Data(oldTag.utf8)).categoryId == nil)

        let category = PlanCategory(id: "family", name: "家族", colorHex: "#00FF00", order: 2,
                                    isShared: true, shareCode: "PLAN-ABCDEFGH", ownerId: "owner", sharedWith: ["owner", "me"])
        #expect(try JSONDecoder().decode(PlanCategory.self, from: JSONEncoder().encode(category)) == category)
    }

    @Test("届いた共有カテゴリは、手元の並び順を残したまま、名前・色・メンバーを新しくする")
    func appliedCategory() {
        let record = SharedCategoryRecord(id: "family", name: "家族（改）", colorHex: "#00FF00", shareCode: "PLAN-ABCDEFGH",
                                          ownerId: "owner", sharedWith: ["owner", "me", "sis"], tags: [], updatedAt: nil)
        let local = PlanCategory(id: "family", name: "家族", order: 3)
        let applied = record.applied(to: local, order: 9)
        #expect(applied.order == 3)
        #expect(applied.name == "家族（改）")
        #expect(applied.isShared)
        #expect(applied.sharedWith.count == 3)
        #expect(record.applied(to: nil, order: 9).order == 9)
    }
}
