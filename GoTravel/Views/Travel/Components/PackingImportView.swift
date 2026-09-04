import SwiftUI

/// 前の旅行のリストを、いまの旅行に取り込む。
///
/// 「よく使う候補」から選び直すのではなく、**前回そのまま**を求める声があった。
/// 毎回だいたい同じものを持っていく人にとっては、候補を1つずつ選ぶより
/// 前の旅行を指すほうが早い。
///
/// 計画の複製（`DuplicateTravelPlanView`）とは別物。あちらは旅行ごと写すもので、
/// これは**行き先も日程も違う新しい旅行に、リストだけ**持ってくる。
struct PackingImportView: View {
    let kind: PackingItem.Kind
    let currentPlan: TravelPlan
    /// 選ばれた旅行の項目を渡す。取り込みの実行は呼び出し側
    let onImport: ([PackingItem]) -> Void

    @EnvironmentObject var viewModel: TravelPlanViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    private var theme: ThemePreset { themeManager.currentTheme }

    /// 取り込める旅行。
    /// いまの旅行と、このリストが空の旅行は出さない（選んでも何も起きないため）
    private var sources: [TravelPlan] {
        viewModel.travelPlans
            .filter { $0.id != currentPlan.id }
            .filter { !items(from: $0).isEmpty }
            .sorted { $0.startDate > $1.startDate }
    }

    /// その旅行から持ってこられる項目。
    /// 自分に見えないもの（同行者だけのもの）は端末に無いので自然に外れる
    private func items(from plan: TravelPlan) -> [PackingItem] {
        plan.packingItems.filter { $0.kind == kind && $0.isVisible(to: authVM.userId) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if sources.isEmpty {
                    emptyState
                } else {
                    List {
                        Section {
                            ForEach(sources) { plan in
                                Button {
                                    onImport(items(from: plan))
                                    dismiss()
                                } label: {
                                    row(for: plan)
                                }
                                .buttonStyle(.plain)
                            }
                        } footer: {
                            Text("チェックは外した状態で取り込みます。いま入っているものはそのまま残り、同じ名前のものは重ねて追加しません。")
                        }
                    }
                }
            }
            .navigationTitle("前の旅行から取り込む")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                        .foregroundColor(theme.secondaryText)
                }
            }
        }
    }

    private func row(for plan: TravelPlan) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(plan.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(theme.text)
                    .lineLimit(1)

                Text("\(plan.destination)・\(dateRange(plan))")
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text("\(items(from: plan).count)件")
                .font(.caption.weight(.semibold))
                .foregroundColor(theme.secondaryText)

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.bold))
                .foregroundColor(theme.tertiaryText)
        }
        .contentShape(Rectangle())
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 34))
                .foregroundColor(theme.secondaryText.opacity(0.5))

            Text("取り込めるリストがありません")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(theme.text)

            Text("ほかの旅行で\(kind.title)を作ると、ここから持ってこられるようになります。")
                .font(.caption)
                .foregroundColor(theme.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(28)
    }

    private func dateRange(_ plan: TravelPlan) -> String {
        let formatter = DateFormatter.japanese
        formatter.dateFormat = "yyyy/M/d"
        return formatter.string(from: plan.startDate)
    }
}
