import SwiftUI

struct EnjoyWorldView: View {

    // MARK: - View State
    enum ViewState {
        case loading
        case empty
        case content([TravelPlan])
    }

    enum PlanListState {
        case empty
        case content([Plan])
    }

    // MARK: - Properties
    @StateObject private var travelPlanViewModel = TravelPlanViewModel()
    @StateObject private var plansViewModel = PlansViewModel()
    @State private var selectedTab: TabType = .all
    @State private var selectedPlanTab: PlanTabType = .all
    @State private var showAddTravelPlan = false
    @State private var showAddPlan = false
    @State private var planToDelete: TravelPlan?
    @State private var showDeleteConfirmation = false
    @State private var planEventToDelete: Plan?
    @State private var showPlanDeleteConfirmation = false
    @Environment(\.colorScheme) var colorScheme
    @Namespace private var animation
    @Namespace private var planAnimation

    // MARK: - Computed Properties
    private var travelPlansState: ViewState {
        if travelPlanViewModel.travelPlans.isEmpty {
            return .empty
        } else {
            return .content(filteredTravelPlans)
        }
    }

    private var planListState: PlanListState {
        if plansViewModel.plans.isEmpty {
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

    // MARK: - Body
    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    titleSection
                    tabSelectionSection
                    travelPlansSection
                    planEventsTitleSection
                    planTabSelectionSection
                    planEventsListSection
                }
            }
            .background(backgroundGradient)
            .sheet(isPresented: $showAddTravelPlan) {
                AddTravelPlanView { newPlan in
                    travelPlanViewModel.add(newPlan)
                }
            }
            .sheet(isPresented: $showAddPlan) {
                AddPlanView { newPlan in
                    plansViewModel.add(newPlan)
                }
            }
            .alert("旅行計画を削除", isPresented: $showDeleteConfirmation, presenting: planToDelete) { plan in
                Button("削除", role: .destructive) {
                    travelPlanViewModel.delete(plan)
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
                    plansViewModel.deletePlan(plan)
                    planEventToDelete = nil
                }
                Button("キャンセル", role: .cancel) {
                    planEventToDelete = nil
                }
            } message: { plan in
                Text("「\(plan.title)」を本当に削除しますか？")
            }
            .onAppear {
                selectedTab = hasOngoingPlans ? .ongoing : .all
            }
        }
    }

    // MARK: - View Components
    private var headerSection: some View {
        HStack {
            Button(action: {}) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 24))
                    .foregroundColor(.black)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    private var titleSection: some View {
        Text("旅行計画")
            .font(.title.weight(.semibold))
            .padding(.horizontal, 20)
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
                ProgressView()
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
                .font(.title.weight(.semibold))
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
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                selectedTab = tab
            }
        }) {
            ZStack {
                if selectedTab == tab {
                    Capsule()
                        .fill(.orange)
                        .matchedGeometryEffect(id: "TAB", in: animation)
                }

                Text(tab.displayName)
                    .font(.caption)
                    .fontWeight(selectedTab == tab ? .semibold : .regular)
                    .foregroundColor(selectedTab == tab ? .white : .gray)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
        }
    }

    private func planTabButton(for tab: PlanTabType) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                selectedPlanTab = tab
            }
        }) {
            ZStack {
                if selectedPlanTab == tab {
                    Capsule()
                        .fill(.orange)
                        .matchedGeometryEffect(id: "PLAN_TAB", in: planAnimation)
                }

                Text(tab.displayName)
                    .font(.caption)
                    .fontWeight(selectedPlanTab == tab ? .semibold : .regular)
                    .foregroundColor(selectedPlanTab == tab ? .white : .gray)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
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
                    .foregroundColor(.orange)

                Text("旅行計画を作成")
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("新しい旅行計画を追加してください")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 250, height: 250)
            .background(Color.white)
            .cornerRadius(25)
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
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
                }

                addTravelPlanButton
            }
            .padding(.horizontal, 20)
        }
    }

    private var addTravelPlanButton: some View {
        Button(action: {
            showAddTravelPlan = true
        }) {
            VStack {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.orange)

                Text("予定を追加")
                    .font(.headline)
                    .foregroundColor(.orange)
            }
            .frame(width: 150, height: 250)
            .background(Color.white)
            .cornerRadius(25)
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        }
    }

    private var emptyPlanEventsView: some View {
        VStack(spacing: 15) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.5))

            Text("まだ予定がありません")
                .font(.body)
                .foregroundColor(.gray)

            Button(action: {
                showAddPlan = true
            }) {
                Text("予定を追加")
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
    }

    private func planEventsListView(plans: [Plan]) -> some View {
        VStack(spacing: 20) {
            PlanEventSectionView(
                title: "現在の予定",
                plans: currentFilteredPlans,
                viewModel: plansViewModel,
                onDelete: { plan in
                    planEventToDelete = plan
                    showPlanDeleteConfirmation = true
                }
            )

            PlanEventSectionView(
                title: "今後の予定",
                plans: futureFilteredPlans,
                viewModel: plansViewModel,
                onDelete: { plan in
                    planEventToDelete = plan
                    showPlanDeleteConfirmation = true
                }
            )

            PlanEventSectionView(
                title: "過去の予定",
                plans: pastFilteredPlans,
                viewModel: plansViewModel,
                onDelete: { plan in
                    planEventToDelete = plan
                    showPlanDeleteConfirmation = true
                }
            )

            addPlanButton
        }
    }

    private var addPlanButton: some View {
        Button(action: {
            showAddPlan = true
        }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.orange)
                Text("予定を追加")
                    .font(.headline)
                    .foregroundColor(.orange)
            }
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .cornerRadius(15)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
    }


    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: colorScheme == .dark ? [.blue.opacity(0.7), .black] : [.blue.opacity(0.8), .white]),
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
        case all = "All"
        case ongoing = "Ongoing"
        case upcoming = "Upcoming"
        case past = "Past"

        var id: String { rawValue }

        var displayName: String { rawValue }
    }

    enum PlanTabType: String, CaseIterable, Identifiable {
        case all = "All"
        case goingout = "おでかけ"
        case everyday = "日常"

        var id: String { rawValue }

        var displayName: String { rawValue }
    }
}

