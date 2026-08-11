import WidgetKit
import SwiftUI

// MARK: - Entry

struct TravoryEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
    let contentType: WidgetContentType
}

// MARK: - Provider

struct TravoryProvider: AppIntentTimelineProvider {

    func placeholder(in context: Context) -> TravoryEntry {
        TravoryEntry(date: Date(), snapshot: .preview, contentType: .travel)
    }

    func snapshot(for configuration: TravoryWidgetIntent, in context: Context) async -> TravoryEntry {
        let data = context.isPreview ? WidgetSnapshot.preview : WidgetDataStore.load()
        return TravoryEntry(date: Date(), snapshot: data, contentType: configuration.contentType)
    }

    func timeline(for configuration: TravoryWidgetIntent, in context: Context) async -> Timeline<TravoryEntry> {
        let now = Date()
        let stored = WidgetDataStore.load()

        let calendar = Calendar.current
        let nextMidnight = calendar.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0),
            matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(60 * 60)

        // 予定の時刻ごとに区切ってエントリを作る。
        // 1件だけだとアプリを起動するまで古い予定が残り続けるため、
        // 各時刻の時点で正しい内容をあらかじめ用意しておく。
        //
        // WidgetKit の更新は時刻ちょうどに走る保証がなく、特にロック画面は
        // 機会が少ない。今日の分しか用意しないと日付が変わっても前日の表示が
        // 残るため、数日先まで作っておく
        let windowEnd = calendar.date(byAdding: .day, value: 3, to: calendar.startOfDay(for: now))
            ?? now.addingTimeInterval(60 * 60 * 72)

        var checkpoints: [Date] = [now]

        // 日付の変わり目。残り日数と「今日 / 明日」の表記がここで変わる
        var midnight = nextMidnight
        while midnight < windowEnd {
            checkpoints.append(midnight)
            guard let next = calendar.date(byAdding: .day, value: 1, to: midnight) else { break }
            midnight = next
        }

        // 予定・旅行とも、開始時刻ではなく次に譲る時刻で表示が変わる。
        // 開始時刻を区切り点にすると、切り替わる瞬間にエントリが無く反映が遅れる
        checkpoints += stored.upcomingPlans.compactMap(\.expiresAt)
        checkpoints += stored.travelScheduleItems.compactMap(\.travelExpiresAt)

        checkpoints = checkpoints.filter { $0 == now || ($0 > now && $0 <= windowEnd) }

        let sortedCheckpoints = Array(Set(checkpoints)).sorted().prefix(40)

        let entries = sortedCheckpoints.map { date in
            TravoryEntry(
                date: date,
                snapshot: stored.filtered(at: date),
                contentType: configuration.contentType
            )
        }

        // 0時以降に取り直してよい。取れなくても上のエントリで数日は正しく表示される
        return Timeline(entries: entries, policy: .after(nextMidnight))
    }
}

// MARK: - Widget

struct GoTravelWidget: Widget {
    let kind = "GoTravelWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: TravoryWidgetIntent.self, provider: TravoryProvider()) { entry in
            TravoryWidgetView(
                snapshot: entry.snapshot,
                contentType: entry.contentType,
                referenceDate: entry.date
            )
                // ウィジェットは壁紙と切り離して描画されるため Material のぼかしは効かない。
                // 透明化も不可なので、システム標準の塗りを使う
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("旅行と予定")
        .description("次の旅行までの日数や、これからの予定を表示します。")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

// MARK: - Palette

/// ウィジェットは別ターゲットのため ThemeManager を参照できない。
/// アプリの既定テーマに近い色をここで持つ
enum TravoryWidgetPalette {
    static let accent = Color.blue
    static let ongoing = Color.green
}

// MARK: - Root View

struct TravoryWidgetView: View {
    let snapshot: WidgetSnapshot
    let contentType: WidgetContentType
    /// このエントリが表示される時刻。先の時刻の分も前もって描画されるため Date() は使わない
    let referenceDate: Date
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryRectangular:
            LockScreenView(
                snapshot: snapshot,
                contentType: contentType.resolved(for: snapshot, asOf: referenceDate),
                referenceDate: referenceDate
            )
        case .systemMedium:
            // 中サイズは旅行と予定の両方を並べるので設定に関わらず同じ
            MediumView(snapshot: snapshot, referenceDate: referenceDate)
        default:
            SmallView(
                snapshot: snapshot,
                contentType: contentType.resolved(for: snapshot, asOf: referenceDate),
                referenceDate: referenceDate
            )
        }
    }
}

extension WidgetContentType {
    /// 「自動」を、実際に表示する側へ解決する
    func resolved(for snapshot: WidgetSnapshot, asOf date: Date) -> WidgetContentType {
        guard self == .automatic else { return self }
        return snapshot.prefersTravel(asOf: date) ? .travel : .plan
    }
}

// MARK: - Small

