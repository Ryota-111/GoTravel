import SwiftUI

struct EnjoyWorldView: View {

    // MARK: - View State
    enum ViewState {
        case loading
        case empty
        case content([TravelPlan])
    }

    enum PlanListState {
        case loading
        case empty
        case content([Plan])
    }

    // MARK: - Properties
    @EnvironmentObject var travelPlanViewModel: TravelPlanViewModel
    @EnvironmentObject var plansViewModel: PlansViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject var themeManager = ThemeManager.shared
    @State private var selectedTab: TabType = .all
    @State private var selectedPlanTab: PlanTabType = .all
    @State private var showAddTravelPlan = false
    @State private var showAddPlan = false
    @State private var showJoinPlan = false
    @State private var planToDelete: TravelPlan?
    @State private var showDeleteConfirmation = false
    @State private var planEventToDelete: Plan?
    @State private var showPlanDeleteConfirmation = false
    @State private var showAuthError = false
    @State private var hasLoadedData = false
    @Environment(\.colorScheme) var colorScheme
    @Namespace private var animation
    @State private var showTodayDate = true

    // MARK: - Computed Properties
    private var travelPlansState: ViewState {
        if travelPlanViewModel.isLoading {
            return .loading
        } else if travelPlanViewModel.travelPlans.isEmpty {
            return .empty
        } else {
            return .content(filteredTravelPlans)
        }
    }

    private var planListState: PlanListState {
        if plansViewModel.isLoading {
            return .loading
        } else if plansViewModel.plans.isEmpty {
            return .empty
        } else {
            return .content(filteredPlans)
        }
    }

    private var filteredPlans: [Plan] {
        let filtered: [Plan]
        switch selectedPlanTab {
        case .all:
            filtered = plansViewModel.plans
        case .goingout:
            filtered = plansViewModel.plans.filter { $0.planType == .outing }
        case .everyday:
            filtered = plansViewModel.plans.filter { $0.planType == .daily }
        }
        return filtered
    }

    private var currentFilteredPlans: [Plan] {
        filteredPlans.filter { plan in
            let calendar = Calendar.current
            let now = Date()
            let todayStart = calendar.startOfDay(for: now)
            let planStart = calendar.startOfDay(for: plan.startDate)
            let planEnd = calendar.startOfDay(for: plan.endDate)
            return planStart <= todayStart && planEnd >= todayStart
        }.sorted { $0.endDate < $1.endDate }
    }

    private var futureFilteredPlans: [Plan] {
        filteredPlans.filter { plan in
            let calendar = Calendar.current
            let now = Date()
            let todayStart = calendar.startOfDay(for: now)
            let planStart = calendar.startOfDay(for: plan.startDate)
            return planStart > todayStart
        }.sorted { $0.startDate < $1.startDate }
    }

    private var pastFilteredPlans: [Plan] {
        filteredPlans.filter { plan in
            let calendar = Calendar.current
            let now = Date()
            let todayStart = calendar.startOfDay(for: now)
            let planEnd = calendar.startOfDay(for: plan.endDate)
            return planEnd < todayStart
        }.sorted { $0.endDate > $1.endDate }
    }

    private var filteredTravelPlans: [TravelPlan] {
        let now = Date()
        let plans = travelPlanViewModel.travelPlans

        switch selectedTab {
        case .all:
            return plans.sorted { plan1, plan2 in
                sortPlansForAllTab(plan1: plan1, plan2: plan2, at: now)
            }
        case .ongoing:
            return plans
                .filter { isOngoing(plan: $0, at: now) }
                .sorted { $0.startDate < $1.startDate }
        case .upcoming:
            return plans
                .filter { isFuture(plan: $0, at: now) }
                .sorted { $0.startDate < $1.startDate }
        case .past:
            return plans
                .filter { isPast(plan: $0, at: now) }
                .sorted { $0.startDate > $1.startDate }
        }
    }

    private var hasOngoingPlans: Bool {
        let now = Date()
        return travelPlanViewModel.travelPlans.contains { isOngoing(plan: $0, at: now) }
    }

