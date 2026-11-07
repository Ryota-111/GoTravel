import Foundation
import MetricKit

/// MetricKit から届く「落ちた・固まった・止められた」の情報を受け取り、開発者に送る（3.4）。
///
/// - iOS が1日に1回ほど、前の日の計測（止められた回数）を渡してくる。落ちた・固まった記録は、次に起動したときに届く
/// - **メモリ不足で iOS に止められた回数も分かる。** 旅のダイジェストで落ちていた件はこれで、
///   ふつうのクラッシュの記録には残らなかった
/// - 送るのは `DiagnosticsSummary` がまとめた文だけ（個人の情報は入らない）。送り先はご意見と同じ CloudKit の公開データベース
/// - 設定（ヘルプ・サポート）の「不具合の情報を送る」をオフにしていれば、受け取っても送らない
/// - 送れなかった分は端末に取っておき、次に起動したときに送り直す
final class DiagnosticsReporter: NSObject, MXMetricManagerSubscriber {

    static let shared = DiagnosticsReporter()

    /// 送るかどうか（設定のスイッチ）。初めは送る
    static let enabledKey = "sendsDiagnostics"
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    /// まだ送れていない文
    private let pendingKey = "pendingDiagnostics"
    /// 取っておく数の上限（送れないまま溜まり続けないように）
    private let maxPending = 5

    private override init() {}

    /// 起動時に1回呼ぶ。MetricKit に登録し、前に送れなかった分を送り直す
    func start() {
        MXMetricManager.shared.add(self)
        Task { await flush() }
    }

    // MARK: MXMetricManagerSubscriber

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        let texts = payloads.compactMap { DiagnosticsSummary.diagnostics(fromJSON: $0.jsonRepresentation()) }
        enqueue(texts)
    }

    func didReceive(_ payloads: [MXMetricPayload]) {
        let texts = payloads.compactMap { DiagnosticsSummary.exits(fromJSON: $0.jsonRepresentation()) }
        enqueue(texts)
    }

    // MARK: 送る

    private func enqueue(_ texts: [String]) {
        guard Self.isEnabled, !texts.isEmpty else { return }
        var pending = UserDefaults.standard.stringArray(forKey: pendingKey) ?? []
        pending.append(contentsOf: texts)
        UserDefaults.standard.set(Array(pending.suffix(maxPending)), forKey: pendingKey)
        Task { await flush() }
    }

    /// 取っておいた文を順に送る。送れたものだけ消す
    func flush() async {
        guard Self.isEnabled else {
            // オフにしたら、取っておいた分も捨てる
            UserDefaults.standard.removeObject(forKey: pendingKey)
            return
        }
        var pending = UserDefaults.standard.stringArray(forKey: pendingKey) ?? []
        while let text = pending.first {
            guard await FeedbackService.shared.submitDiagnostic(text) else { break }
            pending.removeFirst()
            UserDefaults.standard.set(pending, forKey: pendingKey)
        }
    }
}
