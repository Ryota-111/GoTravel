import Foundation
import CloudKit
import CoreData

/// データの診断。旅行計画が見当たらないときに、どこにあるのか（無いのか）を確かめる。
///
/// 「旅行計画が全部消えた」というお問い合わせ（2026年10月）では、アプリのコードに消す道筋が無く、
/// iCloud の中を見られないため、原因を決めきれなかった。考えられるのは次のどれか。
/// - iCloud が外れて端末の中が片付けられ、読み込み直しが止まっている（iCloud には残っている）
/// - そもそも iCloud に保存されていなかった（容量がいっぱい、Travory の iCloud がオフ）
/// - 設定の「ストレージを管理」から Travory のデータが削除された
/// - アプリに別の Apple アカウントでサインインし、別の人の分として隠れている
///
/// これを見分けるため、**端末の中**と**iCloud の中**の旅行計画を数えて比べる。
/// iCloud は、Core Data が使っている保存先（ゾーン）を直接読んで数える。
///
/// 数えるのは件数と ID の末尾だけ。旅行計画の中身や名前は読まない・送らない
enum DataDiagnostics {

    // MARK: - 結果

    /// 端末の中の件数
    struct LocalCounts: Equatable {
        /// 今の人の旅行計画（一覧に出るもの）
        var travelPlans = 0
        /// 今の人のゴミ箱の旅行計画
        var trashedTravelPlans = 0
        /// 別の ID の旅行計画（ID → 件数）
        var otherUserTravelPlans: [String: Int] = [:]
        /// 今の人の予定計画・保存した場所
        var plans = 0
        var places = 0
        /// 別の ID の予定計画・保存した場所
        var otherUserPlans = 0
        var otherUserPlaces = 0

        var otherUserTravelPlanCount: Int { otherUserTravelPlans.values.reduce(0, +) }
    }

    /// iCloud の中の件数
    struct CloudCounts: Equatable {
        var travelPlans = 0
        var trashedTravelPlans = 0
        var otherUserTravelPlans = 0
        var plans = 0
        var places = 0
        /// 保存先にあるレコードの数（旅行計画以外も含む）
        var records = 0
    }

    enum CloudResult: Equatable {
        case counted(CloudCounts)
        /// iCloud に Travory の保存先が無い（一度も保存されていない）
        case zoneMissing
        /// iCloud の Travory の保存先が、設定などから削除された
        case zoneDeleted
        /// iCloud が使えないので数えていない
        case skipped
        /// 数えられなかった（通信など）
        case failed(String)
    }

    struct Report {
        var date = Date()
        var userId: String
        var accountStatus: CKAccountStatus?
        var local: LocalCounts
        var cloud: CloudResult
        var backupCount: Int?
        var backupSavedAt: Date?
        var log: [SyncDiagnosticsLog.Entry]

        var verdict: Verdict { DataDiagnostics.verdict(for: self) }
    }

    // MARK: - 判断（純粋関数。テストで確かめる）

    enum Verdict: Equatable {
        /// 端末に旅行計画がある（iCloud とも揃っている、または iCloud は分からない）
        case fine(count: Int)
        /// 端末にはあるが、iCloud のほうが多い（読み込みが途中）
        case partiallyLoaded(local: Int, cloud: Int)
        /// 一覧には無いが、ゴミ箱にある
        case inTrash(count: Int)
        /// この端末に、別の ID の旅行計画がある（別の Apple アカウントでサインインした）
        case otherUser(count: Int)
        /// iCloud が使えない状態
        case iCloudUnavailable
        /// 端末には無いが、iCloud にはある（読み込み直せば戻る）
        case cloudHasData(count: Int)
        /// iCloud の Travory のデータが削除されている
        case cloudDeleted
        /// iCloud にも無い（保存されていなかった）
        case cloudEmpty
        /// iCloud を数えられず、決めきれない
        case unknown
    }

    static func verdict(for report: Report) -> Verdict {
        let local = report.local
        let cloudCounts: CloudCounts? = {
            if case .counted(let counts) = report.cloud { return counts }
            return nil
        }()

        if local.travelPlans > 0 {
            if let cloudCounts, cloudCounts.travelPlans > local.travelPlans {
                return .partiallyLoaded(local: local.travelPlans, cloud: cloudCounts.travelPlans)
            }
            return .fine(count: local.travelPlans)
        }
        if local.otherUserTravelPlanCount > 0 { return .otherUser(count: local.otherUserTravelPlanCount) }
        if local.trashedTravelPlans > 0 { return .inTrash(count: local.trashedTravelPlans) }
        if ICloudSyncMonitor.problem(for: report.accountStatus) != nil { return .iCloudUnavailable }

        switch report.cloud {
        case .counted(let counts):
            if counts.travelPlans > 0 { return .cloudHasData(count: counts.travelPlans) }
            // 別の ID の分が iCloud にだけある場合も、読み込めば「別の ID」として出てくる
            if counts.otherUserTravelPlans > 0 { return .cloudHasData(count: counts.otherUserTravelPlans) }
            if counts.trashedTravelPlans > 0 { return .cloudHasData(count: counts.trashedTravelPlans) }
            return .cloudEmpty
        case .zoneMissing:
            return .cloudEmpty
        case .zoneDeleted:
            return .cloudDeleted
        case .skipped:
            return .iCloudUnavailable
        case .failed:
            return .unknown
        }
    }

