import SwiftUI

struct ScheduleItemEditorView: View {
    @Binding var plan: Plan
    let scheduleItem: PlanScheduleItem?
    let onSave: (Plan) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var themeManager = ThemeManager.shared

    @State private var time: Date
    @State private var selectedDay: Int
    @State private var title: String
    @State private var selectedPlaceId: String?
    @State private var note: String

    private var isEditing: Bool {
        scheduleItem != nil
    }

    init(plan: Binding<Plan>, scheduleItem item: PlanScheduleItem?, onSave: @escaping (Plan) -> Void) {
        self._plan = plan
        self.scheduleItem = item
        self.onSave = onSave

        // Initialize @State variables
        _time = State(initialValue: item?.time ?? Date())
        _title = State(initialValue: item?.title ?? "")
        _selectedPlaceId = State(initialValue: item?.placeId)
        _note = State(initialValue: item?.note ?? "")

        // 何日目の予定かを復元する。新規なら1日目から
        let planValue = plan.wrappedValue
        _selectedDay = State(initialValue: item.map { planValue.dayNumber(for: $0) } ?? 1)
    }

    /// 選んだ日と時刻を合成した、保存する日時
    private var composedDate: Date {
        let calendar = Calendar.current
        let dayDate = plan.date(forDay: selectedDay)
        let components = calendar.dateComponents([.hour, .minute], from: time)

        return calendar.date(
            bySettingHour: components.hour ?? 0,
            minute: components.minute ?? 0,
            second: 0,
            of: dayDate
        ) ?? dayDate
    }

    /// 何日目の予定かを選ぶ
    private var daySelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("日付")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(1...plan.dayCount, id: \.self) { day in
                        dayChip(day)
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

    private func dayChip(_ day: Int) -> some View {
        let isSelected = selectedDay == day
        let accent = plan.planType == .daily
            ? themeManager.currentTheme.dailyPlanColor
            : themeManager.currentTheme.outingPlanColor

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedDay = day
            }
        } label: {
            VStack(spacing: 3) {
                Text("\(day)日目")
                    .font(.caption.weight(.bold))
                Text(dayLabel(for: day))
                    .font(.caption2)
                    .opacity(0.85)
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12).fill(accent)
                } else {
                    RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground))
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.clear : Color(.separator).opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func dayLabel(for day: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d(E)"
        return formatter.string(from: plan.date(forDay: day))
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 2日以上の予定のときだけ、何日目かを選べるようにする
                    if plan.isMultiDay {
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

    private func saveScheduleItem() {
        var updatedPlan = plan

        if let existingItem = scheduleItem {
            // 編集モード
            if let index = updatedPlan.scheduleItems.firstIndex(where: { $0.id == existingItem.id }) {
                updatedPlan.scheduleItems[index] = PlanScheduleItem(
                    id: existingItem.id,
                    time: composedDate,
                    title: title,
                    placeId: selectedPlaceId,
                    note: note.isEmpty ? nil : note
                )
            }
        } else {
            // 新規追加モード
            let newItem = PlanScheduleItem(
                time: composedDate,
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
