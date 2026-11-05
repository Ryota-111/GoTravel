import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// 旅行中のライブアクティビティの見た目。
///
/// - ロック画面：何日目・次の予定と時刻・残り時間・その次の予定・「更新」ボタン
/// - Dynamic Island：小さいときは飛行機と時刻、広げると次の予定とその次
/// - Apple Watch のスマートスタック（watchOS 11〜）：小さい形（`.small`）で次の予定と時刻
///
/// 「次の予定」は、描く時点の時刻で `items` から選ぶ。アプリが動いていなくても、
/// 切り替わる時刻（`staleDate`）にシステムが描き直すので、そこで次の予定に進む。
/// 進みきれなかったとき（古い扱いのまま、さらに予定が過ぎたとき）は「更新」ボタンで直る
struct TravelLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TravelActivityAttributes.self) { context in
            TravelActivityLockScreenView(context: context)
                .activityBackgroundTint(nil)
                .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            let view = TravelActivityViewModel(state: context.state, isStale: context.isStale)
            return DynamicIsland {
                // 左右の欄は島の丸い角にかかるので、端から少し離す（右端の「あと2件」が切れていた）
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(view.dayText)
                    } icon: {
                        Image(systemName: "airplane")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(TravelActivityStyle.accent)
                    .padding(.leading, 6)
                    .padding(.top, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TravelActivityCountdown(view: view)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, 10)
                        .padding(.top, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.travelTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let next = view.next {
                        VStack(alignment: .leading, spacing: 4) {
                            TravelActivityNextRow(entry: next)
                            HStack {
                                if let later = view.later {
                                    Text(TravelActivityStyle.later(later))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 8)
                                if view.needsRefresh {
                                    TravelActivityRefreshButton()
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 6)
                    } else {
                        Text("今日の予定は終わりました")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: "airplane")
                    .foregroundStyle(TravelActivityStyle.accent)
            } compactTrailing: {
                Text(view.next?.timeText ?? "今日")
                    .font(.caption.weight(.semibold).monospacedDigit())
            } minimal: {
                Image(systemName: "airplane")
                    .foregroundStyle(TravelActivityStyle.accent)
            }
        }
        // Apple Watch のスマートスタックにも、小さい形で出す
        .supplementalActivityFamilies([.small])
    }
}

// MARK: - 描く時点の中身

/// 描く時点の時刻で、次の予定・その次の予定を選ぶ
private struct TravelActivityViewModel {
    let state: TravelActivityAttributes.ContentState
    let isStale: Bool
    let now = Date()

    private var index: Int? { state.currentIndex(at: now) }

    var next: TravelActivityAttributes.ContentState.Entry? {
        index.map { state.items[$0] }
    }

    var later: TravelActivityAttributes.ContentState.Entry? {
        guard let index, index + 1 < state.items.count else { return nil }
        return state.items[index + 1]
    }

    var remainingCount: Int {
        index.map { state.items.count - $0 } ?? 0
    }

    /// 選び直した「次の予定」の、その次まで過ぎている（システムの描き直しが追いつかない）とき
    var needsRefresh: Bool {
        guard isStale else { return false }
        guard let index else { return true }
        // 描き直したばかりで、今の「次の予定」がまだ終わっていないなら、ボタンは要らない
        return (state.items[index].endsAt ?? .distantFuture) <= now
    }

    var dayText: String {
        state.dayCount > 1 ? "\(state.dayNumber)日目 / \(state.dayCount)日" : "今日"
    }
}

// MARK: - ロック画面（Apple Watch では小さい形）

private struct TravelActivityLockScreenView: View {
    let context: ActivityViewContext<TravelActivityAttributes>
    @Environment(\.activityFamily) private var family

    private var view: TravelActivityViewModel {
        TravelActivityViewModel(state: context.state, isStale: context.isStale)
    }

    var body: some View {
        switch family {
        case .small:
            watchBody
        default:
            lockScreenBody
        }
    }

    private var lockScreenBody: some View {
        let view = self.view
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "airplane")
                    .foregroundStyle(TravelActivityStyle.accent)
                Text(context.attributes.travelTitle)
                    .lineLimit(1)
                Text(view.dayText)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                TravelActivityCountdown(view: view)
                    .lineLimit(1)
            }
            .font(.caption.weight(.semibold))

            if let next = view.next {
                TravelActivityNextRow(entry: next)

                HStack {
                    if let later = view.later {
                        Text(TravelActivityStyle.later(later))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    TravelActivityRefreshButton()
                }
            } else {
                Text("今日の予定は終わりました")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
    }

    /// Apple Watch のスマートスタック。字を大きく、次の予定だけにする
    private var watchBody: some View {
        let view = self.view
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "airplane")
                    .foregroundStyle(TravelActivityStyle.accent)
                Text(view.next?.timeText ?? view.dayText)
                    .monospacedDigit()
            }
            .font(.caption.weight(.semibold))

            Text(view.next?.title ?? "今日の予定は終わりました")
                .font(.headline)
                .lineLimit(2)

            if view.needsRefresh {
                Text("iPhoneで更新")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
    }
}

// MARK: - 部品

/// 次の予定（時刻・名前・場所）
private struct TravelActivityNextRow: View {
    let entry: TravelActivityAttributes.ContentState.Entry

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            if let time = entry.timeText {
                Text(time)
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(TravelActivityStyle.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.headline)
                    .lineLimit(1)
                if let subtitle = entry.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}

/// 次の予定までの残り時間。始まっていたら残りの件数
private struct TravelActivityCountdown: View {
    let view: TravelActivityViewModel

    var body: some View {
        if let startsAt = view.next?.startsAt, startsAt > view.now {
            // 0:00 で止まる数え方。過ぎたあとに数え上がっていかないように
            Text(timerInterval: view.now...startsAt, countsDown: true)
                .monospacedDigit()
                .foregroundStyle(TravelActivityStyle.accent)
        } else if view.remainingCount > 0 {
            Text("あと\(view.remainingCount)件")
                .foregroundStyle(.secondary)
        }
    }
}

/// 「更新」ボタン。押すとアプリが裏で起きて、いまの時刻で書き換える（アプリの画面は開かない）
private struct TravelActivityRefreshButton: View {
    var body: some View {
        Button(intent: RefreshTravelActivityIntent()) {
            Label("更新", systemImage: "arrow.clockwise")
                .font(.caption.weight(.semibold))
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .tint(TravelActivityStyle.accent)
    }
}

private enum TravelActivityStyle {
    /// Travory の差し色（標準テーマのオレンジ）
    static let accent = Color.orange

    static func later(_ entry: TravelActivityAttributes.ContentState.Entry) -> String {
        if let time = entry.timeText { return "つぎ  \(time)  \(entry.title)" }
        return "つぎ  \(entry.title)"
    }
}
