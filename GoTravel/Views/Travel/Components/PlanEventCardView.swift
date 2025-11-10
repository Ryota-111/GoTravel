import SwiftUI

// MARK: - Plan Event Card View
struct PlanEventCardView: View {
    let plan: Plan
    var onDelete: (() -> Void)? = nil
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        let textColor = colorScheme == .dark ? Color.white : Color.black
        let secondaryTextColor = colorScheme == .dark ? Color.white.opacity(0.9) : Color.black.opacity(0.7)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(plan.title)
                        .font(.headline)
                        .foregroundColor(textColor)

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
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                            .padding(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            if !plan.places.isEmpty {
                Divider()
                    .background(colorScheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.3))

                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(plan.planType == .daily ? .orange : .blue)

                    Text("\(plan.places.count) 件の場所")
                        .font(.caption)
                        .foregroundColor(secondaryTextColor)
                }
            }
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: plan.planType == .daily ? [.orange, colorScheme == .dark ? .black.opacity(0.1) : .white.opacity(0.1)] : [.blue.opacity(0.8), colorScheme == .dark ? .black.opacity(0.1) : .white.opacity(0.1)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: plan.planType == .daily ? [.orange.opacity(0.5), .orange.opacity(0.2)] : [.blue.opacity(0.5), .blue.opacity(0.2)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
        .shadow(
            color: plan.planType == .daily ? .orange.opacity(0.5) : .blue.opacity(0.5),
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
