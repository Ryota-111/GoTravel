import Foundation

// MARK: - 予定ごとの時間帯（3.0）
//
// 2.7 では「現地（旅行の目的地1か所）」と「日本」の2つしか選べず、
// 何ヶ国も回る旅行や、目的地の座標が引けない旅行では現地の時刻で入れられなかった。
// 予定の場所・その日・目的地・日本・最近使った時間帯から選べるようにする。
// 現地に着いてから、日本時間で入っていた予定を直す方法も2つ用意する（`docs/設計_3.0.md` 1章）

/// 入っている予定を別の時間帯にするときの直し方
enum ScheduleZoneConversion: Equatable {
    /// 時:分の数字はそのまま（「現地の 15:00 のつもりで入れた」を直す）
    case keepWallClock
    /// 同じ瞬間の、その時間帯の時刻にする（日本 15:00 → パリ 8:00）
    case keepMoment
}

/// 時刻の欄で選べる時間帯の1つ
struct ScheduleZoneChoice: Identifiable, Equatable {
    enum Source: Equatable {
        /// この予定の場所
        case place
        /// この日の時間帯
        case day
        /// 旅行の目的地
        case destination
        /// いま端末がある場所
        case current
        /// 日本
        case japan
        /// 最近使った
        case recent
        /// 検索して選んだ
        case searched
    }

    let zone: TimeZone
    let source: Source

    var id: String { zone.identifier }

    /// 一覧に出す説明（「この予定の場所」など）
    var sourceLabel: String? {
        switch source {
        case .place: return "この予定の場所"
        case .day: return "この日の時間帯"
        case .destination: return "旅行の目的地"
        case .current: return "いまいる場所"
        case .japan: return nil
        case .recent: return "最近使った"
        case .searched: return nil
        }
    }
}

extension ScheduleClock {

    // MARK: 候補

    /// 時刻の欄で選べる時間帯。上から勧めたい順に並べ、時差が同じものは1つにまとめる。
    /// 日本は必ず入る
    static func zoneChoices(place: TimeZone?, day: TimeZone?, destination: TimeZone?,
                            current: TimeZone? = nil, recents: [TimeZone] = [],
                            at date: Date) -> [ScheduleZoneChoice] {
        var candidates: [ScheduleZoneChoice] = []
        func add(_ zone: TimeZone?, _ source: ScheduleZoneChoice.Source) {
            guard let zone, !candidates.contains(where: { showsSameTime($0.zone, zone, at: date) }) else { return }
            candidates.append(ScheduleZoneChoice(zone: zone, source: source))
        }
        add(place, .place)
        add(day, .day)
        add(destination, .destination)
        add(legacyTimeZone, .japan)
        // 海外にいるときだけ、いまいる場所も出す（日本にいれば「日本」と同じ）
        if let current, isForeign(current, at: date) { add(current, .current) }
        for zone in recents { add(zone, .recent) }
        return candidates
    }

    /// 時間帯の選択を出すか。日本と時差のある候補が1つも無い（国内旅行）なら出さない
    static func offersZoneChoice(_ choices: [ScheduleZoneChoice], selected: TimeZone, at date: Date) -> Bool {
        isForeign(selected, at: date) || choices.contains { isForeign($0.zone, at: date) }
    }

    // MARK: 名前

