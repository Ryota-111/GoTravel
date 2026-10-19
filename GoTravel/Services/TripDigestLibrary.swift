import Foundation

/// 作った旅のダイジェスト動画を、端末の中に残しておく（Travory Pro）。
///
/// 旅行と範囲（旅行全体・Day ごと）ごとに最新の1本だけを残す（作り直したら置き換える）。
/// 「思い出」タブのカードから、作り直さずに見られるようにするため。iCloud には上げない
enum TripDigestLibrary {

    struct Entry: Codable, Hashable, Identifiable {
        var planId: String
        var scopeId: String
        /// 「Day 2・9月22日(火)」など
        var title: String
        var createdAt: Date
        var fileName: String

        var id: String { fileName }
    }

    static var directory: URL {
        let url = FileManager.documentsDirectory().appendingPathComponent("TripDigests", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static var indexURL: URL { directory.appendingPathComponent("index.json") }

    static func allEntries() -> [Entry] {
        guard let data = try? Data(contentsOf: indexURL),
              let entries = try? JSONDecoder().decode([Entry].self, from: data) else { return [] }
        // ファイルが消えていれば、無かったことにする
        return entries.filter { FileManager.default.fileExists(atPath: url(of: $0).path) }
    }

    /// その旅行の動画（新しい順）
    static func entries(planId: String?) -> [Entry] {
        guard let planId else { return [] }
        return allEntries().filter { $0.planId == planId }.sorted { $0.createdAt > $1.createdAt }
    }

    static func entry(planId: String?, scopeId: String) -> Entry? {
        entries(planId: planId).first { $0.scopeId == scopeId }
    }

    static func url(of entry: Entry) -> URL {
        directory.appendingPathComponent(entry.fileName)
    }

    /// 作った動画を残す（同じ旅行・同じ範囲の前の動画は置き換える）。残した場所を返す
    @discardableResult
    static func save(_ temporary: URL, planId: String?, scopeId: String, title: String, now: Date = Date()) throws -> URL {
        let planKey = planId ?? "unknown"
        let fileName = "\(planKey)-\(scopeId).mp4"
        let destination = directory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: temporary, to: destination)

        var entries = allEntries().filter { !($0.planId == planKey && $0.scopeId == scopeId) }
        entries.append(Entry(planId: planKey, scopeId: scopeId, title: title, createdAt: now, fileName: fileName))
        try JSONEncoder().encode(entries).write(to: indexURL, options: .atomic)
        return destination
    }

    static func remove(_ entry: Entry) {
        try? FileManager.default.removeItem(at: url(of: entry))
        let entries = allEntries().filter { $0 != entry }
        try? JSONEncoder().encode(entries).write(to: indexURL, options: .atomic)
    }
}
