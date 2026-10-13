import Foundation
import CloudKit
import CoreData
import Combine

/// iCloud が使えない・保存できていない状態を見張り、ホームに知らせるためのもの。
///
/// 旅行計画は iCloud（Core Data + CloudKit）に保存している。iCloud からサインアウトした、
/// 確認待ちになった、Travory の iCloud をオフにした、といったときは、端末の中のデータが
/// いったん片付けられ、一覧が空に見える。「全部消えた」というお問い合わせの多くがこれで、
/// 起動時のアラート1回だけでは気づけなかった（2026年10月）。
///
/// iCloud の容量がいっぱいで保存できていないときも知らせる。気づかずに機種変更すると、
/// 本当にデータを失うため
@MainActor
final class ICloudSyncMonitor: ObservableObject {

    static let shared = ICloudSyncMonitor()

    enum Problem: Equatable {
        /// iCloud にサインインしていない
        case notSignedIn
        /// パスワードの入力や規約の同意などの確認待ち
        case temporarilyUnavailable
        /// 機能制限（スクリーンタイムなど）で使えない
        case restricted
        /// iCloud の容量がいっぱいで、保存できていない
        case quotaExceeded
    }

    @Published private(set) var problem: Problem?

    private var accountProblem: Problem?
    private var quotaExceeded = false
    private var started = false

    private init() {}

    /// 起動したときに1回呼ぶ
    func start() {
        guard !started, !CoreDataManager.isEmptyDataMode else { return }
        started = true

        NotificationCenter.default.addObserver(forName: .CKAccountChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: CoreDataManager.shared.persistentContainer,
            queue: .main
        ) { [weak self] notification in
            guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event else { return }
            Task { @MainActor in self?.handle(event) }
        }
        refresh()
    }

    /// アカウントの状態を確かめ直す（アプリに戻ってきたときなど）
    func refresh() {
        Task {
            let status = try? await CKContainer(identifier: "iCloud.com.gmail.taismryotasis.Travory").accountStatus()
            accountProblem = Self.problem(for: status)
            SyncDiagnosticsLog.recordAccount(status)
            publish()
        }
    }

    // MARK: - 中身（判断はテストで確かめる）

    /// アカウントの状態から、知らせることを決める。
    /// 分からない（`couldNotDetermine`、通信できないときなど）は知らせない。圏外のたびに騒がないため
    nonisolated static func problem(for status: CKAccountStatus?) -> Problem? {
        switch status {
        case .noAccount: return .notSignedIn
        case .temporarilyUnavailable: return .temporarilyUnavailable
        case .restricted: return .restricted
        default: return nil
        }
    }

    /// 同期の結果から、容量の問題が起きているかを決める。
    /// 書き出しが成功したら解消とみなす
    nonisolated static func isQuotaError(_ error: Error?) -> Bool {
        guard let ckError = error as? CKError else { return false }
        if ckError.code == .quotaExceeded { return true }
        if ckError.code == .partialFailure,
           let partial = ckError.partialErrorsByItemID?.values {
            return partial.contains { ($0 as? CKError)?.code == .quotaExceeded }
        }
        return false
    }

    private func handle(_ event: NSPersistentCloudKitContainer.Event) {
        guard event.endDate != nil else { return }   // 終わった知らせだけを見る
        SyncDiagnosticsLog.record(event)   // データの診断で見せる記録
        if Self.isQuotaError(event.error) {
            quotaExceeded = true
        } else if event.type == .export, event.succeeded {
            quotaExceeded = false
        }
        publish()
    }

    private func publish() {
        // アカウントの問題を先に出す（サインインしていなければ、容量の話は意味がない）
        problem = accountProblem ?? (quotaExceeded ? .quotaExceeded : nil)
    }
}
