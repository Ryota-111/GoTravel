import Foundation
import ActivityKit

/// 旅行中のライブアクティビティを、ウィジェットと同じ中身（`WidgetSnapshot`）から出し入れする。
///
/// - 旅行の日で、今日このあとに予定が残っていれば出す（無ければ消す）
/// - 中身はアプリを開いたとき・予定を変えたときに書き換える（`WidgetSnapshotBuilder.update` から呼ばれる）
/// - 次の予定の時刻を過ぎたら古い扱い（`staleDate`）にして、ウィジェット側で「アプリを開いて更新」と出す
/// - 本人がロック画面で消したら、その日はもう出さない
///
/// 新しく出せるのはアプリが前面にあるときだけ（ActivityKit の決まり）。裏に回るときの呼び出しでは
/// 書き換えと終了だけが効き、新しく出すのは次にアプリを開いたときになる
@MainActor
enum TravelLiveActivity {

    /// 本人が消した日（「旅行名|2026-10-10」）。その日のうちは出し直さない
    private static let dismissedKey = "TravelLiveActivity.dismissedDay"

    /// 出しているアクティビティの状態を見張っているもの（消されたことに気づくため）
    private static var watchedActivityIds = Set<String>()
    /// アプリが自分で終わらせたもの。これが消えたのは本人が消したのではないので、覚えない
    private static var endedByAppIds = Set<String>()

    /// ライブアクティビティの「更新」ボタンで呼ぶ処理を差し込む。アプリの起動時に1回呼ぶ
    static func registerRefresher() {
        TravelActivityRefresher.handler = {
            // 保存してある最新の中身から、いまの時刻で選び直す（アプリの画面は開かない）
            sync(with: WidgetDataStore.load())
        }
    }

    static func sync(with snapshot: WidgetSnapshot, now: Date = Date()) {
        let activities = Activity<TravelActivityAttributes>.activities

        guard ActivityAuthorizationInfo().areActivitiesEnabled,
              let title = snapshot.travelTitle,
              snapshot.isTravelOngoing(asOf: now),
              let state = contentState(from: snapshot, now: now)
        else {
            endAll(activities)
            return
        }

        let attributes = TravelActivityAttributes(travelTitle: title, destination: snapshot.travelDestination)
        let content = ActivityContent(state: state, staleDate: staleDate(of: state, now: now))

        // 別の旅行のものが残っていたら消す
        endAll(activities.filter { $0.attributes != attributes })

        if let current = activities.first(where: { $0.attributes == attributes && $0.activityState == .active }) {
            watch(current, dayTag: dayTag(title: title, now: now))
            guard current.content.state != state || current.content.staleDate != content.staleDate else { return }
            Task { await current.update(content) }
            return
        }

        let tag = dayTag(title: title, now: now)
        guard UserDefaults.standard.string(forKey: dismissedKey) != tag else { return }

        do {
            let activity = try Activity.request(attributes: attributes, content: content, pushType: nil)
            watch(activity, dayTag: tag)
        } catch {
            // 裏に回るときなど、新しく出せない場面では失敗する。次にアプリを開いたときに出す
            #if DEBUG
            print("[LiveActivity] 出せませんでした: \(error)")
            #endif
        }
    }

    // MARK: - 中身

    /// 今日このあとの予定を、時刻順に最大 `maxItems` 件まとめる。
    ///
    /// 「次の予定」として見せ終える瞬間（`endsAt`）は、ウィジェットと同じく始まって5分後。
    /// ただし次の予定がそれより早く始まるときは、その時刻で譲る
    /// （14:00 の次に 14:03 の予定があるのに、14:05 まで 14:00 が残っていた）
    static func contentState(from snapshot: WidgetSnapshot, now: Date) -> TravelActivityAttributes.ContentState? {
        let remaining = snapshot.travelItems(on: now)
            .filter { ($0.travelExpiresAt ?? .distantFuture) > now }
            .sorted { ($0.occursAt ?? .distantFuture) < ($1.occursAt ?? .distantFuture) }
            .prefix(TravelActivityAttributes.ContentState.maxItems)
        guard !remaining.isEmpty else { return nil }

        let list = Array(remaining)
        let entries = list.enumerated().map { index, item in
            let startsAt = item.time == nil ? nil : item.occursAt
            let nextStart = index + 1 < list.count && list[index + 1].time != nil ? list[index + 1].occursAt : nil
            let endsAt: Date? = {
                switch (item.travelExpiresAt, nextStart) {
                case let (end?, next?): return min(end, max(next, startsAt ?? next))
                case let (end?, nil): return end
                case let (nil, next?): return next
                case (nil, nil): return nil
                }
            }()
            let subtitle = item.subtitle.flatMap { $0.isEmpty || $0 == item.title ? nil : $0 }
            return TravelActivityAttributes.ContentState.Entry(
                title: item.title,
                subtitle: subtitle,
                timeText: item.timeText,
                startsAt: startsAt,
                endsAt: endsAt
            )
        }

        return TravelActivityAttributes.ContentState(
            dayNumber: dayNumber(of: snapshot, now: now),
            dayCount: dayCount(of: snapshot),
            items: entries
        )
    }

    /// 次の予定に切り替える瞬間。この時刻にシステムが描き直し（古い扱いになり）、
    /// 表示する側がその時点の「次の予定」を選び直す
    private static func staleDate(of state: TravelActivityAttributes.ContentState, now: Date) -> Date? {
        state.items.compactMap(\.endsAt).filter { $0 > now }.min()
    }

    private static func dayNumber(of snapshot: WidgetSnapshot, now: Date) -> Int {
        guard let startKey = snapshot.travelStartDayKey,
              let start = DayKey.date(from: startKey),
              let today = DayKey.date(from: DayKey.string(for: now)) else { return 1 }
        let days = Calendar.current.dateComponents([.day], from: start, to: today).day ?? 0
        return max(days + 1, 1)
    }

    private static func dayCount(of snapshot: WidgetSnapshot) -> Int {
        guard let startKey = snapshot.travelStartDayKey, let endKey = snapshot.travelEndDayKey,
              let start = DayKey.date(from: startKey), let end = DayKey.date(from: endKey) else { return 1 }
        let days = Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
        return max(days + 1, 1)
    }

    private static func dayTag(title: String, now: Date) -> String {
        "\(title)|\(DayKey.string(for: now))"
    }

    // MARK: - 消す・見張る

    private static func endAll(_ activities: [Activity<TravelActivityAttributes>]) {
        for activity in activities {
            endedByAppIds.insert(activity.id)
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    /// 本人がロック画面から消したら、その日はもう出さない
    private static func watch(_ activity: Activity<TravelActivityAttributes>, dayTag: String) {
        guard !watchedActivityIds.contains(activity.id) else { return }
        watchedActivityIds.insert(activity.id)
        Task {
            for await state in activity.activityStateUpdates where state == .dismissed {
                await MainActor.run {
                    guard !endedByAppIds.contains(activity.id) else { return }
                    UserDefaults.standard.set(dayTag, forKey: dismissedKey)
                }
            }
        }
    }
}