    /// 旅行先で多い都市の日本語名。`TimeZone` は都市名を日本語で返さないため持っておく
    private static let japaneseCityNames: [String: String] = [
        "Asia/Tokyo": "日本", "Asia/Seoul": "ソウル", "Asia/Taipei": "台北", "Asia/Shanghai": "上海",
        "Asia/Hong_Kong": "香港", "Asia/Macau": "マカオ", "Asia/Bangkok": "バンコク", "Asia/Singapore": "シンガポール",
        "Asia/Ho_Chi_Minh": "ホーチミン", "Asia/Saigon": "ホーチミン", "Asia/Manila": "マニラ",
        "Asia/Jakarta": "ジャカルタ", "Asia/Makassar": "バリ", "Asia/Kuala_Lumpur": "クアラルンプール",
        "Asia/Kolkata": "インド", "Asia/Calcutta": "インド", "Asia/Dubai": "ドバイ", "Asia/Kathmandu": "カトマンズ",
        "Asia/Phnom_Penh": "プノンペン", "Asia/Yangon": "ヤンゴン", "Asia/Ulaanbaatar": "ウランバートル",
        "Asia/Colombo": "コロンボ", "Asia/Vladivostok": "ウラジオストク", "Asia/Qatar": "ドーハ",
        "Europe/London": "ロンドン", "Europe/Paris": "パリ", "Europe/Berlin": "ベルリン", "Europe/Rome": "ローマ",
        "Europe/Madrid": "マドリード", "Europe/Amsterdam": "アムステルダム",
        "Europe/Brussels": "ブリュッセル", "Europe/Vienna": "ウィーン", "Europe/Zurich": "チューリッヒ",
        "Europe/Prague": "プラハ", "Europe/Budapest": "ブダペスト", "Europe/Warsaw": "ワルシャワ",
        "Europe/Copenhagen": "コペンハーゲン", "Europe/Stockholm": "ストックホルム", "Europe/Oslo": "オスロ",
        "Europe/Helsinki": "ヘルシンキ", "Europe/Lisbon": "リスボン", "Europe/Athens": "アテネ",
        "Europe/Istanbul": "イスタンブール", "Europe/Dublin": "ダブリン", "Europe/Moscow": "モスクワ",
        "Atlantic/Reykjavik": "レイキャビク", "Africa/Cairo": "カイロ", "Africa/Casablanca": "カサブランカ",
        "Africa/Johannesburg": "ヨハネスブルグ", "Africa/Nairobi": "ナイロビ",
        "America/New_York": "ニューヨーク", "America/Chicago": "シカゴ", "America/Denver": "デンバー",
        "America/Los_Angeles": "ロサンゼルス", "America/Phoenix": "フェニックス", "America/Anchorage": "アンカレッジ",
        "America/Toronto": "トロント", "America/Vancouver": "バンクーバー", "America/Mexico_City": "メキシコシティ",
        "America/Cancun": "カンクン", "America/Sao_Paulo": "サンパウロ", "America/Lima": "リマ",
        "America/Buenos_Aires": "ブエノスアイレス", "America/Argentina/Buenos_Aires": "ブエノスアイレス",
        "Pacific/Honolulu": "ホノルル", "Pacific/Guam": "グアム", "Pacific/Saipan": "サイパン",
        "Pacific/Auckland": "オークランド", "Pacific/Tahiti": "タヒチ", "Pacific/Palau": "パラオ",
        "Pacific/Fiji": "フィジー", "Australia/Sydney": "シドニー", "Australia/Melbourne": "メルボルン",
        "Australia/Brisbane": "ブリスベン", "Australia/Perth": "パース", "Australia/Adelaide": "アデレード",
        "Australia/Darwin": "ダーウィン", "Indian/Maldives": "モルディブ", "Indian/Mauritius": "モーリシャス"
    ]

    /// 「パリ」「ロサンゼルス」。知らない都市は "Europe/Paris" の "Paris"
    static func cityName(of zone: TimeZone) -> String {
        if let name = japaneseCityNames[zone.identifier] { return name }
        let city = zone.identifier.split(separator: "/").last.map(String.init) ?? zone.identifier
        return city.replacingOccurrences(of: "_", with: " ")
    }

    /// 「パリ（中央ヨーロッパ時間）」。一覧に出す名前
    static func choiceTitle(of zone: TimeZone) -> String {
        let city = cityName(of: zone)
        if zone.identifier == legacyTimeZone.identifier { return "日本時間" }
        return "\(city)（\(displayName(of: zone))）"
    }

    // MARK: 検索

