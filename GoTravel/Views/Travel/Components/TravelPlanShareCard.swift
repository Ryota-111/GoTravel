import SwiftUI

// MARK: - Text Export

/// 旅程をテキストに書き出す。
/// 共有コードは相手も Travory を入れている必要があるため、
/// アプリを持っていない同行者に渡す手段としてこちらを用意した
enum TravelPlanTextExporter {

    static func fullItinerary(for plan: TravelPlan) -> String {
        var lines: [String] = []

        lines.append("【\(plan.title)】")
        lines.append("\(dateString(plan.startDate)) 〜 \(dateString(plan.endDate))")
        if !plan.destination.isEmpty {
            lines.append("目的地: \(plan.destination)")
        }

        let days = plan.daySchedules.sorted { $0.dayNumber < $1.dayNumber }
        for day in days where !day.scheduleItems.isEmpty {
            lines.append("")
            lines.append("◆ Day \(day.dayNumber)  \(dateString(day.date))")

            for item in sortedByTime(day.scheduleItems) {
                var row = "\(timeString(item.time))  \(item.title)"
                if let location = item.location, !location.isEmpty {
                    row += "  @\(location)"
                }
                if let cost = item.cost, cost > 0 {
                    row += "  \(currency(cost))"
                }
                lines.append(row)

                if let notes = item.notes, !notes.isEmpty {
                    lines.append("　　\(notes)")
                }
                if let link = item.linkURL, !link.isEmpty {
                    lines.append("　　\(link)")
                }
            }
        }

        let total = plan.daySchedules
            .flatMap(\.scheduleItems)
            .compactMap(\.cost)
            .reduce(0, +)

        if total > 0 {
            lines.append("")
            lines.append("合計: \(currency(total))")
        }

        if !plan.packingItems.isEmpty {
            lines.append("")
            lines.append("◆ 持ち物")
            for packing in plan.packingItems {
                lines.append("\(packing.isChecked ? "☑" : "☐") \(packing.name)")
            }
        }

        lines.append("")
        lines.append("Travory で作成")

        return lines.joined(separator: "\n")
    }

    // MARK: Helpers

    static func sortedByTime(_ items: [ScheduleItem]) -> [ScheduleItem] {
        items.sorted { minutes(of: $0.time) < minutes(of: $1.time) }
    }

    private static func minutes(of date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    static func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日(E)"
        return formatter.string(from: date)
    }

    static func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    static func currency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return "¥\(formatter.string(from: NSNumber(value: amount)) ?? "0")"
    }
}

// MARK: - Image Export

/// 画像として書き出す1日分の旅程カード。
/// ImageRenderer に渡すため、画面表示ではなく固定幅で組んでいる
struct TravelPlanShareCard: View {
    let plan: TravelPlan
    let daySchedule: DaySchedule
    let accentColor: Color

    static let width: CGFloat = 390

    private var items: [ScheduleItem] {
        TravelPlanTextExporter.sortedByTime(daySchedule.scheduleItems)
    }

    private var dayTotal: Double {
        daySchedule.scheduleItems.compactMap(\.cost).reduce(0, +)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().padding(.horizontal, 24)
            timeline
            footer
        }
        .frame(width: Self.width, alignment: .leading)
        .background(Color(.systemBackground))
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(plan.title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(2)

            if !plan.destination.isEmpty {
                Label(plan.destination, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 6) {
                Text("Day \(daySchedule.dayNumber)")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(accentColor, in: Capsule())

                Text(TravelPlanTextExporter.dateString(daySchedule.date))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
            }
        }
        .padding(24)
    }

    // MARK: Timeline

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            if items.isEmpty {
                Text("この日の予定はありません")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 24)
            } else {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    row(item: item, isLast: index == items.count - 1)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private func row(item: ScheduleItem, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(TravelPlanTextExporter.timeString(item.time))
                .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundColor(accentColor)
                .frame(width: 44, alignment: .leading)
                .padding(.top, 1)

            // 時系列がつながって見えるよう、点と縦線で結ぶ
            VStack(spacing: 0) {
                Circle()
                    .fill(accentColor)
                    .frame(width: 9, height: 9)
                if !isLast {
                    Rectangle()
                        .fill(accentColor.opacity(0.25))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .padding(.top, 4)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)

                if let location = item.location, !location.isEmpty {
                    Label(location, systemImage: "mappin")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let notes = item.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let cost = item.cost, cost > 0 {
                    Text(TravelPlanTextExporter.currency(cost))
                        .font(.caption.weight(.bold))
                        .foregroundColor(accentColor)
                }
            }
            .padding(.bottom, isLast ? 0 : 18)

            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 10) {
            if dayTotal > 0 {
                HStack {
                    Text("この日の費用")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(TravelPlanTextExporter.currency(dayTotal))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
            }

            HStack(spacing: 5) {
                Image(systemName: "airplane.departure")
                    .font(.caption2)
                Text("Travory")
                    .font(.caption.weight(.bold))
                Spacer()
            }
            .foregroundColor(accentColor)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .background(accentColor.opacity(0.07))
    }
}
