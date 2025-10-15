import SwiftUI

struct AddScheduleItemView: View {

    // MARK: - Properties
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var viewModel: TravelPlanViewModel

    let plan: TravelPlan
    let daySchedule: DaySchedule

    @State private var title: String = ""
    @State private var location: String = ""
    @State private var notes: String = ""
    @State private var time: Date = Date()
    @State private var cost: String = ""
    @State private var mapURL: String = ""
    @State private var linkURL: String = ""
    @State private var isSaving = false

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
            .navigationTitle("予定を追加")
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
    }

    // MARK: - View Components
    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                dayInfoCard
                formSection
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

        let newItem = createScheduleItem()
        let updatedPlan = addScheduleItemToPlan(newItem)

        logSaveDetails(newItem: newItem, updatedPlan: updatedPlan)

        viewModel.update(updatedPlan)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSaving = false
            presentationMode.wrappedValue.dismiss()
        }
    }

    private func createScheduleItem() -> ScheduleItem {
        let costValue = cost.isEmpty ? nil : Double(cost)

        print("AddScheduleItemView: 金額入力 - '\(cost)'")
        print("AddScheduleItemView: 金額変換後 - \(costValue?.description ?? "nil")")

        return ScheduleItem(
            time: time,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            location: location.isEmpty ? nil : location.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines),
            cost: costValue,
            mapURL: mapURL.isEmpty ? nil : mapURL.trimmingCharacters(in: .whitespacesAndNewlines),
            linkURL: linkURL.isEmpty ? nil : linkURL.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func addScheduleItemToPlan(_ newItem: ScheduleItem) -> TravelPlan {
        var updatedPlan = plan

        if let dayIndex = updatedPlan.daySchedules.firstIndex(where: { $0.id == daySchedule.id }) {
            updatedPlan.daySchedules[dayIndex].scheduleItems.append(newItem)
            print("AddScheduleItemView: Day \(daySchedule.dayNumber)に追加")
        } else {
            var newDaySchedule = daySchedule
            newDaySchedule.scheduleItems.append(newItem)
            updatedPlan.daySchedules.append(newDaySchedule)
            print("AddScheduleItemView: 新しいDay \(daySchedule.dayNumber)を作成")
        }

        return updatedPlan
    }

    private func logSaveDetails(newItem: ScheduleItem, updatedPlan: TravelPlan) {
        print("AddScheduleItemView: 新規アイテム作成 - タイトル: \(newItem.title), 金額: \(newItem.cost?.description ?? "nil")")
        print("AddScheduleItemView: 更新後の全スケジュール数: \(updatedPlan.daySchedules.flatMap { $0.scheduleItems }.count)")

        let totalCost = updatedPlan.daySchedules.flatMap { $0.scheduleItems }.compactMap { $0.cost }.reduce(0, +)
        print("AddScheduleItemView: 更新後の合計金額: \(totalCost)")
    }
}