    /// 都市名（日本語・英語）・時間帯の名前で探す。空なら主な都市を返す
    static func searchZones(_ query: String) -> [TimeZone] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if text.isEmpty {
            // 古い別名（Asia/Saigon など）は同じ都市が2つ並ぶので除く
            let aliases: Set<String> = ["Asia/Saigon", "Asia/Calcutta", "America/Buenos_Aires", legacyTimeZone.identifier]
            return japaneseCityNames.keys
                .filter { !aliases.contains($0) }
                .compactMap(TimeZone.init(identifier:))
                .sorted { cityName(of: $0) < cityName(of: $1) }
        }
        return TimeZone.knownTimeZoneIdentifiers.compactMap(TimeZone.init(identifier:)).filter { zone in
            cityName(of: zone).lowercased().contains(text)
                || zone.identifier.lowercased().replacingOccurrences(of: "_", with: " ").contains(text)
                || displayName(of: zone).lowercased().contains(text)
        }
    }

    // MARK: 直す

    /// 2つの時計で、同じ瞬間の日付が何日ずれているか（日本 9:00 → ロサンゼルスなら -1）
    static func dayDifference(of date: Date, from source: TimeZone, to target: TimeZone) -> Int {
        let a = calendar(in: source).dateComponents([.year, .month, .day], from: date)
        let b = calendar(in: target).dateComponents([.year, .month, .day], from: date)
        let utc = calendar(in: TimeZone(identifier: "UTC")!)
        guard let dayA = utc.date(from: a), let dayB = utc.date(from: b) else { return 0 }
        return utc.dateComponents([.day], from: dayA, to: dayB).day ?? 0
    }
}

// MARK: - 予定

extension ScheduleItem {

    /// 別の時間帯の予定にする
    func converted(to target: TimeZone, mode: ScheduleZoneConversion) -> ScheduleItem {
        switch mode {
        case .keepWallClock:
            return keepingWallClock(in: target)
        case .keepMoment:
            var copy = self
            let shift = (dayShift ?? 0) + ScheduleClock.dayDifference(of: time, from: timeZone, to: target)
            copy.timeZoneIdentifier = target.identifier
            copy.dayShift = shift == 0 ? nil : shift
            return copy
        }
    }

    /// 「前日」「翌日」「2日後」。その日の時刻なら nil
    var dayShiftLabel: String? {
        Self.dayShiftLabel(dayShift)
    }

    static func dayShiftLabel(_ dayShift: Int?) -> String? {
        switch dayShift ?? 0 {
        case 0: return nil
        case -1: return "前日"
        case 1: return "翌日"
        case let shift where shift < 0: return "\(-shift)日前"
        case let shift: return "\(shift)日後"
        }
    }

    /// その日（年月日）に置いたときに、実際に起きる瞬間。ウィジェットやカレンダーに使う
    func occurrence(onDay day: DateComponents) -> Date {
        let clock = ScheduleClock.calendar(in: timeZone)
        let hm = clock.dateComponents([.hour, .minute], from: time)
        var parts = day
        parts.hour = hm.hour
        parts.minute = hm.minute
        let base = clock.date(from: parts) ?? time
        return clock.date(byAdding: .day, value: dayShift ?? 0, to: base) ?? base
    }
}

// MARK: - 日・旅行計画

extension DaySchedule {
    /// この日の時間帯。決めていなければ nil
    var timeZone: TimeZone? {
        timeZoneIdentifier.flatMap(TimeZone.init(identifier:))
    }
}

extension TravelPlan {

    /// その日の時間帯。決めていなければ nil
    func dayTimeZone(_ dayNumber: Int) -> TimeZone? {
        daySchedules.first { $0.dayNumber == dayNumber }?.timeZone
    }

    /// その日の予定で使っている、日本と時差のある時間帯（多い順）。日の時間帯を決めるときの勧めに使う
    func foreignZonesUsed(onDay dayNumber: Int) -> [TimeZone] {
        let items = daySchedules.first { $0.dayNumber == dayNumber }?.scheduleItems ?? []
        var counts: [String: Int] = [:]
        for item in items where ScheduleClock.isForeign(item.timeZone, at: item.time) {
            counts[item.timeZone.identifier, default: 0] += 1
        }
        return counts.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .compactMap { TimeZone(identifier: $0.key) }
    }

