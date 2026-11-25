import Testing
import Foundation
import UIKit
@testable import GoTravel

/// 実際の予約の見本を全部読み、正解・ルール・AI・最終を項目ごとに並べた表を書き出す（3.8）。
///
/// 目で確かめるためのもの。見本と同じフォルダ（git にも iCloud にも入らない）に
/// `report-detail.html`（画像と元の文つき）と `report-detail.md` を書く。外れてもテストは失敗にしない
struct ReservationEmailDetailReportTests {

    static let fields = ["kind", "title", "confirmationNumber", "transportNumber", "departurePlace", "arrivalPlace",
                         "start", "arrival", "end", "cost"]
    static let fieldLabels = ["kind": "種類", "title": "名前", "confirmationNumber": "予約番号", "transportNumber": "便名・列車名",
                              "departurePlace": "出発地", "arrivalPlace": "到着地", "start": "始まり・出発",
                              "arrival": "到着", "end": "終わり", "cost": "金額"]

    enum Verdict: String { case ok = "ok", wrong = "wrong", spurious = "spurious", missing = "missing", none = "none" }

    static func verdict(want: String?, wantKnown: Bool, got: String?) -> Verdict {
        guard wantKnown else { return .none }
        switch (want, got) {
        case let (w, g) where w == g: return .ok
        case (nil, _?): return .spurious
        case (_?, nil): return .missing
        default: return .wrong
        }
    }

    @Test("見本を全部読み、項目ごとの表を書き出す", .enabled(if: !ReservationEmailSampleTests.sampleFiles.isEmpty))
    func writeDetailedReport() async throws {
        let folder = ReservationEmailSampleTests.samplesFolder
        var html: [String] = []
        var md: [String] = []
        var counts: [String: [Verdict: Int]] = ["rules": [:], "final": [:]]
        var perfect: [String: Int] = ["rules": 0, "final": 0]
        var measured = 0
        var aiAvailable = false
        if #available(iOS 26.0, *) { aiAvailable = ReservationAIReader.isAvailable }

        for file in ReservationEmailSampleTests.sampleFiles {
            let relative = file.path.replacingOccurrences(of: folder.path + "/", with: "")
            let name = (relative as NSString).deletingPathExtension
            let isImage = ReservationEmailSampleTests.imageExtensions.contains(file.pathExtension.lowercased())
            let text = try await Self.sourceText(of: file, isImage: isImage)
            let expectedURL = file.deletingPathExtension().appendingPathExtension("expected.json")
            guard let data = try? Data(contentsOf: expectedURL),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let expected = json["reservations"] as? [[String: Any]] else { continue }
            let referenceDate = (json["referenceDate"] as? String).flatMap(Self.parseDay) ?? Date()
            measured += 1

            let rules = ReservationEmailParser.parse(text, referenceDate: referenceDate)
            var ai: [ReservationDraft]? = nil
            if #available(iOS 26.0, *), aiAvailable {
                let kind = rules.first?.kind ?? .other
                ai = await ReservationAIReader.suggest(text: text, kind: kind, referenceDate: referenceDate)
            }
            let final = ai.map { aiDrafts -> [ReservationDraft] in
                if #available(iOS 26.0, *) { return ReservationAIReader.merge(rules: rules, ai: aiDrafts) }
                return rules
            } ?? rules

            let count = max(expected.count, rules.count, final.count, ai?.count ?? 0)
            var rulesPerfect = rules.count == expected.count
            var finalPerfect = final.count == expected.count

            html.append("<section><h2>\(Self.escape(name))</h2>")
            html.append("<p class=meta>\(isImage ? "スクリーンショット" : "メール") ／ 基準日 \(json["referenceDate"] as? String ?? "-") ／ 件数：正解 \(expected.count)・ルール \(rules.count)・AI \(ai.map { "\($0.count)" } ?? "答えなし")・最終 \(final.count)</p>")
            if isImage {
                html.append("<img src=\"\(Self.escape(relative))\" loading=lazy>")
            }
            md.append("### \(name)（\(isImage ? "スクショ" : "メール")）")
            md.append("件数：正解 \(expected.count)・ルール \(rules.count)・AI \(ai.map { "\($0.count)" } ?? "答えなし")・最終 \(final.count)")
            md.append("")
            md.append("| # | 項目 | 正解 | ルール | AI | 最終 | 判定 |")
            md.append("|---|---|---|---|---|---|---|")

            html.append("<table><tr><th>#</th><th>項目</th><th>正解</th><th>ルール</th><th>AI（照合後）</th><th>最終</th></tr>")
            for index in 0..<count {
                let answer = index < expected.count ? expected[index] : [:]
                for field in Self.fields {
                    let known = answer.keys.contains(field)
                    let want = answer[field] as? String
                    let r = index < rules.count ? Self.value(field, rules[index]) : nil
                    let a = ai.flatMap { index < $0.count ? Self.value(field, $0[index]) : nil }
                    let f = index < final.count ? Self.value(field, final[index]) : nil
                    // どれにも値が無く、正解にも項目が無い行は出さない
                    if !known && r == nil && a == nil && f == nil { continue }
                    let vr = Self.verdict(want: want, wantKnown: known && index < expected.count, got: r)
                    let vf = Self.verdict(want: want, wantKnown: known && index < expected.count, got: f)
                    let va = Self.verdict(want: want, wantKnown: known && index < expected.count, got: a)
                    if known && index < expected.count {
                        counts["rules", default: [:]][vr, default: 0] += 1
                        counts["final", default: [:]][vf, default: 0] += 1
                        if vr != .ok { rulesPerfect = false }
                        if vf != .ok { finalPerfect = false }
                    }
                    let wantText = known ? (want ?? "（無し）") : "（正解に項目なし）"
                    html.append("<tr><td>\(index + 1)</td><td>\(Self.fieldLabels[field] ?? field)</td>"
                                + "<td class=want>\(Self.escape(wantText))</td>"
                                + "<td class=\(vr.rawValue)>\(Self.escape(r ?? "—"))</td>"
                                + "<td class=\(ai == nil ? "none" : va.rawValue)>\(Self.escape(ai == nil ? "答えなし" : (a ?? "—")))</td>"
                                + "<td class=\(vf.rawValue)>\(Self.escape(f ?? "—"))</td></tr>")
                    md.append("| \(index + 1) | \(Self.fieldLabels[field] ?? field) | \(wantText) | \(r ?? "—") | \(ai == nil ? "答えなし" : (a ?? "—")) | \(f ?? "—") | \(Self.mark(vr))/\(Self.mark(vf)) |")
                }
            }
            html.append("</table>")
            html.append("<details><summary>\(isImage ? "読み取った文字（OCR）" : "メールの本文")</summary><pre>\(Self.escape(text))</pre></details></section>")
            md.append("")
            if rulesPerfect { perfect["rules", default: 0] += 1 }
            if finalPerfect { perfect["final", default: 0] += 1 }
        }

