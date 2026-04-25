import SwiftUI

struct BudgetSummaryView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var themeManager = ThemeManager.shared

    let plan: TravelPlan

    // MARK: - Computed Properties
    private var totalCost: Double {
        plan.daySchedules
            .flatMap { $0.scheduleItems }
            .compactMap { $0.cost }
            .reduce(0, +)
    }

    private var memberCount: Int {
        plan.isShared ? plan.sharedWith.count : 1
    }

    private var costPerPerson: Double {
        guard memberCount > 0 else { return 0 }
        return totalCost / Double(memberCount)
    }

    private var costByDay: [(dayNumber: Int, date: Date, cost: Double)] {
        plan.daySchedules.map { day in
            let cost = day.scheduleItems.compactMap { $0.cost }.reduce(0, +)
            return (day.dayNumber, day.date, cost)
        }.filter { $0.cost > 0 }
    }

    private var costByDayDetailed: [(dayNumber: Int, date: Date, items: [(title: String, cost: Double)])] {
        plan.daySchedules.compactMap { day in
            let items = day.scheduleItems
                .filter { ($0.cost ?? 0) > 0 }
                .map { ($0.title, $0.cost!) }
            guard !items.isEmpty else { return nil }
            return (day.dayNumber, day.date, items)
        }
    }

    private var tripDays: Int {
        (Calendar.current.dateComponents([.day], from: plan.startDate, to: plan.endDate).day ?? 0) + 1
    }

    // MARK: - Theme Colors
    private var accentColor: Color {
        colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1
    }

    private var budgetColor: Color {
        switch themeManager.currentTheme.type {
        case .whiteBlack: return Color.black
        default: return themeManager.currentTheme.primary
        }
    }

    private var cardBg: Color {
        colorScheme == .dark
            ? themeManager.currentTheme.secondaryBackgroundDark
            : themeManager.currentTheme.secondaryBackgroundLight
    }

    private var bgGradient: some View {
        let colors: [Color]
        switch themeManager.currentTheme.type {
        case .whiteBlack:
            colors = [Color(white: 0.96), Color(white: 0.91)]
        default:
            colors = colorScheme == .dark
                ? [themeManager.currentTheme.backgroundDark, themeManager.currentTheme.secondaryBackgroundDark]
                : [themeManager.currentTheme.backgroundLight, themeManager.currentTheme.secondaryBackgroundLight]
        }
        return LinearGradient(gradient: Gradient(colors: colors), startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            bgGradient

            VStack(spacing: 0) {
                headerView

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        totalCostCard

                        if plan.isShared && totalCost > 0 {
                            costSplitCard
                        }

                        if !costByDay.isEmpty {
                            costByDayCard
                        }

                        if !costByDayDetailed.isEmpty {
                            costBreakdownCard
                        }

                        if totalCost == 0 {
                            emptyStateView
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - Header
    private var headerView: some View {
        HStack {
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                Image(systemName: "xmark")
                    .foregroundColor(accentColor)
                    .imageScale(.medium)
                    .padding(8)
                    .background(accentColor.opacity(0.1))
                    .clipShape(Circle())
            }

            Spacer()

            VStack(spacing: 2) {
                Text("予算サマリー")
                    .font(.headline)
                    .foregroundColor(accentColor)
                Text(plan.title)
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(budgetColor.opacity(0.12))
    }

    // MARK: - Total Cost Hero Card
    private var totalCostCard: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                gradient: Gradient(colors: [budgetColor.opacity(0.85), budgetColor.opacity(0.5)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .cornerRadius(20)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "yensign.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.8))
                        Text("合計予算")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.white.opacity(0.8))
                    }

                    Spacer()

                    Text("\(tripDays)日間")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.2))
                        .clipShape(Capsule())
                }

                Text(formatCurrency(totalCost))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text(plan.destination)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(20)
        }
        .frame(height: 160)
        .shadow(color: budgetColor.opacity(0.35), radius: 12, x: 0, y: 6)
    }

    // MARK: - Cost Split Card
    private var costSplitCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .foregroundColor(budgetColor)
                    .font(.subheadline)
                Text("金額折半")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(accentColor)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("参加人数")
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                    Text("\(memberCount)人")
                        .font(.title3.weight(.bold))
                        .foregroundColor(accentColor)
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.secondaryText.opacity(0.4))

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("1人あたり")
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                    Text(formatCurrency(costPerPerson))
                        .font(.title3.weight(.bold))
                        .foregroundColor(budgetColor)
                }
            }
            .padding(14)
            .background(budgetColor.opacity(0.06))
            .cornerRadius(12)

            Text("合計 \(formatCurrency(totalCost)) ÷ \(memberCount)人")
                .font(.caption)
                .foregroundColor(themeManager.currentTheme.secondaryText)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBg)
                .shadow(color: themeManager.currentTheme.shadow, radius: 6, x: 0, y: 2)
        )
    }

    // MARK: - Cost By Day Card (progress bars)
    private var costByDayCard: some View {
        let maxCost = costByDay.map { $0.cost }.max() ?? 1

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(budgetColor)
                    .font(.subheadline)
                Text("日別の支出")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(accentColor)
            }

            VStack(spacing: 12) {
                ForEach(costByDay, id: \.dayNumber) { day in
                    VStack(spacing: 5) {
                        HStack {
                            Text("Day \(day.dayNumber)")
                                .font(.caption.weight(.bold))
                                .foregroundColor(accentColor)
                                .frame(width: 44, alignment: .leading)
                            Text(formatDate(day.date))
                                .font(.caption)
                                .foregroundColor(themeManager.currentTheme.secondaryText)
                            Spacer()
                            Text(formatCurrency(day.cost))
                                .font(.caption.weight(.semibold))
                                .foregroundColor(budgetColor)
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(budgetColor.opacity(0.1))
                                    .frame(height: 6)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            colors: [budgetColor, budgetColor.opacity(0.6)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geo.size.width * CGFloat(day.cost / maxCost), height: 6)
                            }
                        }
                        .frame(height: 6)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBg)
                .shadow(color: themeManager.currentTheme.shadow, radius: 6, x: 0, y: 2)
        )
    }

    // MARK: - Cost Breakdown Card (grouped by day)
    private var costBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "list.bullet.rectangle")
                    .foregroundColor(budgetColor)
                    .font(.subheadline)
                Text("支出の内訳")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(accentColor)
            }

            VStack(spacing: 12) {
                ForEach(costByDayDetailed, id: \.dayNumber) { day in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Text("Day \(day.dayNumber)")
                                .font(.caption.weight(.bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(budgetColor.opacity(0.8))
                                .clipShape(Capsule())
                            Text(formatDate(day.date))
                                .font(.caption)
                                .foregroundColor(themeManager.currentTheme.secondaryText)
                        }

                        VStack(spacing: 0) {
                            ForEach(day.items.indices, id: \.self) { idx in
                                let item = day.items[idx]
                                HStack {
                                    Text(item.title)
                                        .font(.subheadline)
                                        .foregroundColor(accentColor)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(formatCurrency(item.cost))
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(budgetColor)
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)

                                if idx < day.items.count - 1 {
                                    Divider()
                                        .padding(.horizontal, 12)
                                }
                            }
                        }
                        .background(budgetColor.opacity(0.04))
                        .cornerRadius(10)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBg)
                .shadow(color: themeManager.currentTheme.shadow, radius: 6, x: 0, y: 2)
        )
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(budgetColor.opacity(0.08))
                    .frame(width: 80, height: 80)
                Image(systemName: "yensign.circle")
                    .font(.system(size: 36))
                    .foregroundColor(budgetColor.opacity(0.4))
            }
            Text("まだ金額が登録されていません")
                .font(.subheadline.weight(.medium))
                .foregroundColor(accentColor)
            Text("スケジュールに金額を追加すると\nここに表示されます")
                .font(.caption)
                .foregroundColor(themeManager.currentTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(budgetColor.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(budgetColor.opacity(0.15), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                )
        )
    }

    // MARK: - Helpers
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return "¥\(formatter.string(from: NSNumber(value: amount)) ?? "0")"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter.japanese
        formatter.dateFormat = "M月d日(E)"
        return formatter.string(from: date)
    }
}