    /// 指定の日に、その時計になっていない予定がいくつあるか
    func scheduleItemCount(onDays days: Set<Int>, notIn target: TimeZone) -> Int {
        daySchedules
            .filter { days.contains($0.dayNumber) }
            .flatMap(\.scheduleItems)
            .filter { !ScheduleClock.showsSameTime($0.timeZone, target, at: $0.time) }
            .count
    }

    /// 指定の日の時間帯を決め、入っている予定も直す。
    /// - Parameters:
    ///   - mode: 入っている予定の直し方。nil なら予定はそのままで、日の時間帯だけ決める
    ///   - onlyFrom: この時計の予定だけ直す（「日本時間で入った予定だけ」）。nil なら全部
    func settingTimeZone(_ target: TimeZone, onDays days: Set<Int>, mode: ScheduleZoneConversion?,
                         onlyFrom source: TimeZone? = nil) -> TravelPlan {
        var updated = self
        // 予定がまだ無い日も、日の時間帯は決められるようにする
        for day in days where !updated.daySchedules.contains(where: { $0.dayNumber == day }) {
            updated.daySchedules.append(DaySchedule(dayNumber: day, date: date(forDay: day)))
        }
        updated.daySchedules.sort { $0.dayNumber < $1.dayNumber }

        updated.daySchedules = updated.daySchedules.map { day in
            guard days.contains(day.dayNumber) else { return day }
            var copy = day
            copy.timeZoneIdentifier = target.identifier
            if let mode {
                copy.scheduleItems = day.scheduleItems.map { item in
                    if ScheduleClock.showsSameTime(item.timeZone, target, at: item.time) { return item }
                    if let source, !ScheduleClock.showsSameTime(item.timeZone, source, at: item.time) { return item }
                    return item.converted(to: target, mode: mode)
                }
            }
            return copy
        }
        return updated
    }
}

extension TravelPlan {
    /// 指定の日の時間帯を外す（予定の時刻はそのまま）
    func clearingDayTimeZone(onDays days: Set<Int>) -> TravelPlan {
        var updated = self
        updated.daySchedules = daySchedules.map { day in
            guard days.contains(day.dayNumber) else { return day }
            var copy = day
            copy.timeZoneIdentifier = nil
            return copy
        }
        return updated
    }

    /// 日本時間で入っていて、指定の時計になっていない予定（指定の日の分）。現地に着いたときの案内に使う
    func japanTimeItems(onDays days: Set<Int>, notIn target: TimeZone) -> [ScheduleItem] {
        daySchedules
            .filter { days.contains($0.dayNumber) }
            .sorted { $0.dayNumber < $1.dayNumber }
            .flatMap { $0.scheduleItems.sorted(by: ScheduleItem.chronologically) }
            .filter {
                ScheduleClock.showsSameTime($0.timeZone, ScheduleClock.legacyTimeZone, at: $0.time)
                    && !ScheduleClock.showsSameTime($0.timeZone, target, at: $0.time)
            }
    }

    /// 今日が旅行の何日目か。旅行の期間外なら nil
    func dayNumber(on date: Date, calendar: Calendar = .current) -> Int? {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: startDate),
                                           to: calendar.startOfDay(for: date)).day ?? -1
        let total = calendar.dateComponents([.day], from: calendar.startOfDay(for: startDate),
                                            to: calendar.startOfDay(for: endDate)).day ?? 0
        return (0...max(0, total)).contains(days) ? days + 1 : nil
    }
}

// MARK: - 最近使った時間帯

/// 最近使った時間帯（日本以外）。端末の中だけに持つ
enum RecentTimeZones {
    private static let key = "recentScheduleTimeZones"
    static let limit = 5

    static func list(defaults: UserDefaults = .standard) -> [TimeZone] {
        (defaults.stringArray(forKey: key) ?? []).compactMap(TimeZone.init(identifier:))
    }

    static func record(_ zone: TimeZone, defaults: UserDefaults = .standard) {
        guard ScheduleClock.isForeign(zone, at: Date()) else { return }
        var ids = defaults.stringArray(forKey: key) ?? []
        ids.removeAll { $0 == zone.identifier }
        ids.insert(zone.identifier, at: 0)
        defaults.set(Array(ids.prefix(limit)), forKey: key)
    }
}
