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

        /// 日付と時刻を合成した実際の開始日時。ウィジェットの更新時刻の算出に使う
        var occursAt: Date? {
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
    }

    /// 直近の旅行（進行中または今後）
    var travelTitle: String?
    var travelDestination: String?
    var travelStartDate: Date?
    var travelEndDate: Date?

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
    func isTravelOngoing(asOf now: Date) -> Bool {
        guard let start = travelStartDate, let end = travelEndDate else { return false }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        return calendar.startOfDay(for: start) <= today && calendar.startOfDay(for: end) >= today
    }

    /// 出発までの日数。旅行が無い、または進行中の場合は nil
    func daysUntilTravel(asOf now: Date) -> Int? {
        guard !isTravelOngoing(asOf: now), let start = travelStartDate else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let startDay = calendar.startOfDay(for: start)
        guard startDay > today else { return nil }
        return calendar.dateComponents([.day], from: today, to: startDay).day
    }

    /// 指定時刻の日にあたる旅行スケジュール
    func travelItems(on date: Date) -> [Item] {
        let calendar = Calendar.current
        return travelScheduleItems.filter { item in
            guard let itemDate = item.date else { return false }
            return calendar.isDate(itemDate, inSameDayAs: date)
        }
    }

    /// 指定時刻の時点で有効な内容に絞り込む。
    /// アプリが起動されなくてもウィジェット側で古い予定が消えるようにするため、
    /// 書き出し時ではなく表示時にこの絞り込みを通す
    func filtered(at date: Date) -> WidgetSnapshot {
        let calendar = Calendar.current
        var copy = self

        // その日の分だけを取り出し、進行中のものを先頭にして以降を残す。
        // 常に先頭を出すと、夕方でも朝の予定が表示されたままになる
        copy.travelScheduleItems = Self.currentAndUpcoming(travelItems(on: date), at: date)

        copy.upcomingPlans = upcomingPlans.filter { item in
            guard let itemDate = item.date else { return true }

            // 時刻のある予定は、その時刻を過ぎたら消す
            if item.time != nil, let occursAt = item.occursAt {
                return occursAt >= date
            }

            // 時刻のない予定はその日いっぱい残す
            return calendar.startOfDay(for: itemDate) >= calendar.startOfDay(for: date)
        }

        return copy
    }

    var hasContent: Bool {
        travelTitle != nil || !upcomingPlans.isEmpty
    }

    /// 進行中の予定を先頭に、それ以降を返す。
    /// 開始済みの予定は次の予定が始まるまで「今やっていること」として残す
    private static func currentAndUpcoming(_ items: [Item], at date: Date) -> [Item] {
        guard !items.isEmpty else { return [] }

        var startIndex = 0
        for (index, item) in items.enumerated() {
            guard let occursAt = item.occursAt else { continue }
            if occursAt <= date {
                startIndex = index
            } else {
                break
            }
        }

        return Array(items[startIndex...])
    }

    /// 「自動」表示のときに旅行と予定のどちらを主役にするか。
    /// 旅行中なら旅行、そうでなければ先に来るほうを選ぶ
    func prefersTravel(asOf now: Date) -> Bool {
        if isTravelOngoing(asOf: now) { return true }

        let calendar = Calendar.current
        switch (travelStartDate, upcomingPlans.first?.date) {
        case (nil, _):
            return false
        case (_, nil):
            return true
        case let (travelStart?, planDate?):
            return calendar.startOfDay(for: travelStart) <= calendar.startOfDay(for: planDate)
        }
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
