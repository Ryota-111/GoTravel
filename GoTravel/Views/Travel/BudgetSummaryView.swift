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

    /// 明細を閉じている日。
    /// 開いた状態から始める（何に使ったかは開かなくても見えていてほしい）
    @State private var collapsedDays: Set<Int> = []

    /// ViewModelから最新のプランを見る。人数を変えた結果を即座に反映するため
    private var currentPlan: TravelPlan {
        travelPlanViewModel.travelPlans.first(where: { $0.id == plan.id }) ?? plan
    }

    private var allItems: [ScheduleItem] {
        currentPlan.daySchedulesInRange.flatMap { $0.scheduleItems }
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

    /// 日ごとの金額。
    ///
    /// 予算と実績の両方を持たせる。以前は予算しか見ていなかったため、
    /// 実績だけ入れた項目が日別にも内訳にも出ず、合計と食い違って見えていた
    private var costByDay: [DayCost] {
        currentPlan.daySchedulesInRange.compactMap { day in
            let items = day.scheduleItems
                .filter { ($0.cost ?? 0) > 0 || ($0.actualCost ?? 0) > 0 }
                .map { ItemCost(id: $0.id, title: $0.title, budget: $0.cost, actual: $0.actualCost) }
            guard !items.isEmpty else { return nil }

            return DayCost(
                dayNumber: day.dayNumber,
                date: currentPlan.date(forDay: day.dayNumber),
                budget: items.compactMap(\.budget).reduce(0, +),
                actual: items.compactMap(\.actual).reduce(0, +),
                hasActual: items.contains { $0.actual != nil },
                items: items
            )
        }
    }

    struct DayCost: Identifiable {
        let dayNumber: Int
        let date: Date
        let budget: Double
        let actual: Double
        let hasActual: Bool
        let items: [ItemCost]
        var id: Int { dayNumber }
    }

    struct ItemCost: Identifiable {
        let id: String
        let title: String
        let budget: Double?
        let actual: Double?
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

    /// 白黒テーマで背景に溶けないよう、どのカードにも引く薄い枠
    private var cardStroke: Color {
        ThemePreset.readableText(on: cardBg).opacity(0.12)
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
        // カードは3枚まで。以前は5枚あり、予算と実績を見比べるのに
        // スクロールが要り、日別と内訳も同じことを2度書いていた
        VStack(spacing: 16) {
            summaryCard

            // 共有していなくても同行者と割り勘したい場面があるため常に出す
            if splitBaseCost > 0 {
                costSplitCard
            }

            if !costByDay.isEmpty {
                dailyCard
            }

            if totalCost == 0 && !hasActualCost {
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

    // MARK: - 1枚目：使った金額と予算

    /// 実績を主役にし、予算はバーの背景と残額で見せる。
    /// 「予算に対して今いくらか」が一番知りたい情報なので、
    /// 予算と実績を別のカードに分けない
    private var summaryCard: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                gradient: Gradient(colors: [budgetColor.opacity(0.85), budgetColor.opacity(0.5)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .cornerRadius(20)

            // 目的地は上の写真に出ているので、ここでは繰り返さない
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "yensign.circle.fill")
                            .font(.system(size: 13))
                        Text(hasActualCost ? "使った金額" : "合計予算")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundColor(.white.opacity(0.85))

                    Spacer()

                    Text("\(tripDays)日間")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.white.opacity(0.2))
                        .clipShape(Capsule())
                }

                Text(formatCurrency(hasActualCost ? totalActualCost : totalCost))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                if hasActualCost && totalCost > 0 {
                    budgetBar
                    HStack {
                        Text("予算 \(formatCurrency(totalCost))")
                        Spacer()
                        Text(remainingText)
                            .fontWeight(.semibold)
                    }
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.9))
                } else if !hasActualCost && totalCost > 0 {
                    // 実績を記録できること自体が知られていないので、ここで伝える
                    Text("予定をタップして「実際に使った金額」を入れると、差額が分かります")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .shadow(color: budgetColor.opacity(0.25), radius: 8, x: 0, y: 4)
    }

    /// 予算に対して実績がどこまで来たか。超えた分は色を変える
    private var budgetBar: some View {
        GeometryReader { geo in
            let ratio = min(totalActualCost / max(totalCost, 1), 1)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.25))
                Capsule()
                    .fill(costDifference > 0 ? Color.white : Color.white.opacity(0.9))
                    .frame(width: max(geo.size.width * CGFloat(ratio), 4))
            }
        }
        .frame(height: 6)
        .padding(.top, 2)
    }

    private var remainingText: String {
        if costDifference > 0 {
            return "\(formatCurrency(costDifference)) 超過"
        } else if costDifference < 0 {
            return "あと \(formatCurrency(abs(costDifference)))"
        }
        return "予算どおり"
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
                // 白黒テーマは背景(0.96)とカード(0.95)がほぼ同じ明るさで、
                // 塗りだけだと境界が見えない。どのテーマでも薄い枠を引く
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(cardStroke, lineWidth: 1))
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

    // MARK: - 3枚目：日ごと

    /// 日別の合計と、その日の明細を1枚にまとめる。
    /// 以前は「日別の支出」と「支出の内訳」の2枚に分かれていて、
    /// 同じことを違う見せ方で2度書いていた
    private var dailyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(budgetColor)
                    .font(.subheadline)
                Text("日ごと")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(accentColor)

                Spacer()

                Text("実績 / 予算")
                    .font(.caption2)
                    .foregroundColor(themeManager.currentTheme.secondaryText)
            }

            VStack(spacing: 0) {
                ForEach(costByDay) { day in
                    dayRow(day)

                    if !collapsedDays.contains(day.dayNumber) {
                        VStack(spacing: 0) {
                            ForEach(day.items) { item in
                                itemRow(item)
                            }
                        }
                        .padding(.leading, 8)
                        .padding(.bottom, 6)
                    }

                    if day.dayNumber != costByDay.last?.dayNumber {
                        Divider()
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBg)
                // 白黒テーマは背景(0.96)とカード(0.95)がほぼ同じ明るさで、
                // 塗りだけだと境界が見えない。どのテーマでも薄い枠を引く
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(cardStroke, lineWidth: 1))
                .shadow(color: themeManager.currentTheme.shadow, radius: 6, x: 0, y: 2)
        )
    }

    private func dayRow(_ day: DayCost) -> some View {
        HStack(spacing: 8) {
            Text("Day \(day.dayNumber)")
                .font(.caption.weight(.bold))
                .foregroundColor(accentColor)

            Text(formatDate(day.date))
                .font(.caption)
                .foregroundColor(themeManager.currentTheme.secondaryText)

            Spacer(minLength: 4)

            Text(day.hasActual ? formatCurrency(day.actual) : "－")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(day.hasActual ? budgetColor : themeManager.currentTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text("/ \(formatCurrency(day.budget))")
                .font(.caption)
                .foregroundColor(themeManager.currentTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Image(systemName: collapsedDays.contains(day.dayNumber) ? "chevron.right" : "chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(themeManager.currentTheme.secondaryText)
        }
        .padding(.vertical, 10)
        // Button にすると横スワイプでも反応してしまうため onTapGesture を使う
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                if collapsedDays.contains(day.dayNumber) {
                    collapsedDays.remove(day.dayNumber)
                } else {
                    collapsedDays.insert(day.dayNumber)
                }
            }
        }
    }

    private func itemRow(_ item: ItemCost) -> some View {
        HStack(spacing: 8) {
            Text("・\(item.title)")
                .font(.caption)
                .foregroundColor(accentColor)
                .lineLimit(1)

            Spacer(minLength: 4)

            // 実績が入っていればそれを出し、予算しか無ければ予算を出す
            if let actual = item.actual {
                Text(formatCurrency(actual))
                    .font(.caption.weight(.medium))
                    .foregroundColor(budgetColor)
                if let budget = item.budget, budget != actual {
                    Text("/ \(formatCurrency(budget))")
                        .font(.caption2)
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                }
            } else if let budget = item.budget {
                Text(formatCurrency(budget))
                    .font(.caption.weight(.medium))
                    .foregroundColor(themeManager.currentTheme.secondaryText)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
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
