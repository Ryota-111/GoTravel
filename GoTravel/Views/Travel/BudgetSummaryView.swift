import SwiftUI

// 金額画面
struct BudgetSummaryView: View {
    // MARK: - Properties
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var themeManager = ThemeManager.shared

    let plan: TravelPlan

    // MARK: - Computed Properties
    private var totalCost: Double {
        let allItems = plan.daySchedules.flatMap { $0.scheduleItems }
        logBudgetDetails(allItems: allItems)

        let costsArray = allItems.compactMap { $0.cost }
        let total = costsArray.reduce(0, +)

        return total
    }

    private var memberCount: Int {
        if plan.isShared {
            // Owner + shared members
            return plan.sharedWith.count
        }
        return 1
    }

    private var costPerPerson: Double {
        guard memberCount > 0 else { return 0 }
        return totalCost / Double(memberCount)
    }

    private var costByDay: [(dayNumber: Int, date: Date, cost: Double)] {
        plan.daySchedules.map { daySchedule in
            let dayCost = daySchedule.scheduleItems.compactMap { $0.cost }.reduce(0, +)
            return (daySchedule.dayNumber, daySchedule.date, dayCost)
        }.filter { $0.cost > 0 }
    }

    private var costByCategory: [(category: String, items: [(title: String, cost: Double)])] {
        let itemsWithCost = extractItemsWithCost()
        return [("すべての支出", itemsWithCost)]
    }

    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: colorScheme == .dark ? [themeManager.currentTheme.gradientDark, themeManager.currentTheme.dark] : [themeManager.currentTheme.gradientLight, themeManager.currentTheme.light]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            backgroundGradient

