import SwiftUI
import WeatherKit

// EnjoyWorldView -> TravelPlanの詳細画面
struct TravelPlanDetailView: View {

    // MARK: - View State
    enum ViewState {
        case loading
        case loaded(TravelPlan)
    }

    // MARK: - Properties
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var viewModel: TravelPlanViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject var themeManager = ThemeManager.shared
    @State private var selectedDay: Int = 1
    @State private var showAddScheduleItem = false
    @State private var showBasicInfoEditor = false
    @State private var showBudgetSummary = false
    @State private var showShareView = false
    @State private var animateContent = false
    @State private var dragOffset: CGFloat = 0

    // Weather Properties
    @State private var planWeather: WeatherService.DayWeather?
    @State private var isLoadingPlanWeather = false
    @State private var planWeatherError: String?
    @State private var weatherAttribution: WeatherService.WeatherAttribution?

    let planId: String

    // MARK: - Initialization
    init(plan: TravelPlan) {
        self.planId = plan.id ?? ""
    }

    // MARK: - Computed Properties
    private var viewState: ViewState {
        if let plan = currentPlan {
            return .loaded(plan)
        } else {
            return .loading
        }
    }

    private var currentPlan: TravelPlan? {
        viewModel.travelPlans.first(where: { $0.id == planId })
    }

    private var tripDuration: Int {
        guard let plan = currentPlan else { return 1 }
        let days = Calendar.current.dateComponents([.day], from: plan.startDate, to: plan.endDate).day ?? 0
        return days + 1
    }

