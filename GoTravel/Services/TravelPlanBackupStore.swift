import Foundation

/// 旅行計画の「控え」。端末の中に、iCloud の仕組みとは別に書き出しておく。
///
/// 旅行計画は iCloud（Core Data + CloudKit）に保存している。iCloud からサインアウトしたり、
/// 確認待ちになったりすると、iOS が端末の中の分を片付けるため、つながるまで何も見られない。
/// 「旅行当日に全部消えた」というお問い合わせがあった（2026年10月）。
///
/// 控えは**読むだけ**で見せる（`TravelPlanBackupView`）。控えに書き込んで戻すと、iCloud が
/// 戻ったときに中身が二重になったり、新しい内容を古い内容で上書きしたりするおそれがあるため。
/// 写真は大きいので含めない（文字の情報だけ）
enum TravelPlanBackupStore {

    struct Backup: Codable {
        let userId: String
        let savedAt: Date
        let plans: [TravelPlan]
    }

    private static var fileURL: URL {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Backup", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("travel_plans.json")
    }

    /// 控えを書き出す。**空の一覧では上書きしない。**
    /// iCloud が外れて一覧が空になったときに、控えまで空にしてしまうと意味がないため
    static func save(_ plans: [TravelPlan], userId: String, now: Date = Date(), to url: URL? = nil) {
        guard !plans.isEmpty else { return }
        let backup = Backup(userId: userId, savedAt: now, plans: plans)
        guard let data = try? JSONEncoder().encode(backup) else { return }
        try? data.write(to: url ?? fileURL, options: [.atomic, .completeFileProtection])
    }

    /// この人の控え。別の人の控えは見せない（同じ端末で別の Apple ID にサインインした場合）
    static func load(userId: String, from url: URL? = nil) -> Backup? {
        guard let data = try? Data(contentsOf: url ?? fileURL),
              let backup = try? JSONDecoder().decode(Backup.self, from: data),
              backup.userId == userId, !backup.plans.isEmpty else { return nil }
        return backup
    }
}
