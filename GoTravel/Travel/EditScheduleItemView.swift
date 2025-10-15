import SwiftUI

struct EditScheduleItemView: View {

    // MARK: - Properties
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var viewModel: TravelPlanViewModel

    let plan: TravelPlan
    let daySchedule: DaySchedule
    let item: ScheduleItem

    @State private var title: String
    @State private var location: String
    @State private var notes: String
    @State private var time: Date
    @State private var cost: String
    @State private var mapURL: String
    @State private var linkURL: String
    @State private var isSaving = false
    @State private var showDeleteConfirmation = false

    // MARK: - Initialization
    init(plan: TravelPlan, daySchedule: DaySchedule, item: ScheduleItem) {
        self.plan = plan
        self.daySchedule = daySchedule
        self.item = item

        _title = State(initialValue: item.title)
        _location = State(initialValue: item.location ?? "")
        _notes = State(initialValue: item.notes ?? "")
        _time = State(initialValue: item.time)
        _cost = State(initialValue: item.cost != nil ? String(Int(item.cost!)) : "")
        _mapURL = State(initialValue: item.mapURL ?? "")
        _linkURL = State(initialValue: item.linkURL ?? "")
    }

    // MARK: - Computed Properties
    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [Color.blue.opacity(0.9), Color.black]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient
                scrollContent
            }
            .navigationTitle("予定を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    cancelButton
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    saveButton
                }
            }
        }
        .alert("予定を削除しますか？", isPresented: $showDeleteConfirmation) {
            Button("キャンセル", role: .cancel) { }
            Button("削除", role: .destructive) {
                deleteScheduleItem()
            }
        } message: {
            Text("この操作は取り消せません")
        }
    }

    // MARK: - View Components
    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                dayInfoCard
                formSection
                deleteButton
            }
            .padding()
        }
        .background(Color.clear)
        .onTapGesture {
            hideKeyboard()
        }
    }

    private var dayInfoCard: some View {
        VStack(spacing: 10) {
            Text("Day \(daySchedule.dayNumber)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text(formatDate(daySchedule.date))
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.2))
        .cornerRadius(15)
    }

    private var formSection: some View {
        VStack(spacing: 15) {
            customTextField(icon: "text.alignleft", placeholder: "タイトル（例：浅草寺観光）", text: $title)
            customTextField(icon: "mappin.circle", placeholder: "場所", text: $location)
            costField
            customTextField(icon: "map", placeholder: "地図URL（任意）", text: $mapURL)
            customTextField(icon: "link", placeholder: "リンク（任意）", text: $linkURL)
            notesField
            timePickerField
        }
        .padding()
    }

    private var costField: some View {
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
    }

    private var notesField: some View {
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
    }

    private var timePickerField: some View {
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

    private var deleteButton: some View {
        Button(action: { showDeleteConfirmation = true }) {
            HStack {
                Image(systemName: "trash")
                Text("予定を削除")
            }
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.red.opacity(0.8))
            .cornerRadius(10)
        }
        .padding()
    }

    private var cancelButton: some View {
        Button("キャンセル") {
            presentationMode.wrappedValue.dismiss()
        }
        .foregroundColor(.red)
    }

    private var saveButton: some View {
        Button(action: saveScheduleItem) {
            if isSaving {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else {
                Text("保存")
                    .foregroundColor(.blue)
            }
        }
        .disabled(!isFormValid || isSaving)
    }

    // MARK: - Helper Views
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

    // MARK: - Helper Methods
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter.japanese
        formatter.dateFormat = "M月d日(E)"
        return formatter.string(from: date)
    }

    // MARK: - Actions
    private func saveScheduleItem() {
        isSaving = true

        let updatedItem = createUpdatedItem()
        let updatedPlan = updatePlanWithItem(updatedItem)

        viewModel.update(updatedPlan)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSaving = false
            presentationMode.wrappedValue.dismiss()
        }
    }

    private func createUpdatedItem() -> ScheduleItem {
        let costValue = cost.isEmpty ? nil : Double(cost)

        return ScheduleItem(
            id: item.id,
            time: time,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            location: location.isEmpty ? nil : location.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines),
            latitude: item.latitude,
            longitude: item.longitude,
            cost: costValue,
            mapURL: mapURL.isEmpty ? nil : mapURL.trimmingCharacters(in: .whitespacesAndNewlines),
            linkURL: linkURL.isEmpty ? nil : linkURL.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func updatePlanWithItem(_ updatedItem: ScheduleItem) -> TravelPlan {
        var updatedPlan = plan

        if let dayIndex = updatedPlan.daySchedules.firstIndex(where: { $0.id == daySchedule.id }) {
            if let itemIndex = updatedPlan.daySchedules[dayIndex].scheduleItems.firstIndex(where: { $0.id == item.id }) {
                updatedPlan.daySchedules[dayIndex].scheduleItems[itemIndex] = updatedItem
            }
        }

        return updatedPlan
    }

    private func deleteScheduleItem() {
        isSaving = true

        let updatedPlan = removePlaceFromPlan()

        viewModel.update(updatedPlan)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSaving = false
            presentationMode.wrappedValue.dismiss()
        }
    }

    private func removePlaceFromPlan() -> TravelPlan {
        var updatedPlan = plan

        if let dayIndex = updatedPlan.daySchedules.firstIndex(where: { $0.id == daySchedule.id }) {
            updatedPlan.daySchedules[dayIndex].scheduleItems.removeAll(where: { $0.id == item.id })
        }

        return updatedPlan
    }
}
