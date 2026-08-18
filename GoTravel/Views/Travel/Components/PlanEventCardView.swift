import SwiftUI

// MARK: - Plan Event Card View
struct PlanEventCardView: View {
    let plan: Plan
    var onDelete: (() -> Void)? = nil
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var themeManager = ThemeManager.shared

    // メインテーマ色（カード全体の主役。種別カラーはアクセントに限定）
    private var mainColor: Color {
        themeManager.currentTheme.xprimary
    }

    private var titleColor: Color {
        colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1
    }

    private var subTextColor: Color {
        titleColor.opacity(0.65)
    }

    private var typeIcon: String {
        plan.planType == .daily ? "house.fill" : "figure.walk"
    }

    private var typeName: String {
        plan.planType == .daily ? "日常" : "おでかけ"
    }

    private var isSingleDay: Bool {
        Calendar.current.isDate(plan.startDate, inSameDayAs: plan.endDate)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // アイコンチップ（テーマ色主体、アイコン形状で種別を表現）
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [mainColor, mainColor.opacity(0.65)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 46, height: 46)
                        .shadow(color: mainColor.opacity(0.35), radius: 5, x: 0, y: 3)
                    Image(systemName: typeIcon)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(.white)
                }

                // 種別カラーのドット（色分けのアクセント）
                Circle()
                    .fill(typeColor)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(colorScheme == .dark
                                    ? themeManager.currentTheme.secondaryBackgroundDark
                                    : themeManager.currentTheme.backgroundLight,
                                    lineWidth: 2)
                    )
                    .offset(x: 3, y: 3)
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text(plan.title)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundColor(titleColor)
                        .lineLimit(1)

                    // 種別バッジ
                    Text(typeName)
                        .font(.caption2.weight(.bold))
                        .foregroundColor(typeColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(typeColor.opacity(0.14), in: Capsule())
                }

                HStack(spacing: 10) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text(isSingleDay
                             ? dateString(plan.startDate)
                             : "\(dateString(plan.startDate)) 〜 \(dateString(plan.endDate))")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundColor(subTextColor)

                    if plan.planType == .daily, let time = plan.time {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text(formatTime(time))
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                        }
                        .foregroundColor(mainColor)
                    }

                    if !plan.places.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.caption2)
                            Text("\(plan.places.count)件")
                                .font(.caption.weight(.medium))
                        }
                        .foregroundColor(subTextColor)
                    }
                }
            }

            Spacer(minLength: 0)

            if let onDelete = onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.subheadline)
                        .foregroundColor(subTextColor)
                        .padding(8)
                        .background(titleColor.opacity(0.06), in: Circle())
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel("予定を削除")
            }
        }
        .padding(14)
        .background(
            // ベース背景 + テーマ色のごく淡い色被せ
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(colorScheme == .dark
                          ? themeManager.currentTheme.secondaryBackgroundDark
                          : themeManager.currentTheme.backgroundLight)
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                mainColor.opacity(colorScheme == .dark ? 0.16 : 0.10),
                                mainColor.opacity(0.02)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(mainColor.opacity(0.28), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 7, x: 0, y: 3)
    }

    private var typeColor: Color {
        plan.planType == .daily
            ? themeManager.currentTheme.dailyPlanColor
            : themeManager.currentTheme.outingPlanColor
    }

    private func dateString(_ d: Date) -> String {
        DateFormatter.japaneseDate.string(from: d)
    }

    private func formatTime(_ time: Date) -> String {
        DateFormatter.japaneseTime.string(from: time)
    }
}
