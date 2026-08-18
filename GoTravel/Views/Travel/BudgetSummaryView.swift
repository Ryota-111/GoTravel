import SwiftUI

struct BudgetSummaryView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var themeManager = ThemeManager.shared
    @EnvironmentObject var travelPlanViewModel: TravelPlanViewModel
    @EnvironmentObject var authVM: AuthViewModel

    let plan: TravelPlan
    /// タブに埋め込むときは true。独自のヘッダーを出さない
    var isEmbedded: Bool = false

    /// ViewModelから最新のプランを見る。人数を変えた結果を即座に反映するため
    private var currentPlan: TravelPlan {
        travelPlanViewModel.travelPlans.first(where: { $0.id == plan.id }) ?? plan
    }

    private var allItems: [ScheduleItem] {
        currentPlan.daySchedules.flatMap { $0.scheduleItems }
    }

    // MARK: - Computed Properties
    private var totalCost: Double {
        allItems.compactMap { $0.cost }.reduce(0, +)
    }

    /// 実際に使った金額の合計。未入力の項目は集計しない
    private var totalActualCost: Double {
        allItems.compactMap { $0.actualCost }.reduce(0, +)
    }

    private var hasActualCost: Bool {
        allItems.contains { $0.actualCost != nil }
    }

    /// 実績 - 予算。プラスなら予算オーバー
    private var costDifference: Double {
        totalActualCost - totalCost
    }

    private var memberCount: Int {
        currentPlan.splitCount
    }

    /// 折半の対象になる金額。実績が入っていればそちらを優先する
    private var splitBaseCost: Double {
        hasActualCost ? totalActualCost : totalCost
    }

    private var costPerPerson: Double {
        guard memberCount > 0 else { return 0 }
        return splitBaseCost / Double(memberCount)
    }

    private var costByDay: [(dayNumber: Int, date: Date, cost: Double)] {
        currentPlan.daySchedules.map { day in
            let cost = day.scheduleItems.compactMap { $0.cost }.reduce(0, +)
            return (day.dayNumber, day.date, cost)
        }.filter { $0.cost > 0 }
    }

    private var costByDayDetailed: [(dayNumber: Int, date: Date, items: [(title: String, cost: Double)])] {
        currentPlan.daySchedules.compactMap { day in
            let items = day.scheduleItems
                .filter { ($0.cost ?? 0) > 0 }
                .map { ($0.title, $0.cost!) }
            guard !items.isEmpty else { return nil }
            return (day.dayNumber, day.date, items)
        }
    }

    private var tripDays: Int {
        (Calendar.current.dateComponents([.day], from: currentPlan.startDate, to: currentPlan.endDate).day ?? 0) + 1
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
        if isEmbedded {
            // 親がスクロールを持つので、ここでは入れ子にしない
            cards
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 30)
        } else {
            ZStack {
                bgGradient

                VStack(spacing: 0) {
                    headerView

                    ScrollView(showsIndicators: false) {
                        cards
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }

    private var cards: some View {
        VStack(spacing: 16) {
            totalCostCard

            if hasActualCost {
                actualCostCard
            }

            // 共有していなくても同行者と割り勘したい場面があるため常に出す
            if splitBaseCost > 0 {
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
                Text(currentPlan.title)
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
                    Text(currentPlan.destination)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(20)
        }
        .frame(height: 160)
        .shadow(color: budgetColor.opacity(0.35), radius: 12, x: 0, y: 6)
    }

    // MARK: - Actual Cost Card
    /// 予算と実績の比較。実績が1件でも入っているときだけ出す
    private var actualCostCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(budgetColor)
                    .font(.subheadline)
                Text("実際に使った金額")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(accentColor)
            }

            HStack(spacing: 12) {
                amountColumn(label: "予算", amount: totalCost, color: themeManager.currentTheme.secondaryText)

                Spacer()

                amountColumn(label: "実績", amount: totalActualCost, color: budgetColor)

                Spacer()

                amountColumn(
                    label: costDifference > 0 ? "超過" : "節約",
                    amount: abs(costDifference),
                    color: costDifference > 0 ? themeManager.currentTheme.error : themeManager.currentTheme.success
                )
            }
            .padding(14)
            .background(budgetColor.opacity(0.06))
            .cornerRadius(12)

            Text(differenceMessage)
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

    private func amountColumn(label: String, amount: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(themeManager.currentTheme.secondaryText)
            Text(formatCurrency(amount))
                .font(.subheadline.weight(.bold))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private var differenceMessage: String {
        if costDifference > 0 {
            return "予算より \(formatCurrency(costDifference)) 多く使いました"
        } else if costDifference < 0 {
            return "予算より \(formatCurrency(abs(costDifference))) 少なく済みました"
        }
        return "予算どおりに収まりました"
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

                Spacer()

                // 共有していない同行者がいるため、人数は共有人数と一致しない
                if currentPlan.customSplitCount != nil {
                    Button("自動に戻す") { updateSplitCount(nil) }
                        .font(.caption)
                        .foregroundColor(budgetColor)
                }
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("割る人数")
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.secondaryText)

                    HStack(spacing: 10) {
                        splitStepButton(systemName: "minus", enabled: memberCount > 1) {
                            updateSplitCount(memberCount - 1)
                        }

                        Text("\(memberCount)人")
                            .font(.title3.weight(.bold))
                            .foregroundColor(accentColor)
                            .frame(minWidth: 52)

                        splitStepButton(systemName: "plus", enabled: memberCount < 99) {
                            updateSplitCount(memberCount + 1)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("1人あたり")
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                    Text(formatCurrency(costPerPerson))
                        .font(.title3.weight(.bold))
                        .foregroundColor(budgetColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .padding(14)
            .background(budgetColor.opacity(0.06))
            .cornerRadius(12)

            Text("\(hasActualCost ? "実績" : "合計") \(formatCurrency(splitBaseCost)) ÷ \(memberCount)人")
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

    private func splitStepButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(enabled ? budgetColor : themeManager.currentTheme.secondaryText.opacity(0.4))
                .frame(width: 32, height: 32)
                .background(Circle().fill(budgetColor.opacity(enabled ? 0.12 : 0.05)))
        }
        .disabled(!enabled)
    }

    /// 割り勘の人数を保存する。nil を渡すと自動（共有人数）に戻る
    private func updateSplitCount(_ count: Int?) {
        guard let userId = authVM.userId else { return }
        var updated = currentPlan
        updated.customSplitCount = count
        travelPlanViewModel.update(updated, userId: userId)
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