    private var todayDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/M/d"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: Date())
    }

    private var nextPlanSummary: String {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        let upcoming = plansViewModel.plans
            .filter { plan in
                let planDayStart = calendar.startOfDay(for: plan.startDate)
                if planDayStart > todayStart { return true }
                if planDayStart == todayStart {
                    if let t = plan.time { return t > now }
                    return true
                }
                return false
            }
            .sorted { $0.startDate < $1.startDate }
        if let next = upcoming.first {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ja_JP")
            if let t = next.time {
                formatter.dateFormat = "M月d日 HH:mm"
                return "\(next.title) \(formatter.string(from: t))"
            } else {
                formatter.dateFormat = "M月d日"
                return "\(next.title) \(formatter.string(from: next.startDate))"
            }
        }
        return "今後の予定はありません"
    }

    // MARK: - Body
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 15) {
                titleSection
                ScrollView(.vertical, showsIndicators: false) {
                    travelEventsTitleSection
                    tabSelectionSection
                    travelPlansSection
                    planEventsTitleSection
                    planTabSelectionSection
                    planEventsListSection
                }
            }
            .background(backgroundGradient)
            .navigationBarHidden(true)
            .sheet(isPresented: $showAddTravelPlan) {
                AddTravelPlanView { newPlan in
                    if let userId = authVM.userId {
                        travelPlanViewModel.add(newPlan, userId: userId)
                    }
                }
            }
            .sheet(isPresented: $showAddPlan) {
                AddPlanView { newPlan in
                    if let userId = authVM.userId {
                        plansViewModel.add(newPlan, userId: userId)
                    } else {
                        showAuthError = true
                    }
                }
            }
            .sheet(isPresented: $showJoinPlan) {
                JoinTravelPlanView()
                    .environmentObject(travelPlanViewModel)
            }
            .alert("認証が必要です", isPresented: $showAuthError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("予定を保存するには、アプリを再起動してApple IDでサインインしてください。")
            }
            .alert("旅行計画を削除", isPresented: $showDeleteConfirmation, presenting: planToDelete) { plan in
                Button("削除", role: .destructive) {
                    if let userId = authVM.userId {
                        travelPlanViewModel.delete(plan, userId: userId)
                    }
                    planToDelete = nil
                }
                Button("キャンセル", role: .cancel) {
                    planToDelete = nil
                }
            } message: { plan in
                Text("「\(plan.title)」を本当に削除しますか？")
            }
            .alert("予定を削除", isPresented: $showPlanDeleteConfirmation, presenting: planEventToDelete) { plan in
                Button("削除", role: .destructive) {
                    if let userId = authVM.userId {
                        Task {
                            await plansViewModel.deletePlan(plan, userId: userId)
                        }
                    }
                    planEventToDelete = nil
                }
                Button("キャンセル", role: .cancel) {
                    planEventToDelete = nil
                }
            } message: { plan in
                Text("「\(plan.title)」を本当に削除しますか？")
            }
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    withAnimation(.easeInOut(duration: 0.6)) {
                        showTodayDate.toggle()
                    }
                }
            }
            .onAppear {
                selectedTab = hasOngoingPlans ? .ongoing : .all

                // 初回のみCore DataのFetchedResultsControllerをセットアップ
                if !hasLoadedData, let userId = authVM.userId {
                    // 1. CloudKitからCore Dataへのデータ移行（初回のみ）
                    Task {
                        do {
                            try await CloudKitMigrationService.shared.migrateAllData(userId: userId)
                        } catch {
                        }
                    }

                    // 2. Core DataのFetchedResultsControllerをセットアップ
                    travelPlanViewModel.setupFetchedResultsController(userId: userId)
                    plansViewModel.setupFetchedResultsController(userId: userId)
                    hasLoadedData = true
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - View Components
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .leading) {
                Text("Travory")
                    .opacity(showTodayDate ? 1 : 0)
                Text("次の予定")
                    .opacity(showTodayDate ? 0 : 1)
            }
            .foregroundColor(colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1)
            .padding(.horizontal, 40)
            .font(.caption.weight(.bold))
            .animation(.easeInOut(duration: 0.6), value: showTodayDate)
            .padding(.top, 10)
            
            HStack {
                LinearGradient(
                    colors: [themeManager.currentTheme.secondary, themeManager.currentTheme.primary],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(width: 4, height: 40)
                    .cornerRadius(2)
                ZStack(alignment: .leading) {
                    Text(todayDateString)
                        .opacity(showTodayDate ? 1 : 0)
                    Text(nextPlanSummary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .opacity(showTodayDate ? 0 : 1)
                }
                .foregroundColor(colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1)
                .font(.system(size: 40))
                .animation(.easeInOut(duration: 0.6), value: showTodayDate)

                Spacer()

                Button(action: {
                    showJoinPlan = true
                }) {
                    ZStack {
                        Circle()
                            .fill(Color(.systemGray6))
                            .frame(width: 44, height: 44)
                            .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)

                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 20))
                            .foregroundColor(themeManager.currentTheme.success)
                    }
                }

                NavigationLink(destination: ProfileView()) {
                    ZStack {
                        Circle()
                            .fill(Color(.systemGray6))
                            .frame(width: 44, height: 44)
                            .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)

                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 35, height: 35)
                            .foregroundStyle(LinearGradient(colors: [.white, themeManager.currentTheme.secondary], startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                    .padding(.trailing, 2)
                }
            }
            .padding(.horizontal, 20)
        }
        
    }
    
    private var travelEventsTitleSection: some View {
        HStack {
            Text("旅行計画")
                .foregroundColor(colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1)
                .font(.title.weight(.semibold))
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    private var tabSelectionSection: some View {
        HStack(spacing: 8) {
            ForEach(TabType.allCases) { tab in
                tabButton(for: tab)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private var travelPlansSection: some View {
        Group {
            switch travelPlansState {
            case .loading:
                VStack(spacing: 15) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("旅行計画を読み込み中...")
                        .font(.subheadline)
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                }
                .frame(width: 200, height: 200)
                .background(Color.white.opacity(0.2))
                .cornerRadius(25)
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                .padding(.horizontal, 20)
            case .empty:
                emptyTravelPlansView
            case .content(let plans):
                travelPlansListView(plans: plans)
            }
        }
    }

    private var planEventsTitleSection: some View {
        HStack {
            Text("予定計画")
                .foregroundColor(colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1)
                .font(.title.weight(.semibold))
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    private var planTabSelectionSection: some View {
        HStack(spacing: 8) {
            ForEach(PlanTabType.allCases) { tab in
                planTabButton(for: tab)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private var planEventsListSection: some View {
        VStack(spacing: 15) {
            switch planListState {
            case .loading:
                VStack(spacing: 15) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("予定を読み込み中...")
                        .font(.subheadline)
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            case .empty:
                emptyPlanEventsView
            case .content(let plans):
                planEventsListView(plans: plans)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    // MARK: - Helper Views
    private func tabButton(for tab: TabType) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) {
                selectedTab = tab
            }
        }) {
            Text(tab.displayName)
                .font(.callout)
                .fontWeight(selectedTab == tab ? .semibold : .regular)
                .foregroundColor(selectedTab == tab ? themeManager.currentTheme.light : themeManager.currentTheme.secondaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background {
                    if selectedTab == tab {
                        Capsule()
                            .fill(themeManager.currentTheme.secondary)
                            .matchedGeometryEffect(id: "TAB", in: animation)
                    }
                }
        }
    }

    private func planTabButton(for tab: PlanTabType) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) {
                selectedPlanTab = tab
            }
        }) {
            Text(tab.displayName)
                .font(.callout)
                .fontWeight(selectedPlanTab == tab ? .semibold : .regular)
                .foregroundColor(selectedPlanTab == tab ? themeManager.currentTheme.light : themeManager.currentTheme.secondaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background {
                    if selectedPlanTab == tab {
                        Capsule()
                            .fill(themeManager.currentTheme.secondary)
                            .matchedGeometryEffect(id: "PLAN_TAB", in: animation)
                    }
                }
        }
    }

    private var emptyTravelPlansView: some View {
        Button(action: {
            showAddTravelPlan = true
        }) {
            VStack(spacing: 15) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(themeManager.currentTheme.secondary)

                Text("旅行計画を作成")
                    .font(.headline)
                    .foregroundColor(themeManager.currentTheme.text)

                Text("新しい旅行計画を追加してください")
                    .font(.subheadline)
                    .foregroundColor(themeManager.currentTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 200, height: 200)
            .background(themeManager.currentTheme.tertiary)
            .cornerRadius(25)
            .shadow(color: themeManager.currentTheme.accent1.opacity(0.1), radius: 10, x: 0, y: 5)
        }
        .padding(.horizontal, 20)
    }

    private func travelPlansListView(plans: [TravelPlan]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 15) {
                ForEach(plans) { plan in
                    TravelPlanCard(
                        plan: plan,
                        onDelete: {
                            planToDelete = plan
                            showDeleteConfirmation = true
                        }
                    )
                    .environmentObject(travelPlanViewModel)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.3).combined(with: .opacity),
                        removal: .opacity
                    ))
                }

                addTravelPlanButton
            }
            .padding(.horizontal, 20)
        }
        .animation(.spring(response: 0.7, dampingFraction: 0.6), value: plans.count)
    }

    private var addTravelPlanButton: some View {
        Button(action: {
            showAddTravelPlan = true
        }) {
            VStack {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(themeManager.currentTheme.secondary)

                Text("予定を追加")
                    .font(.headline)
                    .foregroundColor(themeManager.currentTheme.secondary)
            }
            .frame(width: 150, height: 200)
            .background(themeManager.currentTheme.accent2.opacity(0.2))
            .cornerRadius(25)
            .shadow(color: themeManager.currentTheme.accent1.opacity(0.1), radius: 10, x: 0, y: 5)
        }
    }

    private var emptyPlanEventsView: some View {
        VStack(spacing: 15) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 50))
                .foregroundColor(themeManager.currentTheme.secondaryText.opacity(0.5))

            Text("まだ予定がありません")
                .font(.body)
                .foregroundColor(themeManager.currentTheme.secondaryText)

            Button(action: {
                showAddPlan = true
            }) {
                Text("予定を追加")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(themeManager.currentTheme.secondary)
                    .cornerRadius(25)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func planEventsListView(plans: [Plan]) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 10) {
                PlanEventSectionView(
                    title: "今日の予定",
                    plans: currentFilteredPlans,
                    viewModel: plansViewModel,
                    onDelete: { plan in
                        planEventToDelete = plan
                        showPlanDeleteConfirmation = true
                    }
                )
                .animation(.spring(response: 0.7, dampingFraction: 0.6), value: currentFilteredPlans.count)

                PlanEventSectionView(
                    title: "今後の予定",
                    plans: futureFilteredPlans,
                    viewModel: plansViewModel,
                    onDelete: { plan in
                        planEventToDelete = plan
                        showPlanDeleteConfirmation = true
                    }
                )
                .animation(.spring(response: 0.7, dampingFraction: 0.6), value: futureFilteredPlans.count)

                addPlanButton
            }
            .padding(.horizontal, 1)
        }
        .animation(.spring(response: 0.7, dampingFraction: 0.6), value: plans.count)
    }

    private var addPlanButton: some View {
        Button(action: {
            showAddPlan = true
        }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(themeManager.currentTheme.secondary)
                Text("予定を追加")
                    .font(.headline)
                    .foregroundColor(themeManager.currentTheme.secondary)
            }
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity)
            .background(themeManager.currentTheme.accent2.opacity(0.2))
            .cornerRadius(15)
            .shadow(color: themeManager.currentTheme.accent1.opacity(0.05), radius: 5, x: 0, y: 2)
        }
    }


    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: colorScheme == .dark ? [themeManager.currentTheme.gradientDark, themeManager.currentTheme.dark] : [themeManager.currentTheme.gradientLight, themeManager.currentTheme.light]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Helper Methods
    private func sortPlansForAllTab(plan1: TravelPlan, plan2: TravelPlan, at date: Date) -> Bool {
        let plan1Ongoing = isOngoing(plan: plan1, at: date)
        let plan2Ongoing = isOngoing(plan: plan2, at: date)
        let plan1Future = isFuture(plan: plan1, at: date)
        let plan2Future = isFuture(plan: plan2, at: date)

        if plan1Ongoing && !plan2Ongoing {
            return true
        } else if !plan1Ongoing && plan2Ongoing {
            return false
        } else if plan1Future && !plan2Future {
            return true
        } else if !plan1Future && plan2Future {
            return false
        } else if plan1Future && plan2Future {
            return plan1.startDate < plan2.startDate
        } else {
            return plan1.startDate > plan2.startDate
        }
    }

    private func isOngoing(plan: TravelPlan, at date: Date) -> Bool {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let planStart = calendar.startOfDay(for: plan.startDate)
        let planEnd = calendar.startOfDay(for: plan.endDate)
        return startOfDay >= planStart && startOfDay <= planEnd
    }

    private func isFuture(plan: TravelPlan, at date: Date) -> Bool {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let planStart = calendar.startOfDay(for: plan.startDate)
        return planStart > startOfDay
    }

    private func isPast(plan: TravelPlan, at date: Date) -> Bool {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let planEnd = calendar.startOfDay(for: plan.endDate)
        return planEnd < startOfDay
    }
}

// MARK: - Tab Type
extension EnjoyWorldView {
    enum TabType: String, CaseIterable, Identifiable {
        case all = "すべて"
        case ongoing = "進行中"
        case upcoming = "今後の旅行"
        case past = "過去の旅行"

        var id: String { rawValue }

        var displayName: String { rawValue }
    }

    enum PlanTabType: String, CaseIterable, Identifiable {
        case all = "すべて"
        case goingout = "おでかけ"
        case everyday = "日常"

        var id: String { rawValue }

        var displayName: String { rawValue }
    }
}

// MARK: - Preview
#Preview {
    let authVM = AuthViewModel()
    let travelPlanVM = TravelPlanViewModel()
    let plansVM = PlansViewModel()

    return EnjoyWorldView()
        .environmentObject(authVM)
        .environmentObject(travelPlanVM)
        .environmentObject(plansVM)
}
