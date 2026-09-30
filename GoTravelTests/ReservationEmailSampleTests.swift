import Testing
import Foundation
@testable import GoTravel

/// 実際の予約確認メールで、読み取りの精度を測る。
///
/// メールは個人情報を含むので、リポジトリには入れない。
/// `~/Developer/travory-reservation-emails/` に置いた `.txt` と、同じ名前の
/// `.expected.json`（正解）を比べ、結果を同じフォルダの `report.md` に書き出す。
///
/// **精度を測るためのもの。外れてもテストは失敗にしない**（読み取りの改善で数字を上げていく）。
/// フォルダやメールが無ければ飛ばす
struct ReservationEmailSampleTests {

    /// `/Users/<名前>/Developer/travory-reservation-emails`。
    /// シミュレーターの中からでも Mac のフォルダを読めるので、このファイルの場所からホームを割り出す
    static var samplesFolder: URL {
        let parts = URL(fileURLWithPath: #filePath).pathComponents
        let home = parts.count > 2 ? "/" + parts[1...2].joined(separator: "/") : NSHomeDirectory()
        return URL(fileURLWithPath: home).appendingPathComponent("Developer/travory-reservation-emails")
    }

    /// サブフォルダ（「予約メールサンプル」など）の中も読む
    static var sampleFiles: [URL] {
        guard let enumerator = FileManager.default.enumerator(at: samplesFolder, includingPropertiesForKeys: nil) else { return [] }
        return enumerator.compactMap { $0 as? URL }
            .filter { $0.pathExtension == "txt" }
            .sorted { $0.path < $1.path }
    }

    /// 比べる項目。正解の JSON に書いた項目だけ比べる（null と書けば「読み取らないこと」が正解）
    private static let fields = ["kind", "title", "confirmationNumber", "transportNumber",
                                 "departurePlace", "arrivalPlace", "start", "arrival", "end"]

    @Test("実際のメールで精度を測る", .enabled(if: !sampleFiles.isEmpty))
    func measureAccuracy() throws {
        var fieldHits: [String: Int] = [:]
        var fieldTotals: [String: Int] = [:]
        var perfect = 0
        var measured = 0
        var lines: [String] = []

        for file in Self.sampleFiles {
            // サブフォルダのものは「フォルダ/名前」で出す
            let relative = file.path.replacingOccurrences(of: Self.samplesFolder.path + "/", with: "")
            let name = (relative as NSString).deletingPathExtension
            let expectedURL = file.deletingPathExtension().appendingPathExtension("expected.json")
            let text = try String(contentsOf: file, encoding: .utf8)

            guard let data = try? Data(contentsOf: expectedURL),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let expected = json["reservations"] as? [[String: Any]] else {
                lines.append("- `\(name)`：正解（.expected.json）がまだありません")
                continue
            }

            let referenceDate = (json["referenceDate"] as? String).flatMap(Self.parseDay) ?? Date()
            let drafts = ReservationEmailParser.parse(text, referenceDate: referenceDate)
            measured += 1

            var misses: [String] = []
            if drafts.count != expected.count {
                misses.append("件数 \(drafts.count)（正解 \(expected.count)）")
            }
            for (index, answer) in expected.enumerated() {
                let draft = index < drafts.count ? drafts[index] : nil
                for field in Self.fields where answer.keys.contains(field) {
                    let want = answer[field] as? String
                    let got = draft.flatMap { Self.value(of: field, in: $0) }
                    fieldTotals[field, default: 0] += 1
                    if want == got {
                        fieldHits[field, default: 0] += 1
                    } else {
                        misses.append("\(index + 1)件目の \(field)：\(got ?? "なし")（正解 \(want ?? "なし")）")
                    }
                }
            }

            if misses.isEmpty {
                perfect += 1
                lines.append("- `\(name)`：✅")
            } else {
                lines.append("- `\(name)`：" + misses.joined(separator: "、"))
            }
        }

        var report = ["# 予約メールの読み取り精度", "",
                      "測った日：\(Self.dayString(Date()))", "",
                      "**直さずに保存できた割合：\(perfect) / \(measured)**", "",
                      "| 項目 | 正解 |", "|---|---|"]
        for field in Self.fields where fieldTotals[field] != nil {
            let hits = fieldHits[field] ?? 0
            let total = fieldTotals[field] ?? 0
            report.append("| \(field) | \(hits) / \(total)（\(total == 0 ? 0 : hits * 100 / total)%） |")
        }
        report += ["", "## メールごと", ""] + lines

        let output = report.joined(separator: "\n")
        try? output.write(to: Self.samplesFolder.appendingPathComponent("report.md"), atomically: true, encoding: .utf8)
        print(output)
    }

    // MARK: - 比べやすい形にする

    private static func value(of field: String, in draft: ReservationDraft) -> String? {
        switch field {
        case "kind": return draft.kind.rawValue
        case "title": return draft.title.isEmpty ? nil : draft.title
        case "confirmationNumber": return draft.confirmationNumber
        case "transportNumber": return draft.transportNumber
        case "departurePlace": return draft.departurePlace
        case "arrivalPlace": return draft.arrivalPlace
        case "start": return text(of: draft.start)
        case "arrival": return text(of: draft.arrival)
        case "end": return text(of: draft.end)
        default: return nil
        }
    }

    /// "2026-10-06 07:00"（時刻が無ければ "2026-10-06"）
    private static func text(of c: DateComponents?) -> String? {
        guard let c, let y = c.year, let m = c.month, let d = c.day else { return nil }
        guard let h = c.hour else { return String(format: "%04d-%02d-%02d", y, m, d) }
        return String(format: "%04d-%02d-%02d %02d:%02d", y, m, d, h, c.minute ?? 0)
    }

    private static func parseDay(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }

    private static func dayString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
