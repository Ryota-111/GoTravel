import Foundation
import CryptoKit

// MARK: - .ics ファイルの読み込み（3.0）
//
// 他のカレンダーから書き出した .ics を、Travory の予定（おでかけ・日常・記念日）にする。
// 「Travory で開く」とカレンダーのメニューから読み込み、確かめてから入れる（`ICSImportView`）。
//
// - **同じ予定は2重にしない。** 予定の id を .ics の UID から決めるので、同じファイルを
//   もう一度読み込むと、同じ予定を新しい内容で直す（Core Data に項目を足さずに済む）
// - 繰り返しは Travory にある「毎週・毎月・毎年」だけ。ほかの繰り返しは1回目だけ入れる
// - 書き出し（`CalendarICS`）は一度きりの写し。読み込みも同じで、あとで元が変わっても追いかけない

/// .ics の予定1件（読み取ったそのまま）
struct ICSEvent: Equatable {
    var uid: String?
    var summary: String
    var description: String?
    var location: String?
    var url: String?
    var start: Date
    /// 終わり（終日なら次の日の 0:00 で、その日は含まない。.ics の決まり）
    var end: Date?
    var isAllDay: Bool
    var rrule: String?
    /// 繰り返しの中の1回だけを変えた予定の印
    var recurrenceId: String?
    var isCancelled = false
}

enum ICSParser {

    /// .ics の中身から予定を取り出す。読めない行は飛ばす
    static func parse(_ text: String) -> [ICSEvent] {
        var events: [ICSEvent] = []
        var current: [(name: String, params: [String: String], value: String)]?
        var depth = 0  // VEVENT の中の VALARM などを読み飛ばすため

        for line in unfold(text) {
            guard let (name, params, value) = split(line) else { continue }
            if name == "BEGIN" {
                if value == "VEVENT" { current = []; depth = 0 } else if current != nil { depth += 1 }
                continue
            }
            if name == "END" {
                if value == "VEVENT", let props = current {
                    if let event = event(from: props) { events.append(event) }
                    current = nil
                } else if current != nil {
                    depth -= 1
                }
                continue
            }
            if depth == 0 { current?.append((name, params, value)) }
        }
        return events
    }

