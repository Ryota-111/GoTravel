import SwiftUI

// MARK: - Calendar Timeline Item Model
struct CalendarTimelineItem: Identifiable {
    let id = UUID()
    let time: Date
    let title: String
    let subtitle: String?
    let type: CalendarItemType
    let relatedPlan: Plan?
    let relatedTravelPlan: TravelPlan?
}

enum CalendarItemType {
    case dailyPlan
    case outingPlan
    case travel
}

struct CalendarView: View {
    @StateObject private var viewModel = PlansViewModel()
    @StateObject private var travelViewModel = TravelPlanViewModel()
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    @State private var showAddSheet = false
    @State private var dragOffset: CGFloat = 0
    @State private var timelineHeight: CGFloat = 250
    @State private var scrollOffset: CGFloat = 0
    @Environment(\.colorScheme) var colorScheme
    @Namespace private var animation

    private let calendar = Calendar.current
    private let daysOfWeek = ["日", "月", "火", "水", "木", "金", "土"]

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: colorScheme == .dark ? [.blue.opacity(0.7), .black] : [.blue.opacity(0.6), .white]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    monthNavigationHeader

                    monthCalendarGrid
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)

                    Divider()

                    scheduleListSection
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedDate = Date()
                            currentMonth = Date()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar.circle.fill")
                            Text("今日")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.orange)
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text(monthYearString)
                        .font(.headline)
                        .foregroundColor(.primary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showAddSheet = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.orange)
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddPlanView { newPlan in
                    viewModel.add(newPlan)
                }
            }
        }
    }

    // MARK: - Computed Properties
    private var selectedDatePlans: [Plan] {
        viewModel.plans.filter { plan in
            isDateInPlanRange(date: selectedDate, plan: plan)
        }.sorted { plan1, plan2 in
            // 時系列順にソート (0時→24時)
            let time1 = plan1.time ?? calendar.startOfDay(for: plan1.startDate)
            let time2 = plan2.time ?? calendar.startOfDay(for: plan2.startDate)

            let components1 = calendar.dateComponents([.hour, .minute], from: time1)
            let components2 = calendar.dateComponents([.hour, .minute], from: time2)

            let minutes1 = (components1.hour ?? 0) * 60 + (components1.minute ?? 0)
            let minutes2 = (components2.hour ?? 0) * 60 + (components2.minute ?? 0)

            return minutes1 < minutes2
        }
    }

    private var dailyTimeline: [CalendarTimelineItem] {
        // Daily plan items
        let dailyPlanItems = viewModel.plans
            .filter { plan in
                plan.planType == .daily &&
                isDateInPlanRange(date: selectedDate, plan: plan)
            }
            .compactMap { plan -> CalendarTimelineItem? in
                let time = plan.time ?? calendar.startOfDay(for: plan.startDate)
                return CalendarTimelineItem(
                    time: time,
                    title: plan.title,
                    subtitle: plan.description,
                    type: .dailyPlan,
                    relatedPlan: plan,
                    relatedTravelPlan: nil
                )
            }

        // Outing plan items
        let outingPlanItems = viewModel.plans
            .filter { plan in
                plan.planType == .outing &&
                isDateInPlanRange(date: selectedDate, plan: plan)
            }
            .map { plan -> CalendarTimelineItem in
                let time = plan.time ?? calendar.startOfDay(for: plan.startDate)
                let dateInfo = formatOutingDateInfo(plan: plan)
                return CalendarTimelineItem(
                    time: time,
                    title: plan.title,
                    subtitle: dateInfo,
                    type: .outingPlan,
                    relatedPlan: plan,
                    relatedTravelPlan: nil
                )
            }

        // Travel plan items
        let travelItems = travelViewModel.travelPlans
            .filter { travelPlan in
                calendar.isDate(travelPlan.startDate, inSameDayAs: selectedDate)
            }
            .map { travelPlan -> CalendarTimelineItem in
                CalendarTimelineItem(
                    time: travelPlan.startDate,
                    title: travelPlan.title,
                    subtitle: "\(travelPlan.destination) - \(dateRangeString(travelPlan.startDate, travelPlan.endDate))",
                    type: .travel,
                    relatedPlan: nil,
                    relatedTravelPlan: travelPlan
                )
            }

        // 時系列順にソート
        return (dailyPlanItems + outingPlanItems + travelItems).sorted { item1, item2 in
            let components1 = calendar.dateComponents([.hour, .minute], from: item1.time)
            let components2 = calendar.dateComponents([.hour, .minute], from: item2.time)

            let minutes1 = (components1.hour ?? 0) * 60 + (components1.minute ?? 0)
            let minutes2 = (components2.hour ?? 0) * 60 + (components2.minute ?? 0)

            return minutes1 < minutes2
        }
    }

    // 指定日がプランの範囲内かチェック
    private func isDateInPlanRange(date: Date, plan: Plan) -> Bool {
        let startOfSelectedDate = calendar.startOfDay(for: date)
        let startOfPlanStartDate = calendar.startOfDay(for: plan.startDate)
        let startOfPlanEndDate = calendar.startOfDay(for: plan.endDate)

        if plan.planType == .daily {
            // 日常プランは完全一致
            return calendar.isDate(plan.startDate, inSameDayAs: date)
        } else {
            // おでかけプランは範囲内
            return startOfSelectedDate >= startOfPlanStartDate && startOfSelectedDate <= startOfPlanEndDate
        }
    }

    // おでかけプランの日付情報をフォーマット
    private func formatOutingDateInfo(plan: Plan) -> String {
        let isStartDate = calendar.isDate(plan.startDate, inSameDayAs: selectedDate)
        let isEndDate = calendar.isDate(plan.endDate, inSameDayAs: selectedDate)

        if isStartDate && isEndDate {
            return "日帰り旅行"
        } else if isStartDate {
            return "出発日 - \(dateRangeString(plan.startDate, plan.endDate))"
        } else if isEndDate {
            return "最終日 - \(dateRangeString(plan.startDate, plan.endDate))"
        } else {
            let dayNumber = calendar.dateComponents([.day], from: plan.startDate, to: selectedDate).day ?? 0
            return "\(dayNumber + 1)日目 - \(dateRangeString(plan.startDate, plan.endDate))"
        }
    }

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年 M月"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: currentMonth)
    }

    private var daysInMonth: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start) else {
            return []
        }

        var days: [Date?] = []
        var currentDate = monthFirstWeek.start

        let firstDayWeekday = calendar.component(.weekday, from: monthInterval.start)
        for _ in 1..<firstDayWeekday {
            days.append(nil)
        }

        while currentDate < monthInterval.end {
            if calendar.isDate(currentDate, equalTo: currentMonth, toGranularity: .month) {
                days.append(currentDate)
            }
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }

        return days
    }

    // MARK: - Month Navigation Header
    private var monthNavigationHeader: some View {
        HStack(spacing: 20) {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    changeMonth(by: -1)
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.orange)
            }

            Spacer()

            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    changeMonth(by: 1)
                }
            }) {
                Image(systemName: "chevron.right")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.orange)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Month Calendar Grid
    private var monthCalendarGrid: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 12) {
                ForEach(Array(daysInMonth.enumerated()), id: \.offset) { _, date in
                    if let date = date {
                        calendarDayCell(date: date)
                    } else {
                        Color.clear
                            .frame(height: 50)
                    }
                }
            }
            .offset(x: dragOffset)
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation.width
                }
                .onEnded { value in
                    let threshold: CGFloat = 50

                    if value.translation.width < -threshold {
                        // 左スワイプ → 次月へ
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            changeMonth(by: 1)
                            dragOffset = 0
                        }
                    } else if value.translation.width > threshold {
                        // 右スワイプ → 前月へ
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            changeMonth(by: -1)
                            dragOffset = 0
                        }
                    } else {
                        // スワイプ距離が足りない場合は元に戻す
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = 0
                        }
                    }
                }
        )
    }

    private func calendarDayCell(date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let hasEvents = hasEventsOn(date: date)
        let dayNumber = calendar.component(.day, from: date)

        return VStack(spacing: 4) {
            Text("\(dayNumber)")
                .font(.system(size: 16, weight: isSelected ? .bold : .regular))
                .foregroundColor(isSelected ? .white : (isToday ? .orange : .primary))
                .frame(width: 44, height: 44)
                .background(
                    ZStack {
                        if isSelected {
                            Circle()
                                .fill(Color.orange)
                                .matchedGeometryEffect(id: "selectedDay", in: animation)
                        } else if isToday {
                            Circle()
                                .stroke(Color.orange, lineWidth: 2)
                        }
                    }
                )

            if hasEvents {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 4, height: 4)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedDate = date
            }
        }
    }

    private func hasEventsOn(date: Date) -> Bool {
        let hasPlans = viewModel.plans.contains { plan in
            isDateInPlanRange(date: date, plan: plan)
        }

        let hasTravelPlans = travelViewModel.travelPlans.contains { travelPlan in
            calendar.isDate(travelPlan.startDate, inSameDayAs: date)
        }

        return hasPlans || hasTravelPlans
    }

    // MARK: - Schedule List Section
    private var scheduleListSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            scheduleHeader

            if dailyTimeline.isEmpty {
                emptyScheduleView
                    .transition(.opacity.combined(with: .slide))
            } else {
                timelineView
                    .transition(.opacity.combined(with: .slide))
            }
        }
    }

    private var scheduleHeader: some View {
        GeometryReader { geometry in
            HStack {
                Text(selectedDateString)
                    .font(.headline.bold())
                    .foregroundColor(.primary)

                Spacer()

                Text("\(dailyTimeline.count)件の予定")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground))
            .background(
                GeometryReader { innerGeometry in
                    Color.clear
                        .preference(key: ScrollOffsetPreferenceKey.self, value: innerGeometry.frame(in: .named("scroll")).minY)
                }
            )
        }
        .frame(height: 44)
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            let offset = value

            // スクロールオフセットに基づいてタイムライン高さを調整
            if offset < 0 {
                // 上方向スクロール時に高さを増やす
                let newHeight = min(500, 250 + abs(offset) * 1.5)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    timelineHeight = newHeight
                }
            } else {
                // 元の位置に戻る時は最小値に戻す
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    timelineHeight = 250
                }
            }
        }
    }

    // MARK: - Timeline View
    private var timelineView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(dailyTimeline.enumerated()), id: \.element.id) { index, item in
                    timelineItemView(item: item, isLast: index == dailyTimeline.count - 1)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .frame(height: timelineHeight)
        .coordinateSpace(name: "scroll")
    }

    private func timelineItemView(item: CalendarTimelineItem, isLast: Bool) -> some View {
        let iconColor: Color = {
            switch item.type {
            case .dailyPlan: return .orange
            case .outingPlan: return .blue
            case .travel: return .green
            }
        }()

        let iconName: String = {
            switch item.type {
            case .dailyPlan: return "house.fill"
            case .outingPlan: return "figure.walk"
            case .travel: return "airplane"
            }
        }()

        return HStack(alignment: .top, spacing: 16) {
            // Timeline indicator
            VStack(spacing: 0) {
                // Icon circle
                ZStack {
                    Circle()
                        .fill(iconColor)
                        .frame(width: 50, height: 50)
                        .shadow(color: iconColor.opacity(0.3), radius: 4, x: 0, y: 2)

                    Image(systemName: iconName)
                        .font(.title3)
                        .foregroundColor(.white)
                }

                // Connecting line
                if !isLast {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    iconColor.opacity(0.5),
                                    Color.gray.opacity(0.2)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 2)
                        .padding(.vertical, 4)
                }
            }

            // Card content
            VStack(alignment: .leading, spacing: 0) {
                timelineCardContent(item: item)
                    .padding(.bottom, isLast ? 0 : 24)
            }
        }
    }

    private func timelineCardContent(item: CalendarTimelineItem) -> some View {
        Group {
            if (item.type == .dailyPlan || item.type == .outingPlan), let plan = item.relatedPlan {
                NavigationLink(destination: PlanDetailView(plan: plan).environmentObject(viewModel)) {
                    timelineCard(item: item)
                }
                .buttonStyle(PlainButtonStyle())
            } else if item.type == .travel, let travelPlan = item.relatedTravelPlan {
                NavigationLink(destination: TravelPlanDetailView(plan: travelPlan).environmentObject(travelViewModel)) {
                    timelineCard(item: item)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private func timelineCard(item: CalendarTimelineItem) -> some View {
        let cardColor: Color = {
            switch item.type {
            case .dailyPlan: return .orange
            case .outingPlan: return .blue
            case .travel: return .green
            }
        }()

        return VStack(alignment: .leading, spacing: 12) {
            // Time
            Text(formatTime(item.time))
                .font(.caption.weight(.semibold))
                .foregroundColor(cardColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(cardColor.opacity(0.15))
                )

            // Title
            Text(item.title)
                .font(.headline.bold())
                .foregroundColor(.primary)
                .lineLimit(2)

            // Subtitle
            if let subtitle = item.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    colorScheme == .dark ?
                    Color(.secondarySystemBackground) :
                    Color.white.opacity(0.9)
                )
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            cardColor.opacity(0.2),
                            Color.clear
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    private var emptyScheduleView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 60))
                .foregroundColor(.orange.opacity(0.3))

            Text("予定がありません")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button(action: {
                showAddSheet = true
            }) {
                Text("予定を追加")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.orange)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func scheduleCard(plan: Plan) -> some View {
        NavigationLink(destination: PlanDetailView(plan: plan).environmentObject(viewModel)) {
            HStack(spacing: 16) {
                if let time = plan.time {
                    VStack(spacing: 4) {
                        Text(formatTime(time))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)
                    }
                    .frame(width: 60)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(plan.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    if let description = plan.description, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var selectedDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日(E)"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: selectedDate)
    }

    // MARK: - Helper Methods
    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = newMonth
        }
    }

    private func formatTime(_ time: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: time)
    }

    private func dateRangeString(_ start: Date, _ end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        formatter.locale = Locale(identifier: "ja_JP")
        return "\(formatter.string(from: start))〜\(formatter.string(from: end))"
    }
}

// MARK: - Preference Key for Scroll Offset
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    CalendarView()
}
