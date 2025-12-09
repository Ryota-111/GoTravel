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
                Text(title)
                    .font(.headline)
                    .foregroundColor(colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1)

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
