import Foundation

// MARK: - 書き出しファイルの中身（3.0）
//
// 「旅行計画が全部消えた」お問い合わせ（2026年10月）で、データが iCloud にしか無く、
// iCloud 側で失われると戻せないことが分かった。自分の手で書き出して保存し、いつでも戻せるようにする
// （`docs/設計_3.0.md` 3章）。
//
// **形式の版を持つ。** あとで項目が増えても古いファイルを読めるよう、知らない項目は読み飛ばし、
// 無い項目は空として読む。端末の中の毎日の控え（`LocalSnapshotStore`）も同じ形を使う

struct TravoryExport: Codable {
    static let currentFormatVersion = 1

    /// ゴミ箱に入っているかも残す（戻すときもゴミ箱に入ったまま戻す）
    struct TravelPlanRecord: Codable {
        var plan: TravelPlan
        var deletedAt: Date?
    }

    /// 持ち物の候補
    struct PackingPresetRecord: Codable, Equatable {
        var id: String
        var name: String
        var kind: String
        var order: Int
        var createdAt: Date?
    }

    var formatVersion = currentFormatVersion
    var exportedAt = Date()
    var appVersion = ""
    /// 書き出した人（毎日の控えで、別の人の控えを戻さないため。ファイルの読み込みでは使わない）
    var userId: String?
    var travelPlans: [TravelPlanRecord] = []
    var plans: [Plan] = []
    var places: [VisitedPlace] = []
    var tags: [PlanTag] = []
    /// 予定のカテゴリ（カレンダー）（3.0）
    var planCategories: [PlanCategory] = []
    var categories: [CustomPlaceCategory] = []
    var packingPresets: [PackingPresetRecord] = []
    var tasks: [TaskItem] = []
    var albums: [Album] = []
    /// 一緒に入れた写真（"Documents/xxx.jpg" / "Albums/xxx.jpg"）
    var imagePaths: [String] = []

    init() {}

    /// 何か入っているか（空の控えで上書きしないため）
    var isEmpty: Bool {
        travelPlans.isEmpty && plans.isEmpty && places.isEmpty
    }

    /// 確認の画面に出す件数（ゴミ箱の旅行計画は数えない）
    var summary: String {
        var parts: [String] = []
        let active = travelPlans.filter { $0.deletedAt == nil }.count
        if active > 0 { parts.append("旅行計画 \(active)件") }
        if !plans.isEmpty { parts.append("予定 \(plans.count)件") }
        if !places.isEmpty { parts.append("保存した場所 \(places.count)件") }
        if !albums.isEmpty { parts.append("アルバム \(albums.count)件") }
        if !imagePaths.isEmpty { parts.append("写真 \(imagePaths.count)枚") }
        return parts.isEmpty ? "データはありません" : parts.joined(separator: "・")
    }

    // MARK: 読み書き（知らない項目・無い項目に強くする）

    enum CodingKeys: String, CodingKey {
        case formatVersion, exportedAt, appVersion, userId, travelPlans, plans, places, tags, planCategories, categories
        case packingPresets, tasks, albums, imagePaths
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        formatVersion = try c.decodeIfPresent(Int.self, forKey: .formatVersion) ?? 1
        exportedAt = try c.decodeIfPresent(Date.self, forKey: .exportedAt) ?? Date()
        appVersion = try c.decodeIfPresent(String.self, forKey: .appVersion) ?? ""
        userId = try c.decodeIfPresent(String.self, forKey: .userId)
        travelPlans = Self.lenient(c, .travelPlans)
        plans = Self.lenient(c, .plans)
        places = Self.lenient(c, .places)
        tags = Self.lenient(c, .tags)
        planCategories = Self.lenient(c, .planCategories)
        categories = Self.lenient(c, .categories)
        packingPresets = Self.lenient(c, .packingPresets)
        tasks = Self.lenient(c, .tasks)
        albums = Self.lenient(c, .albums)
        imagePaths = (try? c.decodeIfPresent([String].self, forKey: .imagePaths)) ?? []
    }

