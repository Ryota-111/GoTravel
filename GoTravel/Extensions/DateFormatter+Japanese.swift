import Foundation

extension DateFormatter {
    static var japanese: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        return formatter
    }

    static var japaneseDate: DateFormatter {
        let formatter = DateFormatter.japanese
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }

    static var japaneseDateShort: DateFormatter {
        let formatter = DateFormatter.japanese
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }

    static var japaneseDateLong: DateFormatter {
        let formatter = DateFormatter.japanese
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }

    static var japaneseTime: DateFormatter {
        let formatter = DateFormatter.japanese
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }

    static var japaneseDateTime: DateFormatter {
        let formatter = DateFormatter.japanese
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }

    static var japaneseMonthDay: DateFormatter {
        let formatter = DateFormatter.japanese
        formatter.dateFormat = "M月d日"
        return formatter
    }

    static var japaneseYearMonthDay: DateFormatter {
        let formatter = DateFormatter.japanese
        formatter.dateFormat = "yyyy年M月d日"
        return formatter
    }

    static var japaneseWeekday: DateFormatter {
        let formatter = DateFormatter.japanese
        formatter.dateFormat = "EEEE"
        return formatter
    }
}

extension Date {
    func japaneseFormatted(_ style: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter.japanese
        formatter.dateStyle = style
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }

    func japaneseMonthDay() -> String {
        DateFormatter.japaneseMonthDay.string(from: self)
    }

    func japaneseYearMonthDay() -> String {
        DateFormatter.japaneseYearMonthDay.string(from: self)
    }

    func japaneseWeekday() -> String {
        DateFormatter.japaneseWeekday.string(from: self)
    }
}
