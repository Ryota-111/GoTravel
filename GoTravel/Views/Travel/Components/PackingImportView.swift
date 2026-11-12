import SwiftUI

/// 前の旅行のリストを、いまの旅行に取り込む。
///
/// 「よく使う候補」から選び直すのではなく、**前回そのまま**を求める声があった。
/// 毎回だいたい同じものを持っていく人にとっては、候補を1つずつ選ぶより
/// 前の旅行を指すほうが早い。
///
/// 計画の複製（`DuplicateTravelPlanView`）とは別物。あちらは旅行ごと写すもので、
/// これは**行き先も日程も違う新しい旅行に、リストだけ**持ってくる。
///
/// 旅行を選んだあと、**持ってくるものを選ぶ**（3.5）。全部まとめて入ると、
/// 今回は要らないもの（前回だけのお土産など）を1つずつ消すことになっていた
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

    /// いまの旅行にもう入っているもの。選ぶ画面で「追加済み」にする
    private var existingKeys: Set<String> {
        let current = viewModel.travelPlans.first { $0.id == currentPlan.id } ?? currentPlan
        return Set(items(from: current).map(SouvenirGrouping.importKey(of:)))
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
                                NavigationLink {
                                    PackingImportItemsView(kind: kind,
                                                           sourceTitle: plan.title,
                                                           items: items(from: plan),
                                                           existingKeys: existingKeys) { selected in
                                        onImport(selected)
                                        dismiss()
                                    }
                                } label: {
                                    row(for: plan)
                                }
                            }
                        } footer: {
                            Text("旅行を選ぶと、持ってくるものを選べます。チェックは外した状態で取り込みます。")
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

/// 前の旅行のリストから、持ってくるものを選ぶ（3.5）。はじめは何も選んでいない
private struct PackingImportItemsView: View {
    let kind: PackingItem.Kind
    let sourceTitle: String
    let items: [PackingItem]
    /// いまの旅行にもう入っているもの（`SouvenirGrouping.importKey`）。選べないようにする
    let existingKeys: Set<String>
    let onImport: ([PackingItem]) -> Void

    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var selected: Set<String> = []

    private var theme: ThemePreset { themeManager.currentTheme }

    private var selectable: [PackingItem] {
        items.filter { !existingKeys.contains(SouvenirGrouping.importKey(of: $0)) }
    }

    private var allSelected: Bool {
        !selectable.isEmpty && selectable.allSatisfy { selected.contains($0.id) }
    }

    var body: some View {
        List {
            Section {
                ForEach(items) { item in
                    let isAdded = existingKeys.contains(SouvenirGrouping.importKey(of: item))
                    let isSelected = selected.contains(item.id)
                    Button {
                        if isSelected { selected.remove(item.id) } else { selected.insert(item.id) }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: isAdded ? "checkmark.circle" : (isSelected ? "checkmark.circle.fill" : "circle"))
                                .font(.system(size: 20))
                                .foregroundColor(isAdded ? theme.tertiaryText : (isSelected ? theme.actionFill : theme.secondaryText.opacity(0.5)))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(.subheadline)
                                    .foregroundColor(isAdded ? theme.secondaryText : theme.text)
                                if let detail = item.recipientAndNote {
                                    Text(detail)
                                        .font(.caption)
                                        .foregroundColor(theme.secondaryText)
                                }
                            }
                            Spacer(minLength: 8)
                            if isAdded {
                                Text("追加済み")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundColor(theme.tertiaryText)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isAdded)
                    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                }
            } header: {
                HStack {
                    Text("\(sourceTitle)の\(kind.title)")
                    Spacer()
                    if !selectable.isEmpty {
                        Button(allSelected ? "選択を解除" : "すべて選択") {
                            selected = allSelected ? [] : Set(selectable.map(\.id))
                        }
                        .font(.caption.weight(.semibold))
                        .textCase(nil)
                    }
                }
            }
        }
        .navigationTitle("持ってくるものを選ぶ")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                onImport(items.filter { selected.contains($0.id) })
            } label: {
                Text(selected.isEmpty ? "持ってくるものを選んでください" : "\(selected.count)件を追加")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(selected.isEmpty ? theme.secondaryText : ThemePreset.readableText(on: theme.actionFill))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: AppRadius.large)
                        .fill(selected.isEmpty ? theme.actionFill.opacity(0.12) : theme.actionFill))
            }
            .buttonStyle(.plain)
            .disabled(selected.isEmpty)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }
}
