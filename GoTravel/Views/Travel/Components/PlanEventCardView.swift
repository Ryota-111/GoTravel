import SwiftUI

// MARK: - Plan Event Card View
struct PlanEventCardView: View {
    let plan: Plan
    var onDelete: (() -> Void)? = nil
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var themeManager = ThemeManager.shared

    var body: some View {
        let secondaryTextColor = colorScheme == .dark ? themeManager.currentTheme.light.opacity(0.9) : themeManager.currentTheme.dark.opacity(0.9)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(plan.title)
                        .font(.headline)
                        .foregroundColor(colorScheme == .dark ? themeManager.currentTheme.light : themeManager.currentTheme.dark)

                    HStack {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundColor(secondaryTextColor)
                        Text("\(dateString(plan.startDate)) 〜 \(dateString(plan.endDate))")
                            .font(.subheadline)
                            .foregroundColor(secondaryTextColor)
                    }

                    if plan.planType == .daily, let time = plan.time {
                        HStack {
                            Image(systemName: "clock")
                                .font(.caption)
                                .foregroundColor(secondaryTextColor)
                            Text(formatTime(time))
                                .font(.subheadline)
                                .foregroundColor(secondaryTextColor)
                        }
                    }
                }

                Spacer()

                if let onDelete = onDelete {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1)
                            .padding(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            if !plan.places.isEmpty {
                Divider()
                    .background(colorScheme == .dark ? themeManager.currentTheme.accent2.opacity(0.5) : themeManager.currentTheme.accent1.opacity(0.5))

                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(secondaryTextColor)

                    Text("\(plan.places.count) 件の場所")
                        .font(.caption)
                        .foregroundColor(secondaryTextColor)
                }
            }
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: plan.planType == .daily ? [themeManager.currentTheme.xsecondary, colorScheme == .dark ? themeManager.currentTheme.dark.opacity(0.1) : themeManager.currentTheme.light.opacity(0.1)] : [themeManager.currentTheme.xprimary, colorScheme == .dark ? themeManager.currentTheme.dark.opacity(0.1) : themeManager.currentTheme.light.opacity(0.1)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: plan.planType == .daily ? [themeManager.currentTheme.dailyPlanColor.opacity(0.5), themeManager.currentTheme.dailyPlanColor.opacity(0.2)] : [themeManager.currentTheme.outingPlanColor.opacity(0.5), themeManager.currentTheme.outingPlanColor.opacity(0.2)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
        .shadow(
            color: plan.planType == .daily ? themeManager.currentTheme.xsecondary.opacity(0.5) : themeManager.currentTheme.xprimary.opacity(0.5),
            radius: 10
        )
    }

    private func dateString(_ d: Date) -> String {
        DateFormatter.japaneseDate.string(from: d)
    }

    private func formatTime(_ time: Date) -> String {
        DateFormatter.japaneseTime.string(from: time)
    }
}