    private var backgroundGradient: some View {
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

    private var accentColor: Color {
        colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1
    }

    private var scheduleAccentColor: Color {
        switch themeManager.currentTheme.type {
        case .whiteBlack: return Color.black
        default: return themeManager.currentTheme.primary
        }
    }

    // MARK: - Body
    var body: some View {
        Group {
            switch viewState {
            case .loading:
                ProgressView()
            case .loaded(let plan):
                contentView(plan: plan)
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - View Components
    private func contentView(plan: TravelPlan) -> some View {
        ZStack {
            backgroundGradient

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        planHeaderSection(plan: plan)

                        VStack(spacing: 0) {
                            planWeatherSection
                                .padding(.top, 16)
                            budgetCard(plan: plan)
                            dayScheduleSection(plan: plan)
                            packingListSection(plan: plan)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 30)
                    }
                }
            }
        }
        .offset(x: dragOffset * 0.3)
        .opacity(1 - Double(dragOffset) / 500)
        .gesture(swipeBackGesture)
        .fullScreenCover(isPresented: $showAddScheduleItem) {
            AddScheduleItemView(plan: plan, dayNumber: selectedDay)
                .environmentObject(viewModel)
                .environmentObject(authVM)
        }
        .sheet(isPresented: $showBasicInfoEditor) {
            EditTravelPlanBasicInfoView(plan: plan)
                .environmentObject(viewModel)
        }
        .sheet(isPresented: $showBudgetSummary) {
            if let currentPlan = currentPlan {
                BudgetSummaryView(plan: currentPlan)
            }
        }
        .sheet(isPresented: $showShareView) {
            if let currentPlan = currentPlan {
                ShareTravelPlanView(plan: currentPlan) { shareCode in
                    if let userId = authVM.userId {
                        viewModel.updateShareCode(planId: currentPlan.id ?? "", shareCode: shareCode, userId: userId)
                    }
                }
                .environmentObject(viewModel)
            }
        }
        .onAppear {
            withAnimation {
                animateContent = true
            }
            fetchPlanWeather()
        }
    }

    private var swipeBackGesture: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onChanged { value in
                // 右方向のドラッグのみを許可
                if value.translation.width > 0 {
                    dragOffset = value.translation.width
                }
            }
            .onEnded { value in
                if value.translation.width > 100 && value.translation.height < 50 && value.translation.height > -50 {
                    // 十分な距離をドラッグし、かつ横方向のスワイプの場合のみdismiss
                    presentationMode.wrappedValue.dismiss()
                }
                // アニメーションでオフセットをリセット
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    dragOffset = 0
                }
            }
    }

    private func emptyScheduleMessage(plan: TravelPlan) -> some View {
        Button(action: { showAddScheduleItem = true }) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(scheduleAccentColor.opacity(0.08))
                        .frame(width: 64, height: 64)
                    Image(systemName: "plus.circle")
                        .font(.system(size: 28))
                        .foregroundColor(scheduleAccentColor.opacity(0.5))
                }
                Text("予定を追加する")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(themeManager.currentTheme.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 36)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(scheduleAccentColor.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(scheduleAccentColor.opacity(0.2), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func deleteScheduleItem(_ item: ScheduleItem, from plan: TravelPlan) {
        var updatedPlan = plan
        if let dayIndex = updatedPlan.daySchedules.firstIndex(where: { $0.dayNumber == selectedDay }) {
            updatedPlan.daySchedules[dayIndex].scheduleItems.removeAll { $0.id == item.id }
        }
        if let userId = authVM.userId {
            viewModel.update(updatedPlan, userId: userId)
        }
    }

    private func timelineItemView(item: ScheduleItem, isLast: Bool, plan: TravelPlan) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // タイムラインライン
            VStack(spacing: 0) {
                // 時刻バッジ
                Text(formatTime(item.time))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(scheduleAccentColor)
                    .clipShape(Capsule())
                    .frame(width: 54)

                if !isLast {
                    Rectangle()
                        .fill(scheduleAccentColor.opacity(0.25))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                        .padding(.vertical, 6)
                }
            }
            .frame(width: 54)

            // カードコンテンツ
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(accentColor)

                if let location = item.location, !location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(scheduleAccentColor.opacity(0.7))
                        Text(location)
                            .font(.system(size: 12))
                            .foregroundColor(themeManager.currentTheme.secondaryText)
                    }
                }

                if let cost = item.cost, cost > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "yensign.circle")
                            .font(.system(size: 11))
                            .foregroundColor(themeManager.currentTheme.secondaryText)
                        Text("¥\(Int(cost))")
                            .font(.system(size: 12))
                            .foregroundColor(themeManager.currentTheme.secondaryText)
                    }
                }

                if let notes = item.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.system(size: 12))
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                        .lineLimit(2)
                }
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)

            // 削除メニュー
            Menu {
                Button(role: .destructive) {
                    deleteScheduleItem(item, from: plan)
                } label: {
                    Label("削除", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 18))
                    .foregroundColor(themeManager.currentTheme.secondaryText.opacity(0.5))
                    .padding(.top, 14)
            }
        }
        .padding(.horizontal, 4)
    }

    private func planHeaderSection(plan: TravelPlan) -> some View {
        ZStack {
            // 背景画像
            Group {
                if let planId = plan.id, let image = viewModel.planImages[planId] {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if let localImageFileName = plan.localImageFileName,
                          let image = FileManager.documentsImage(named: localImageFileName) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [
                                themeManager.currentTheme.primary.opacity(0.8),
                                themeManager.currentTheme.secondary.opacity(0.6)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .overlay(
                            Image(systemName: "airplane")
                                .font(.system(size: 80))
                                .foregroundColor(.white.opacity(0.15))
                        )
                }
            }
            .frame(height: 300)
            .clipped()

            // グラデーションオーバーレイ（下部を暗く）
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: Color.black.opacity(0.3), location: 0.4),
                    .init(color: Color.black.opacity(0.85), location: 1)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 300)

            // テキスト情報（下部）
            VStack(alignment: .leading, spacing: 8) {
                // 目的地バッジ
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.caption.weight(.semibold))
                    Text(plan.destination)
                        .font(.caption.weight(.semibold))
                }
                .foregroundColor(.white.opacity(0.85))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())

                Text(plan.title)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 1)
                    .lineLimit(2)

                HStack(spacing: 16) {
                    Label(formatDateWithWeekday(plan.startDate), systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                    Label(formatTripDuration(), systemImage: "moon.stars.fill")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                }
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            // ナビゲーションボタン（上部）
            HStack {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    ZStack {
                        Circle().fill(.ultraThinMaterial).frame(width: 40, height: 40)
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.leading, 16)

                Spacer()

                HStack(spacing: 10) {
                    Button(action: { showShareView = true }) {
                        ZStack {
                            Circle().fill(.ultraThinMaterial).frame(width: 40, height: 40)
                            Image(systemName: plan.isShared ? "person.2.fill" : "person.2")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(plan.isShared ? themeManager.currentTheme.success : .white)
                        }
                    }
                    Button(action: { showBasicInfoEditor = true }) {
                        ZStack {
                            Circle().fill(.ultraThinMaterial).frame(width: 40, height: 40)
                            Image(systemName: "pencil")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.trailing, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 12)
        }
        .frame(height: 300)
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : -20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animateContent)
    }

    private func budgetCard(plan: TravelPlan) -> some View {
        Button(action: { showBudgetSummary = true }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(scheduleAccentColor.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: "yensign.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(scheduleAccentColor.opacity(0.8))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("合計予算")
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                    Text(formatBudgetAmount(plan: plan))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(accentColor)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(themeManager.currentTheme.secondaryText.opacity(0.5))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(colorScheme == .dark ? themeManager.currentTheme.secondaryBackgroundDark : themeManager.currentTheme.secondaryBackgroundLight)
                    .shadow(color: themeManager.currentTheme.shadow, radius: 6, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.top, 12)
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : 10)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: animateContent)
    }

    private func dayScheduleSection(plan: TravelPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // セクションヘッダー
            HStack {
                Text("タイムスケジュール")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(accentColor)
                Spacer()
                Button(action: { showAddScheduleItem = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                        Text("追加")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(scheduleAccentColor)
                    .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
            }

            // Day タブ（横スクロール）
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(1...tripDuration, id: \.self) { day in
                        let isSelected = selectedDay == day
                        let itemCount = plan.daySchedules.first(where: { $0.dayNumber == day })?.scheduleItems.count ?? 0
                        let dayDate: Date? = {
                            let d = plan.daySchedules.first(where: { $0.dayNumber == day })?.date
                            return d ?? Calendar.current.date(byAdding: .day, value: day - 1, to: plan.startDate)
                        }()

                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedDay = day
                            }
                        }) {
                            VStack(spacing: 4) {
                                Text("Day \(day)")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(isSelected ? .white : accentColor)

                                if let d = dayDate {
                                    Text(formatDate(d))
                                        .font(.system(size: 10))
                                        .foregroundColor(isSelected ? .white.opacity(0.8) : themeManager.currentTheme.secondaryText)
                                }

                                if itemCount > 0 {
                                    Text("\(itemCount)件")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(isSelected ? .white.opacity(0.8) : scheduleAccentColor)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isSelected ? scheduleAccentColor : (colorScheme == .dark ? themeManager.currentTheme.secondaryBackgroundDark : themeManager.currentTheme.secondaryBackgroundLight))
                                    .shadow(color: isSelected ? scheduleAccentColor.opacity(0.3) : themeManager.currentTheme.shadow, radius: isSelected ? 6 : 3, x: 0, y: 2)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.vertical, 4)
            }

            // スケジュールアイテムリスト
            if let daySchedule = plan.daySchedules.first(where: { $0.dayNumber == selectedDay }),
               !daySchedule.scheduleItems.isEmpty {
                let sortedItems = sortedScheduleItems(daySchedule.scheduleItems)
                VStack(spacing: 0) {
                    ForEach(Array(sortedItems.enumerated()), id: \.element.id) { index, item in
                        timelineItemView(item: item, isLast: index == sortedItems.count - 1, plan: plan)
                    }
                }
            } else {
                emptyScheduleMessage(plan: plan)
            }
        }
        .padding(.top, 20)
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : 10)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.25), value: animateContent)
    }

    // MARK: - Weather Section
    @ViewBuilder
    private var planWeatherSection: some View {
        if #available(iOS 16.0, *) {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Text("天気")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1)
                    
                    if let attribution = weatherAttribution {
                        VStack(alignment: .trailing, spacing: 4) {
                            AsyncImage(url: colorScheme == .dark ? attribution.combinedMarkDarkURL : attribution.combinedMarkLightURL) { image in
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 15)
                            } placeholder: {
                                ProgressView()
                                    .controlSize(.mini)
                            }

                            Link(destination: attribution.legalPageURL) {
                                Text("その他のデータソース")
                                    .font(.caption2)
                                    .foregroundColor(themeManager.currentTheme.accent2)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }

                if let plan = currentPlan {
                    if plan.latitude == nil || plan.longitude == nil {
                        // 座標が設定されていない場合
                        Text("設定された場所には天気の情報がありませんでした")
                            .font(.caption)
                            .foregroundColor(.gray)
                    } else if isLoadingPlanWeather {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else if planWeatherError != nil {
                        Text("10日前になると天気が表示されます")
                            .font(.caption)
                            .foregroundColor(.gray)
                    } else if let weather = planWeather {
                        HStack(spacing: 15) {
                            ZStack {
                                Circle()
                                    .fill(scheduleAccentColor.opacity(0.15))
                                    .frame(width: 60, height: 60)
                                Image(systemName: weather.symbolName)
                                    .font(.system(size: 28))
                                    .foregroundColor(scheduleAccentColor.opacity(0.7))
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(weather.condition)
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1)
                                Text("\(Int(weather.highTemperature))°C")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1)
                            }
                            Spacer()
                        }
                    }
                }
            }
            .padding(.vertical, 20)
            .opacity(animateContent ? 1 : 0)
            .offset(y: animateContent ? 0 : 10)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: animateContent)
        }
    }

    // MARK: - Packing List Section
    private func packingListSection(plan: TravelPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("持ち物リスト")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(accentColor)
                Spacer()
            }

            if let currentPlan = currentPlan {
                PackingListView(plan: currentPlan)
                    .environmentObject(viewModel)
            }
        }
        .padding(.top, 20)
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : 10)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.35), value: animateContent)
    }

    // MARK: - Helper Methods
    private func sortedScheduleItems(_ items: [ScheduleItem]) -> [ScheduleItem] {
        let calendar = Calendar.current

        return items.sorted { item1, item2 in
            // Extract hour and minute components only (ignore date)
            let components1 = calendar.dateComponents([.hour, .minute], from: item1.time)
            let components2 = calendar.dateComponents([.hour, .minute], from: item2.time)

            let hour1 = components1.hour ?? 0
            let minute1 = components1.minute ?? 0
            let hour2 = components2.hour ?? 0
            let minute2 = components2.minute ?? 0

            // Compare by hour first, then by minute
            if hour1 != hour2 {
                return hour1 < hour2
            } else {
                return minute1 < minute2
            }
        }
    }

    private func formatBudgetAmount(plan: TravelPlan) -> String {
        let total = plan.daySchedules
            .flatMap { $0.scheduleItems }
            .compactMap { $0.cost }
            .reduce(0, +)

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0

        return "¥\(formatter.string(from: NSNumber(value: total)) ?? "0")"
    }

    private func formatTotalCost(plan: TravelPlan) -> String {
        let total = plan.daySchedules
            .flatMap { $0.scheduleItems }
            .compactMap { $0.cost }
            .reduce(0, +)

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0

        if total == 0 {
            return "まだ金額が登録されていません"
        } else {
            return "合計: ¥\(formatter.string(from: NSNumber(value: total)) ?? "0")"
        }
    }

    private func formatDateWithWeekday(_ date: Date) -> String {
        let formatter = DateFormatter.japanese
        formatter.dateFormat = "yyyy年MM月dd日(E)"
        return formatter.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter.japanese
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func dateRangeString(plan: TravelPlan) -> String {
        let formatter = DateFormatter.japanese
        formatter.dateFormat = "M/d"
        return "\(formatter.string(from: plan.startDate)) - \(formatter.string(from: plan.endDate))"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter.japanese
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter.japanese
        formatter.dateFormat = "M/d HH:mm"
        return formatter.string(from: date)
    }

    private func formatTripDuration() -> String {
        if tripDuration == 1 {
            return "1日"
        } else {
            return "\(tripDuration)日間"
        }
    }

    // MARK: - Weather Fetching
    private func fetchPlanWeather() {
        guard #available(iOS 16.0, *) else {
            return
        }

        guard let plan = currentPlan else {
            return
        }

        guard let latitude = plan.latitude,
              let longitude = plan.longitude else {
            planWeather = nil
            isLoadingPlanWeather = false
            planWeatherError = nil
            weatherAttribution = nil
            return
        }

        isLoadingPlanWeather = true
        planWeatherError = nil

        Task { @MainActor in
            // WeatherKitの準備が完了するまで少し待機
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒

            do {
                // Fetch weather data
                let fetchedWeather = try await WeatherService.shared.fetchDayWeather(
                    latitude: latitude,
                    longitude: longitude,
                    date: plan.startDate
                )

                // Fetch attribution
                let fetchedAttribution = try await WeatherService.shared.getWeatherAttribution()

                self.planWeather = fetchedWeather
                self.weatherAttribution = fetchedAttribution
                self.isLoadingPlanWeather = false
            } catch {
                self.planWeatherError = error.localizedDescription
                self.isLoadingPlanWeather = false
            }
        }
    }
}