    /// 折り返された行（次の行が空白で始まる）をつなぐ
    static func unfold(_ text: String) -> [String] {
        var lines: [String] = []
        for raw in text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n") {
            if let first = raw.first, first == " " || first == "\t", !lines.isEmpty {
                lines[lines.count - 1] += raw.dropFirst()
            } else if !raw.isEmpty {
                lines.append(raw)
            }
        }
        return lines
    }

    /// "DTSTART;TZID=Asia/Tokyo:20261020T090000" → 名前・引数・値
    private static func split(_ line: String) -> (String, [String: String], String)? {
        // 値の中の ":" で切らないよう、引数の "..." の外にある最初の ":" で分ける
        var inQuotes = false
        var colon: String.Index?
        for index in line.indices {
            let ch = line[index]
            if ch == "\"" { inQuotes.toggle() }
            if ch == ":" && !inQuotes { colon = index; break }
        }
        guard let colon else { return nil }
        let head = line[..<colon]
        let value = String(line[line.index(after: colon)...])
        var parts = head.split(separator: ";").map(String.init)
        guard !parts.isEmpty else { return nil }
        let name = parts.removeFirst().uppercased()
        var params: [String: String] = [:]
        for part in parts {
            let kv = part.split(separator: "=", maxSplits: 1).map(String.init)
            if kv.count == 2 {
                params[kv[0].uppercased()] = kv[1].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }
        }
        return (name, params, value)
    }

    private static func event(from props: [(name: String, params: [String: String], value: String)]) -> ICSEvent? {
        func prop(_ name: String) -> (params: [String: String], value: String)? {
            props.first { $0.name == name }.map { ($0.params, $0.value) }
        }
        guard let dtstart = prop("DTSTART"), let start = date(dtstart.value, params: dtstart.params) else { return nil }
        let summary = prop("SUMMARY").map { unescape($0.value) }?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        var end: Date?
        if let dtend = prop("DTEND") {
            end = date(dtend.value, params: dtend.params)?.date
        } else if let duration = prop("DURATION"), let seconds = durationSeconds(duration.value) {
            end = start.date.addingTimeInterval(seconds)
        }

        return ICSEvent(
            uid: prop("UID")?.value.trimmingCharacters(in: .whitespaces),
            summary: summary.isEmpty ? "（題名なし）" : summary,
            description: prop("DESCRIPTION").map { unescape($0.value) }.flatMap(nonEmpty),
            location: prop("LOCATION").map { unescape($0.value) }.flatMap(nonEmpty),
            url: prop("URL").map(\.value).flatMap(nonEmpty),
            start: start.date,
            end: end,
            isAllDay: start.isAllDay,
            rrule: prop("RRULE")?.value,
            recurrenceId: prop("RECURRENCE-ID")?.value,
            isCancelled: prop("STATUS")?.value.uppercased() == "CANCELLED"
        )
    }

    private static func nonEmpty(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    /// 日付・日時を読む。
    /// - "20261020"（終日）→ この端末の時間帯のその日の 0:00
    /// - "20261020T090000Z" → 世界標準時
    /// - "20261020T090000" と TZID → その時間帯。TZID が無ければこの端末の時間帯
    static func date(_ value: String, params: [String: String], localZone: TimeZone = .current) -> (date: Date, isAllDay: Bool)? {
        let v = value.trimmingCharacters(in: .whitespaces)
        let digits = v.filter(\.isNumber)
        let isAllDay = params["VALUE"]?.uppercased() == "DATE" || (!v.contains("T") && digits.count == 8)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = localZone

        func number(_ from: Int, _ length: Int) -> Int? {
            guard digits.count >= from + length else { return nil }
            let start = digits.index(digits.startIndex, offsetBy: from)
            return Int(digits[start..<digits.index(start, offsetBy: length)])
        }
        guard let year = number(0, 4), let month = number(4, 2), let day = number(6, 2) else { return nil }

        if isAllDay {
            return calendar.date(from: DateComponents(year: year, month: month, day: day)).map { ($0, true) }
        }
        guard let hour = number(8, 2), let minute = number(10, 2) else { return nil }
        let second = number(12, 2) ?? 0
        if v.hasSuffix("Z") {
            calendar.timeZone = TimeZone(identifier: "UTC")!
        } else if let tzid = params["TZID"], let zone = timeZone(tzid) {
            calendar.timeZone = zone
        }
        return calendar.date(from: DateComponents(year: year, month: month, day: day,
                                                  hour: hour, minute: minute, second: second)).map { ($0, false) }
    }

    /// TZID を時間帯にする。Outlook の書き出しに多い Windows の名前も、よく使うものは読む
    static func timeZone(_ tzid: String) -> TimeZone? {
        if let zone = TimeZone(identifier: tzid) { return zone }
        let windows: [String: String] = [
            "Tokyo Standard Time": "Asia/Tokyo",
            "Korea Standard Time": "Asia/Seoul",
            "China Standard Time": "Asia/Shanghai",
            "Taipei Standard Time": "Asia/Taipei",
            "Singapore Standard Time": "Asia/Singapore",
            "SE Asia Standard Time": "Asia/Bangkok",
            "AUS Eastern Standard Time": "Australia/Sydney",
            "Hawaiian Standard Time": "Pacific/Honolulu",
            "Pacific Standard Time": "America/Los_Angeles",
            "Mountain Standard Time": "America/Denver",
            "Central Standard Time": "America/Chicago",
            "Eastern Standard Time": "America/New_York",
            "GMT Standard Time": "Europe/London",
            "W. Europe Standard Time": "Europe/Berlin",
            "Romance Standard Time": "Europe/Paris",
            "UTC": "UTC"
        ]
        if let name = windows[tzid] { return TimeZone(identifier: name) }
        // "/mozilla.org/20050126_1/Asia/Tokyo" のような前置きつき
        if let range = tzid.range(of: #"[A-Za-z]+/[A-Za-z_]+$"#, options: .regularExpression) {
            return TimeZone(identifier: String(tzid[range]))
        }
        return nil
    }

    /// "PT1H30M" / "P1D" / "P1W" → 秒
    static func durationSeconds(_ value: String) -> TimeInterval? {
        var v = value.uppercased()
        let negative = v.hasPrefix("-")
        v = v.trimmingCharacters(in: CharacterSet(charactersIn: "+-"))
        guard v.hasPrefix("P") else { return nil }
        var total: TimeInterval = 0
        var number = ""
        var inTime = false
        for ch in v.dropFirst() {
            if ch.isNumber { number.append(ch); continue }
            if ch == "T" { inTime = true; continue }
            let n = TimeInterval(number) ?? 0
            number = ""
            switch ch {
            case "W": total += n * 7 * 86_400
            case "D": total += n * 86_400
            case "H" where inTime: total += n * 3_600
            case "M" where inTime: total += n * 60
            case "S" where inTime: total += n
            default: return nil
            }
        }
        return negative ? -total : total
    }

    /// 文字の決まりごと（\n・\,・\;・\\）を戻す
    static func unescape(_ value: String) -> String {
        var out = ""
        var escaping = false
        for ch in value {
            if escaping {
                switch ch {
                case "n", "N": out.append("\n")
                default: out.append(ch)
                }
                escaping = false
            } else if ch == "\\" {
                escaping = true
            } else {
                out.append(ch)
            }
        }
        return out
    }
}