            VStack(spacing: 0) {
                headerView
                scrollContent
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - View Components
    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                totalCostCard

                if plan.isShared && totalCost > 0 {
                    costSplitSection
                }

                if !costByDay.isEmpty {
                    costByDaySection
                }

                if !costByCategory.isEmpty {
                    costBreakdownSection
                }

                if totalCost == 0 {
                    emptyStateView
                }
            }
            .padding()
        }
    }

    private var headerView: some View {
        HStack {
            backButton

            Spacer()

            Text("金額管理")
                .font(.headline)
                .foregroundColor(colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1)

            Spacer()
        }
        .padding()
        .background(themeManager.currentTheme.accent1.opacity(0.2))
    }

    private var backButton: some View {
        Button(action: { presentationMode.wrappedValue.dismiss() }) {
            HStack {
                Image(systemName: "chevron.left")
                    .foregroundColor(colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1)
                    .imageScale(.large)
                Text("戻る")
                    .foregroundColor(colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1)
            }
        }
    }

    private var totalCostCard: some View {
        VStack(spacing: 15) {
            HStack {
                Image(systemName: "yensign.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.green)

                VStack(alignment: .leading, spacing: 5) {
                    Text("合計金額")
                        .font(.headline)
                        .foregroundColor(colorScheme == .dark ? themeManager.currentTheme.budgetDarkText : themeManager.currentTheme.budgetLightText)

                    Text(formatCurrency(totalCost))
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1)
                }

                Spacer()
            }
        }
        .padding()
        .background(themeManager.currentTheme.accent2.opacity(0.2))
        .cornerRadius(15)
    }

    private var costSplitSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "person.2.fill")
                    .font(.title2)
                    .foregroundColor(themeManager.currentTheme.primary)

                Text("金額折半")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1)
            }

            // Member count and per-person cost
            VStack(spacing: 12) {
                HStack {
                    Text("参加人数")
                        .font(.subheadline)
                        .foregroundColor(colorScheme == .dark ? themeManager.currentTheme.budgetDarkText : themeManager.currentTheme.budgetLightText)
                    Spacer()

                    Text("\(memberCount)人")
                        .font(.headline)
                        .foregroundColor(colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1)
                }

                Divider()
                    .background(themeManager.currentTheme.accent2.opacity(0.3))

                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("1人あたりの金額")
                            .font(.headline)
                            .foregroundColor(colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1)

                        Text("合計 \(formatCurrency(totalCost)) ÷ \(memberCount)人")
                            .font(.caption)
                            .foregroundColor(colorScheme == .dark ? themeManager.currentTheme.budgetDarkText : themeManager.currentTheme.budgetLightText)
                    }

                    Spacer()

                    Text(formatCurrency(costPerPerson))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1)
                }
            }
            .padding()
            .background(themeManager.currentTheme.accent2.opacity(0.1))
            .cornerRadius(10)
        }
        .padding()
        .background(themeManager.currentTheme.accent2.opacity(0.2))
        .cornerRadius(15)
    }

    private var costByDaySection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("日別の支出")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1)

            ForEach(costByDay, id: \.dayNumber) { day in
                dayBudgetRow(day: day)
            }
        }
        .padding()
        .background(themeManager.currentTheme.accent2.opacity(0.2))
        .cornerRadius(15)
    }

    private func dayBudgetRow(day: (dayNumber: Int, date: Date, cost: Double)) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text("Day \(day.dayNumber)")
                    .font(.headline)
                    .foregroundColor(colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1)

                Text(formatDate(day.date))
                    .font(.caption)
                    .foregroundColor(colorScheme == .dark ? themeManager.currentTheme.budgetDarkText : themeManager.currentTheme.budgetLightText)
            }

            Spacer()

            Text(formatCurrency(day.cost))
                .font(.headline)
                .foregroundColor(.green)
        }
        .padding()
        .background(themeManager.currentTheme.accent2.opacity(0.15))
        .cornerRadius(10)
    }

    private var costBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("支出の内訳")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1)

            ForEach(costByCategory, id: \.category) { category in
                categoryItemsList(category: category)
            }
        }
        .padding()
        .background(themeManager.currentTheme.accent2.opacity(0.2))
        .cornerRadius(15)
    }

    private func categoryItemsList(category: (category: String, items: [(title: String, cost: Double)])) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(category.items.indices, id: \.self) { index in
                let item = category.items[index]
                VStack(spacing: 0) {
                    HStack {
                        Text(item.title)
                            .font(.subheadline)
                            .foregroundColor(colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1)

                        Spacer()

                        Text(formatCurrency(item.cost))
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                    .padding(.vertical, 8)

                    if index < category.items.count - 1 {
                        Divider()
                            .background(themeManager.currentTheme.accent2.opacity(0.3))
                    }
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 15) {
            Image(systemName: "yensign.circle")
                .font(.system(size: 60))
                .foregroundColor(colorScheme == .dark ? themeManager.currentTheme.budgetDarkText : themeManager.currentTheme.budgetLightText)

            Text("まだ金額が登録されていません")
                .font(.body)
                .foregroundColor(colorScheme == .dark ? themeManager.currentTheme.budgetDarkText : themeManager.currentTheme.budgetLightText)

            Text("スケジュールに金額を追加すると、ここに表示されます")
                .font(.caption)
                .foregroundColor(colorScheme == .dark ? themeManager.currentTheme.budgetDarkText : themeManager.currentTheme.budgetLightText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(themeManager.currentTheme.accent2.opacity(0.2))
        .cornerRadius(15)
    }

    // MARK: - Helper Methods
    private func extractItemsWithCost() -> [(title: String, cost: Double)] {
        var itemsWithCost: [(title: String, cost: Double)] = []

        for daySchedule in plan.daySchedules {
            for item in daySchedule.scheduleItems {
                if let cost = item.cost {
                    itemsWithCost.append((item.title, cost))
                }
            }
        }

        return itemsWithCost
    }

    private func logBudgetDetails(allItems: [ScheduleItem]) {
        for (_, _) in allItems.enumerated() {
        }

        _ = allItems.compactMap { $0.cost }
    }

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
