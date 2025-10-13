import SwiftUI

struct ScheduleEditorView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var viewModel = TravelPlanViewModel()

    let plan: TravelPlan
    @State private var daySchedules: [DaySchedule]
    @State private var selectedDay: Int = 1
    @State private var showAddScheduleItem = false
    @State private var isSaving = false

    init(plan: TravelPlan) {
        self.plan = plan
        _daySchedules = State(initialValue: plan.daySchedules)
    }

    var tripDuration: Int {
        let days = Calendar.current.dateComponents([.day], from: plan.startDate, to: plan.endDate).day ?? 0
        return days + 1
    }

    var currentDaySchedule: DaySchedule? {
        daySchedules.first(where: { $0.dayNumber == selectedDay })
    }

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: colorScheme == .dark ? [Color.blue.opacity(0.7), Color.black] : [Color.blue.opacity(0.8), Color.white]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    headerView

                    ScrollView {
                        VStack(spacing: 20) {
                            planInfoCard
                            daySelectionTabs
                            scheduleItemsList
                        }
                        .padding()
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }

    private var headerView: some View {
        HStack {
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.white)
                    .imageScale(.large)
                Text("戻る")
                    .foregroundColor(.white)
            }

            Spacer()

            Text("スケジュール編集")
                .font(.headline)
                .foregroundColor(.white)

            Spacer()

            Button(action: saveSchedule) {
                if isSaving {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("保存")
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                }
            }
            .disabled(isSaving)
        }
        .padding()
        .background(Color.black.opacity(0.2))
    }

    private var planInfoCard: some View {
        VStack(spacing: 10) {
            Text(plan.title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(colorScheme == .dark ? .white : .black)

            HStack(spacing: 15) {
                HStack(spacing: 5) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.orange)
                    Text(plan.destination)
                        .font(.subheadline)
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .gray)
                }

                HStack(spacing: 5) {
                    Image(systemName: "calendar")
                        .foregroundColor(.orange)
                    Text(dateRangeString)
                        .font(.subheadline)
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .gray)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.2))
        .cornerRadius(15)
    }

    private var daySelectionTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(1...tripDuration, id: \.self) { day in
                    Button(action: {
                        withAnimation(.spring()) {
                            selectedDay = day
                        }
                    }) {
                        VStack(spacing: 5) {
                            Text("Day \(day)")
                                .font(.headline)
                                .foregroundColor(selectedDay == day ? .white : (colorScheme == .dark ? .white.opacity(0.6) : .gray))

                            if let daySchedule = daySchedules.first(where: { $0.dayNumber == day }) {
                                Text("\(daySchedule.scheduleItems.count)件")
                                    .font(.caption2)
                                    .foregroundColor(selectedDay == day ? .white.opacity(0.8) : (colorScheme == .dark ? .white.opacity(0.5) : .gray.opacity(0.7)))
                            } else {
                                Text("0件")
                                    .font(.caption2)
                                    .foregroundColor(selectedDay == day ? .white.opacity(0.8) : (colorScheme == .dark ? .white.opacity(0.5) : .gray.opacity(0.7)))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(selectedDay == day ? Color.orange : Color.white.opacity(0.3))
                        )
                    }
                }
            }
        }
    }

    private var scheduleItemsList: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("Day \(selectedDay)の予定")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(colorScheme == .dark ? .white : .black)

                Spacer()

                Button(action: { showAddScheduleItem = true }) {
                    HStack(spacing: 5) {
                        Image(systemName: "plus.circle.fill")
                        Text("追加")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.orange)
                }
            }

            if let currentSchedule = currentDaySchedule {
                if currentSchedule.scheduleItems.isEmpty {
                    emptyScheduleView
                } else {
                    ForEach(currentSchedule.scheduleItems.sorted(by: { $0.time < $1.time })) { item in
                        ScheduleItemEditCard(
                            item: item,
                            colorScheme: colorScheme,
                            plan: plan,
                            onDelete: {
                                deleteScheduleItem(item)
                            },
                            onEdit: {
                                // 編集機能は後で追加可能
                            }
                        )
                    }
                }
            } else {
                emptyScheduleView
            }
        }
        .padding()
        .background(Color.white.opacity(0.2))
        .cornerRadius(15)
        .sheet(isPresented: $showAddScheduleItem) {
            AddScheduleItemToEditorView(
                dayNumber: selectedDay,
                daySchedules: $daySchedules,
                plan: plan
            )
        }
    }

    private var emptyScheduleView: some View {
        VStack(spacing: 15) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 50))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.5) : .gray.opacity(0.5))

            Text("まだ予定がありません")
                .font(.subheadline)
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .gray)

            Button(action: { showAddScheduleItem = true }) {
                Text("最初の予定を追加")
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
        .background(Color.white.opacity(0.1))
        .cornerRadius(15)
    }

    private var dateRangeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return "\(formatter.string(from: plan.startDate)) - \(formatter.string(from: plan.endDate))"
    }

    private func deleteScheduleItem(_ item: ScheduleItem) {
        if let dayIndex = daySchedules.firstIndex(where: { $0.dayNumber == selectedDay }) {
            daySchedules[dayIndex].scheduleItems.removeAll(where: { $0.id == item.id })
        }
    }

    private func saveSchedule() {
        isSaving = true

        var updatedPlan = plan
        updatedPlan.daySchedules = daySchedules

        viewModel.update(updatedPlan)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSaving = false
            presentationMode.wrappedValue.dismiss()
        }
    }
}

