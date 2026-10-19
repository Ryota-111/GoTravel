import Foundation

// MARK: - 旅行のメモ（3.0）
//
// 2.9 のメモ帳は1枚の文章だった。「複数のメモを登録でき、リスト化されるようになると嬉しい。
// それぞれ個人用か共有するかも選べると便利」というご要望から、メモの一覧にする
// （`docs/設計_3.0.md` 4章）。
//
// - 共有した旅行では、メモごとに「みんなで見る」か「自分だけ」を選ぶ
// - 自分だけのメモは共有レコード（パブリックDB）に載せない。自分の Core Data にだけある
// - 2.9 以前のアプリのために、1枚目の共有メモの本文を `memoText` に写して入れ続ける。
//   2.9 の人が `memoText` を書き換えたら、1枚目の共有メモに反映する

struct TripMemo: Identifiable, Codable, Equatable {
    var id: String = UUID().uuidString
    var title: String = ""
    var body: String = ""
    /// 自分だけのメモか（共有した旅行でも、他の人には見えない）
    var isPrivate = false
    /// 書いた人（自分だけのメモの持ち主）
    var authorId: String?
    var createdAt = Date()
    var updatedAt = Date()

    /// 2.9 の1枚のメモ帳から移したメモの id。
    /// **どの端末で移しても同じ id にする。** 端末ごとに違う id で移すと、共有した旅行で
    /// 同じメモが人数分に増える
    static let legacyId = "legacy-memo"

    /// 一覧に出す題名（空なら本文の1行目）
    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let firstLine = body.split(whereSeparator: \.isNewline).first.map(String.init)?
            .trimmingCharacters(in: .whitespaces) ?? ""
        return firstLine.isEmpty ? "メモ" : firstLine
    }

    var isEmpty: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    enum CodingKeys: String, CodingKey {
        case id, title, body, isPrivate, authorId, createdAt, updatedAt
    }

    init(id: String = UUID().uuidString, title: String = "", body: String = "", isPrivate: Bool = false,
         authorId: String? = nil, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.body = body
        self.isPrivate = isPrivate
        self.authorId = authorId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        body = try c.decodeIfPresent(String.self, forKey: .body) ?? ""
        isPrivate = try c.decodeIfPresent(Bool.self, forKey: .isPrivate) ?? false
        authorId = try c.decodeIfPresent(String.self, forKey: .authorId)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }
}

// MARK: - 2.9 の1枚のメモとの行き来（純粋関数。テストで確かめる）

enum TripMemoLegacy {

    /// 2.9 以前のアプリに見せる文章。1枚目の共有メモの本文
    static func legacyText(of memos: [TripMemo]) -> String? {
        guard let first = memos.first(where: { !$0.isPrivate }) else { return nil }
        let trimmed = first.body.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : first.body
    }

    /// 保存してあるメモの一覧と、2.9 の1枚のメモ（`memoText`）を突き合わせる。
    ///
    /// - メモの一覧が無く、1枚のメモだけがある（2.9 までのデータ）→ その文章を共有メモ1枚にする
    /// - 1枚のメモが、1枚目の共有メモの本文と違う（2.9 の人が書き換えた）→ 1枚目の共有メモに反映する
    ///
    /// **どの端末で行っても同じ結果にする**（日時に「今」を使わない）。端末ごとに違うと、
    /// 共有した旅行の突き合わせで「書き換えた」とみなされ、同行者のメモを古い内容で上書きする
    static func reconcile(memos: [TripMemo], legacy: String?) -> [TripMemo] {
        let legacyText = legacy.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        guard let legacyText else { return memos }
        guard let index = memos.firstIndex(where: { !$0.isPrivate }) else {
            return [TripMemo(id: TripMemo.legacyId, title: "メモ", body: legacyText,
                             createdAt: legacyDate, updatedAt: legacyDate)] + memos
        }
        guard memos[index].body != legacyText else { return memos }
        var updated = memos
        updated[index].body = legacyText
        return updated
    }

    /// 2.9 から移したメモの日時（どの端末でも同じ値にするため、決まった日時にする）
    static let legacyDate = Date(timeIntervalSince1970: 0)

    static func encode(_ memos: [TripMemo]) -> String? {
        guard !memos.isEmpty else { return nil }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return (try? encoder.encode(memos)).flatMap { String(data: $0, encoding: .utf8) }
    }

    static func decode(_ json: String?) -> [TripMemo] {
        guard let data = json?.data(using: .utf8) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([TripMemo].self, from: data)) ?? []
    }
}
