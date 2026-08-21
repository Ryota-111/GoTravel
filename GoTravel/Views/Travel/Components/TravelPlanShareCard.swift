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

        let days = plan.daySchedulesInRange
        for day in days where !day.scheduleItems.isEmpty {
            lines.append("")
            lines.append("◆ Day \(day.dayNumber)  \(dateString(plan.date(forDay: day.dayNumber)))")

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

    /// 全日程を1枚にまとめるカードから、この日の中身だけを借りる
    var dayBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            dayHeading
            timeline
        }
    }

    private var dayHeading: some View {
        HStack(spacing: 6) {
            Text("Day \(daySchedule.dayNumber)")
                .font(.caption.weight(.bold))
                .foregroundColor(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(accentColor, in: Capsule())

            Text(TravelPlanTextExporter.dateString(plan.date(forDay: daySchedule.dayNumber)))
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)

            Spacer(minLength: 0)

            if dayTotal > 0 {
                Text(TravelPlanTextExporter.currency(dayTotal))
                    .font(.caption.weight(.bold))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
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

                Text(TravelPlanTextExporter.dateString(plan.date(forDay: daySchedule.dayNumber)))
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

// MARK: - 全日程を1枚に

/// 旅程まるごと1枚の画像。
/// 日ごとに分けると枚数が増えてカメラロールが埋まるため、1枚にまとめる
struct TravelPlanFullShareCard: View {
    let plan: TravelPlan
    let accentColor: Color

    private var days: [DaySchedule] {
        plan.daySchedulesInRange.filter { !$0.scheduleItems.isEmpty }
    }

    private var total: Double {
        plan.daySchedulesInRange
            .flatMap { $0.scheduleItems }
            .compactMap(\.cost)
            .reduce(0, +)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ShareCardHeader(plan: plan, subtitle: nil, accentColor: accentColor)

            Divider().padding(.horizontal, 24)

            if days.isEmpty {
                Text("予定がまだありません")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(24)
            } else {
                ForEach(days) { day in
                    TravelPlanShareCard(plan: plan, daySchedule: day, accentColor: accentColor)
                        .dayBody
                }
            }

            ShareCardFooter(accentColor: accentColor) {
                if total > 0 {
                    HStack {
                        Text("合計")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(TravelPlanTextExporter.currency(total))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .frame(width: TravelPlanShareCard.width, alignment: .leading)
        .background(Color(.systemBackground))
    }
}

// MARK: - 予約と持ち物を1枚に

/// 空港や宿で見たいものと、出発前に見たいものをまとめた1枚
struct TravelPlanExtrasShareCard: View {
    let plan: TravelPlan
    let accentColor: Color
    let includesReservations: Bool
    let includesPacking: Bool
    /// 予約番号は画像になるとSNSに出回りうるので、既定では入れない
    let includesConfirmationNumbers: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ShareCardHeader(plan: plan, subtitle: "予約・持ち物", accentColor: accentColor)

            Divider().padding(.horizontal, 24)

            if includesReservations && !plan.reservations.isEmpty {
                section(title: "予約") {
                    ForEach(plan.reservations) { reservation in
                        reservationRow(reservation)
                    }
                }
            }

            if includesPacking && !plan.packingItems.isEmpty {
                section(title: "持ち物（\(plan.packingItems.count)件）") {
                    // 2列にして縦に伸びすぎないようにする
                    LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading),
                                        GridItem(.flexible(), alignment: .leading)],
                              spacing: 6) {
                        ForEach(plan.packingItems) { item in
                            HStack(spacing: 6) {
                                Image(systemName: item.isChecked ? "checkmark.square.fill" : "square")
                                    .font(.caption)
                                    .foregroundColor(item.isChecked ? accentColor : .secondary)
                                Text(item.name)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }

            ShareCardFooter(accentColor: accentColor) { EmptyView() }
        }
        .frame(width: TravelPlanShareCard.width, alignment: .leading)
        .background(Color(.systemBackground))
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundColor(accentColor)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private func reservationRow(_ reservation: Reservation) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: reservation.kind.icon)
                .font(.caption)
                .foregroundColor(accentColor)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(reservation.title.isEmpty ? reservation.kind.label : reservation.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

                if let date = reservation.date {
                    Text(TravelPlanTextExporter.dateString(date) + " " + TravelPlanTextExporter.timeString(date))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                if reservation.hasRoute {
                    Text([reservation.departurePlace, reservation.arrivalPlace]
                        .compactMap { $0 }
                        .joined(separator: " → "))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                if let seat = reservation.seat, !seat.isEmpty {
                    Text("座席 \(seat)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                if includesConfirmationNumbers,
                   let number = reservation.confirmationNumber, !number.isEmpty {
                    Text("予約番号 \(number)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)
                }
            }

            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - 共通の見出しと足元

private struct ShareCardHeader: View {
    let plan: TravelPlan
    let subtitle: String?
    let accentColor: Color

    var body: some View {
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

            Text(subtitle ?? "\(TravelPlanTextExporter.dateString(plan.startDate)) 〜 \(TravelPlanTextExporter.dateString(plan.endDate))")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
    }
}

private struct ShareCardFooter<Content: View>: View {
    let accentColor: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 10) {
            content()

            HStack(spacing: 5) {
                Image(systemName: "airplane.departure")
                    .font(.caption2)
                Text("Travory")
                    .font(.caption.weight(.bold))
                Spacer()
            }
            .foregroundColor(accentColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .background(accentColor.opacity(0.07))
    }
}
