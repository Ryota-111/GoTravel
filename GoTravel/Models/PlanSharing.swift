import Foundation

// MARK: - カテゴリ（カレンダー）ごとに友達と共有（3.0）
//
// カテゴリに「共有する」を付けると共有コード（"PLAN-XXXXXXXX"）ができ、そのカテゴリの予定とタグを
// メンバー全員で見て書ける（`SharedCategoryService`、`docs/設計_3.0.md` 5章）。
//
// | みんなで持つ | 自分だけ |
// |---|---|
// | 題名・日時・終わる時刻・種類・行き先・スケジュール・説明・リンク・繰り返し・カテゴリ・タグ | 通知・済みの印・写真・色 |
//
// 済みの印は「自分は行ったが友達はまだ」があるため、通知は人によって欲しい時機が違うため、自分だけにする

extension Plan {

    static let shareCodePrefix = "PLAN"

    /// "PLAN-XXXXXXXX"。O と I は 0・1 と見間違えるため含めない（旅行計画と同じ）
    static func generateShareCode() -> String {
        let body = String((0..<8).map { _ in "ABCDEFGHJKLMNPQRSTUVWXYZ0123456789".randomElement()! })
        return "\(shareCodePrefix)-\(body)"
    }

    /// カテゴリと共有の項目をまとめて入れる（Core Data から作るとき）
    func withSharing(categoryId: String?, lastEditedBy: String?, updatedAt: Date?) -> Plan {
        var copy = self
        copy.categoryId = categoryId
        copy.lastEditedBy = lastEditedBy
        copy.updatedAt = updatedAt
        return copy
    }

    /// みんなで持つ部分だけ（自分だけの項目と、端末ごとの値を空にしたもの）
    var sharedPart: Plan {
        var copy = self
        copy.userId = nil
        copy.localImageFileName = nil
        copy.reminders = nil
        copy.isCompleted = false
        copy.lastEditedBy = nil
        copy.updatedAt = nil
        copy.tagIDs = tagIDs.sorted()
        // 色は共有しない（共有レコードに載せていない）
        copy.cardColor = nil
        return copy
    }

    /// みんなで持つ部分が同じか（自分だけの項目を変えただけなら、送るものは無い）
    func isSharedContentEqual(to other: Plan) -> Bool {
        sharedPart == other.sharedPart
    }

    /// 自分だけの項目を、手元の予定から持ってくる
    func keepingPersonalFields(of local: Plan?, myUserId: String) -> Plan {
        var copy = self
        copy.userId = myUserId
        copy.localImageFileName = local?.localImageFileName
        copy.reminders = local?.reminders
        copy.isCompleted = local?.isCompleted ?? false
        // 色は共有していないので、手元のものを使う
        copy.cardColor = local?.cardColor
        return copy
    }
}

/// 共有したカテゴリ（`SharedCategory` レコードの中身）。カテゴリのタグも一緒に持つ
struct SharedCategoryRecord: Equatable {
    var id: String
    var name: String
    var colorHex: String?
    var shareCode: String
    var ownerId: String
    var sharedWith: [String]
    var tags: [PlanTag]
    var updatedAt: Date?

    /// 手元のカテゴリにする（並び順は手元のまま）
    func applied(to local: PlanCategory?, order: Int) -> PlanCategory {
        PlanCategory(id: id, name: name, colorHex: colorHex, order: local?.order ?? order,
                     isShared: true, shareCode: shareCode, ownerId: ownerId, sharedWith: sharedWith)
    }

    /// 手元のカテゴリとタグから作る
    init(category: PlanCategory, tags: [PlanTag], updatedAt: Date? = Date()) {
        id = category.id
        name = category.name
        colorHex = category.colorHex
        shareCode = category.shareCode ?? ""
        ownerId = category.ownerId ?? ""
        sharedWith = category.sharedWith
        self.tags = tags
        self.updatedAt = updatedAt
    }

    init(id: String, name: String, colorHex: String?, shareCode: String, ownerId: String,
         sharedWith: [String], tags: [PlanTag], updatedAt: Date?) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.shareCode = shareCode
        self.ownerId = ownerId
        self.sharedWith = sharedWith
        self.tags = tags
        self.updatedAt = updatedAt
    }

    /// カテゴリのタグを、手元・相手・前回の3つで突き合わせる（足したタグ・消したタグを取り違えない）
    static func mergedTags(local: [PlanTag], remote: [PlanTag], base: [PlanTag]?) -> [PlanTag] {
        SharedPlanMerge.merge(local: local, remote: remote, base: base ?? [], id: \.id, hasBase: base != nil)
    }
}

/// 共有した予定の突き合わせ（`SharedPlanMerge` の予定版）。
///
/// 手元・相手・前回そろえたときの3つを見て、項目ごとに「書き換えたほう」を採る。
/// 行き先とスケジュールは1件ずつ突き合わせる（相手が足した行き先と、自分が足した行き先の両方を残す）
enum PlanShareMerge {

    enum Decision: Equatable {
        case takeRemote(Plan)
        case pushLocal(Plan)
        case takeAndPush(Plan)
        case doNothing

