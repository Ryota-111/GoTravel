import SwiftUI

// MARK: - Day Schedule View
struct DayScheduleView: View {

    // MARK: - Properties
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var viewModel: TravelPlanViewModel
    let daySchedule: DaySchedule
    let plan: TravelPlan
    @State private var showScheduleEditor = false
    @State private var editingItem: ScheduleItem?

    // MARK: - Computed Properties
    private var sortedScheduleItems: [ScheduleItem] {
        let calendar = Calendar.current

        // Debug: Print BEFORE sorting
        #if DEBUG
        print("\n=== Day \(daySchedule.dayNumber) BEFORE sorting ===")
        for (index, item) in daySchedule.scheduleItems.enumerated() {
            let fullFormatter = DateFormatter()
            fullFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let components = calendar.dateComponents([.hour, .minute], from: item.time)
            print("\(index + 1). Full Date: \(fullFormatter.string(from: item.time)) - \(item.title)")
            print("   Time components: \(components.hour ?? 0):\(components.minute ?? 0)")
        }
        #endif

        let sorted = daySchedule.scheduleItems.sorted { item1, item2 in
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

        // Debug: Print AFTER sorting
        #if DEBUG
        print("\n=== Day \(daySchedule.dayNumber) AFTER sorting ===")
        for (index, item) in sorted.enumerated() {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            print("\(index + 1). \(timeFormatter.string(from: item.time)) - \(item.title)")
        }
        print("===\n")
        #endif

        return sorted
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
        .sheet(isPresented: $showScheduleEditor) {
            ScheduleEditorView(plan: plan)
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

            Button(action: { showScheduleEditor = true }) {
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
                ScheduleItemCard(item: item, editingItem: $editingItem)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 5, leading: 0, bottom: 5, trailing: 0))
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
