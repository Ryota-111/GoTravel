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

    static let homeTimeZoneKey = "homeTimeZone"

    /// 旅行の日付（出発日・帰る日）を読む時計。住んでいる地域の時間帯で、選んでいなければ日本時間（3.3）。
    ///
    /// 旅行の日付は、入れた時刻ごと保存されている。日本に住む人が海外で開いても日付が動かないよう、
    /// 日本で入れたものとして読んできた。ところが海外に住む人では、入れた日付と読む日付がずれる
    /// （ロサンゼルスの夜 20:00 に入れた「11月10日」は、日本時間では 11日の昼）。
    /// 何日目かの数え方・ウィジェット・カレンダーへの書き出しが1日ずれていたので、選べるようにした
    static var homeTimeZone: TimeZone {
        UserDefaults.standard.string(forKey: homeTimeZoneKey).flatMap(TimeZone.init(identifier:)) ?? legacyTimeZone
    }

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

    /// 24時以降の書き方（0:30 → "24:30"、1:00 → "25:00"）。前の日の続きとして出すときに使う（3.2）
    static func lateNightText(_ date: Date, in timeZone: TimeZone) -> String {
        let parts = calendar(in: timeZone).dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", (parts.hour ?? 0) + 24, parts.minute ?? 0)
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
        // 何ヶ国も回る旅行では「現地」が1つに決まらないので、都市名で出す
        return cityName(of: zone)
    }

    /// 2つの時刻の日付（それぞれの時計で読んだもの）が何日離れているか
    static func dateDifference(from start: Date, in startZone: TimeZone, to end: Date, in endZone: TimeZone) -> Int {
        let a = calendar(in: startZone).dateComponents([.year, .month, .day], from: start)
        let b = calendar(in: endZone).dateComponents([.year, .month, .day], from: end)
        let utc = calendar(in: TimeZone(identifier: "UTC")!)
        guard let dayA = utc.date(from: a), let dayB = utc.date(from: b) else { return 0 }
        return utc.dateComponents([.day], from: dayA, to: dayB).day ?? 0
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

    /// 「6時間30分」「45分」
    static func durationText(_ interval: TimeInterval) -> String {
        let minutes = max(0, Int((interval / 60).rounded()))
        let (h, m) = (minutes / 60, minutes % 60)
        if h == 0 { return "\(m)分" }
        return m == 0 ? "\(h)時間" : "\(h)時間\(m)分"
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

    /// 画面に出す時刻（入れたとおりの時:分）。日付をまたいだ夜の予定は「24:30」「25:00」。
    /// 時間未定の予定は「未定」（3.4。`time` は並ぶ位置にしか使っていない）
    var timeText: String {
        if hasUndecidedTime { return ScheduleUndecided.label }
        return isLateNight ? ScheduleClock.lateNightText(time, in: timeZone) : ScheduleClock.timeText(time, in: timeZone)
    }

    /// 24時以降として出す予定か（3.2）。翌日（`dayShift` が 1）の 0:00〜5:59。
    ///
    /// 「翌日 0:30」より「24:30」のほうが、その日の夜の続きだと一目で分かる（ご要望から）。
    /// 時間帯を直してずれた翌日の昼の予定などは、今までどおり「翌日 17:00」と出す
    var isLateNight: Bool {
        dayShift == 1 && ScheduleClock.calendar(in: timeZone).component(.hour, from: time) < 6
    }

    /// 終わる時刻を読む時計。決めていなければ始まりと同じ
    var endTimeZone: TimeZone {
        endTimeZoneIdentifier.map { ScheduleClock.timeZone(identifier: $0) } ?? timeZone
    }

    /// 始まりと終わりで時差のある時計を使っているか（飛行機などの移動）
    var crossesTimeZones: Bool {
        guard let endTime else { return false }
        return !ScheduleClock.showsSameTime(timeZone, endTimeZone, at: endTime)
    }

    /// 終わりが、その日（`DaySchedule`）から何日あとか。終わりが無ければ 0。
    ///
    /// 始まりの日付は始まりの時計で、終わりの日付は着いた先の時計で読む
    /// （羽田 22:00 発 → ホノルル同じ日の 10:00 着 は 0、パリ 22:00 発 → 羽田 翌日 17:00 着 は 1）
    var endDayOffset: Int {
        guard let endTime else { return 0 }
        return ScheduleClock.dateDifference(from: time, in: timeZone, to: endTime, in: endTimeZone) + (dayShift ?? 0)
    }

    /// 次の日まで続く予定として、着く日の予定表にも出すか（3.3）。
    ///
    /// 夜行便・夜行バスのような移動は出す。「24:30〜26:00」のような、その日の夜の続きとして
    /// 入れた短い予定は出さない（翌朝の予定表に並ぶと、かえって分かりにくい）。
    /// 朝 6:00 より後に終わる・時差をまたぐ・4時間以上かかる、のどれかなら移動とみなす
    var continuesIntoNextDay: Bool {
        guard let endTime, endDayOffset > 0 else { return false }
        if crossesTimeZones || endTime.timeIntervalSince(time) >= 4 * 60 * 60 { return true }
        return ScheduleClock.calendar(in: endTimeZone).component(.hour, from: endTime) >= 6
    }

    /// 終わる時刻（入れたとおりの時:分）。無ければ nil。
    /// 始まりの日の夜の続き（23:00〜1:00 の 1:00、24:30 に始まる予定の終わり）は「25:00」と出す。
    /// 翌日の朝 6:00 からは「翌 08:00」と出す（3.3）。時刻だけだと、夜行便の「22:00〜08:00」が
    /// 翌日に着くのか分からず、「日付も入れたい」とご要望をいただいた
    var endTimeText: String? {
        guard let endTime, !hasUndecidedTime else { return nil }
        let offset = endDayOffset
        if !crossesTimeZones, offset == 1,
           ScheduleClock.calendar(in: endTimeZone).component(.hour, from: endTime) < 6 {
            return ScheduleClock.lateNightText(endTime, in: endTimeZone)
        }
        let text = ScheduleClock.timeText(endTime, in: endTimeZone)
        switch offset {
        case 0: return text
        case 1: return "翌 \(text)"
        case 2...: return "\(offset)日後 \(text)"
        default: return "前日 \(text)"
        }
    }

    /// 時刻の列で始まりの下に添える終わり（"〜11:30"）。時差をまたぐ移動は "→23:00"
    var endTimeColumnText: String? {
        endTimeText.map { (crossesTimeZones ? "→" : "〜") + $0 }
    }

    /// 時差をまたぐ移動の、出発と到着の都市（"パリ発" / "ドーハ着"）。またがなければ nil
    var departureZoneLabel: String? {
        crossesTimeZones ? "\(ScheduleClock.cityName(of: timeZone))発" : nil
    }
    var arrivalZoneLabel: String? {
        crossesTimeZones ? "\(ScheduleClock.cityName(of: endTimeZone))着" : nil
    }

    /// 「10:00〜11:30」。終わりが無ければ「10:00」。日をまたいで直した予定は「前日 17:00」。
    /// 時差をまたぐ移動は「15:00 パリ → 23:00 ドーハ」
    var timeRangeText: String {
        let range: String
        if crossesTimeZones, let endTimeText {
            range = "\(timeText) \(ScheduleClock.cityName(of: timeZone)) → \(endTimeText) \(ScheduleClock.cityName(of: endTimeZone))"
        } else {
            range = endTimeText.map { "\(timeText)〜\($0)" } ?? timeText
        }
        return dayShiftLabel.map { "\($0) \(range)" } ?? range
    }

    /// 終わりの時:分を、始まりの日に合わせた日時にする。
    /// 始まりより前（23:00〜1:00 のような）なら翌日の時刻とみなす。
    ///
    /// 終わりを別の時計で入れたとき（`endZone`）は、その時計での始まりの日に合わせる。
    /// 東京 10:00 発 → ホノルル 22:00 着（ホノルルではまだ前日）も、正しく前日の 22:00 になる
    static func endTime(hourAndMinuteOf end: Date, after start: Date, in zone: TimeZone,
                        endZone: TimeZone? = nil) -> Date {
        let clock = ScheduleClock.calendar(in: endZone ?? zone)
        let hm = clock.dateComponents([.hour, .minute], from: end)
        var day = clock.dateComponents([.year, .month, .day], from: start)
        day.hour = hm.hour
        day.minute = hm.minute
        let sameDay = clock.date(from: day) ?? end
        return sameDay > start ? sameDay : (clock.date(byAdding: .day, value: 1, to: sameDay) ?? sameDay)
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
        minutesOfDay - timeZone.secondsFromGMT(for: time) / 60 + (dayShift ?? 0) * 24 * 60
    }

    /// 起きる順に並べるための比較
    ///
    /// 分まで同じなら、時刻のある予定を先にし、時間未定の予定どうしは位置の秒で並べる（3.4、`ScheduleUndecided`）
    static func chronologically(_ lhs: ScheduleItem, _ rhs: ScheduleItem) -> Bool {
        let left = lhs.chronologicalMinutes, right = rhs.chronologicalMinutes
        if left != right { return left < right }
        return ScheduleUndecided.comesFirst(atSameMinute: lhs, rhs)
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
        // 終わりも同じ時:分のまま付け替える（2.9 まではここが抜けていて、終わりの時刻がずれていた）。
        // 終わりを別の時計（着いた先）で入れた移動は、終わりはそのまま
        if endTimeZoneIdentifier == nil {
            copy.endTime = endTime.map { ScheduleClock.keepingWallClock($0, from: timeZone, to: target) }
        }
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