// MARK: - Preview
#Preview {
    let viewModel = TravelPlanViewModel()
    let authVM = AuthViewModel()

    // サンプルのスケジュールアイテムを作成
    let sampleScheduleItems = [
        ScheduleItem(
            id: UUID().uuidString,
            time: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!,
            title: "東京タワー観光",
            location: "東京タワー",
            notes: "展望台からの眺めを楽しむ",
            latitude: 35.6586,
            longitude: 139.7454,
            cost: 1200,
            mapURL: nil,
            linkURL: "https://www.tokyotower.co.jp"
        ),
        ScheduleItem(
            id: UUID().uuidString,
            time: Calendar.current.date(bySettingHour: 12, minute: 30, second: 0, of: Date())!,
            title: "ランチ",
            location: "レストラン芝",
            notes: "和食のコース料理",
            latitude: 35.6560,
            longitude: 139.7470,
            cost: 3500,
            mapURL: nil,
            linkURL: nil
        ),
        ScheduleItem(
            id: UUID().uuidString,
            time: Calendar.current.date(bySettingHour: 15, minute: 0, second: 0, of: Date())!,
            title: "浅草観光",
            location: "浅草寺",
            notes: "雷門と仲見世通りを散策",
            latitude: 35.7148,
            longitude: 139.7967,
            cost: 0,
            mapURL: nil,
            linkURL: nil
        )
    ]

    // サンプルのDayScheduleを作成
    let sampleDaySchedules = [
        DaySchedule(
            dayNumber: 1,
            date: Date(),
            scheduleItems: sampleScheduleItems
        ),
        DaySchedule(
            dayNumber: 2,
            date: Calendar.current.date(byAdding: .day, value: 1, to: Date())!,
            scheduleItems: [
                ScheduleItem(
                    id: UUID().uuidString,
                    time: Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!,
                    title: "スカイツリー",
                    location: "東京スカイツリー",
                    notes: "展望デッキと水族館",
                    latitude: 35.7101,
                    longitude: 139.8107,
                    cost: 2500,
                    mapURL: nil,
                    linkURL: nil
                )
            ]
        )
    ]

    // サンプルのTravelPlanを作成
    let samplePlan = TravelPlan(
        id: UUID().uuidString,
        title: "東京旅行",
        startDate: Date(),
        endDate: Calendar.current.date(byAdding: .day, value: 2, to: Date())!,
        destination: "東京",
        latitude: 35.6762,
        longitude: 139.6503,
        localImageFileName: nil,
        cardColor: nil,
        createdAt: Date(),
        userId: "sample-user-id",
        daySchedules: sampleDaySchedules,
        packingItems: [],
        isShared: true,
        shareCode: "ABC123",
        sharedWith: ["user1", "user2"],
        ownerId: "sample-user-id",
        lastEditedBy: "sample-user-id",
        updatedAt: Date()
    )

    // ViewModelにサンプルプランを追加
    viewModel.travelPlans = [samplePlan]

    return NavigationView {
        TravelPlanDetailView(plan: samplePlan)
            .environmentObject(viewModel)
            .environmentObject(authVM)
    }
}

