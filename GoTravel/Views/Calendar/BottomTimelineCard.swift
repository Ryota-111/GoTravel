import SwiftUI

struct BottomTimelineCard: View {
    let selectedDate: Date
    let timelineItems: [CalendarTimelineItem]
    @Binding var isExpanded: Bool
    var onAddPlan: () -> Void = {}

    @EnvironmentObject var plansViewModel: PlansViewModel
    @EnvironmentObject var travelViewModel: TravelPlanViewModel
    @ObservedObject var themeManager = ThemeManager.shared

    @Environment(\.colorScheme) var colorScheme
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 0) {
                    // Grip bar
                    gripBar
                        .padding(.top, 12)
                        .padding(.bottom, 8)

                    // Header
                    headerSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)

                    if timelineItems.isEmpty {
                        emptyStateView
                            .frame(maxHeight: .infinity)
                    } else {
                        timelineScrollView
                    }
                }
                .frame(height: currentHeight(for: geometry))
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        // 背後のカレンダーより一段明るい面にする。
                        // 同じ色だと、シートの上端が影だけになって境目が見えない
                        .fill(themeManager.currentTheme.elevatedSurface(for: colorScheme))
                        .shadow(color: themeManager.currentTheme.accent1.opacity(0.15), radius: 20, x: 0, y: -5)
                )
                .offset(y: max(0, dragOffset))
            }
            .gesture(dragGesture)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isExpanded)
            .animation(.spring(response: 0.3, dampingFraction: 0.9), value: dragOffset)
        }
    }

    private func minHeight(for geometry: GeometryProxy) -> CGFloat {
        geometry.size.height * 0.35
    }

    private func maxHeight(for geometry: GeometryProxy) -> CGFloat {
        geometry.size.height * 0.88
    }

    private func currentHeight(for geometry: GeometryProxy) -> CGFloat {
        isExpanded ? maxHeight(for: geometry) : minHeight(for: geometry)
    }

    // MARK: - Grip Bar
    private var gripBar: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.secondary.opacity(0.3))
            .frame(width: 40, height: 5)
    }

    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(formattedDate)
                    .font(.headline.bold())
                    .foregroundColor(colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1)


                Text("\(timelineItems.count)件の予定")
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.accent3)
            }

            Spacer()

            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                Image(systemName: isExpanded ? "chevron.down.circle.fill" : "chevron.up.circle.fill")
                    .font(.title3)
                    .foregroundColor(themeManager.currentTheme.secondary)
            }
        }
    }

    // MARK: - Timeline Scroll View
    private var timelineScrollView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(timelineItems.enumerated()), id: \.element.id) { index, item in
                    TimelineItemCard(
                        item: item,
                        isLast: index == timelineItems.count - 1,
                        state: rowState(index: index)
                    )
                }

                addOnThisDayButton
                    .padding(.top, 6)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    /// 選んだ日に予定を足す導線。
    ///
    /// 右上の＋は今日の日付で始まるため、8月30日を見ていても
    /// 8月30日の予定は作れなかった
    private var addOnThisDayButton: some View {
        Button(action: onAddPlan) {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                Text("この日に追加")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(themeManager.currentTheme.secondaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        themeManager.currentTheme.secondaryText.opacity(0.35),
                        style: StrokeStyle(lineWidth: 1.5, dash: [7, 5])
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    /// 今日を選んでいるときだけ、過ぎた分と次の1件を出し分ける。
    ///
    /// **時刻を持たない予定は対象にしない。** おでかけ・記念日・旅行は
    /// 日付だけの予定で、並べ替えのために 0:00 を入れてある。
    /// これを時刻として数えると、日付が変わった瞬間に「0:00 に終わった予定」
    /// と見なされ、当日なのに薄く表示されてしまう
    private func rowState(index: Int) -> CalendarRowState {
        guard Calendar.current.isDateInToday(selectedDate) else { return .flat }
        guard timelineItems.indices.contains(index),
              timelineItems[index].hasTime else { return .flat }

        let calendar = Calendar.current
        func minutes(of date: Date) -> Int {
            let parts = calendar.dateComponents([.hour, .minute], from: date)
            return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        }

        let nowMinutes = minutes(of: Date())
        // 次に来るのは「時刻を持つ予定」だけ。終日の予定を挟んで判定しない
        guard let nowIndex = timelineItems.firstIndex(where: {
            $0.hasTime && minutes(of: $0.time) >= nowMinutes
        }) else {
            return .past
        }

        if index < nowIndex { return .past }
        if index == nowIndex { return .now }
        return .future
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 14) {
            Text("予定がありません")
                .font(.subheadline)
                .foregroundColor(themeManager.currentTheme.accent3)

            addOnThisDayButton
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
    }

    // MARK: - Drag Gesture
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let translation = value.translation.height
                // 下方向のドラッグのみ許可（正の値）
                if translation > 0 {
                    dragOffset = translation * 0.5
                } else {
                    // 上方向のドラッグは抵抗を加える
                    dragOffset = translation * 0.2
                }
            }
            .onEnded { value in
                let translation = value.translation.height
                let velocity = value.predictedEndTranslation.height

                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    // 上方向のスワイプ（展開）
                    if translation < -80 || velocity < -200 {
                        if !isExpanded {
                            isExpanded = true
                        }
                    }
                    // 下方向のスワイプ（縮小）
                    else if translation > 80 || velocity > 200 {
                        if isExpanded {
                            isExpanded = false
                        }
                    }
                    // 元に戻す
                    dragOffset = 0
                }
            }
    }

    // MARK: - Date Formatter
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日(E)"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: selectedDate)
    }
}