// MARK: - 予定にする（純粋関数。テストで確かめる）

enum ICSImportRule {

    /// 読み込んだ予定1件の行き先
    struct Candidate: Identifiable, Equatable {
        var plan: Plan
        /// 入れるときに知らせること（「毎日の繰り返しは入れられないので1回目だけ」など）
        var notes: [String]
        var id: String { plan.id }
    }

    /// 予定の id。同じ UID なら同じ id になる（読み込み直したときに2重にしないため）
    static func planId(for event: ICSEvent) -> String {
        let key = event.uid ?? "\(event.summary)|\(event.start.timeIntervalSince1970)"
        let digest = SHA256.hash(data: Data(key.utf8))
        return "ics-" + digest.prefix(16).map { String(format: "%02x", $0) }.joined()
    }

    /// 読み込む予定の一覧。取り消された予定と、繰り返しの中の1回だけを変えた予定は入れない
    static func candidates(from events: [ICSEvent], now: Date = Date(), calendar: Calendar = .current) -> [Candidate] {
        var seen = Set<String>()
        return events.compactMap { event in
            guard !event.isCancelled, event.recurrenceId == nil else { return nil }
            let candidate = self.candidate(from: event, now: now, calendar: calendar)
            guard seen.insert(candidate.plan.id).inserted else { return nil }
            return candidate
        }
        .sorted { $0.plan.startDate < $1.plan.startDate }
    }

