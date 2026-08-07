import Foundation

extension DateFormatter {
    /// 日本語表記のフォーマッタ。
    ///
    /// タイムゾーンは端末の設定に従う。以前は Asia/Tokyo に固定していたが、
    /// 予定の入力に使う DatePicker は端末のタイムゾーンで値を書くため、
    /// 海外では入力した時刻と表示される時刻がずれていた。
    /// また、ここを使わず個別に組み立てているフォーマッタは端末側に従うので、
    /// 固定すると同じ予定が画面によって違う時刻に見えていた。
    /// 国内では端末のタイムゾーンが Asia/Tokyo のため表示は変わらない。
    static var japanese: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
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
