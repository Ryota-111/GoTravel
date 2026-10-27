import Foundation

/// カレンダーの予定を .ics ファイルの中身にする（3.0）。
///
/// カレンダーへのアクセスを許可しなくても、共有シートで送って Google カレンダーなどに
/// 取り込めるようにするためのもの。一度きりの書き出しで、あとから直しても反映されない
enum CalendarICS {

    /// - Parameter uidPrefix: 予定の UID の頭。取り込み直したときに同じ予定として扱われるよう、
    ///   旅行計画の id などを渡す
    static func document(_ drafts: [CalendarEventDraft], uidPrefix: String, now: Date = Date()) -> String {
        var lines = [
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "PRODID:-//Travory//JP",
            "CALSCALE:GREGORIAN",
            "METHOD:PUBLISH"
        ]
        for draft in drafts {
            lines.append("BEGIN:VEVENT")
            lines.append("UID:\(uidPrefix)-\(draft.key)@travory")
            lines.append("DTSTAMP:\(utc(now))")
            if draft.isAllDay {
                // 終日の予定の終わりは「次の日」で書く決まり
                let calendar = ScheduleClock.calendar(in: draft.timeZone ?? .current)
                let endDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: draft.end)) ?? draft.end
                lines.append("DTSTART;VALUE=DATE:\(day(draft.start, calendar: calendar))")
                lines.append("DTEND;VALUE=DATE:\(day(endDay, calendar: calendar))")
            } else {
                // 時刻は世界時で書く。どの時間帯で開いても同じ瞬間になる
                lines.append("DTSTART:\(utc(draft.start))")
                lines.append("DTEND:\(utc(draft.end))")
            }
            lines.append("SUMMARY:\(escape(draft.title))")
            if let location = draft.location { lines.append("LOCATION:\(escape(location))") }
            if let notes = draft.notes { lines.append("DESCRIPTION:\(escape(notes))") }
            if let url = draft.url { lines.append("URL:\(url.absoluteString)") }
            lines.append("END:VEVENT")
        }
        lines.append("END:VCALENDAR")
        return lines.map(fold).joined(separator: "\r\n") + "\r\n"
    }

    /// 送るためのファイルを一時フォルダに書く
    static func writeFile(_ drafts: [CalendarEventDraft], uidPrefix: String, fileName: String) -> URL? {
        let safeName = fileName.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safeName).ics")
        do {
            try document(drafts, uidPrefix: uidPrefix).write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    // MARK: - 部品

    private static func utc(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return formatter.string(from: date)
    }

    private static func day(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d%02d%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// 決まりで特別な意味を持つ文字を逃がす
    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: "\r\n", with: "\\n")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    /// 1行は75バイトまで。超えたら折り返し、次の行の頭に空白を入れる（日本語の途中で切らない）
    static func fold(_ line: String) -> String {
        var result = ""
        var current = ""
        var bytes = 0
        for character in line {
            let size = String(character).utf8.count
            if bytes + size > 75 {
                result += current + "\r\n "
                current = ""
                bytes = 1
            }
            current.append(character)
            bytes += size
        }
        return result + current
    }
}