    /// 端末の中の毎日の控え（`LocalSnapshotStore`）から戻してよいか。
    ///
    /// **iCloud にデータが無いと確かめられたときだけ。** iCloud にあるのに戻すと、
    /// あとで iCloud から読み込まれた分と2重になる
    static func canRestoreFromSnapshot(_ verdict: Verdict) -> Bool {
        switch verdict {
        case .cloudEmpty, .cloudDeleted: return true
        default: return false
        }
    }

    // MARK: - 調べる

    static let zoneID = CKRecordZone.ID(zoneName: "com.apple.coredata.cloudkit.zone",
                                        ownerName: CKCurrentUserDefaultName)

    @MainActor
    static func run(userId: String) async -> Report {
        let container = CKContainer(identifier: "iCloud.com.gmail.taismryotasis.Travory")
        let status = try? await container.accountStatus()
        SyncDiagnosticsLog.recordAccount(status)

        let local = countLocal(userId: userId, context: CoreDataManager.shared.viewContext)

        let cloud: CloudResult
        if status == .available {
            cloud = await countCloud(userId: userId, database: container.privateCloudDatabase)
        } else {
            cloud = .skipped
        }

        let backup = TravelPlanBackupStore.load(userId: userId)
        return Report(userId: userId, accountStatus: status, local: local, cloud: cloud,
                      backupCount: backup?.plans.count, backupSavedAt: backup?.savedAt,
                      log: SyncDiagnosticsLog.entries())
    }

    /// 端末の中を数える
    static func countLocal(userId: String, context: NSManagedObjectContext) -> LocalCounts {
        var counts = LocalCounts()

        for row in fetchRows("TravelPlanEntity", keys: ["userId", "ownerId", "deletedAt"], context: context) {
            let owner = row["userId"] as? String
            let mine = owner == userId || (row["ownerId"] as? String) == userId
            if mine {
                if row["deletedAt"] == nil { counts.travelPlans += 1 } else { counts.trashedTravelPlans += 1 }
            } else {
                counts.otherUserTravelPlans[owner ?? "", default: 0] += 1
            }
        }
        for row in fetchRows("PlanEntity", keys: ["userId"], context: context) {
            if (row["userId"] as? String) == userId { counts.plans += 1 } else { counts.otherUserPlans += 1 }
        }
        for row in fetchRows("VisitedPlaceEntity", keys: ["userId"], context: context) {
            if (row["userId"] as? String) == userId { counts.places += 1 } else { counts.otherUserPlaces += 1 }
        }
        return counts
    }

    private static func fetchRows(_ entity: String, keys: [String], context: NSManagedObjectContext) -> [[String: Any]] {
        let request = NSFetchRequest<NSDictionary>(entityName: entity)
        request.resultType = .dictionaryResultType
        request.propertiesToFetch = keys
        return ((try? context.fetch(request)) ?? []).compactMap { $0 as? [String: Any] }
    }

    /// iCloud の中を数える。Core Data が使っている保存先の変更を最初から読む
    /// （検索用の索引が要らない読み方）。中身は読まず、数えるのに要る項目だけ取る
    static func countCloud(userId: String, database: CKDatabase) async -> CloudResult {
        var counts = CloudCounts()
        var token: CKServerChangeToken?
        do {
            repeat {
                let since = token
                let changes = try await withTimeout(seconds: 30) {
                    try await database.recordZoneChanges(
                        inZoneWith: zoneID, since: since,
                        desiredKeys: ["CD_userId", "CD_ownerId", "CD_deletedAt"], resultsLimit: 400)
                }
                for (_, result) in changes.modificationResultsByID {
                    guard case .success(let modification) = result else { continue }
                    let record = modification.record
                    counts.records += 1
                    let owner = record["CD_userId"] as? String
                    let mine = owner == userId || (record["CD_ownerId"] as? String) == userId
                    switch record.recordType {
                    case "CD_TravelPlanEntity":
                        if !mine {
                            counts.otherUserTravelPlans += 1
                        } else if record["CD_deletedAt"] == nil {
                            counts.travelPlans += 1
                        } else {
                            counts.trashedTravelPlans += 1
                        }
                    case "CD_PlanEntity":
                        if owner == userId { counts.plans += 1 }
                    case "CD_VisitedPlaceEntity":
                        if owner == userId { counts.places += 1 }
                    default:
                        break
                    }
                }
                token = changes.changeToken
                if !changes.moreComing { break }
            } while true
            return .counted(counts)
        } catch let error as CKError where error.code == .zoneNotFound {
            return .zoneMissing
        } catch let error as CKError where error.code == .userDeletedZone {
            return .zoneDeleted
        } catch {
            return .failed(SyncDiagnosticsLog.describe(error))
        }
    }