/// タイムラインの1行の状態。
/// 過ぎた・次の1件・これからは、選んだ日が今日のときだけ意味を持つ
enum CalendarRowState {
    case past, now, future, flat
}

// MARK: - Timeline Item Card
struct TimelineItemCard: View {
    let item: CalendarTimelineItem
    let isLast: Bool
    var state: CalendarRowState = .flat

    @EnvironmentObject var plansViewModel: PlansViewModel
    @EnvironmentObject var travelViewModel: TravelPlanViewModel
    @ObservedObject var themeManager = ThemeManager.shared
    @ObservedObject var tagManager = PlanTagManager.shared
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationLink(destination: destinationView) {
            cardContent
        }
        .buttonStyle(PlainButtonStyle())
    }

    /// この行の予定に付いているタグ。旅行計画はタグを持たない
    private var planTags: [PlanTag] {
        guard let plan = item.relatedPlan else { return [] }
        return tagManager.tags(for: plan.tagIDs)
    }

    /// 終わりの時刻。日常の予定だけが持つ
    private var endTimeText: String? {
        guard let endTime = item.relatedPlan?.endTime else { return nil }
        return DateFormatter.japaneseTime.string(from: endTime)
    }

    /// 旅行計画・予定計画と同じ時刻レール。
    ///
    /// 以前は1件ごとに50ptの丸と影付きカードを積んでいたため、
    /// 閉じた高さでは2件しか見えず、時刻もカードの中に埋もれていた
    private var cardContent: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .trailing, spacing: 1) {
                Text(formatTimeOrDate(item.time, type: item.type))
                    .font(.system(size: 13, weight: .bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundColor(state == .past
                                     ? themeManager.currentTheme.secondaryText.opacity(0.6)
                                     : themeManager.currentTheme.secondaryText)

                // 終わりの時刻はレールの下に小さく続ける。
                // 「14:00 〜 15:30」と1行にすると52ptの時刻欄に収まらない
                if let endTimeText {
                    Text("〜" + endTimeText)
                        .font(.system(size: 11))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundColor(themeManager.currentTheme.secondaryText.opacity(0.7))
                }
            }
            .frame(width: 52, alignment: .trailing)
            .padding(.top, 1)

            // レール
            VStack(spacing: 0) {
                dot

                if !isLast {
                    Rectangle()
                        .fill(state == .past
                              ? itemColor.opacity(0.4)
                              : themeManager.currentTheme.secondaryText.opacity(0.18))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 12)
            .padding(.leading, 10)
            .padding(.trailing, 14)
            .padding(.top, 3)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    // 種別は色と小さなアイコンで示す。50ptの丸は要らない
                    Image(systemName: iconName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(itemColor)

                    Text(item.title)
                        .font(.system(size: 15, weight: state == .now ? .bold : .semibold))
                        .foregroundColor(state == .past
                                         ? themeManager.currentTheme.secondaryText
                                         : (colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1))
                        .lineLimit(1)

                    tagChip
                }

                if let subtitle = item.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                        .lineLimit(2)
                }
            }
            // 行間はここで決まる。詰めすぎると時刻の並びが読みにくい
            .padding(.bottom, 20)

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(themeManager.currentTheme.secondaryText.opacity(0.4))
                .padding(.top, 2)
        }
    }

    /// 代表タグ。一覧のカード（`PlanEventCardView`）と同じ大きさ・同じ出し方に揃える
    @ViewBuilder
    private var tagChip: some View {
        if let tag = planTags.first {
            Text(tag.name)
                .font(.system(size: 10, weight: .bold))
                .lineLimit(1)
                .foregroundColor(state == .past ? themeManager.currentTheme.secondaryText : tag.color)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(
                    tag.color.opacity(state == .past ? 0.08 : (colorScheme == .dark ? 0.24 : 0.14)),
                    in: RoundedRectangle(cornerRadius: 6)
                )

            if planTags.count > 1 {
                Text("+\(planTags.count - 1)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(themeManager.currentTheme.secondaryText)
            }
        }
    }

    /// レールの点。過ぎた分は塗り、次の1件は光らせ、これからは中を抜く
    @ViewBuilder
    private var dot: some View {
        switch state {
        case .now:
            Circle()
                .fill(itemColor)
                .frame(width: 12, height: 12)
                .overlay(Circle().stroke(itemColor.opacity(0.16), lineWidth: 5))
        case .past:
            Circle()
                .fill(itemColor.opacity(0.55))
                .frame(width: 12, height: 12)
        case .future, .flat:
            Circle()
                // 中を抜いて見せる点なので、シートの面と同じ色でなければならない
                .fill(themeManager.currentTheme.elevatedSurface(for: colorScheme))
                .frame(width: 12, height: 12)
                .overlay(
                    Circle().strokeBorder(
                        state == .flat ? itemColor.opacity(0.6) : themeManager.currentTheme.secondaryText.opacity(0.65),
                        lineWidth: 2.5
                    )
                )
        }
    }

    @ViewBuilder
    private var destinationView: some View {
        switch item.type {
        case .dailyPlan, .outingPlan, .anniversary:
            if let plan = item.relatedPlan {
                PlanDetailView(plan: plan)
                    .environmentObject(plansViewModel)
            } else {
                EmptyView()
            }
        case .travel:
            if let travelPlan = item.relatedTravelPlan {
                TravelPlanDetailView(plan: travelPlan)
                    .environmentObject(travelViewModel)
            } else {
                EmptyView()
            }
        }
    }

    private var itemColor: Color {
        switch item.type {
        case .dailyPlan: return themeManager.currentTheme.dailyPlanColor
        case .outingPlan: return themeManager.currentTheme.outingPlanColor
        case .anniversary: return themeManager.currentTheme.anniversaryPlanColor
        case .travel: return themeManager.currentTheme.success
        }
    }

    private var iconName: String {
        switch item.type {
        case .dailyPlan: return "house.fill"
        case .outingPlan: return "figure.walk"
        case .anniversary: return "heart.fill"
        case .travel: return "airplane"
        }
    }

    private func formatTime(_ time: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: time)
    }

    private func formatTimeOrDate(_ time: Date, type: CalendarItemType) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")

        switch type {
        case .dailyPlan:
            // 日常プランは時刻を表示
            formatter.dateFormat = "HH:mm"
        case .anniversary:
            // 記念日は時刻を持たない
            return "終日"
        case .outingPlan, .travel:
            // おでかけプランと旅行プランは日付を表示
            formatter.dateFormat = "M月d日"
        }

        return formatter.string(from: time)
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.2)
            .ignoresSafeArea()

        VStack {
            Spacer()

            BottomTimelineCard(
                selectedDate: Date(),
                timelineItems: [],
                isExpanded: .constant(false),
                onAddPlan: {}
            )
        }
        .ignoresSafeArea(edges: .bottom)
    }
}
