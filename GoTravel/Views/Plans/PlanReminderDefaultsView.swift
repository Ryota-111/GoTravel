import SwiftUI

/// 通知の初期設定。新しく作る予定に最初から入る通知を種別ごとに決める。
///
/// 予定ごとの設定（`PlanNotificationSettingsView`）とは別物で、
/// **ここを変えても、すでにある予定の通知は変わらない**
struct PlanReminderDefaultsView: View {
    @ObservedObject var defaults = PlanReminderDefaults.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme

    private var accentColor: Color {
        themeManager.currentTheme.adaptiveText(for: colorScheme)
    }

    var body: some View {
        List {
            Section {
                Text("新しく作る予定に、最初から入れておく通知です。すでにある予定の通知は変わりません。")
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.secondaryText)
            }

            ForEach(PlanType.allCases, id: \.self) { planType in
                section(for: planType)
            }
        }
        .navigationTitle("通知の初期設定")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(for planType: PlanType) -> some View {
        // 時刻ありの選択肢まで出す。時刻を入れなかった予定では自動的に外れる
        let options = PlanReminder.options(for: planType, hasTime: true)
        let selected = defaults.reminders(for: planType)

        return Section {
            ForEach(options) { reminder in
                Button {
                    toggle(reminder, for: planType)
                } label: {
                    HStack(spacing: 12) {
                        Text(reminder.displayName)
                            .foregroundColor(accentColor)

                        Spacer()

                        Image(systemName: selected.contains(reminder) ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20))
                            .foregroundColor(
                                selected.contains(reminder)
                                    ? planType.color(themeManager.currentTheme)
                                    : themeManager.currentTheme.secondaryText.opacity(0.35)
                            )
                    }
                    .padding(.vertical, 2)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }

            if defaults.isCustomized(planType) {
                Button("初期状態に戻す") {
                    defaults.reset(planType)
                }
                .font(.subheadline)
                .foregroundColor(themeManager.currentTheme.secondaryText)
            }
        } header: {
            HStack(spacing: 6) {
                Image(systemName: planType.icon)
                    .foregroundColor(planType.color(themeManager.currentTheme))
                Text(planType.displayName)
            }
        } footer: {
            if planType == .daily {
                Text("「1時間前」などは、開始時刻を入れた予定にだけ入ります。")
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.secondaryText)
            }
        }
    }

    private func toggle(_ reminder: PlanReminder, for planType: PlanType) {
        var current = defaults.reminders(for: planType)

        if let index = current.firstIndex(of: reminder) {
            current.remove(at: index)
        } else {
            current.append(reminder)
        }

        defaults.setReminders(current, for: planType)
    }
}
