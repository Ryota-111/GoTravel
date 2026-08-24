import Foundation

extension Calendar {
    /// 時刻を無視した日数の差。
    ///
    /// `Date` をそのまま `dateComponents([.day], from:to:)` に渡すと時刻まで
    /// 比べてしまう。8/24 18:50 → 8/26 00:00 は 29時間しか離れていないため
    /// 「1日」と数えられ、2泊3日の旅行が1泊2日になり、
    /// タイムスケジュールの日タブも Day 2 までしか出なくなっていた。
    ///
    /// 保存されている日付は作成時の時刻を持ったままなので、
    /// **日数を数えるときは必ずこれを使うこと。**
    func dayDifference(from start: Date, to end: Date) -> Int {
        dateComponents([.day], from: startOfDay(for: start), to: startOfDay(for: end)).day ?? 0
    }
}
