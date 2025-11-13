import SwiftUI

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
    @State private var selectedDay: Int = 1
    @State private var showScheduleEditor = false
    @State private var showBasicInfoEditor = false
    @State private var showBudgetSummary = false
    @State private var showShareView = false

    // Weather Properties
    @State private var planWeather: WeatherService.DayWeather?
    @State private var isLoadingPlanWeather = false
    @State private var planWeatherError: String?

    // Feature Flag: WeatherKit機能を有効化
    private let isWeatherFeatureEnabled = true

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
        LinearGradient(
            gradient: Gradient(colors: colorScheme == .dark ? [Color.blue.opacity(0.7), Color.black] : [Color.blue.opacity(0.8), Color.white]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
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
        .navigationBarItems(trailing: navigationButtons)
    }

    // MARK: - View Components
    private func contentView(plan: TravelPlan) -> some View {
        ZStack {
            backgroundGradient

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {
                        planInfoCard(plan: plan)

                        // 天気機能は将来のアップデート用に一時的に無効化
                        if isWeatherFeatureEnabled {
                            planWeatherSection
                        }

                        budgetButton(plan: plan)
                        daySelectionTabs(plan: plan)
                        scheduleSection(plan: plan)
                        packingListSection(plan: plan)
                    }
                    .padding()
                }
            }
        }
        .gesture(swipeBackGesture)
        .sheet(isPresented: $showScheduleEditor) {
            ScheduleEditorView(plan: plan)
        }
        .sheet(isPresented: $showBasicInfoEditor) {
            EditTravelPlanBasicInfoView(plan: plan)
        }
        .sheet(isPresented: $showBudgetSummary) {
            if let currentPlan = currentPlan {
                BudgetSummaryView(plan: currentPlan)
            }
        }
        .sheet(isPresented: $showShareView) {
            if let currentPlan = currentPlan {
                ShareTravelPlanView(plan: currentPlan) { shareCode in
                    // Update plan with share code
                    viewModel.updateShareCode(planId: currentPlan.id ?? "", shareCode: shareCode)
                }
                .environmentObject(viewModel)
            }
        }
        .onAppear {
            // 天気機能が有効な場合のみ天気を取得
            if isWeatherFeatureEnabled {
                fetchPlanWeather()
            }
        }
    }

    private var navigationButtons: some View {
        HStack(spacing: 15) {
            // Share Button
            if let plan = currentPlan {
                Button(action: { showShareView = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: plan.isShared ? "person.2.fill" : "person.2")
                            .foregroundColor(plan.isShared ? .green : .white)
                            .imageScale(.large)
                        if plan.isShared {
                            Text("\(plan.sharedWith.count)")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
            }

            // Edit Button
            Button(action: { showBasicInfoEditor = true }) {
                HStack {
                    Image(systemName: "pencil")
                        .foregroundColor(.white)
                        .imageScale(.large)
                    Text("編集")
                        .foregroundColor(.black)
                }
            }
        }
    }

    private var swipeBackGesture: some Gesture {
        DragGesture()
            .onEnded { value in
                if value.translation.width > 100 {
                    presentationMode.wrappedValue.dismiss()
                }
            }
    }

    private func scheduleSection(plan: TravelPlan) -> some View {
        Group {
            if let daySchedule = plan.daySchedules.first(where: { $0.dayNumber == selectedDay }) {
                DayScheduleView(daySchedule: daySchedule, plan: plan)
                    .environmentObject(viewModel)
            } else {
                emptyScheduleView
            }
        }
    }

    private func planInfoCard(plan: TravelPlan) -> some View {
        VStack(spacing: 15) {
            Text(plan.title)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(colorScheme == .dark ? .white : .black)

            HStack(spacing: 20) {
                destinationInfo(plan: plan)
                dateInfo(plan: plan)
            }
            .font(.subheadline)

            if plan.isShared {
                lastUpdatedInfo(plan: plan)
            }

            if let localImageFileName = plan.localImageFileName,
               let image = FileManager.documentsImage(named: localImageFileName) {
                planImage(image: image)
            }
        }
        .padding()
        .background(Color.white.opacity(0.2))
        .cornerRadius(15)
    }

    private func lastUpdatedInfo(plan: TravelPlan) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.caption)
                .foregroundColor(.green)
            Text("最終更新: \(formatDateTime(plan.updatedAt))")
                .font(.caption)
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .gray)
        }
    }

    private func destinationInfo(plan: TravelPlan) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "mappin.circle.fill")
                .foregroundColor(.orange)
            Text(plan.destination)
                .foregroundColor(colorScheme == .dark ? .white : .black)
        }
    }

    private func dateInfo(plan: TravelPlan) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "calendar")
                .foregroundColor(.orange)
            Text(dateRangeString(plan: plan))
                .foregroundColor(colorScheme == .dark ? .white : .black)
        }
    }

    private func planImage(image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(height: 200)
            .cornerRadius(15)
            .clipped()
    }

    private func budgetButton(plan: TravelPlan) -> some View {
        Button(action: { showBudgetSummary = true }) {
            HStack {
                Image(systemName: "yensign.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)

                VStack(alignment: .leading, spacing: 5) {
                    Text("金額管理")
                        .font(.headline)
                        .foregroundColor(colorScheme == .dark ? .white : .black)

                    Text(formatTotalCost(plan: plan))
                        .font(.subheadline)
                        .foregroundColor(.green)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .gray)
            }
            .padding()
            .background(Color.white.opacity(0.2))
            .cornerRadius(15)
        }
    }

    private func daySelectionTabs(plan: TravelPlan) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(1...tripDuration, id: \.self) { day in
                    dayTab(day: day, plan: plan)
                }
            }
        }
    }

    private func dayTab(day: Int, plan: TravelPlan) -> some View {
        Button(action: {
            withAnimation(.spring()) {
                selectedDay = day
            }
        }) {
            VStack(spacing: 5) {
                Text("Day \(day)")
                    .font(.headline)
                    .foregroundColor(dayTabTextColor(isSelected: selectedDay == day))

                if let daySchedule = plan.daySchedules.first(where: { $0.dayNumber == day }) {
                    Text(formatDate(daySchedule.date))
                        .font(.caption)
                        .foregroundColor(dayTabSubtextColor(isSelected: selectedDay == day))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(dayTabBackground(isSelected: selectedDay == day))
        }
    }

    private func dayTabTextColor(isSelected: Bool) -> Color {
        isSelected ? .white : (colorScheme == .dark ? .white.opacity(0.6) : .gray)
    }

    private func dayTabSubtextColor(isSelected: Bool) -> Color {
        isSelected ? .white.opacity(0.8) : (colorScheme == .dark ? .white.opacity(0.5) : .gray.opacity(0.7))
    }

    private func dayTabBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 15)
            .fill(isSelected ? Color.orange : Color.white.opacity(0.3))
    }

    private var emptyScheduleView: some View {
        VStack(spacing: 15) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 50))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.5) : .gray.opacity(0.5))

            Text("この日のスケジュールはまだありません")
                .font(.body)
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .gray)

            Button(action: { showScheduleEditor = true }) {
                Text("スケジュールを追加")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(.orange)
                    .cornerRadius(25)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color.white.opacity(0.2))
        .cornerRadius(15)
    }

    // MARK: - Weather Section
    @ViewBuilder
    private var planWeatherSection: some View {
        if #available(iOS 16.0, *) {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Image(systemName: "cloud.sun.fill")
                        .foregroundColor(.orange)
                        .font(.title2)
                    Text("目的地の天気")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                    Spacer()
                }

                if let plan = currentPlan {
                    if plan.latitude == nil || plan.longitude == nil {
                        // 座標が設定されていない場合
                        VStack(spacing: 10) {
                            Image(systemName: "location.slash")
                                .font(.system(size: 30))
                                .foregroundColor(.orange.opacity(0.7))
                            Text("目的地の座標が設定されていません")
                                .font(.subheadline)
                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .gray)
                            Text("旅行プランを編集して目的地を入力してください")
                                .font(.caption)
                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .gray.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    } else if isLoadingPlanWeather {
                        WeatherLoadingView()
                    } else if let error = planWeatherError {
                        WeatherErrorView(error: error)
                    } else if let weather = planWeather {
                        VStack(spacing: 12) {
                            WeatherCardView(weather: weather, dayNumber: nil)

                            // Apple Weather Attribution (required by App Store Guidelines 5.2.5)
                            VStack(spacing: 8) {
                                // Apple Weather Trademark
                                HStack(spacing: 4) {
                                    Text(" Weather")
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .foregroundColor(.white)
                                }

                                // Legal Attribution Link
                                Link(destination: URL(string: "https://weatherkit.apple.com/legal-attribution.html")!) {
                                    Text("データソースと法的情報")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                        .underline()
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(10)
                        }
                    }
                }
            }
            .padding()
            .background(Color.white.opacity(0.2))
            .cornerRadius(15)
        }
    }

    // MARK: - Packing List Section
    private func packingListSection(plan: TravelPlan) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("🧳 持ち物リスト")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(colorScheme == .dark ? .white : .black)

                Spacer()
            }

            if let currentPlan = currentPlan {
                PackingListView(plan: currentPlan)
                    .environmentObject(viewModel)
            }
        }
        .padding()
        .background(Color.white.opacity(0.2))
        .cornerRadius(15)
    }

    // MARK: - Helper Methods
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

    // MARK: - Weather Fetching
    private func fetchPlanWeather() {
        guard #available(iOS 16.0, *) else {
            #if DEBUG
            print("⚠️ WeatherKit requires iOS 16.0 or later")
            #endif
            return
        }

        guard let plan = currentPlan else {
            #if DEBUG
            print("⚠️ No current plan found")
            #endif
            return
        }

        guard let latitude = plan.latitude,
              let longitude = plan.longitude else {
            #if DEBUG
            print("⚠️ Plan coordinates not set: latitude=\(plan.latitude?.description ?? "nil"), longitude=\(plan.longitude?.description ?? "nil")")
            #endif
            planWeather = nil
            isLoadingPlanWeather = false
            planWeatherError = nil
            return
        }

        #if DEBUG
        print("✅ Starting weather fetch for: \(plan.destination)")
        print("   Coordinates: (\(latitude), \(longitude))")
        print("   Date: \(plan.startDate)")
        #endif

        isLoadingPlanWeather = true
        planWeatherError = nil

        Task { @MainActor in
            // WeatherKitの準備が完了するまで少し待機
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒

            do {
                let fetchedWeather = try await WeatherService.shared.fetchDayWeather(
                    latitude: latitude,
                    longitude: longitude,
                    date: plan.startDate
                )

                #if DEBUG
                print("✅ Weather fetched successfully: \(fetchedWeather.condition)")
                #endif

                self.planWeather = fetchedWeather
                self.isLoadingPlanWeather = false
            } catch {
                #if DEBUG
                print("❌ Weather fetch error: \(error.localizedDescription)")
                #endif

                self.planWeatherError = error.localizedDescription
                self.isLoadingPlanWeather = false
            }
        }
    }
}

