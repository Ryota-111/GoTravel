import SwiftUI

struct ScheduleItemEditorView: View {
    @Binding var plan: Plan
    let scheduleItem: PlanScheduleItem?
    /// 新規追加時に初期選択する日付（nil ならプラン初日）
    let initialDate: Date?
    let onSave: (Plan) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var themeManager = ThemeManager.shared

    @State private var selectedDate: Date
    @State private var time: Date
    @State private var title: String
    @State private var selectedPlaceId: String?
    @State private var note: String

    private var isEditing: Bool {
        scheduleItem != nil
    }

    init(plan: Binding<Plan>,
         scheduleItem item: PlanScheduleItem?,
         initialDate: Date? = nil,
         onSave: @escaping (Plan) -> Void) {
        self._plan = plan
        self.scheduleItem = item
        self.initialDate = initialDate
        self.onSave = onSave

        // Initialize @State variables
        let calendar = Calendar.current
        let availableDates = plan.wrappedValue.scheduleDates
        let requestedDate = item?.date ?? initialDate ?? plan.wrappedValue.startDate
        let normalized = calendar.startOfDay(for: requestedDate)
        // プランの日程内に無い日付（日程変更後など）は初日にフォールバック
        _selectedDate = State(initialValue: availableDates.contains(normalized) ? normalized : (availableDates.first ?? normalized))
        _time = State(initialValue: item?.time ?? Date())
        _title = State(initialValue: item?.title ?? "")
        _selectedPlaceId = State(initialValue: item?.placeId)
        _note = State(initialValue: item?.note ?? "")
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Day Picker（複数日のおでかけプランのみ表示）
                    if plan.hasMultipleScheduleDays {
                        daySelectionSection
                    }

                    // Time Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("時刻")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .padding(12)
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(.separator).opacity(0.5), lineWidth: 1)
                            )
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.secondarySystemBackground))
                            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                    )

                    // Title Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("予定名")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        TextField("例：浅草寺を観光", text: $title)
                            .font(.body)
                            .padding(12)
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(.separator).opacity(0.5), lineWidth: 1)
                            )
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.secondarySystemBackground))
                            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                    )

                    // Place Picker
                    if !plan.places.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("場所（任意）")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)

                            Menu {
                                Button("場所を選択しない") {
                                    selectedPlaceId = nil
                                }

                                ForEach(plan.places) { place in
                                    Button(action: {
                                        selectedPlaceId = place.id
                                    }) {
                                        HStack {
                                            Text(place.name)
                                            if selectedPlaceId == place.id {
                                                Spacer()
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    if let placeId = selectedPlaceId,
                                       let place = plan.places.first(where: { $0.id == placeId }) {
                                        Image(systemName: "mappin.circle.fill")
                                            .foregroundColor(themeManager.currentTheme.primary)
                                        Text(place.name)
                                            .foregroundColor(.primary)
                                    } else {
                                        Image(systemName: "mappin.circle")
                                            .foregroundColor(.secondary)
                                        Text("場所を選択")
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .font(.body)
                                .padding(12)
                                .background(Color(.systemBackground))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color(.separator).opacity(0.5), lineWidth: 1)
                                )
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.secondarySystemBackground))
                                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                        )
                    }

                    // Note Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("メモ（任意）")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        ZStack(alignment: .topLeading) {
                            if note.isEmpty {
                                Text("メモを入力...")
                                    .foregroundColor(.secondary.opacity(0.5))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 20)
                            }

                            TextEditor(text: $note)
                                .font(.body)
                                .frame(minHeight: 100)
                                .padding(8)
                                .scrollContentBackground(.hidden)
                                .background(Color(.systemBackground))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color(.separator).opacity(0.5), lineWidth: 1)
                                )
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.secondarySystemBackground))
                            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                    )
                }
                .padding(24)
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: colorScheme == .dark ?
                        [themeManager.currentTheme.primary.opacity(0.8), .black] :
                        [themeManager.currentTheme.primary.opacity(0.7), .white.opacity(0.1)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle(isEditing ? "スケジュール編集" : "スケジュール追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveScheduleItem()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }

    // MARK: - Day Selection
    private var daySelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("日付")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(plan.scheduleDates.enumerated()), id: \.element) { index, date in
                        dayChip(dayNumber: index + 1, date: date)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }

    private func dayChip(dayNumber: Int, date: Date) -> some View {
        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)

        return Button(action: {
            selectedDate = Calendar.current.startOfDay(for: date)
        }) {
            VStack(spacing: 4) {
                Text("\(dayNumber)日目")
                    .font(.system(size: 14, weight: .bold))
                Text(formatDayLabel(date))
                    .font(.caption2)
            }
            .frame(minWidth: 68)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .foregroundColor(isSelected ? .white : .primary)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? themeManager.currentTheme.primary : Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.clear : Color(.separator).opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func formatDayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d(E)"
        return formatter.string(from: date)
    }

    /// 選択した日付と時刻を1つの Date に合成する
    private func combinedDateTime() -> Date {
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        return calendar.date(bySettingHour: timeComponents.hour ?? 0,
                             minute: timeComponents.minute ?? 0,
                             second: 0,
                             of: selectedDate) ?? time
    }

    private func saveScheduleItem() {
        var updatedPlan = plan
        let day = Calendar.current.startOfDay(for: selectedDate)
        let combined = combinedDateTime()

        if let existingItem = scheduleItem {
            // 編集モード
            if let index = updatedPlan.scheduleItems.firstIndex(where: { $0.id == existingItem.id }) {
                updatedPlan.scheduleItems[index] = PlanScheduleItem(
                    id: existingItem.id,
                    date: day,
                    time: combined,
                    title: title,
                    placeId: selectedPlaceId,
                    note: note.isEmpty ? nil : note
                )
            }
        } else {
            // 新規追加モード
            let newItem = PlanScheduleItem(
                date: day,
                time: combined,
                title: title,
                placeId: selectedPlaceId,
                note: note.isEmpty ? nil : note
            )
            updatedPlan.scheduleItems.append(newItem)
        }

        onSave(updatedPlan)
        dismiss()
    }
}
