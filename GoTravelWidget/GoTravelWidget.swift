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
        let entry = TravoryEntry(
            date: Date(),
            snapshot: WidgetDataStore.load(),
            contentType: configuration.contentType
        )

        // 残り日数や「今日・明日」の表記は日付が変わると内容が変わるため、次の0時に作り直す
        let nextMidnight = Calendar.current.nextDate(
            after: Date(),
            matching: DateComponents(hour: 0, minute: 0),
            matchingPolicy: .nextTime
        ) ?? Date().addingTimeInterval(60 * 60)

        return Timeline(entries: [entry], policy: .after(nextMidnight))
    }
}

// MARK: - Widget

struct GoTravelWidget: Widget {
    let kind = "GoTravelWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: TravoryWidgetIntent.self, provider: TravoryProvider()) { entry in
            TravoryWidgetView(snapshot: entry.snapshot, contentType: entry.contentType)
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
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryRectangular:
            LockScreenView(snapshot: snapshot, contentType: contentType.resolved(for: snapshot))
        case .systemMedium:
            // 中サイズは旅行と予定の両方を並べるので設定に関わらず同じ
            MediumView(snapshot: snapshot)
        default:
            SmallView(snapshot: snapshot, contentType: contentType.resolved(for: snapshot))
        }
    }
}

extension WidgetContentType {
    /// 「自動」を、実際に表示する側へ解決する
    func resolved(for snapshot: WidgetSnapshot) -> WidgetContentType {
        guard self == .automatic else { return self }
        return snapshot.prefersTravel ? .travel : .plan
    }
}

// MARK: - Small

private struct SmallView: View {
    let snapshot: WidgetSnapshot
    let contentType: WidgetContentType

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
        if snapshot.isTravelOngoing, let title = snapshot.travelTitle {
            Label("旅行中", systemImage: "airplane")
                .font(.caption2.weight(.bold))
                .foregroundStyle(TravoryWidgetPalette.ongoing)

            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .lineLimit(2)

            if let next = snapshot.todayItems.first {
                Spacer(minLength: 0)
                ItemRow(item: next, compact: true, showsDate: false)
            }

        } else if let days = snapshot.daysUntilTravel, let title = snapshot.travelTitle {
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

            ForEach(snapshot.upcomingPlans.prefix(3)) { item in
                ItemRow(item: item, compact: true, showsDate: true)
            }
        }
    }
}

// MARK: - Medium

private struct MediumView: View {
    let snapshot: WidgetSnapshot

    /// 旅行中はその日のスケジュール、それ以外は今後の予定を並べる
    private var listItems: [WidgetSnapshot.Item] {
        snapshot.isTravelOngoing ? snapshot.todayItems : snapshot.upcomingPlans
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            leadingColumn
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text(snapshot.isTravelOngoing ? "今日の予定" : "これからの予定")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)

                if listItems.isEmpty {
                    Text("予定はありません")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(listItems.prefix(3)) { item in
                        // 旅行中の一覧はすべて当日なので日付は出さない
                        ItemRow(item: item, compact: true, showsDate: !snapshot.isTravelOngoing)
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var leadingColumn: some View {
        if snapshot.isTravelOngoing, let title = snapshot.travelTitle {
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

        } else if let days = snapshot.daysUntilTravel, let title = snapshot.travelTitle {
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
        if snapshot.isTravelOngoing, let title = snapshot.travelTitle {
            Text(title)
                .font(.headline)
                .lineLimit(1)
            if let next = snapshot.todayItems.first {
                // 旅行中の一覧は当日のみなので日付は出さない
                Text(line(for: next, showsDate: false))
                    .font(.caption)
                    .lineLimit(1)
            }

        } else if let days = snapshot.daysUntilTravel, let title = snapshot.travelTitle {
            Text("\(title) まで")
                .font(.caption)
                .lineLimit(1)
            Text("あと\(days)日")
                .font(.headline)

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
            Text("次の予定")
                .font(.caption)
            Text(line(for: next))
                .font(.headline)
                .lineLimit(1)

        } else {
            Text("予定はありません")
                .font(.headline)
            Text("予定を追加しましょう")
                .font(.caption)
        }
    }

    /// 「今日 14:00 ジム」のように、日付と時刻を前に置く
    private func line(for item: WidgetSnapshot.Item, showsDate: Bool = true) -> String {
        var parts: [String] = []
        if showsDate, let label = TravoryWidgetFormatter.dayLabel(for: item.date) {
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

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 5) {
                if showsDate, let label = TravoryWidgetFormatter.dayLabel(for: item.date) {
                    Text(label)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(TravoryWidgetPalette.accent)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(TravoryWidgetPalette.accent.opacity(0.15), in: Capsule())
                }

                if let time = item.time {
                    Text(TravoryWidgetFormatter.time.string(from: time))
                        .font(.caption2.weight(.bold).monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Text(item.title)
                    .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.bold))
                    .lineLimit(1)
            }

            if !compact, let subtitle = item.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
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

    /// 近い日付は「今日」「明日」、それ以降は日付で返す
    static func dayLabel(for date: Date?) -> String? {
        guard let date else { return nil }

        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "今日" }
        if calendar.isDateInTomorrow(date) { return "明日" }
        return monthDay.string(from: date)
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
