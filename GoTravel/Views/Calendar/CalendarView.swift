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
    @EnvironmentObject var viewModel: PlansViewModel
    @EnvironmentObject var travelViewModel: TravelPlanViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    @State private var showAddSheet = false
    @State private var dragOffset: CGFloat = 0
    @State private var isTimelineExpanded = false
    @State private var hasLoadedData = false
    @State private var showAuthError = false
    @Environment(\.colorScheme) var colorScheme
    @Namespace private var animation

    private let calendar: Calendar = {
        var cal = Calendar.current
        cal.firstWeekday = 2  // 2 = 月曜日始まり (1 = 日曜日, 2 = 月曜日)
        return cal
    }()
    private let daysOfWeek = ["月", "火", "水", "木", "金", "土", "日"]

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: colorScheme == .dark ? [.blue.opacity(0.7), .black] : [.blue.opacity(0.6), .white]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // Calendar content
                VStack(spacing: 0) {
                    monthNavigationHeader

                    monthCalendarGrid
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)

                    Spacer()
                }
                .blur(radius: isTimelineExpanded ? 4 : 0)
                .opacity(isTimelineExpanded ? 0.6 : 1.0)

                // Dimming overlay when sheet is expanded
                if isTimelineExpanded {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                isTimelineExpanded = false
                            }
                        }
                }
                // Bottom timeline card
                BottomTimelineCard(
                    selectedDate: selectedDate,
                    timelineItems: dailyTimeline,
                    isExpanded: $isTimelineExpanded
                )
                .environmentObject(viewModel)
                .environmentObject(travelViewModel)
                .ignoresSafeArea(.keyboard, edges: .bottom)
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
                    print("📅 [CalendarView] AddPlanView onSave called")
                    print("📅 [CalendarView] - authVM.userId: \(authVM.userId ?? "nil")")
                    if let userId = authVM.userId {
                        print("📅 [CalendarView] - userId is valid, calling viewModel.add()")
                        viewModel.add(newPlan, userId: userId)
                    } else {
                        print("❌ [CalendarView] - userId is NIL! Plan will NOT be saved!")
                        showAuthError = true
                    }
                }
            }
            .alert("認証が必要です", isPresented: $showAuthError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("予定を保存するには、アプリを再起動してApple IDでサインインしてください。")
            }
            .task {
                // CloudKitからプランを取得（初回のみ）
                if !hasLoadedData, let userId = authVM.userId {
                    hasLoadedData = true
                    viewModel.refreshFromCloudKit(userId: userId)
                    travelViewModel.refreshFromCloudKit(userId: userId)
                }
            }
        }
        .navigationViewStyle(.stack)
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
                let time = plan.time ?? calendar.startOfDay(for: selectedDate)
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
                isDateInTravelPlanRange(date: selectedDate, travelPlan: travelPlan)
            }
            .map { travelPlan -> CalendarTimelineItem in
                let dateInfo = formatTravelDateInfo(travelPlan: travelPlan)
                return CalendarTimelineItem(
                    time: selectedDate,
                    title: travelPlan.title,
                    subtitle: dateInfo,
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

    // 旅行プランの日付情報をフォーマット
    private func formatTravelDateInfo(travelPlan: TravelPlan) -> String {
        let isStartDate = calendar.isDate(travelPlan.startDate, inSameDayAs: selectedDate)
        let isEndDate = calendar.isDate(travelPlan.endDate, inSameDayAs: selectedDate)

        if isStartDate && isEndDate {
            return "\(travelPlan.destination) - 日帰り旅行"
        } else if isStartDate {
            return "\(travelPlan.destination) - 出発日 (\(dateRangeString(travelPlan.startDate, travelPlan.endDate)))"
        } else if isEndDate {
            return "\(travelPlan.destination) - 最終日 (\(dateRangeString(travelPlan.startDate, travelPlan.endDate)))"
        } else {
            let dayNumber = calendar.dateComponents([.day], from: travelPlan.startDate, to: selectedDate).day ?? 0
            return "\(travelPlan.destination) - \(dayNumber + 1)日目 (\(dateRangeString(travelPlan.startDate, travelPlan.endDate)))"
        }
    }

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年 M月"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: currentMonth)
    }

    private var daysInMonth: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth) else {
            return []
        }

        var days: [Date?] = []

        // 月の最初の日の曜日を取得
        let firstDayWeekday = calendar.component(.weekday, from: monthInterval.start)

        // 月曜日始まりの場合のオフセット計算
        // weekday: 1=日, 2=月, 3=火, ... 7=土
        // 月曜始まりの場合: 月=0, 火=1, 水=2, 木=3, 金=4, 土=5, 日=6
        let offset = (firstDayWeekday - calendar.firstWeekday + 7) % 7

        // 空白セルを追加
        for _ in 0..<offset {
            days.append(nil)
        }

        // 月の日付を追加
        var currentDate = monthInterval.start
        while currentDate < monthInterval.end {
            days.append(currentDate)
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
        let eventTypes = getEventTypesForDate(date: date)
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

            // イベントインジケーター（イベントタイプごとに色分け）
            if !eventTypes.isEmpty {
                HStack(spacing: 2) {
                    ForEach(eventTypes.prefix(3).indices, id: \.self) { index in
                        Circle()
                            .fill(colorForEventType(eventTypes[index]))
                            .frame(width: 4, height: 4)
                    }
                }
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
            isDateInTravelPlanRange(date: date, travelPlan: travelPlan)
        }

        return hasPlans || hasTravelPlans
    }

    // 指定日が旅行プランの範囲内かチェック
    private func isDateInTravelPlanRange(date: Date, travelPlan: TravelPlan) -> Bool {
        let startOfSelectedDate = calendar.startOfDay(for: date)
        let startOfPlanStartDate = calendar.startOfDay(for: travelPlan.startDate)
        let startOfPlanEndDate = calendar.startOfDay(for: travelPlan.endDate)

        return startOfSelectedDate >= startOfPlanStartDate && startOfSelectedDate <= startOfPlanEndDate
    }

    // 指定日のイベントタイプのリストを取得
    private func getEventTypesForDate(date: Date) -> [CalendarItemType] {
        var eventTypes: [CalendarItemType] = []

        // Daily plans
        let dailyPlans = viewModel.plans.filter { plan in
            plan.planType == .daily && isDateInPlanRange(date: date, plan: plan)
        }
        eventTypes.append(contentsOf: dailyPlans.map { _ in CalendarItemType.dailyPlan })

        // Outing plans
        let outingPlans = viewModel.plans.filter { plan in
            plan.planType == .outing && isDateInPlanRange(date: date, plan: plan)
        }
        eventTypes.append(contentsOf: outingPlans.map { _ in CalendarItemType.outingPlan })

        // Travel plans (期間中のすべての日に表示)
        let travelPlans = travelViewModel.travelPlans.filter { travelPlan in
            isDateInTravelPlanRange(date: date, travelPlan: travelPlan)
        }
        eventTypes.append(contentsOf: travelPlans.map { _ in CalendarItemType.travel })

        return eventTypes
    }

    private func colorForEventType(_ type: CalendarItemType) -> Color {
        switch type {
        case .dailyPlan:
            return .orange
        case .outingPlan:
            return .blue
        case .travel:
            return .green
        }
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

#Preview {
    CalendarView()
}