        func summary(_ key: String) -> String {
            let c = counts[key] ?? [:]
            let total = c.values.reduce(0, +)
            return "直さずに保存できた \(perfect[key] ?? 0) / \(measured) ／ 項目：正解 \(c[.ok] ?? 0)・違う値 \(c[.wrong] ?? 0)・無いはずの値 \(c[.spurious] ?? 0)・空けた \(c[.missing] ?? 0)（全 \(total)）"
        }
        let head = """
        <!doctype html><meta charset=utf-8><title>予約の読み取り 詳細</title>
        <style>
        body{font:14px -apple-system,sans-serif;margin:24px;max-width:1100px}
        h2{margin-top:40px;border-bottom:1px solid #ccc}
        table{border-collapse:collapse;width:100%}td,th{border:1px solid #ddd;padding:4px 6px;vertical-align:top}
        .ok{background:#dff3e0}.wrong{background:#f8d0d0}.spurious{background:#fbe3c4}.missing{background:#e6e6e6}.none{color:#888}
        .want{font-weight:600}.meta{color:#555}img{max-width:420px;max-height:700px;border:1px solid #ccc;display:block;margin:8px 0}
        pre{white-space:pre-wrap;background:#f6f6f6;padding:8px}
        </style>
        <h1>予約の読み取り 詳細（\(Self.dayString(Date()))）</h1>
        <p>AI（端末の中の Foundation Models）：\(aiAvailable ? "使える" : "使えない")</p>
        <p><b>ルールだけ</b>：\(summary("rules"))<br><b>最終（ルール＋AI）</b>：\(summary("final"))</p>
        <p>色：<span class=ok>合っている</span> <span class=wrong>違う値</span> <span class=spurious>無いはずの値</span> <span class=missing>空けた</span>（正解に項目が無い行は判定しない）</p>
        """
        try? (head + html.joined(separator: "\n")).write(to: folder.appendingPathComponent("report-detail.html"), atomically: true, encoding: .utf8)
        let mdHead = ["# 予約の読み取り 詳細（\(Self.dayString(Date()))）", "",
                      "- AI：\(aiAvailable ? "使える" : "使えない")",
                      "- ルールだけ：\(summary("rules"))",
                      "- 最終（ルール＋AI）：\(summary("final"))",
                      "- 判定の印（ルール/最終）：○ 合っている、✕ 違う値、△ 無いはずの値、− 空けた、・ 正解に項目なし", ""]
        try? (mdHead + md).joined(separator: "\n").write(to: folder.appendingPathComponent("report-detail.md"), atomically: true, encoding: .utf8)
    }

    // MARK: - 補助

    static func mark(_ v: Verdict) -> String {
        switch v { case .ok: "○"; case .wrong: "✕"; case .spurious: "△"; case .missing: "−"; case .none: "・" }
    }

    static func sourceText(of file: URL, isImage: Bool) async throws -> String {
        guard isImage else { return try String(contentsOf: file, encoding: .utf8) }
        guard let image = UIImage(contentsOfFile: file.path)?.cgImage else { return "" }
        return (try? await ReservationImageTextReader.text(from: image)) ?? ""
    }

    static func value(_ field: String, _ draft: ReservationDraft) -> String? {
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
        case "cost": return draft.cost.map { String(Int($0)) }
        default: return nil
        }
    }

    static func text(of c: DateComponents?) -> String? {
        guard let c, let y = c.year, let m = c.month, let d = c.day else { return nil }
        guard let h = c.hour else { return String(format: "%04d-%02d-%02d", y, m, d) }
        return String(format: "%04d-%02d-%02d %02d:%02d", y, m, d, h, c.minute ?? 0)
    }

    static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
    }

    static func parseDay(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }

    static func dayString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
