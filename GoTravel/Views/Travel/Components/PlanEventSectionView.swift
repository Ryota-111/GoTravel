import SwiftUI

// MARK: - Plan Event Section View
struct PlanEventSectionView: View {
    let title: String
    let plans: [Plan]
    let viewModel: PlansViewModel
    let onDelete: (Plan) -> Void
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
                    NavigationLink(destination: PlanDetailView(plan: plan).environmentObject(viewModel)) {
                        PlanEventCardView(plan: plan, onDelete: {
                            onDelete(plan)
                        })
                    }
                    .buttonStyle(PlainButtonStyle())
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.3).combined(with: .opacity),
                        removal: .opacity
                    ))
                }
            }
        }
    }
}
