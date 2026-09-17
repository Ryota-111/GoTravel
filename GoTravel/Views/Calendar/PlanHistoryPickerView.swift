import SwiftUI

/// カレンダーの日付を長押ししたときに出す、これまでの予定の一覧。
///
/// 「またジム」「また同じ店」のような繰り返しを、毎回同じ内容で打ち直すのは手間。
/// 過去に作った予定をそのまま選んで、その日に置けるようにする。
///
/// 選んだ時点で作る。確認の画面は挟まない。
/// 直したいことがあれば、できた予定を開いて直せばよい。
struct PlanHistoryPickerView: View {
    let date: Date
    /// 選ばれた予定。呼び出し側がその日付で作り直す
    let onPick: (Plan) -> Void

    @EnvironmentObject var viewModel: PlansViewModel
    @ObservedObject private var tagManager = PlanTagManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""

    private var theme: ThemePreset { themeManager.currentTheme }
    private var accent: Color { theme.actionFill }

    /// 履歴。
    ///
    /// **同じ名前・同じ種別のものは1件にまとめる。** 毎週のジムが
    /// 何十件も並ぶと、探すほうが手間になる。
    /// 新しいものを残すので、直近の内容（タグや時刻）が引き継がれる
    private var history: [Plan] {
        var seen = Set<String>()
        var result: [Plan] = []

        for plan in viewModel.plans.sorted(by: { $0.createdAt > $1.createdAt }) {
            let key = "\(plan.planType.rawValue)\u{1F}\(plan.title)"
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(plan)
        }

        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return result }
        return result.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.plans.isEmpty {
                    emptyState
                } else {
                    List {
                        Section {
                            ForEach(history) { plan in
                                Button {
                                    onPick(plan)
                                    dismiss()
                                } label: {
                                    row(plan)
                                }
                                .buttonStyle(.plain)
                            }
                        } footer: {
                            Text("選ぶとこの日に作ります。中身はそのまま引き継ぎ、日付だけ差し替えます。写真は引き継ぎません。")
                        }
                    }
                    .searchable(text: $searchText, prompt: "予定を探す")
                }
            }
            .navigationTitle(titleText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                        .foregroundColor(theme.secondaryText)
                }
            }
        }
    }

    private var titleText: String {
        let formatter = DateFormatter.japanese
        formatter.dateFormat = "M月d日(E)"
        return "\(formatter.string(from: date)) に作る"
    }

    private func row(_ plan: Plan) -> some View {
        HStack(spacing: 12) {
            Image(systemName: plan.planType.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ThemePreset.readableTint(accent, on: theme.backgroundLight))
                .frame(width: 30, height: 30)
                .background(Circle().fill(accent.opacity(0.12)))

            VStack(alignment: .leading, spacing: 3) {
                Text(plan.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(theme.text)
                    .lineLimit(1)

                Text(subtitle(for: plan))
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Image(systemName: "plus.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(ThemePreset.readableTint(accent, on: theme.backgroundLight))
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    /// 種別・時刻・泊数・タグを1行にまとめる。
    /// どれも「同じ名前の予定を見分ける」ために要る
    private func subtitle(for plan: Plan) -> String {
        var pieces = [plan.planType.displayName]

        if let time = plan.time {
            pieces.append(DateFormatter.japaneseTime.string(from: time))
        }
        if plan.isMultiDay {
            pieces.append("\(plan.dayCount - 1)泊\(plan.dayCount)日")
        }
        if !plan.scheduleItems.isEmpty {
            pieces.append("予定\(plan.scheduleItems.count)件")
        }

        let tags = tagManager.tags(for: plan.tagIDs).map(\.name)
        pieces.append(contentsOf: tags)

        return pieces.joined(separator: "・")
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 34))
                .foregroundColor(theme.secondaryText.opacity(0.5))

            Text("まだ履歴がありません")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(theme.text)

            Text("予定を作ると、次からここに並びます。同じ予定をくり返し置くときに使えます。")
                .font(.caption)
                .foregroundColor(theme.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(28)
    }
}
