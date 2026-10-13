import Foundation
import CloudKit
import CoreData

/// iCloud との同期で起きたことの記録（データの診断 `DataDiagnostics` で見せる・送る）。
///
/// 「旅行計画が全部消えた」というお問い合わせ（2026年10月）で、いつ・何が起きたのかが
/// 端末にも開発者にも何も残っておらず、原因を決めきれなかった。次に起きたときに分かるよう、
/// 同期の結果・iCloud のアカウントの変化・旅行計画の件数が減ったときを残しておく。
///
/// 中身は件数・日時・エラーの番号だけ。旅行計画の中身や名前は残さない
enum SyncDiagnosticsLog {

    struct Entry: Codable, Equatable {
        enum Kind: String, Codable {
            /// 同期の仕組みの準備（iCloud とのつなぎ直しのたびに起きる）
            case setup
            /// iCloud から読み込んだ
            case `import`
            /// iCloud へ書き出した
            case export
            /// iCloud のアカウントの状態が変わった
            case account
            /// 旅行計画の件数が変わった（減ったときと、0 になったとき・0 から戻ったとき）
            case planCount
        }

        let kind: Kind
        let date: Date
        /// 同期なら成功したか
        var succeeded: Bool?
        /// 同期の失敗の中身（"CKErrorDomain 25" など）
        var error: String?
        /// アカウントの状態や件数の変化（"available" / "5 → 0" など）
        var detail: String?
    }

    /// 残す件数。古いものから捨てる
    static let limit = 60

    private static let key = "SyncDiagnosticsLog.entries"
    private static let lastPlanCountKey = "SyncDiagnosticsLog.lastPlanCount"
    private static let lock = NSLock()

    static func entries(defaults: UserDefaults = .standard) -> [Entry] {
        guard let data = defaults.data(forKey: key),
              let entries = try? JSONDecoder().decode([Entry].self, from: data) else { return [] }
        return entries
    }

    static func append(_ entry: Entry, defaults: UserDefaults = .standard) {
        lock.lock(); defer { lock.unlock() }
        var all = entries(defaults: defaults)
        all.append(entry)
        if all.count > limit { all.removeFirst(all.count - limit) }
        if let data = try? JSONEncoder().encode(all) {
            defaults.set(data, forKey: key)
        }
    }

    // MARK: - 記録する

    /// 同期の終わった知らせを残す。成功した読み込み・書き出しは数が多いので、
    /// 種類ごとに最後の成功だけを残す（失敗はすべて残す）
    static func record(_ event: NSPersistentCloudKitContainer.Event, defaults: UserDefaults = .standard) {
        guard let endDate = event.endDate else { return }
        let kind: Entry.Kind
        switch event.type {
        case .setup: kind = .setup
        case .import: kind = .import
        case .export: kind = .export
        @unknown default: return
        }
        record(kind: kind, date: endDate, succeeded: event.succeeded,
               error: event.error.map(describe), defaults: defaults)
    }

    static func record(kind: Entry.Kind, date: Date, succeeded: Bool, error: String?,
                       defaults: UserDefaults = .standard) {
        let entry = Entry(kind: kind, date: date, succeeded: succeeded, error: error)
        if succeeded {
            lock.lock()
            var all = entries(defaults: defaults)
            // 同じ種類の前の記録が成功なら、それを消して日時だけ新しくする
            if let last = all.lastIndex(where: { $0.kind == kind }), all[last].succeeded == true {
                all.remove(at: last)
            }
            all.append(entry)
            if all.count > limit { all.removeFirst(all.count - limit) }
            if let data = try? JSONEncoder().encode(all) { defaults.set(data, forKey: key) }
            lock.unlock()
        } else {
            append(entry, defaults: defaults)
        }
    }

    /// iCloud のアカウントの状態を残す。前と同じなら残さない
    static func recordAccount(_ status: CKAccountStatus?, date: Date = Date(), defaults: UserDefaults = .standard) {
        let detail = describe(status)
        if let last = entries(defaults: defaults).last(where: { $0.kind == .account }), last.detail == detail { return }
        append(Entry(kind: .account, date: date, detail: detail), defaults: defaults)
    }

    /// 旅行計画の件数を残す。減ったとき、0 から戻ったときだけ（増えるのは普段の操作なので残さない）
    static func recordPlanCount(_ count: Int, date: Date = Date(), defaults: UserDefaults = .standard) {
        let previous = defaults.object(forKey: lastPlanCountKey) as? Int
        defaults.set(count, forKey: lastPlanCountKey)
        guard let previous, previous != count else { return }
        guard count < previous || previous == 0 else { return }
        append(Entry(kind: .planCount, date: date, detail: "\(previous) → \(count)"), defaults: defaults)
    }

    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
        defaults.removeObject(forKey: lastPlanCountKey)
    }

    // MARK: - 書き方

    static func describe(_ status: CKAccountStatus?) -> String {
        switch status {
        case .available: return "available"
        case .noAccount: return "noAccount"
        case .restricted: return "restricted"
        case .temporarilyUnavailable: return "temporarilyUnavailable"
        case .couldNotDetermine: return "couldNotDetermine"
        case nil: return "unknown"
        @unknown default: return "other(\(status!.rawValue))"
        }
    }

    /// エラーを「ドメイン 番号」で短く書く。partialFailure なら中の番号も添える
    static func describe(_ error: Error) -> String {
        let ns = error as NSError
        var text = "\(ns.domain) \(ns.code)"
        if let ckError = error as? CKError, ckError.code == .partialFailure,
           let partial = ckError.partialErrorsByItemID?.values {
            let codes = Set(partial.map { ($0 as NSError).code }).sorted()
            text += " [" + codes.map(String.init).joined(separator: ",") + "]"
        }
        return text
    }
}
