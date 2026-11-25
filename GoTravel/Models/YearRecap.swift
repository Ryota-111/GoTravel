import Foundation

/// 年末の「◯年の旅をふり返る」（3.8）。
///
/// 年末は、1年の振り返りが SNS でいちばん広まる時期。「記録」にはストーリー用の画像を作って送る機能があるが、
/// 「記録」の中にあって気づかれにくい。12月1日〜1月15日だけ、思い出タブの上に入口を出す。
/// 1月はまだ前の年のふり返りを出す（年が明けてから見返す人もいるため）
enum YearRecap {

    /// その日にふり返る年。季節でなければ nil
    static func year(on date: Date, calendar: Calendar = .current) -> Int? {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = parts.year, let month = parts.month, let day = parts.day else { return nil }
        if month == 12 { return year }
        if month == 1 && day <= 15 { return year - 1 }
        return nil
    }

    /// 入口を出すか。季節で、その年に出発した旅行があり、閉じていないとき
    static func yearToShow(plans: [TravelPlan], now: Date = Date(), calendar: Calendar = .current,
                           defaults: UserDefaults = .standard) -> Int? {
        guard let year = year(on: now, calendar: calendar),
              !defaults.bool(forKey: dismissedKey(year)),
              plans.contains(where: { calendar.component(.year, from: $0.startDate) == year }) else { return nil }
        return year
    }

    static func dismiss(_ year: Int, defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: dismissedKey(year))
    }

    private static func dismissedKey(_ year: Int) -> String { "YearRecapDismissed_\(year)" }
}
