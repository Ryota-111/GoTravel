import SwiftUI

/// タイムスケジュールの予定を1つ選ぶ。
///
/// 予約を追加するとき、行程に書いた飛行機や宿をもう一度打ち直すのは手間なので、
/// そこから名前・日時・場所を持ってこられるようにする。
struct ScheduleItemPickerView: View {
    let plan: TravelPlan
    /// 選ばれた予定と、それが何日目かの日付を返す
    let onPick: (ScheduleItem, Date) -> Void

    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss

    private var cardFill: Color {
        colorScheme == .dark
            ? themeManager.currentTheme.secondaryBackgroundDark
            : themeManager.currentTheme.secondaryBackgroundLight
    }

    private var textColor: Color { ThemePreset.readableText(on: cardFill) }
    private var accent: Color { themeManager.currentTheme.actionFill }

    /// 予定が入っている日だけ。空の日を並べても選べないので出さない
    private var daysWithItems: [DaySchedule] {
        plan.daySchedules
            .filter { !$0.scheduleItems.isEmpty }
            .sorted { $0.dayNumber < $1.dayNumber }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark
                    ? themeManager.currentTheme.backgroundDark
                    : themeManager.currentTheme.backgroundLight)
                    .ignoresSafeArea()

                if daysWithItems.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 20) {
                            ForEach(daysWithItems) { day in
                                daySection(day)
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("予定から取り込む")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                        .foregroundColor(accent)
                }
            }
        }
    }

    private func daySection(_ day: DaySchedule) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Day \(day.dayNumber)　\(dayLabel(plan.date(forDay: day.dayNumber)))")
                .font(.caption.weight(.semibold))
                .foregroundColor(themeManager.currentTheme.secondaryText)

            ForEach(day.scheduleItems.sorted { $0.time < $1.time }) { item in
                row(item: item, dayDate: plan.date(forDay: day.dayNumber))
            }
        }
    }

    private func row(item: ScheduleItem, dayDate: Date) -> some View {
        HStack(spacing: 12) {
            Text(timeLabel(item.time))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundColor(accent)
                .frame(width: 52)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(textColor)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if let location = item.location, !location.isEmpty {
                    Text(location)
                        .font(.system(size: 12))
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: Reservation.guessedKind(title: item.title, location: item.location).icon)
                .font(.system(size: 14))
                .foregroundColor(themeManager.currentTheme.secondaryText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(textColor.opacity(0.12), lineWidth: 1)
                )
        )
        // Button にすると横スワイプでも反応してしまうため onTapGesture を使う
        .contentShape(Rectangle())
        .onTapGesture {
            onPick(item, dayDate)
            dismiss()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundColor(themeManager.currentTheme.secondaryText.opacity(0.5))

            Text("取り込める予定がありません")
                .font(.headline)
                .foregroundColor(textColor)

            Text("日程タブで予定を追加すると、ここから選べます。")
                .font(.caption)
                .foregroundColor(themeManager.currentTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(30)
    }

    private func dayLabel(_ date: Date) -> String {
        let formatter = DateFormatter.japanese
        formatter.dateFormat = "M月d日(E)"
        return formatter.string(from: date)
    }

    private func timeLabel(_ date: Date) -> String {
        let formatter = DateFormatter.japanese
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
