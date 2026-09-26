import SwiftUI

// MARK: - Plan Event Section View
struct PlanEventSectionView: View {
    let title: String
    let plans: [Plan]
    let viewModel: PlansViewModel
    let onDelete: (Plan) -> Void
    /// まとめて削除するための選択。nil なら普段どおり（押すと詳細を開く）
    var selection: Binding<Set<String>>? = nil
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !plans.isEmpty {
                HStack(spacing: 9) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1)

                    // 何件あるかは、下まで数えないと分からなかった
                    Text("\(plans.count)")
                        .font(.system(size: 11, weight: .bold))
                        .monospacedDigit()
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(themeManager.currentTheme.secondaryText.opacity(colorScheme == .dark ? 0.18 : 0.10))
                        )
                }

                ForEach(plans) { plan in
                    Group {
                        if let selection {
                            selectableRow(plan, selection: selection)
                        } else {
                            NavigationLink(destination: PlanDetailView(plan: plan).environmentObject(viewModel)) {
                                PlanEventCardView(plan: plan, onDelete: {
                                    onDelete(plan)
                                })
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.3).combined(with: .opacity),
                        removal: .opacity
                    ))
                }
            }
        }
    }

    /// 選択中の1行。押すと選ぶ・外す。カードの「…」は選択中は効かないようにする
    private func selectableRow(_ plan: Plan, selection: Binding<Set<String>>) -> some View {
        let isSelected = selection.wrappedValue.contains(plan.id)

        return Button {
            if isSelected {
                selection.wrappedValue.remove(plan.id)
            } else {
                selection.wrappedValue.insert(plan.id)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected
                                     ? themeManager.currentTheme.error
                                     : themeManager.currentTheme.secondaryText.opacity(0.5))

                PlanEventCardView(plan: plan, onDelete: {})
                    .allowsHitTesting(false)
                    .opacity(isSelected ? 0.6 : 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(plan.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