    static func candidate(from event: ICSEvent, now: Date = Date(), calendar: Calendar = .current) -> Candidate {
        var notes: [String] = []
        let id = planId(for: event)
        let description = [event.location.map { "場所：\($0)" }, event.description]
            .compactMap { $0 }.joined(separator: "\n")
        let linkURL = event.url

        var recurrence = PlanRecurrence.none
        var start = event.start
        var end = event.end ?? (event.isAllDay ? calendar.date(byAdding: .day, value: 1, to: event.start)! : event.start)
        if end < start { end = start }

        if let rrule = event.rrule {
            let rule = parseRRule(rrule)
            switch rule.recurrence {
            case .some(let r):
                // 繰り返しが今日より前に終わっていれば、繰り返さない予定として入れる
                if let last = lastOccurrence(start: start, rule: rule, recurrence: r, calendar: calendar),
                   calendar.startOfDay(for: last) < calendar.startOfDay(for: now) {
                    break
                }
                recurrence = r
                // 繰り返しの1回目が過ぎていれば、今日以降の最初の回から始める（過ぎた回をまとめて作らない）
                let span = end.timeIntervalSince(start)
                var next = start
                var guardCount = 0
                while calendar.startOfDay(for: next) < calendar.startOfDay(for: now), guardCount < 2_000,
                      let n = step(r, after: next, calendar: calendar) {
                    next = n; guardCount += 1
                }
                start = next
                end = next.addingTimeInterval(span)
            case .none:
                notes.append("「\(rule.label)」の繰り返しは Travory に無いため、1回目だけ入れます")
            }
        }

        let duration = end.timeIntervalSince(start)
        let plan: Plan
        if event.isAllDay {
            let firstDay = calendar.startOfDay(for: start)
            // 終日の終わりは「次の日の 0:00（含まない）」なので、1日戻した日が最後の日
            let lastDay = max(firstDay, calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: end)) ?? firstDay)
            if recurrence == .yearly && calendar.isDate(firstDay, inSameDayAs: lastDay) {
                plan = Plan(id: id, title: event.summary, startDate: firstDay, endDate: firstDay, places: [],
                            planType: .anniversary, description: nonEmpty(description), linkURL: linkURL, recurrence: .yearly)
            } else {
                if recurrence != .none {
                    notes.append("何日かにわたる予定の繰り返しは入れません（1回目だけ）")
                }
                plan = Plan(id: id, title: event.summary, startDate: firstDay, endDate: lastDay, places: [],
                            planType: .outing, description: nonEmpty(description), linkURL: linkURL)
            }
        } else if duration >= 86_400 {
            // 24時間以上つづく予定は、日付の範囲を持つ「おでかけ」にする
            if recurrence != .none {
                notes.append("何日かにわたる予定の繰り返しは入れません（1回目だけ）")
            }
            plan = Plan(id: id, title: event.summary, startDate: calendar.startOfDay(for: start),
                        endDate: calendar.startOfDay(for: end), places: [], planType: .outing,
                        description: nonEmpty(description), linkURL: linkURL)
        } else {
            plan = Plan(id: id, title: event.summary, startDate: start, endDate: start, places: [],
                        planType: .daily, time: start, endTime: duration > 0 ? end : nil,
                        description: nonEmpty(description), linkURL: linkURL, recurrence: recurrence)
        }
        return Candidate(plan: plan, notes: notes)
    }

    /// 手元にある同じ予定へ、読み込んだ内容を重ねる。
    /// 通知・済みの印・写真・タグ・カテゴリは手元のまま（読み込みで消さない）
    static func merged(_ incoming: Plan, into local: Plan) -> Plan {
        var copy = local
        copy.title = incoming.title
        copy.startDate = incoming.startDate
        copy.endDate = incoming.endDate
        copy.planType = incoming.planType
        copy.time = incoming.time
        copy.endTime = incoming.endTime
        copy.description = incoming.description
        copy.linkURL = incoming.linkURL
        copy.recurrence = incoming.recurrence
        return copy
    }

    enum Status: Equatable {
        /// 新しく入る
        case new
        /// 同じ予定があり、中身が変わる
        case update
        /// 同じ予定があり、中身も同じ
        case unchanged
        /// 繰り返しの予定で、次の回へ進んでいる（手元の回を直すと2重になるので触らない）
        case recurringInProgress
    }

    static func status(of incoming: Plan, local: Plan?) -> Status {
        guard let local else { return .new }
        if local.recurrence != .none && local.isCompleted { return .recurringInProgress }
        return merged(incoming, into: local) == local ? .unchanged : .update
    }

    // MARK: 繰り返し

    struct RRule {
        var recurrence: PlanRecurrence?
        var label: String
        var until: Date?
        var count: Int?
    }

    static func parseRRule(_ value: String) -> RRule {
        var parts: [String: String] = [:]
        for part in value.split(separator: ";") {
            let kv = part.split(separator: "=", maxSplits: 1).map(String.init)
            if kv.count == 2 { parts[kv[0].uppercased()] = kv[1] }
        }
        let freq = parts["FREQ"]?.uppercased() ?? ""
        let interval = Int(parts["INTERVAL"] ?? "1") ?? 1
        // 「毎週月・水」のように1回に何日もある繰り返しは、Travory の「毎週」では表せない
        let manyDays = (parts["BYDAY"]?.split(separator: ",").count ?? 0) > 1
        let until = parts["UNTIL"].flatMap { ICSParser.date($0, params: [:])?.date }
        let count = parts["COUNT"].flatMap { Int($0) }

        let label: String
        switch freq {
        case "DAILY": label = interval == 1 ? "毎日" : "\(interval)日ごと"
        case "WEEKLY": label = interval == 1 ? (manyDays ? "毎週（何曜日か）" : "毎週") : "\(interval)週ごと"
        case "MONTHLY": label = interval == 1 ? "毎月" : "\(interval)か月ごと"
        case "YEARLY": label = interval == 1 ? "毎年" : "\(interval)年ごと"
        default: label = "この"
        }
        guard interval == 1, !manyDays else { return RRule(recurrence: nil, label: label, until: until, count: count) }
        let recurrence: PlanRecurrence? = switch freq {
        case "WEEKLY": .weekly
        case "MONTHLY": .monthly
        case "YEARLY": .yearly
        default: nil
        }
        return RRule(recurrence: recurrence, label: label, until: until, count: count)
    }

    /// 繰り返しの最後の回（終わりが無ければ nil）
    private static func lastOccurrence(start: Date, rule: RRule, recurrence: PlanRecurrence, calendar: Calendar) -> Date? {
        if let until = rule.until { return until }
        guard let count = rule.count else { return nil }
        var date = start
        for _ in 1..<max(count, 1) {
            guard let next = step(recurrence, after: date, calendar: calendar) else { break }
            date = next
        }
        return date
    }

    /// 次の回（`PlanRecurrence.nextDate` と同じ計算を、渡したカレンダーで行う）
    private static func step(_ recurrence: PlanRecurrence, after date: Date, calendar: Calendar) -> Date? {
        switch recurrence {
        case .none: return nil
        case .weekly: return calendar.date(byAdding: .weekOfYear, value: 1, to: date)
        case .monthly: return calendar.date(byAdding: .month, value: 1, to: date)
        case .yearly: return calendar.date(byAdding: .year, value: 1, to: date)
        }
    }

    private static func nonEmpty(_ s: String) -> String? {
        s.isEmpty ? nil : s
    }
}