// MARK: - Travel Plan Card
struct TravelPlanCard: View {
    @EnvironmentObject var viewModel: TravelPlanViewModel
    let plan: TravelPlan
    let onDelete: () -> Void

    var body: some View {
        NavigationLink(destination: TravelPlanDetailView(plan: plan).environmentObject(viewModel)) {
            ZStack {
                cardBackground
                cardOverlay
                cardContent
            }
            .frame(width: 250, height: 250)
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var cardBackground: some View {
        ZStack {
            if let localImageFileName = plan.localImageFileName,
               let image = FileManager.documentsImage(named: localImageFileName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 250, height: 250)
                    .cornerRadius(25)
            } else {
                RoundedRectangle(cornerRadius: 25)
                    .fill(
                        LinearGradient(
                            colors: [
                                plan.cardColor?.opacity(0.8) ?? Color.blue.opacity(0.8),
                                plan.cardColor?.opacity(0.4) ?? Color.blue.opacity(0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 250, height: 250)
            }

            RoundedRectangle(cornerRadius: 25)
                .fill(Color.black.opacity(0.3))
                .frame(width: 250, height: 250)
        }
    }

    private var cardOverlay: some View {
        VStack(alignment: .leading) {
            HStack {
                deleteButton
                Spacer()
            }
            Spacer()
        }
        .padding()
    }

    private var deleteButton: some View {
        Button(action: onDelete) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white)
                    .frame(width: 40, height: 40)
                Image(systemName: "trash")
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundColor(.red)
            }
        }
        .buttonStyle(BorderlessButtonStyle())
        .zIndex(1)
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Spacer()

            VStack(alignment: .leading, spacing: 5) {
                Text(plan.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)

                HStack(spacing: 5) {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundColor(.white)
                    Text(plan.destination)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                HStack(spacing: 5) {
                    Image(systemName: "calendar")
                        .foregroundColor(.white)
                    Text(dateRangeString(from: plan.startDate, to: plan.endDate))
                        .font(.subheadline)
                        .foregroundStyle(.white)
                }
            }
        }
        .padding()
    }

    private func dateRangeString(from start: Date, to end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
}

// MARK: - Plan Event Section View
struct PlanEventSectionView: View {
    let title: String
    let plans: [Plan]
    let viewModel: PlansViewModel
    let onDelete: (Plan) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !plans.isEmpty {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)

                ForEach(plans) { plan in
                    NavigationLink(destination: PlanDetailView(plan: plan)) {
                        PlanEventCardView(plan: plan, onDelete: {
                            onDelete(plan)
                        })
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
}

// MARK: - Plan Event Card View
struct PlanEventCardView: View {
    let plan: Plan
    var onDelete: (() -> Void)? = nil
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        let textColor = colorScheme == .dark ? Color.white : Color.black
        let secondaryTextColor = colorScheme == .dark ? Color.white.opacity(0.9) : Color.black.opacity(0.7)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(plan.title)
                        .font(.headline)
                        .foregroundColor(textColor)

                    HStack {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundColor(secondaryTextColor)
                        Text("\(dateString(plan.startDate)) 〜 \(dateString(plan.endDate))")
                            .font(.subheadline)
                            .foregroundColor(secondaryTextColor)
                    }

                    if plan.planType == .daily, let time = plan.time {
                        HStack {
                            Image(systemName: "clock")
                                .font(.caption)
                                .foregroundColor(secondaryTextColor)
                            Text(formatTime(time))
                                .font(.subheadline)
                                .foregroundColor(secondaryTextColor)
                        }
                    }
                }

                Spacer()

                if let onDelete = onDelete {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                            .padding(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            if !plan.places.isEmpty {
                Divider()
                    .background(colorScheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.3))

                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(plan.planType == .daily ? .orange : .blue)

                    Text("\(plan.places.count) 件の場所")
                        .font(.caption)
                        .foregroundColor(secondaryTextColor)
                }
            }
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: plan.planType == .daily ? [.orange.opacity(0.8), colorScheme == .dark ? .black.opacity(0.1) : .white.opacity(0.1)] : [.blue.opacity(0.8), colorScheme == .dark ? .black.opacity(0.1) : .white.opacity(0.1)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    private func dateString(_ d: Date) -> String {
        DateFormatter.localizedString(from: d, dateStyle: .medium, timeStyle: .none)
    }

    private func formatTime(_ time: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: time)
    }
}

// MARK: - Plan Event Card (Old - for reference, can be removed)
struct PlanEventCard: View {
    let plan: Plan
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 25)
                .fill(.white)
                .frame(height: 130)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)

            HStack(spacing: 15) {
                cardImage
                cardContent
            }
        }
        .frame(height: 130)
    }

    private var cardImage: some View {
        ZStack {
            if let localImageFileName = plan.localImageFileName,
               let image = FileManager.documentsImage(named: localImageFileName) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 130, height: 130)
                    .cornerRadius(radius: 25, corners: [.topLeft, .bottomLeft])
                    .clipped()
            } else {
                LinearGradient(
                    colors: [
                        (plan.cardColor ?? Color.blue).opacity(0.8),
                        (plan.cardColor ?? Color.blue).opacity(0.4)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(width: 130, height: 130)
                .cornerRadius(radius: 25, corners: [.topLeft, .bottomLeft])

                VStack {
                    Image(systemName: "calendar")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                }
            }
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(plan.title)
                    .font(.headline)
                    .foregroundColor(.black)
                    .lineLimit(1)

                Spacer()

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundColor(.red)
                        .padding(8)
                }
            }

            HStack(spacing: 5) {
                Image(systemName: "calendar.circle")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                Text(dateRangeString(from: plan.startDate, to: plan.endDate))
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            Spacer()

            HStack {
                HStack(spacing: 3) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                    Text("\(plan.places.count)箇所")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }

                Spacer()

                let days = Calendar.current.dateComponents([.day], from: plan.startDate, to: plan.endDate).day ?? 0
                HStack(spacing: 3) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                    Text("\(days)泊\(days + 1)日")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.trailing, 15)
    }

    private func dateRangeString(from start: Date, to end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
}
