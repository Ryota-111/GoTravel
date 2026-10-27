import Foundation
import CoreData

/// 端末の中の、毎日の控え（3.0）。旅行計画・予定・保存した場所などを、日ごとに1つずつ残す。
///
/// 2.9.1 の控え（`TravelPlanBackupStore`）は旅行計画だけで、1つを上書きし続ける。
/// 「全部消えた」お問い合わせ（2026年10月）では、iCloud にも何も無く、戻す手立てが無かった。
/// iOS が端末の中を片付けても、ここは Core Data の外（Application Support）にあるので残る。
/// データの診断で「iCloud にデータが無い」と分かったときに、ここから戻せる（`DataDiagnosticsView`）。
///
/// - 写真は入れない（大きいため。写真は書き出しのファイルで残す）
/// - **空の控えは書かない**（消えたあとに、空の控えで上書きしないため）
/// - 直近の3日分を残す。消えた日の控えだけでなく、その前の日の控えも残るように
enum LocalSnapshotStore {

    static let keepDays = 3
    /// 書き直す間隔。同期で一覧が立て続けに変わるので、間を空ける
    static let minimumInterval: TimeInterval = 10 * 60

    struct Snapshot {
        let url: URL
        let savedAt: Date
        let export: TravoryExport
    }

    static var folder: URL {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Backup/Snapshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static let lastSavedKey = "LocalSnapshotStore.lastSavedAt"

    /// 間を空けて、今日の控えを書く（同じ日の分は上書き）
    static func saveIfNeeded(userId: String, context: NSManagedObjectContext, now: Date = Date(),
                             defaults: UserDefaults = .standard, folder: URL = folder) {
        if let last = defaults.object(forKey: lastSavedKey) as? Date, now.timeIntervalSince(last) < minimumInterval {
            return
        }
        let export = DataExportService.collect(userId: userId, context: context)
        guard save(export, now: now, folder: folder) else { return }
        defaults.set(now, forKey: lastSavedKey)
    }

    /// 書いたら true。空なら書かない
    @discardableResult
    static func save(_ export: TravoryExport, now: Date = Date(), folder: URL = folder) -> Bool {
        guard !export.isEmpty else { return false }
        var copy = export
        copy.exportedAt = now
        guard let data = try? TravoryExport.encoder().encode(copy) else { return false }
        let url = folder.appendingPathComponent("\(dayKey(now)).json")
        guard (try? data.write(to: url, options: [.atomic, .completeFileProtection])) != nil else { return false }
        prune(folder: folder)
        return true
    }

    /// その人の、いちばん新しい控え
    static func latest(userId: String, folder: URL = folder) -> Snapshot? {
        all(folder: folder).first { $0.export.userId == userId }
    }

    /// 新しい順
    static func all(folder: URL = folder) -> [Snapshot] {
        let urls = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return urls
            .filter { $0.pathExtension == "json" }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url),
                      let export = try? TravoryExport.decoder().decode(TravoryExport.self, from: data) else { return nil }
                return Snapshot(url: url, savedAt: export.exportedAt, export: export)
            }
            .sorted { $0.savedAt > $1.savedAt }
    }

    /// 古い日の控えを捨てる（新しい順に `keepDays` 日分を残す）
    private static func prune(folder: URL) {
        let urls = ((try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }   // 名前が日付なので、名前の順が新しい順
        for url in urls.dropFirst(keepDays) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private static func dayKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    /// アカウント削除のときに消す（退会した人の控えを残さない）
    static func removeAll(folder: URL = folder) {
        try? FileManager.default.removeItem(at: folder)
    }
}
