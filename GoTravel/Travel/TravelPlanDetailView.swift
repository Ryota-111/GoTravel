import SwiftUI

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
        .navigationBarItems(trailing: editButton)
    }

    // MARK: - View Components
    private func contentView(plan: TravelPlan) -> some View {
        ZStack {
            backgroundGradient

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {
                        planInfoCard(plan: plan)
                        budgetButton(plan: plan)
                        daySelectionTabs(plan: plan)
                        scheduleSection(plan: plan)
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
    }

    private var editButton: some View {
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

            if let localImageFileName = plan.localImageFileName,
               let image = FileManager.documentsImage(named: localImageFileName) {
                planImage(image: image)
            }
        }
        .padding()
        .background(Color.white.opacity(0.2))
        .cornerRadius(15)
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
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return "\(formatter.string(from: plan.startDate)) - \(formatter.string(from: plan.endDate))"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
}

// MARK: - Day Schedule View
struct DayScheduleView: View {

    // MARK: - Properties
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var viewModel: TravelPlanViewModel
    let daySchedule: DaySchedule
    let plan: TravelPlan
    @State private var showAddScheduleItem = false
    @State private var editingItem: ScheduleItem?

    // MARK: - Computed Properties
    private var sortedScheduleItems: [ScheduleItem] {
        daySchedule.scheduleItems.sorted(by: { $0.time < $1.time })
    }

    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            headerSection
            scheduleListSection
        }
        .padding()
        .background(Color.white.opacity(0.2))
        .cornerRadius(15)
        .sheet(isPresented: $showAddScheduleItem) {
            AddScheduleItemView(plan: plan, daySchedule: daySchedule)
                .environmentObject(viewModel)
        }
        .sheet(item: $editingItem) { item in
            EditScheduleItemView(plan: plan, daySchedule: daySchedule, item: item)
                .environmentObject(viewModel)
        }
    }

    // MARK: - View Components
    private var headerSection: some View {
        HStack {
            Text("Day \(daySchedule.dayNumber)のスケジュール")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(colorScheme == .dark ? .white : .black)

            Spacer()

            Button(action: { showAddScheduleItem = true }) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.orange)
                    .imageScale(.large)
            }
        }
    }

    private var scheduleListSection: some View {
        Group {
            if daySchedule.scheduleItems.isEmpty {
                emptyScheduleView
            } else {
                scheduleList
            }
        }
    }

    private var emptyScheduleView: some View {
        VStack(spacing: 10) {
            Image(systemName: "clock.badge.plus")
                .font(.system(size: 40))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.5) : .gray.opacity(0.5))

            Text("予定を追加してください")
                .font(.subheadline)
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(Color.white.opacity(0.1))
        .cornerRadius(15)
    }

    private var scheduleList: some View {
        List {
            ForEach(sortedScheduleItems) { item in
                ScheduleItemCard(item: item)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 5, leading: 0, bottom: 5, trailing: 0))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingItem = item
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            deleteScheduleItem(item)
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .frame(minHeight: CGFloat(daySchedule.scheduleItems.count) * 130)
    }

    // MARK: - Helper Methods
    private func deleteScheduleItem(_ item: ScheduleItem) {
        var updatedPlan = plan

        if let dayIndex = updatedPlan.daySchedules.firstIndex(where: { $0.id == daySchedule.id }) {
            updatedPlan.daySchedules[dayIndex].scheduleItems.removeAll(where: { $0.id == item.id })
        }

        viewModel.update(updatedPlan)
    }
}

// MARK: - Schedule Item Card
struct ScheduleItemCard: View {

    // MARK: - Properties
    @Environment(\.colorScheme) var colorScheme
    let item: ScheduleItem
    @State private var showMapView = false
    @State private var showLink = false

    // MARK: - Body
    var body: some View {
        HStack(spacing: 15) {
            timeSection
            contentSection
            Spacer()
            if item.mapURL != nil {
                mapButton
            }
        }
        .padding()
        .background(Color.white.opacity(0.2))
        .cornerRadius(15)
        .sheet(isPresented: $showMapView) {
            if let mapURL = item.mapURL, let url = URL(string: mapURL) {
                SafariView(url: url)
            }
        }
        .sheet(isPresented: $showLink) {
            if let linkURL = item.linkURL, let url = URL(string: linkURL) {
                SafariView(url: url)
            }
        }
    }

    // MARK: - View Components
    private var timeSection: some View {
        VStack(spacing: 5) {
            Text(formatTime(item.time))
                .font(.headline)
                .foregroundColor(.orange)

            Image(systemName: "clock.fill")
                .foregroundColor(.orange.opacity(0.7))
                .font(.caption)
        }
        .frame(width: 60)
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.title)
                .font(.headline)
                .foregroundColor(colorScheme == .dark ? .white : .black)

            if let location = item.location {
                locationInfo(location: location)
            }

            if let cost = item.cost {
                costInfo(cost: cost)
            }

            if let linkURL = item.linkURL {
                linkButton(linkURL: linkURL)
            }

            if let notes = item.notes {
                notesInfo(notes: notes)
            }
        }
    }

    private func locationInfo(location: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "mappin.circle.fill")
                .font(.caption)
                .foregroundColor(.orange)
            Text(location)
                .font(.subheadline)
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.7))
        }
    }

    private func costInfo(cost: Double) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "yensign.circle.fill")
                .font(.caption)
                .foregroundColor(.green)
            Text(formatCurrency(cost))
                .font(.subheadline)
                .foregroundColor(.green)
        }
    }

    private func linkButton(linkURL: String) -> some View {
        Button(action: { showLink = true }) {
            HStack(spacing: 5) {
                Image(systemName: "link")
                    .font(.caption)
                    .foregroundColor(.blue)
                Text("リンク")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
        }
    }

    private func notesInfo(notes: String) -> some View {
        Text(notes)
            .font(.caption)
            .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .gray)
            .lineLimit(2)
    }

    private var mapButton: some View {
        Button(action: { showMapView = true }) {
            ZStack {
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 80, height: 80)
                    .cornerRadius(10)

                Image(systemName: "map.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.blue)
            }
        }
    }

    // MARK: - Helper Methods
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return "¥\(formatter.string(from: NSNumber(value: amount)) ?? "0")"
    }
}
