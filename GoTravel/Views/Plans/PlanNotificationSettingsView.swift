import SwiftUI

/// 予定ごとの通知設定。
///
/// 以前はベル1つで全部入れるか全部消すかしかできず、しかも設定が保存されていなかった。
/// ここで選んだ内容は予定そのものに残るので、通知が鳴り終わっても、
/// 予定を編集しても、選んだとおりのままになる
struct PlanNotificationSettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme

    let plan: Plan
    /// 選び直した結果。呼び出し元が予定を保存し直す
    let onSave: ([PlanReminder]) -> Void

    @State private var selected: Set<PlanReminder> = []

    private var accentColor: Color {
        colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1
    }

    private var options: [PlanReminder] {
        PlanReminder.options(for: plan.planType, hasTime: plan.time != nil)
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(options) { reminder in
                        Button {
                            toggle(reminder)
                        } label: {
                            HStack(spacing: 12) {
                                Text(reminder.displayName)
                                    .foregroundColor(accentColor)

                                Spacer()

                                Image(systemName: selected.contains(reminder) ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 20))
                                    .foregroundColor(
                                        selected.contains(reminder)
                                            ? plan.planType.color(themeManager.currentTheme)
                                            : themeManager.currentTheme.secondaryText.opacity(0.35)
                                    )
                            }
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                } header: {
                    Text("鳴らすタイミング")
                } footer: {
                    Text(footerText)
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                }

                if !selected.isEmpty {
                    Section {
                        Button("すべて外す") {
                            selected.removeAll()
                        }
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                    }
                }
            }
            .navigationTitle("通知")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { presentationMode.wrappedValue.dismiss() }
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        // 並びは選択順ではなく、鳴る順（`options` の並び）で保存する
                        onSave(options.filter { selected.contains($0) })
                        presentationMode.wrappedValue.dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(plan.planType.color(themeManager.currentTheme))
                }
            }
            .onAppear {
                selected = Set(plan.effectiveReminders)
            }
        }
        .navigationViewStyle(.stack)
    }

    /// 時刻を持たない予定では、時刻基準の選択肢がそもそも出せない。
    /// 何も言わずに項目が減っていると、故障に見える
    private var footerText: String {
        switch plan.planType {
        case .daily where plan.time == nil:
            return "開始時刻を設定すると、「1時間前」などの通知も選べます。ひとつも選ばなければ通知しません。"
        case .outing:
            return "おでかけは日単位の通知だけです。ひとつも選ばなければ通知しません。"
        case .anniversary:
            return "記念日は時刻を持たないため、日単位の通知だけです。ひとつも選ばなければ通知しません。"
        default:
            return "ひとつも選ばなければ通知しません。"
        }
    }

    private func toggle(_ reminder: PlanReminder) {
        if selected.contains(reminder) {
            selected.remove(reminder)
        } else {
            selected.insert(reminder)
        }
    }
}
