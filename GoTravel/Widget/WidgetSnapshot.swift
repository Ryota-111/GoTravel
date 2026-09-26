import Foundation

/// ウィジェットに渡す最小限のデータ。
///
/// ウィジェットは別プロセスで動くため Core Data を直接読めない。
/// ストア自体を App Group へ移すとCloudKit同期を含む移行が必要でリスクが大きいので、
/// 表示に必要な値だけをこの形で共有領域に書き出す方式にしている。
struct WidgetSnapshot: Codable, Equatable {

    /// ウィジェットに並べる1件分
    struct Item: Codable, Equatable, Identifiable {
        var id: String
        /// 予定の日付。今日・明日などの表示に使う
        var date: Date?
        /// 時刻。日常プランやスケジュールのみ入る
        var time: Date?
        var title: String
        var subtitle: String?

        /// 時刻を読む時計（"Europe/Paris" など）。旅行のスケジュールだけ入る。
        ///
        /// **入っているときは `time` が実際に起きる瞬間になっている**（アプリ側で組み立て済み）。
        /// 端末の時計で時:分を読むと、海外に着いたとたんに予定の時刻がずれるため
        var timeZoneIdentifier: String?
        /// 旅行の何日の予定か（"2026-10-10"）。
        ///
        /// 日本の 0:00 という瞬間で持つと、パリでは前日の夕方になり、
        /// 今日の予定が前の日に出てしまう。日付として持って、見ている場所の今日と比べる
        var dayKey: String?

        /// 表示する時刻。予定の時計で読む
        var timeText: String? {
            guard let time else { return nil }
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ja_JP")
            formatter.dateFormat = "HH:mm"
            if let identifier = timeZoneIdentifier, let zone = TimeZone(identifier: identifier) {
                formatter.timeZone = zone
            }
            return formatter.string(from: time)
        }

        /// 日付と時刻を合成した実際の開始日時。ウィジェットの更新時刻の算出に使う
        var occursAt: Date? {
            // アプリ側で瞬間まで組み立ててあるものは、そのまま使う
            if timeZoneIdentifier != nil, let time { return time }

            guard let date else { return nil }
            guard let time else { return date }

            let calendar = Calendar.current
            let components = calendar.dateComponents([.hour, .minute], from: time)
            return calendar.date(
                bySettingHour: components.hour ?? 0,
                minute: components.minute ?? 0,
                second: 0,
                of: date
            )
        }

        /// 「次の予定」として見せ終える時刻。ここを過ぎたら次の予定に切り替わる。
        ///
        /// 時刻のある予定はその1分後まで残す。時刻ちょうどで消すと、
        /// 始まった瞬間に手元から消えて確認できないため。
        /// 時刻のない予定は日付しか決まっていないので、その日の8時を区切りにする
        static let timedGrace: TimeInterval = 60
        static let untimedHandoverHour = 8

        /// 旅行のタイムテーブルは開始5分後に次へ渡す。
        /// 予定より長いのは、移動の途中で見返す場面が多いため
        static let travelGrace: TimeInterval = 300

        var expiresAt: Date? {
            expires(after: Self.timedGrace)
        }

        /// 旅行スケジュール用の区切り
        var travelExpiresAt: Date? {
            expires(after: Self.travelGrace)
        }

        private func expires(after grace: TimeInterval) -> Date? {
            guard let date else { return nil }

            if time != nil, let occursAt {
                return occursAt.addingTimeInterval(grace)
            }

            return Calendar.current.date(
                bySettingHour: Self.untimedHandoverHour,
                minute: 0,
                second: 0,
                of: date
            )
        }
    }

    /// 直近の旅行（進行中または今後）
    var travelTitle: String?
    var travelDestination: String?
    var travelStartDate: Date?
    var travelEndDate: Date?
    /// 旅行の初日と最終日（"2026-10-10"）。
    /// 瞬間で比べると、海外では最終日が前の日に終わったことになる
    var travelStartDayKey: String?
    var travelEndDayKey: String?

    /// 旅行期間中の全日分のスケジュール。
    /// 当日分だけを持つと、アプリを起動しないまま日付をまたいだときに
    /// 表示が止まってしまうため、期間全体を保存して表示時に日付で絞り込む
    var travelScheduleItems: [Item] = []

    /// 旅行がないときに出す直近の予定
    var upcomingPlans: [Item] = []

    /// 日本全国フォトマップの登録済み都道府県数
    var prefectureCount: Int = 0

    var updatedAt: Date = Date()

    static let empty = WidgetSnapshot()