        var takenPlan: Plan? {
            switch self {
            case .takeRemote(let plan), .takeAndPush(let plan): return plan
            default: return nil
            }
        }

        var pushedPlan: Plan? {
            switch self {
            case .pushLocal(let plan), .takeAndPush(let plan): return plan
            default: return nil
            }
        }
    }

    static func decide(local: Plan?, remote: Plan, base: Plan?, myUserId: String) -> Decision {
        guard let local else {
            // まだ手元に無い（参加した直後）。自分だけの項目は空から始める
            return .takeRemote(remote.keepingPersonalFields(of: nil, myUserId: myUserId))
        }
        if local.updatedAt == remote.updatedAt, local.isSharedContentEqual(to: remote) {
            return .doNothing
        }

        var merged = combine(local: local, remote: remote, base: base).keepingPersonalFields(of: local, myUserId: myUserId)
        let needsPush = !merged.isSharedContentEqual(to: remote)
        let needsSave = merged != local

        let localTime = local.updatedAt ?? .distantPast
        let remoteTime = remote.updatedAt ?? .distantPast
        if needsPush {
            // 相手に「新しい」と判断してもらえるよう、相手より後ろの時刻にする
            merged.updatedAt = localTime > remoteTime ? localTime : remoteTime.addingTimeInterval(1)
            return needsSave ? .takeAndPush(merged) : .pushLocal(merged)
        }
        if needsSave {
            merged.updatedAt = remote.updatedAt
            return .takeRemote(merged)
        }
        return .doNothing
    }

    private static func combine(local: Plan, remote: Plan, base: Plan?) -> Plan {
        let newer = (local.updatedAt ?? .distantPast) > (remote.updatedAt ?? .distantPast) ? local : remote
        // 前回の内容が無ければ、比べようがないので新しいほうを正とする
        guard let base else { return newer }

        var merged = newer
        func pick<Value: Equatable>(_ key: KeyPath<Plan, Value>) -> Value {
            let l = local[keyPath: key], r = remote[keyPath: key], b = base[keyPath: key]
            if l == b { return r }
            if r == b { return l }
            return newer[keyPath: key]
        }
        merged.title = pick(\.title)
        merged.startDate = pick(\.startDate)
        merged.endDate = pick(\.endDate)
        merged.time = pick(\.time)
        merged.endTime = pick(\.endTime)
        merged.planType = pick(\.planType)
        merged.description = pick(\.description)
        merged.linkURL = pick(\.linkURL)
        merged.recurrence = pick(\.recurrence)
        merged.places = SharedPlanMerge.merge(local: local.places, remote: remote.places, base: base.places,
                                              id: \.id, hasBase: true)
        merged.scheduleItems = SharedPlanMerge.merge(local: local.scheduleItems, remote: remote.scheduleItems,
                                                     base: base.scheduleItems, id: \.id, hasBase: true)
        merged.categoryId = pick(\.categoryId)
        // タグは1つずつ（相手が付けたタグも、自分が付けたタグも残す）
        merged.tagIDs = SharedPlanMerge.merge(local: local.tagIDs, remote: remote.tagIDs, base: base.tagIDs,
                                              id: \.self, hasBase: true)
        return merged
    }
}

/// 「前回そろえたときの予定」を覚えておく（`SharedPlanBaseStore` の予定版）。端末ごとの覚え書きなので同期しない。
/// 共有したカテゴリのタグの前回分も、ここに置く（`saveCategoryTags`）
enum PlanShareBaseStore {

    private static var directory: URL {
        let url = FileManager.documentsDirectory().appendingPathComponent("SharedPlanBase", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func fileURL(planId: String) -> URL {
        directory.appendingPathComponent("plan-\(planId).json")
    }

    static func load(planId: String) -> Plan? {
        guard let data = try? Data(contentsOf: fileURL(planId: planId)) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Plan.self, from: data)
    }

    /// **相手から受け取った姿（または送った姿）をそのまま入れること**
    static func save(_ plan: Plan) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(plan) else { return }
        try? data.write(to: fileURL(planId: plan.id), options: .atomic)
    }

    static func remove(planId: String) {
        try? FileManager.default.removeItem(at: fileURL(planId: planId))
    }

    // MARK: カテゴリのタグ

    private static func tagsURL(categoryId: String) -> URL {
        directory.appendingPathComponent("category-\(categoryId)-tags.json")
    }

    static func loadCategoryTags(categoryId: String) -> [PlanTag]? {
        guard let data = try? Data(contentsOf: tagsURL(categoryId: categoryId)) else { return nil }
        return try? JSONDecoder().decode([PlanTag].self, from: data)
    }

    static func saveCategoryTags(_ tags: [PlanTag], categoryId: String) {
        guard let data = try? JSONEncoder().encode(tags) else { return }
        try? data.write(to: tagsURL(categoryId: categoryId), options: .atomic)
    }

    static func removeCategoryTags(categoryId: String) {
        try? FileManager.default.removeItem(at: tagsURL(categoryId: categoryId))
    }
}