private struct SmallView: View {
    let snapshot: WidgetSnapshot
    let contentType: WidgetContentType
    let referenceDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // contentType は解決済みなので automatic は来ない
            if contentType == .plan {
                planContent
            } else {
                travelContent
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: 旅行

    @ViewBuilder
    private var travelContent: some View {
        if snapshot.isTravelOngoing(asOf: referenceDate), let title = snapshot.travelTitle {
            Label(title, systemImage: "airplane")
                .font(.caption2.weight(.bold))
                .foregroundStyle(TravoryWidgetPalette.ongoing)
                .lineLimit(1)

            if let current = snapshot.travelScheduleItems.first {
                // 旅行中は「今どこにいる予定か」を主役にする
                Text(TravoryWidgetFormatter.time.string(from: current.time ?? referenceDate))
                    .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(TravoryWidgetPalette.accent)

                Text(current.title)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                if let location = current.subtitle, !location.isEmpty {
                    Label(location, systemImage: "mappin")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

            } else {
                Text("今日の予定はありません")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        } else if let days = snapshot.daysUntilTravel(asOf: referenceDate), let title = snapshot.travelTitle {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(days)")
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .foregroundStyle(TravoryWidgetPalette.accent)
                Text("日後")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            if let destination = snapshot.travelDestination, !destination.isEmpty {
                Label(destination, systemImage: "mappin.and.ellipse")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

        } else {
            EmptyStateView(
                icon: "airplane.departure",
                title: "旅行の予定なし",
                message: "旅行を計画しましょう"
            )
        }
    }

    // MARK: 予定

    @ViewBuilder
    private var planContent: some View {
        if snapshot.upcomingPlans.isEmpty {
            EmptyStateView(
                icon: "calendar",
                title: "予定はありません",
                message: "予定を追加しましょう"
            )
        } else {
            Text("これからの予定")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)

            // 1件が2行になるため、小サイズは2件までにして名前を切らさない
            ForEach(snapshot.upcomingPlans.prefix(2)) { item in
                ItemRow(item: item, compact: true, showsDate: true, referenceDate: referenceDate)
            }
        }
    }
}

// MARK: - Medium

private struct MediumView: View {
    let snapshot: WidgetSnapshot
    let referenceDate: Date

    /// 旅行中はその日のスケジュール、それ以外は今後の予定を並べる
    private var listItems: [WidgetSnapshot.Item] {
        snapshot.isTravelOngoing(asOf: referenceDate) ? snapshot.travelScheduleItems : snapshot.upcomingPlans
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            leadingColumn
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text(snapshot.isTravelOngoing(asOf: referenceDate) ? "ここからの予定" : "これからの予定")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)

                if listItems.isEmpty {
                    Text("予定はありません")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(listItems.prefix(3)) { item in
                        // 旅行中の一覧はすべて当日なので日付は出さない
                        ItemRow(item: item, compact: true, showsDate: !snapshot.isTravelOngoing(asOf: referenceDate), referenceDate: referenceDate)
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var leadingColumn: some View {
        if snapshot.isTravelOngoing(asOf: referenceDate), let title = snapshot.travelTitle {
            VStack(alignment: .leading, spacing: 6) {
                Label("旅行中", systemImage: "airplane")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(TravoryWidgetPalette.ongoing)

                Text(title)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .lineLimit(2)

                destinationLabel
                Spacer(minLength: 0)
            }

        } else if let days = snapshot.daysUntilTravel(asOf: referenceDate), let title = snapshot.travelTitle {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(days)")
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundStyle(TravoryWidgetPalette.accent)
                    Text("日後")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }

                destinationLabel
                Spacer(minLength: 0)
            }

        } else if snapshot.hasContent {
            VStack(alignment: .leading, spacing: 6) {
                Text("次の予定")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)

                if let next = snapshot.upcomingPlans.first {
                    Text(next.title)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }

        } else {
            EmptyStateView()
        }
    }

    @ViewBuilder
    private var destinationLabel: some View {
        if let destination = snapshot.travelDestination, !destination.isEmpty {
            Label(destination, systemImage: "mappin.and.ellipse")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

// MARK: - Lock Screen

private struct LockScreenView: View {
    let snapshot: WidgetSnapshot
    let contentType: WidgetContentType
    let referenceDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if contentType == .plan {
                planContent
            } else {
                travelContent
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var travelContent: some View {
        if snapshot.isTravelOngoing(asOf: referenceDate), let title = snapshot.travelTitle {
            if let current = snapshot.travelScheduleItems.first {
                // 旅行名より、今の予定を大きく見せる
                Text(headerLine(travelTitle: title, item: current))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(current.title)
                    .font(.headline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

            } else {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text("今日の予定はありません")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        } else if let days = snapshot.daysUntilTravel(asOf: referenceDate), let title = snapshot.travelTitle {
            Text("あと\(days)日")
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

        } else {
            Text("旅行の予定なし")
                .font(.headline)
            Text("旅行を計画しましょう")
                .font(.caption)
        }
    }

    @ViewBuilder
    private var planContent: some View {
        if let next = snapshot.upcomingPlans.first {
            // 日付と時刻は上段に置き、名前に2行分を使えるようにする
            Text(metaLine(for: next))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(next.title)
                .font(.headline)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

        } else {
            Text("予定はありません")
                .font(.headline)
            Text("予定を追加しましょう")
                .font(.caption)
        }
    }

    /// 「次の予定 · 今日 14:00」のような見出し行
    private func metaLine(for item: WidgetSnapshot.Item) -> String {
        var parts = ["次の予定"]
        if let label = TravoryWidgetFormatter.dayLabel(for: item.date, asOf: referenceDate) {
            parts.append(label)
        }
        if let time = item.time {
            parts.append(TravoryWidgetFormatter.time.string(from: time))
        }
        return parts.joined(separator: " · ")
    }

    /// 「沖縄旅行 · 14:00」のような見出し行
    private func headerLine(travelTitle: String, item: WidgetSnapshot.Item) -> String {
        guard let time = item.time else { return travelTitle }
        return "\(travelTitle) · \(TravoryWidgetFormatter.time.string(from: time))"
    }

    /// 「今日 14:00 ジム」のように、日付と時刻を前に置く
    private func line(for item: WidgetSnapshot.Item, showsDate: Bool = true) -> String {
        var parts: [String] = []
        if showsDate, let label = TravoryWidgetFormatter.dayLabel(for: item.date, asOf: referenceDate) {
            parts.append(label)
        }
        if let time = item.time {
            parts.append(TravoryWidgetFormatter.time.string(from: time))
        }
        parts.append(item.title)
        return parts.joined(separator: " ")
    }
}

// MARK: - Parts

private struct ItemRow: View {
    let item: WidgetSnapshot.Item
    let compact: Bool
    /// 「今日」「明日」などの日付を先頭に出すか
    var showsDate: Bool = false
    var referenceDate: Date = Date()

    private var dayLabel: String? {
        showsDate ? TravoryWidgetFormatter.dayLabel(for: item.date, asOf: referenceDate) : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            // 日付バッジがあるときは上段に分け、タイトルに横幅をすべて渡す
            if dayLabel != nil {
                HStack(spacing: 4) {
                    if let dayLabel {
                        Text(dayLabel)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(TravoryWidgetPalette.accent)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(TravoryWidgetPalette.accent.opacity(0.15), in: Capsule())
                    }
                    timeText
                }

                titleText
            } else {
                HStack(spacing: 5) {
                    timeText
                    titleText
                }
            }

            if !compact, let subtitle = item.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var timeText: some View {
        if let time = item.time {
            Text(TravoryWidgetFormatter.time.string(from: time))
                .font(.caption2.weight(.bold).monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private var titleText: some View {
        Text(item.title)
            .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.bold))
            .lineLimit(compact ? 2 : 1)
            .minimumScaleFactor(0.85)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct EmptyStateView: View {
    var icon: String = "airplane.departure"
    var title: String = "予定はありません"
    var message: String = "旅行を計画しましょう"

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(TravoryWidgetPalette.accent)
            Text(title)
                .font(.caption.weight(.semibold))
            Text(message)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

enum TravoryWidgetFormatter {
    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let monthDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d"
        return formatter
    }()

    /// 近い日付は「今日」「明日」、それ以降は日付で返す。
    /// 先の時刻の分も前もって描画されるため、基準時刻を受け取る
    static func dayLabel(for date: Date?, asOf now: Date) -> String? {
        guard let date else { return nil }

        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        let baseDay = calendar.startOfDay(for: now)
        let diff = calendar.dateComponents([.day], from: baseDay, to: targetDay).day ?? 0

        switch diff {
        case 0: return "今日"
        case 1: return "明日"
        default: return monthDay.string(from: date)
        }
    }
}

// MARK: - Preview Data

extension WidgetSnapshot {
    static var preview: WidgetSnapshot {
        var snapshot = WidgetSnapshot()
        snapshot.travelTitle = "沖縄旅行"
        snapshot.travelDestination = "沖縄県那覇市"
        snapshot.travelStartDate = Calendar.current.date(byAdding: .day, value: 3, to: Date())
        snapshot.travelEndDate = Calendar.current.date(byAdding: .day, value: 5, to: Date())
        let calendar = Calendar.current
        snapshot.upcomingPlans = [
            .init(id: "1", date: Date(), time: Date(), title: "ジム", subtitle: "日常"),
            .init(id: "2", date: calendar.date(byAdding: .day, value: 1, to: Date()), time: nil, title: "美術館へ", subtitle: "おでかけ")
        ]
        snapshot.prefectureCount = 12
        return snapshot
    }
}
