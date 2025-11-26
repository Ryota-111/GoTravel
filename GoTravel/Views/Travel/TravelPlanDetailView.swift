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
    @EnvironmentObject var authVM: AuthViewModel
    @State private var selectedDay: Int = 1
    @State private var showScheduleEditor = false
    @State private var showBasicInfoEditor = false
    @State private var showBudgetSummary = false
    @State private var showShareView = false
    @State private var animateContent = false

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
        .navigationBarHidden(true)
    }

    // MARK: - View Components
    private func contentView(plan: TravelPlan) -> some View {
        ZStack {
            backgroundGradient

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 16) {
                        planHeaderSection(plan: plan)

                        VStack(spacing: 12) {
                            planWeatherSection
                            budgetCard(plan: plan)
                            daySelectionTabs(plan: plan)
                            scheduleTimelineSection(plan: plan)
                            packingListSection(plan: plan)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        .gesture(swipeBackGesture)
        .sheet(isPresented: $showScheduleEditor) {
            ScheduleEditorView(plan: plan)
                .environmentObject(viewModel)
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
                    // Update plan with share code
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
        DragGesture()
            .onEnded { value in
                if value.translation.width > 100 {
                    presentationMode.wrappedValue.dismiss()
                }
            }
    }

    // 新しいタイムラインセクション
    private func scheduleTimelineSection(plan: TravelPlan) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("タイムスケジュール")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(colorScheme == .dark ? .white : .black)

            if let daySchedule = plan.daySchedules.first(where: { $0.dayNumber == selectedDay }) {
                if daySchedule.scheduleItems.isEmpty {
                    emptyScheduleMessage
                } else {
                    let sortedItems = daySchedule.scheduleItems.sorted { $0.time < $1.time }
                    VStack(spacing: 0) {
                        ForEach(Array(sortedItems.enumerated()), id: \.element.id) { index, item in
                            timelineItemView(item: item, isLast: index == sortedItems.count - 1)
                        }
                    }
                }
            } else {
                emptyScheduleMessage
            }

            Button(action: { showScheduleEditor = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                    Text("スケジュールを追加/編集")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.orange)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .padding(.horizontal, 20)
                .background(Color.orange.opacity(0.15))
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.15 : 0.3), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : 10)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: animateContent)
    }

    private var emptyScheduleMessage: some View {
        Text("スケジュールがありません")
            .font(.subheadline)
            .foregroundColor(.gray)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
    }

    private func timelineItemView(item: ScheduleItem, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 15) {
            // 時刻とタイムラインドット
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.orange.opacity(0.4), Color.orange.opacity(0.2)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)

                    Image(systemName: "clock.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.orange)
                }

                if !isLast {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.orange.opacity(0.4), Color.orange.opacity(0.1)]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 3)
                        .frame(height: 50)
                }
            }

            // スケジュール内容
            VStack(alignment: .leading, spacing: 8) {
                Text(formatTime(item.time))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.orange)

                Text(item.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white : .black)

                if let location = item.location, !location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        Text(location)
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                }

                if let notes = item.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.system(size: 13))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .gray)
                        .lineLimit(2)
                }
            }
            .padding(.bottom, isLast ? 0 : 25)

            Spacer()
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

    // 新しいヘッダーセクション：画像背景にタイトル、日付、時刻を表示
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
                    // デフォルトの背景色
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.orange.opacity(0.7),
                                    Color.pink.opacity(0.6),
                                    Color.purple.opacity(0.7)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .frame(height: 280)
            .clipped()

            // グラデーションオーバーレイ
            LinearGradient(
                gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.8)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 280)

            // テキスト情報（下部）
            VStack(alignment: .leading, spacing: 10) {
                Text(plan.title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)

                HStack(spacing: 20) {
                    Label {
                        Text(formatDateWithWeekday(plan.startDate))
                            .foregroundColor(.white)
                    } icon: {
                        Image(systemName: "calendar")
                            .foregroundColor(.white)
                    }

                    Label {
                        Text(formatTripDuration())
                            .foregroundColor(.white)
                    } icon: {
                        Image(systemName: "clock")
                            .foregroundColor(.white)
                    }
                }
                .font(.subheadline)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(20)

            // ナビゲーションボタン（上部）
            HStack {
                // 戻るボタン
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.3))
                            .frame(width: 40, height: 40)
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.leading, 20)

                Spacer()

                // 編集ボタン
                Button(action: { showBasicInfoEditor = true }) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.3))
                            .frame(width: 40, height: 40)
                        Image(systemName: "pencil")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.trailing, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 10)
        }
        .frame(height: 280)
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : -20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animateContent)
    }

    private func planInfoCard(plan: TravelPlan) -> some View {
        VStack(spacing: 15) {
            HStack {
                Text(plan.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(colorScheme == .dark ? .white : .black)

                Spacer()

                // Share Button
                Button(action: { showShareView = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: plan.isShared ? "person.2.fill" : "person.2")
                            .foregroundColor(plan.isShared ? .green : .orange)
                            .font(.title3)
                        if plan.isShared {
                            Text("\(plan.sharedWith.count)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.3))
                    .cornerRadius(10)
                }
            }

            HStack(spacing: 20) {
                destinationInfo(plan: plan)
                dateInfo(plan: plan)
            }
            .font(.subheadline)

            if plan.isShared {
                lastUpdatedInfo(plan: plan)
            }

            // 画像を表示: planImagesキャッシュを優先、なければローカルファイルから読み込む
            if let planId = plan.id, let image = viewModel.planImages[planId] {
                planImage(image: image)
            } else if let localImageFileName = plan.localImageFileName,
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

    // 新しい予算カード
    private func budgetCard(plan: TravelPlan) -> some View {
        Button(action: { showBudgetSummary = true }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.green.opacity(0.3), Color.green.opacity(0.15)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                    Image(systemName: "yensign.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.green.opacity(0.8))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("予算")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    Text(formatBudgetAmount(plan: plan))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                }

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.green.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.green.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(PlainButtonStyle())
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : 10)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: animateContent)
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
                Text("天気")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .white : .black)

                if let plan = currentPlan {
                    if plan.latitude == nil || plan.longitude == nil {
                        // 座標が設定されていない場合
                        HStack(spacing: 15) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.15))
                                    .frame(width: 60, height: 60)
                                Image(systemName: "cloud.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.blue.opacity(0.7))
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("曇り")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(colorScheme == .dark ? .white : .black)
                                Text("15°C")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(colorScheme == .dark ? .white : .black)
                            }
                            Spacer()
                        }
                    } else if isLoadingPlanWeather {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else if planWeatherError != nil {
                        Text("10日前になると天気が表示されます")
                            .font(.caption)
                            .foregroundColor(.gray)
                    } else if let weather = planWeather {
                        HStack(spacing: 15) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.15))
                                    .frame(width: 60, height: 60)
                                Image(systemName: weather.symbolName)
                                    .font(.system(size: 28))
                                    .foregroundColor(.blue.opacity(0.7))
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(weather.condition)
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(colorScheme == .dark ? .white : .black)
                                Text("\(Int(weather.highTemperature))°C")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(colorScheme == .dark ? .white : .black)
                            }
                            Spacer()
                        }
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.blue.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
            .opacity(animateContent ? 1 : 0)
            .offset(y: animateContent ? 0 : 10)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: animateContent)
        }
    }

    // MARK: - Packing List Section
    private func packingListSection(plan: TravelPlan) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 8) {
                Image(systemName: "bag.fill")
                    .font(.system(size: 20))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                Text("持ち物リスト")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                Spacer()
            }

            if let currentPlan = currentPlan {
                PackingListView(plan: currentPlan)
                    .environmentObject(viewModel)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : 10)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: animateContent)
    }

    // MARK: - Helper Methods
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
                let fetchedAttribution = try await WeatherService.shared.getWeatherAttribution(
                    latitude: latitude,
                    longitude: longitude
                )

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