    /// 1件読めないだけで全部を失わないよう、読めた分だけ取り出す
    private static func lenient<T: Decodable>(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> [T] {
        guard var list = try? c.nestedUnkeyedContainer(forKey: key) else { return [] }
        var result: [T] = []
        while !list.isAtEnd {
            if let value = try? list.decode(T.self) {
                result.append(value)
            } else {
                _ = try? list.decode(AnyDecodable.self)   // 読めない1件は飛ばす
            }
        }
        return result
    }

    private struct AnyDecodable: Decodable {
        init(from decoder: Decoder) throws {}
    }

    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

// MARK: - 読み込みの決まり（純粋関数。テストで確かめる）

enum TravoryImportRule {

    /// 読み込み方（読み込むときに選ぶ）
    enum Mode {
        /// 端末に無いものだけを足す。すでにある旅行計画は、ファイルのほうが新しく共有していないときだけ置き換える
        case addMissing
        /// ファイルの内容に戻す。中身が違えば、新しさに関係なくファイルの内容にする（書き出したあとに直した分は消える）。
        /// 共有中の旅行計画・共有したカテゴリの予定も戻し、次の同期で同行者にもとどける
        case restore
    }

    /// 旅行計画を、ファイルの内容で置き換えるか。
    /// 端末に無ければ足す。あれば、ファイルのほうが新しく、端末の側が共有していないときだけ置き換える
    /// （共有している計画をファイルで置き換えると、同行者の計画まで書き換わるため）
    enum TravelPlanAction: Equatable {
        case add
        case replace
        case keep
    }

    static func travelPlanAction(fileUpdatedAt: Date, localUpdatedAt: Date?, localIsShared: Bool) -> TravelPlanAction {
        guard let localUpdatedAt else { return .add }
        if localIsShared { return .keep }
        return fileUpdatedAt > localUpdatedAt ? .replace : .keep
    }

    /// 読み込む旅行計画を、今の人の、共有していない計画にする。
    /// 他の人の共有レコードを書き換えたり、共有コードを持ち主でない人が引き継いだりしないため
    static func detached(_ plan: TravelPlan, userId: String) -> TravelPlan {
        var copy = plan
        copy.userId = userId
        copy.isShared = false
        copy.shareCode = nil
        copy.sharedWith = []
        copy.ownerId = nil
        copy.lastEditedBy = nil
        return copy
    }

    /// ファイルの内容に戻した旅行計画。
    /// 共有中なら共有の情報（コード・メンバー・名前）は手元のまま残し、自分が今直したことにする。
    /// 同行者の側より新しくなるので、次の同期でみんなにとどく
    static func restored(_ plan: TravelPlan, over local: TravelPlan, userId: String, now: Date) -> TravelPlan {
        guard local.isShared else {
            var copy = detached(plan, userId: userId)
            copy.updatedAt = now
            return copy
        }
        var copy = plan
        copy.userId = userId
        copy.isShared = true
        copy.shareCode = local.shareCode
        copy.sharedWith = local.sharedWith
        copy.ownerId = local.ownerId
        copy.memberNames = local.memberNames
        copy.lastEditedBy = userId
        copy.updatedAt = now
        return copy
    }

    /// 旅行計画の中身が同じか（戻しても何も変わらないなら、置き換えない）
    static func isSame(_ restored: TravelPlan, as local: TravelPlan) -> Bool {
        restored.isContentEqual(to: local)
    }

    /// ファイルの内容に戻した予定。カテゴリは手元のまま（読み込みで共有したカテゴリから出し入れしない）。
    /// 中身が同じなら nil（置き換えない）
    static func restored(_ plan: Plan, over local: Plan, userId: String, now: Date) -> Plan? {
        var copy = plan
        copy.userId = userId
        copy.categoryId = local.categoryId
        copy.lastEditedBy = local.lastEditedBy
        copy.updatedAt = local.updatedAt
        guard copy != local else { return nil }
        copy.lastEditedBy = userId
        copy.updatedAt = now
        return copy
    }

    /// ファイルの内容に戻した保存した場所。中身が同じなら nil
    static func restored(_ place: VisitedPlace, over local: VisitedPlace, userId: String) -> VisitedPlace? {
        var copy = place
        copy.userId = userId
        return copy == local ? nil : copy
    }
}
