import Foundation

/// 予定の時刻を「どこの時計で読むか」込みで扱う。
///
/// タイムスケジュールの予定は、日付ではなく**時:分だけ**が意味を持つ
/// （どの日かは `DaySchedule.dayNumber` が決める）。
/// その時:分を端末の時計で読んでいたため、海外に着くと時刻がずれていた。
/// 予定ごとの時間帯で読むよう、読み書きをここへ集める。
///
/// **時刻を出す・並べる場所では、`Calendar.current` や `DateFormatter` を直接使わず、ここを通すこと。**
enum ScheduleClock {

    /// 時間帯を持たない予定（2.7 より前に入れたもの）の時計。
    ///
    /// 端末の時間帯にすると、いま海外にいる人の予定がその場でずれる。
    /// 利用者の大半は日本で入力しているので、日本時間とみなす
    static let legacyTimeZone = TimeZone(identifier: "Asia/Tokyo")!

    static func calendar(in timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ja_JP")
        calendar.timeZone = timeZone
        return calendar
    }

    /// 時計の針を動かさずに、時間帯だけ付け替える（日本の 15:00 → パリの 15:00）。
    ///
    /// 「現地の時刻を日本時間として入れてしまった」予定を直すときと、
    /// 入力中に現地時間・日本時間を切り替えたときに使う
    static func keepingWallClock(_ date: Date, from source: TimeZone, to target: TimeZone) -> Date {
        let parts = calendar(in: source).dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: date
        )
        return calendar(in: target).date(from: parts) ?? date
    }

    /// "09:30"
    static func timeText(_ date: Date, in timeZone: TimeZone) -> String {
        text(date, format: "HH:mm", in: timeZone)
    }

    /// その時計で整形する（"M月d日(E) HH:mm" など）
    static func text(_ date: Date, format: String, in timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = timeZone
        formatter.dateFormat = format
        return formatter.string(from: date)
    }

    /// 識別子から時計を引く。無い・読めないときは日本時間
    static func timeZone(identifier: String?) -> TimeZone {
        identifier.flatMap(TimeZone.init(identifier:)) ?? legacyTimeZone
    }

    /// 見ている人の時計と違うときだけ添える印（"現地" / "日本"）。同じなら nil。
    ///
    /// 日本で見ているときはパリの予定に「現地」、パリで見ているときは
    /// 日本で入れた予定に「日本」が付く
    static func zoneLabel(_ zone: TimeZone, at date: Date,
                          destination: TimeZone?, viewer: TimeZone = .current) -> String? {
        guard !showsSameTime(zone, viewer, at: date) else { return nil }

        if let destination, showsSameTime(zone, destination, at: date) {
            return "現地"
        }
        if showsSameTime(zone, legacyTimeZone, at: date) {
            return "日本"
        }
        return displayName(of: zone)
    }

    /// その時計で 0:00 から何分か
    static func minutesOfDay(_ date: Date, in timeZone: TimeZone) -> Int {
        let parts = calendar(in: timeZone).dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    /// 2つの時計が、その日時に同じ時刻を指しているか。
    /// 名前が違っても時差が無ければ同じとみなす（東京とソウルなど）
    static func showsSameTime(_ lhs: TimeZone, _ rhs: TimeZone, at date: Date) -> Bool {
        lhs.secondsFromGMT(for: date) == rhs.secondsFromGMT(for: date)
    }

    /// 日本と時差がある時間帯か。現地時間・日本時間の切り替えを出すかどうかに使う
    static func isForeign(_ timeZone: TimeZone, at date: Date) -> Bool {
        !showsSameTime(timeZone, legacyTimeZone, at: date)
    }

    /// 「中央ヨーロッパ時間」のような名前。取れなければ "Europe/Paris" のまま
    static func displayName(of timeZone: TimeZone) -> String {
        timeZone.localizedName(for: .generic, locale: Locale(identifier: "ja_JP")) ?? timeZone.identifier
    }

    /// 日本との時差の説明（"日本より8時間遅い"）。時差が無ければ nil
    static func offsetFromJapanText(_ timeZone: TimeZone, at date: Date) -> String? {
        let diff = timeZone.secondsFromGMT(for: date) - legacyTimeZone.secondsFromGMT(for: date)
        guard diff != 0 else { return nil }
        let hours = Double(abs(diff)) / 3600
        let amount = hours == hours.rounded() ? "\(Int(hours))時間" : String(format: "%.1f時間", hours)
        return diff < 0 ? "日本より\(amount)遅い" : "日本より\(amount)早い"
    }
}