    private struct TimeoutError: Error {}

    private static func withTimeout<T: Sendable>(seconds: Double, _ body: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await body() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }
            defer { group.cancelAll() }
            return try await group.next()!
        }
    }

    // MARK: - 取り戻す

    /// この端末にある別の ID のデータを、今の人のものにする。
    ///
    /// 別の Apple アカウントでアプリにサインインし直すと、前の分は ID が違うため一覧に出ない。
    /// iCloud の保存先は iCloud のアカウントごとなので、ID を付け替えても他の人に見えることはない
    @discardableResult
    static func adoptOtherUserData(into userId: String, context: NSManagedObjectContext) -> Int {
        var changed = 0
        for entity in context.persistentStoreCoordinator?.managedObjectModel.entities ?? [] {
            guard let name = entity.name, entity.attributesByName["userId"] != nil else { continue }
            let request = NSFetchRequest<NSManagedObject>(entityName: name)
            request.predicate = NSPredicate(format: "userId != %@", userId)
            for object in (try? context.fetch(request)) ?? [] {
                // 共有で参加した旅行計画の持ち主（別の人の ID）は書き換えない
                let oldId = object.value(forKey: "userId") as? String
                if name == "TravelPlanEntity", let ownerId = object.value(forKey: "ownerId") as? String,
                   ownerId == oldId {
                    object.setValue(userId, forKey: "ownerId")
                }
                object.setValue(userId, forKey: "userId")
                if name == "TravelPlanEntity" { changed += 1 }
            }
        }
        guard context.hasChanges else { return 0 }
        do {
            try context.save()
            return changed
        } catch {
            context.rollback()
            return 0
        }
    }

    // MARK: - 送る文

    /// 開発者に送る文。件数・状態・同期の記録だけ（中身は含めない）
    static func text(for report: Report) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"

        var lines: [String] = []
        lines.append("判定: \(verdictCode(report.verdict))")
        lines.append("診断日時: \(formatter.string(from: report.date))")
        lines.append("ID末尾: \(shortId(report.userId))")
        lines.append("iCloud: \(SyncDiagnosticsLog.describe(report.accountStatus))")

        let l = report.local
        var localLine = "端末: 旅行\(l.travelPlans) ゴミ箱\(l.trashedTravelPlans) 予定\(l.plans) 場所\(l.places)"
        if l.otherUserTravelPlanCount + l.otherUserPlans + l.otherUserPlaces > 0 {
            let others = l.otherUserTravelPlans.map { "\(shortId($0.key))=\($0.value)" }.sorted().joined(separator: ",")
            localLine += " / 別ID 旅行\(l.otherUserTravelPlanCount)(\(others)) 予定\(l.otherUserPlans) 場所\(l.otherUserPlaces)"
        }
        lines.append(localLine)

        switch report.cloud {
        case .counted(let c):
            lines.append("iCloud内: 旅行\(c.travelPlans) ゴミ箱\(c.trashedTravelPlans) 別ID旅行\(c.otherUserTravelPlans) 予定\(c.plans) 場所\(c.places) 全レコード\(c.records)")
        case .zoneMissing: lines.append("iCloud内: 保存先なし")
        case .zoneDeleted: lines.append("iCloud内: 保存先が削除されている")
        case .skipped: lines.append("iCloud内: 未確認（iCloudが使えない）")
        case .failed(let error): lines.append("iCloud内: 確認失敗 \(error)")
        }

        if let count = report.backupCount, let savedAt = report.backupSavedAt {
            lines.append("控え: \(count)件 \(formatter.string(from: savedAt))")
        } else {
            lines.append("控え: なし")
        }

        let recent = report.log.suffix(25)
        if !recent.isEmpty {
            lines.append("記録:")
            for entry in recent {
                var line = "\(formatter.string(from: entry.date)) \(entry.kind.rawValue)"
                if let succeeded = entry.succeeded { line += succeeded ? " ok" : " NG" }
                if let detail = entry.detail { line += " \(detail)" }
                if let error = entry.error { line += " \(error)" }
                lines.append(line)
            }
        }
        return lines.joined(separator: "\n")
    }

    static func shortId(_ id: String) -> String {
        id.isEmpty ? "(なし)" : String(id.suffix(6))
    }

    private static func verdictCode(_ verdict: Verdict) -> String {
        switch verdict {
        case .fine(let count): return "fine(\(count))"
        case .partiallyLoaded(let local, let cloud): return "partiallyLoaded(\(local)/\(cloud))"
        case .inTrash(let count): return "inTrash(\(count))"
        case .otherUser(let count): return "otherUser(\(count))"
        case .iCloudUnavailable: return "iCloudUnavailable"
        case .cloudHasData(let count): return "cloudHasData(\(count))"
        case .cloudDeleted: return "cloudDeleted"
        case .cloudEmpty: return "cloudEmpty"
        case .unknown: return "unknown"
        }
    }
}
