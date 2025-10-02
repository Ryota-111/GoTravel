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
    @State private var selectedEventType: EventType? = .hotel
    @State private var showAddTravelPlan = false
    @State private var showAddPlan = false
    @State private var planToDelete: TravelPlan?
    @State private var showDeleteConfirmation = false
    @State private var planEventToDelete: Plan?
    @State private var showPlanDeleteConfirmation = false
    @Environment(\.colorScheme) var colorScheme
    @Namespace private var animation

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
            return .content(plansViewModel.plans)
        }
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
                    eventTypeSelectionSection
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

            Spacer()

            Button(action: {}) {
                Text("See All")
                    .font(.body)
                    .foregroundColor(.orange)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    private var eventTypeSelectionSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                ForEach(EventType.allCases) { eventType in
                    horizontalEventsCard(
                        menuName: eventType.displayName,
                        menuImage: eventType.iconName,
                        rectColor: selectedEventType == eventType ? .orange : Color.white,
                        imageColors: selectedEventType == eventType ? .white : .orange,
                        textColor: selectedEventType == eventType ? .orange : .gray
                    )
                    .onTapGesture {
                        withAnimation(.spring()) {
                            selectedEventType = eventType
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
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
        Group {
            ForEach(plans.prefix(3)) { plan in
                NavigationLink(destination: PlanDetailView(plan: plan)) {
                    PlanEventCard(
                        plan: plan,
                        onTap: {},
                        onDelete: {
                            planEventToDelete = plan
                            showPlanDeleteConfirmation = true
                        }
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }

            addPlanButton

            if plans.count > 3 {
                seeAllPlansButton
            }
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

    private var seeAllPlansButton: some View {
        NavigationLink(destination: PlansListView()) {
            HStack {
                Text("すべての予定を見る")
                    .font(.headline)
                Image(systemName: "arrow.right")
            }
            .foregroundColor(.orange)
            .padding(.vertical, 10)
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

// MARK: - Plan Event Card
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

// MARK: - Event Type
enum EventType: String, CaseIterable, Identifiable {
    case hotel
    case camp
    case ship
    case flight
    case mountain

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .hotel: return "Hotel"
        case .camp: return "Camp"
        case .ship: return "Ship"
        case .flight: return "Flight"
        case .mountain: return "Mountain"
        }
    }

    var iconName: String {
        switch self {
        case .hotel: return "house.fill"
        case .camp: return "tent.fill"
        case .ship: return "ferry.fill"
        case .flight: return "airplane"
        case .mountain: return "mountain.2.fill"
        }
    }
}