// MARK: - 予定から使う入口

extension ScheduleItem {

    /// この予定の時刻を読む時計
    var timeZone: TimeZone {
        ScheduleClock.timeZone(identifier: timeZoneIdentifier)
    }

    /// 画面に出す時刻（入れたとおりの時:分）
    var timeText: String {
        ScheduleClock.timeText(time, in: timeZone)
    }

    /// この予定の時計で、0:00 から何分か
    var minutesOfDay: Int {
        ScheduleClock.minutesOfDay(time, in: timeZone)
    }

    /// 並べ替えの鍵。**時間帯が違う予定どうしでも、実際に起きる順に並ぶ。**
    ///
    /// 時:分をそのまま比べると、日本を 22:00 に出てホノルルに同じ日の 10:00 に
    /// 着く便で、到着が出発より前に並んでしまう
    var chronologicalMinutes: Int {
        minutesOfDay - timeZone.secondsFromGMT(for: time) / 60
    }

    /// 起きる順に並べるための比較
    static func chronologically(_ lhs: ScheduleItem, _ rhs: ScheduleItem) -> Bool {
        lhs.chronologicalMinutes < rhs.chronologicalMinutes
    }

    /// 見ている人の時計と違うときだけ添える印（"現地" / "日本"）。同じなら nil。
    ///
    /// 日本で見ているときはパリの予定に「現地」、パリで見ているときは
    /// 日本で入れた予定に「日本」が付く
    func zoneLabel(destination: TimeZone?, viewer: TimeZone = .current) -> String? {
        ScheduleClock.zoneLabel(timeZone, at: time, destination: destination, viewer: viewer)
    }

    /// 時:分を変えずに、別の時間帯の予定として付け替える
    func keepingWallClock(in target: TimeZone) -> ScheduleItem {
        var copy = self
        copy.time = ScheduleClock.keepingWallClock(time, from: timeZone, to: target)
        copy.timeZoneIdentifier = target.identifier
        return copy
    }
}

// MARK: - 旅行計画まるごと

extension TravelPlan {

    /// 指定の時計になっていない予定の数
    func scheduleItemCount(notIn target: TimeZone) -> Int {
        daySchedules
            .flatMap(\.scheduleItems)
            .filter { !ScheduleClock.showsSameTime($0.timeZone, target, at: $0.time) }
            .count
    }

    /// 時:分を変えずに、すべての予定を指定の時計で読むものにする。
    ///
    /// 2.7 より前は時間帯を持てなかったので、海外旅行でも予定は日本時間として
    /// 入っている。「現地の 15:00」のつもりで入れた予定を、現地の 15:00 に直すためのもの
    func withScheduleTimes(keptIn target: TimeZone) -> TravelPlan {
        var updated = self
        updated.daySchedules = daySchedules.map { day in
            var copy = day
            copy.scheduleItems = day.scheduleItems.map { $0.keepingWallClock(in: target) }
            return copy
        }
        return updated
    }
}

// MARK: - 予約

extension Reservation {
    /// `date` を読む時計
    var dateTimeZone: TimeZone {
        ScheduleClock.timeZone(identifier: timeZoneIdentifier)
    }

    /// `arrivalDate` を読む時計
    var arrivalTimeZone: TimeZone {
        ScheduleClock.timeZone(identifier: arrivalTimeZoneIdentifier)
    }
}