struct ScheduleItemEditCard: View {
    let item: ScheduleItem
    let colorScheme: ColorScheme
    let plan: TravelPlan
    let onDelete: () -> Void
    let onEdit: () -> Void

    @State private var showSaveAsVisited = false

    var body: some View {
        HStack(spacing: 15) {
            VStack(spacing: 5) {
                Text(formatTime(item.time))
                    .font(.headline)
                    .foregroundColor(.orange)

                Image(systemName: "clock.fill")
                    .foregroundColor(.orange.opacity(0.7))
                    .font(.caption)
            }
            .frame(width: 60)

            VStack(alignment: .leading, spacing: 8) {
                Text(item.title)
                    .font(.headline)
                    .foregroundColor(colorScheme == .dark ? .white : .black)

                if let location = item.location {
                    HStack(spacing: 5) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text(location)
                            .font(.subheadline)
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.7))
                    }
                }

                if let notes = item.notes {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .gray)
                        .lineLimit(2)
                }
            }

            Spacer()

            VStack(spacing: 15) {
                Button("場所保存") {
                    showSaveAsVisited = true
                }
                .font(.system(size: 12))
                .foregroundColor(.blue)

                Button(action: onDelete) {
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.red.opacity(0.8))
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.2))
        .cornerRadius(15)
        .sheet(isPresented: $showSaveAsVisited) {
            SaveAsVisitedFromScheduleView(
                scheduleItem: item,
                travelPlanTitle: plan.title,
                travelPlanId: plan.id
            )
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

struct AddScheduleItemToEditorView: View {
    @Environment(\.presentationMode) var presentationMode
    let dayNumber: Int
    @Binding var daySchedules: [DaySchedule]
    let plan: TravelPlan

    @State private var title: String = ""
    @State private var location: String = ""
    @State private var notes: String = ""
    @State private var time: Date = Date()
    @State private var cost: String = ""
    @State private var mapURL: String = ""
    @State private var linkURL: String = ""

    var dayDate: Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: dayNumber - 1, to: plan.startDate) ?? plan.startDate
    }

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.9), Color.black]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        dayInfoCard

                        VStack(spacing: 15) {
                            customTextField(icon: "text.alignleft", placeholder: "タイトル（例：浅草寺観光）", text: $title)
                            customTextField(icon: "mappin.circle", placeholder: "場所", text: $location)

                            HStack {
                                Image(systemName: "yensign.circle")
                                    .foregroundColor(.white.opacity(0.7))
                                TextField("金額（任意）", text: $cost)
                                    .foregroundColor(.white)
                                    .keyboardType(.decimalPad)
                                Text("円")
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(10)

                            customTextField(icon: "map", placeholder: "地図URL（任意）", text: $mapURL)
                            customTextField(icon: "link", placeholder: "リンク（任意）", text: $linkURL)

                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Image(systemName: "note.text")
                                        .foregroundColor(.white.opacity(0.7))
                                    Text("メモ")
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                TextEditor(text: $notes)
                                    .frame(height: 100)
                                    .foregroundColor(.white)
                                    .scrollContentBackground(.hidden)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(8)
                            }
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(10)

                            VStack(alignment: .leading, spacing: 10) {
                                Text("時間")
                                    .foregroundColor(.white)
                                    .font(.headline)
                                DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                                    .datePickerStyle(WheelDatePickerStyle())
                                    .labelsHidden()
                            }
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(10)
                        }
                        .padding()
                    }
                    .padding()
                }
                .background(Color.clear)
                .onTapGesture {
                    hideKeyboard()
                }
            }
            .navigationTitle("予定を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.red)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("追加") {
                        addScheduleItem()
                    }
                    .foregroundColor(.blue)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private var dayInfoCard: some View {
        VStack(spacing: 10) {
            Text("Day \(dayNumber)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text(formatDate(dayDate))
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.2))
        .cornerRadius(15)
    }

    private func customTextField(icon: String, placeholder: String, text: Binding<String>) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.white.opacity(0.7))
            TextField(placeholder, text: text)
                .foregroundColor(.white)
        }
        .padding()
        .background(Color.white.opacity(0.2))
        .cornerRadius(10)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd (E)"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }

    private func addScheduleItem() {
        let costValue = cost.isEmpty ? nil : Double(cost)

        let newItem = ScheduleItem(
            time: time,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            location: location.isEmpty ? nil : location.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines),
            cost: costValue,
            mapURL: mapURL.isEmpty ? nil : mapURL.trimmingCharacters(in: .whitespacesAndNewlines),
            linkURL: linkURL.isEmpty ? nil : linkURL.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        if let dayIndex = daySchedules.firstIndex(where: { $0.dayNumber == dayNumber }) {
            daySchedules[dayIndex].scheduleItems.append(newItem)
        } else {
            let newDaySchedule = DaySchedule(
                dayNumber: dayNumber,
                date: dayDate,
                scheduleItems: [newItem]
            )
            daySchedules.append(newDaySchedule)
            daySchedules.sort { $0.dayNumber < $1.dayNumber }
        }

        presentationMode.wrappedValue.dismiss()
    }
}