    /// 旅行中かどうか。保存時の値を持つとアプリ未起動で切り替わらないため、
    /// 表示する時刻から毎回判定する
    /// - Parameter viewer: 見ている場所の時計。テストで差し替えるためのもの
    func isTravelOngoing(asOf now: Date, viewer: TimeZone = .current) -> Bool {
        if let startKey = travelStartDayKey, let endKey = travelEndDayKey {
            let today = DayKey.string(for: now, in: viewer)
            return startKey <= today && today <= endKey
        }
        guard let start = travelStartDate, let end = travelEndDate else { return false }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        return calendar.startOfDay(for: start) <= today && calendar.startOfDay(for: end) >= today
    }

    /// 出発までの日数。旅行が無い、または進行中の場合は nil
    func daysUntilTravel(asOf now: Date) -> Int? {
        guard !isTravelOngoing(asOf: now),
              let start = travelStartDayKey.flatMap(DayKey.date(from:)) ?? travelStartDate else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let startDay = calendar.startOfDay(for: start)
        guard startDay > today else { return nil }
        return calendar.dateComponents([.day], from: today, to: startDay).day
    }

    /// 指定時刻の日にあたる旅行スケジュール
    func travelItems(on date: Date, viewer: TimeZone = .current) -> [Item] {
        let calendar = Calendar.current
        let today = DayKey.string(for: date, in: viewer)
        return travelScheduleItems.filter { item in
            if let dayKey = item.dayKey { return dayKey == today }
            guard let itemDate = item.date else { return false }
            return calendar.isDate(itemDate, inSameDayAs: date)
        }
    }

    /// 指定時刻の時点で有効な内容に絞り込む。
    /// アプリが起動されなくてもウィジェット側で古い予定が消えるようにするため、
    /// 書き出し時ではなく表示時にこの絞り込みを通す
    func filtered(at date: Date) -> WidgetSnapshot {
        var copy = self

        // その日の分から、区切りを過ぎたものを落とす。
        // 以前は開始済みの項目を「今やっていること」として次が始まるまで残していたが、
        // 予定側と挙動が違って分かりにくいため、同じ「時刻＋猶予」の考え方に揃えた
        copy.travelScheduleItems = travelItems(on: date).filter { item in
            guard let travelExpiresAt = item.travelExpiresAt else { return true }
            return travelExpiresAt > date
        }

        // 区切りを過ぎた予定を落として次の予定に切り替える。
        // 比較が >= だと、区切り時刻ちょうどに作ったエントリが自分自身を残してしまい、
        // 次の区切り点まで「次の予定」として居座る
        copy.upcomingPlans = upcomingPlans.filter { item in
            guard let expiresAt = item.expiresAt else { return true }
            return expiresAt > date
        }

        return copy
    }

    var hasContent: Bool {
        travelTitle != nil || !upcomingPlans.isEmpty
    }

    /// 「自動」表示のときに旅行と予定のどちらを主役にするか。
    /// 旅行中なら旅行、そうでなければ先に来るほうを選ぶ
    func prefersTravel(asOf now: Date) -> Bool {
        if isTravelOngoing(asOf: now) { return true }

        let calendar = Calendar.current
        switch (travelStartDayKey.flatMap(DayKey.date(from:)) ?? travelStartDate, upcomingPlans.first?.date) {
        case (nil, _):
            return false
        case (_, nil):
            return true
        case let (travelStart?, planDate?):
            return calendar.startOfDay(for: travelStart) <= calendar.startOfDay(for: planDate)
        }
    }
}

// MARK: - 日付の文字列

/// 「何月何日か」を、時間帯に左右されない形で受け渡す（"2026-10-10"）
enum DayKey {
    private static func formatter(_ timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    /// その時計で見た日付。既定は見ている場所の時計
    static func string(for date: Date, in timeZone: TimeZone = .current) -> String {
        formatter(timeZone).string(from: date)
    }

    /// 見ている場所の、その日の 0:00
    static func date(from key: String) -> Date? {
        formatter(.current).date(from: key)
    }
}

// MARK: - Shared Store

/// App Group 経由でアプリとウィジェットの間を受け渡す
enum WidgetDataStore {
    static let appGroupId = "group.com.gmail.taismryotasis.Travory"
    private static let snapshotKey = "WidgetSnapshot_v1"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }

    static func save(_ snapshot: WidgetSnapshot) {
        guard let defaults else { return }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
    }

    static func load() -> WidgetSnapshot {
        guard let defaults,
              let data = defaults.data(forKey: snapshotKey),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else {
            return .empty
        }
        return snapshot
    }
}
