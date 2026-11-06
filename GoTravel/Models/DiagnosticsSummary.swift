import Foundation

/// MetricKit から届いた診断（JSON）を、送るための短い文にまとめる。
///
/// **個人の情報は入れない。** 入るのは、落ちた・固まった場所（どの部品の何バイト目か）、
/// 落ち方の種類、アプリと OS の版、機種、止められた回数だけ。旅行計画や写真などのデータは含まれない。
///
/// 場所は記号の名前ではなく「部品の UUID とずれ」で届く。読み解くには、そのビルドの dSYM と
/// `atos -arch arm64 -o GoTravel.app.dSYM/Contents/Resources/DWARF/GoTravel -l 0x100000000 <ずれ+0x100000000>` を使う
///
/// JSON の形は Apple の `MXDiagnosticPayload.jsonRepresentation()` / `MXMetricPayload.jsonRepresentation()`。
/// 鍵の名前が変わっても落ちないよう、辞書として読み、無い鍵は飛ばす
enum DiagnosticsSummary {

    /// 落ちたときの処理の段を、上から何段まで送るか
    static let maxFrames = 30
    /// 1回に送る文の長さの上限（CloudKit の1件の大きさに余裕を持たせる）
    static let maxLength = 12_000

    // MARK: 落ちた・固まった（MXDiagnosticPayload）

    /// 診断の JSON から、落ちた・固まったことをまとめた文。何も無ければ nil
    static func diagnostics(fromJSON data: Data) -> String? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        var sections: [String] = []

        for crash in root["crashDiagnostics"] as? [[String: Any]] ?? [] {
            let meta = crash["diagnosticMetaData"] as? [String: Any] ?? [:]
            var lines = ["■ 落ちた", versionLine(meta)]
            if let type = meta["exceptionType"] { lines.append("例外の種類: \(type)  コード: \(meta["exceptionCode"] ?? "-")  シグナル: \(meta["signal"] ?? "-")") }
            if let reason = meta["terminationReason"] as? String { lines.append("理由: \(reason)") }
            if let message = (crash["exceptionReason"] as? [String: Any])?["composedMessage"] as? String {
                lines.append("例外: \(message)")
            }
            lines.append(contentsOf: frames(of: crash["callStackTree"]))
            sections.append(lines.joined(separator: "\n"))
        }

        for hang in root["hangDiagnostics"] as? [[String: Any]] ?? [] {
            let meta = hang["diagnosticMetaData"] as? [String: Any] ?? [:]
            var lines = ["■ 固まった", versionLine(meta)]
            if let duration = meta["hangDuration"] { lines.append("固まった時間: \(duration)") }
            lines.append(contentsOf: frames(of: hang["callStackTree"]))
            sections.append(lines.joined(separator: "\n"))
        }

        guard !sections.isEmpty else { return nil }
        return String(sections.joined(separator: "\n\n").prefix(maxLength))
    }

    // MARK: 止められた回数（MXMetricPayload）

    /// 1日分の計測の JSON から、ふつうでない終わり方（メモリ不足で止められた・落ちた・固まって止められた）の回数。
    /// ふつうの終わり方しか無ければ nil
    static func exits(fromJSON data: Data) -> String? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exits = root["applicationExitMetrics"] as? [String: Any] else { return nil }
        var lines: [String] = []
        for (scope, label) in [("foregroundExitData", "画面に出ているとき"), ("backgroundExitData", "裏にいるとき")] {
            guard let counts = exits[scope] as? [String: Any] else { continue }
            let abnormal = counts
                .compactMap { key, value -> (String, Int)? in
                    guard let count = (value as? NSNumber)?.intValue, count > 0,
                          !key.localizedCaseInsensitiveContains("Normal") else { return nil }
                    return (exitLabel(key), count)
                }
                .sorted { $0.0 < $1.0 }
            guard !abnormal.isEmpty else { continue }
            lines.append("\(label): " + abnormal.map { "\($0.0) \($0.1)回" }.joined(separator: "、"))
        }
        guard !lines.isEmpty else { return nil }
        let meta = root["metaData"] as? [String: Any] ?? [:]
        return (["■ ふつうでない終わり方（1日分）", versionLine(meta)] + lines).joined(separator: "\n")
    }

    // MARK: - Helpers

    private static func versionLine(_ meta: [String: Any]) -> String {
        let app = meta["appVersion"] as? String ?? "?"
        let build = meta["appBuildVersion"] as? String ?? "?"
        let os = meta["osVersion"] as? String ?? "?"
        let device = meta["deviceType"] as? String ?? "?"
        return "版: \(app)（\(build)） / \(os) / \(device)"
    }

    /// 落ちた（または固まった）スレッドの処理の段を、上から順に1行ずつ
    static func frames(of tree: Any?) -> [String] {
        guard let tree = tree as? [String: Any],
              let stacks = tree["callStacks"] as? [[String: Any]] else { return [] }
        let stack = stacks.first { ($0["threadAttributed"] as? Bool) == true } ?? stacks.first
        var result: [String] = []
        var frame = (stack?["callStackRootFrames"] as? [[String: Any]])?.first
        while let current = frame, result.count < maxFrames {
            let binary = current["binaryName"] as? String ?? "?"
            let offset = (current["offsetIntoBinaryTextSegment"] as? NSNumber)?.uint64Value ?? 0
            let uuid = (current["binaryUUID"] as? String).map { " [\($0.prefix(8))]" } ?? ""
            result.append("  \(result.count)  \(binary) +0x\(String(offset, radix: 16))\(uuid)")
            frame = (current["subFrames"] as? [[String: Any]])?.first
        }
        return result
    }

    /// 「cumulativeMemoryResourceLimitExitCount」→「メモリの上限」
    private static func exitLabel(_ key: String) -> String {
        let names: [(String, String)] = [
            ("MemoryResourceLimit", "メモリの上限で止められた"),
            ("MemoryPressure", "メモリ不足で止められた"),
            ("AppWatchdog", "固まって止められた"),
            ("Watchdog", "固まって止められた"),
            ("BadAccess", "落ちた（不正なメモリ参照）"),
            ("IllegalInstruction", "落ちた（不正な命令）"),
            ("Abnormal", "落ちた（そのほか）"),
            ("CPUResourceLimit", "CPU の使いすぎで止められた"),
            ("BackgroundTaskAssertionTimeout", "裏での処理が長すぎて止められた"),
            ("SuspendedWithLockedFile", "ファイルを開いたまま止められた")
        ]
        return names.first { key.contains($0.0) }?.1 ?? key
    }
}
