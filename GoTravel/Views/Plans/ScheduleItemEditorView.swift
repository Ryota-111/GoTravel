import SwiftUI

struct ScheduleItemEditorView: View {
    @Binding var plan: Plan
    let scheduleItem: PlanScheduleItem?
    let onSave: (Plan) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var time: Date
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
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
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
                                            .foregroundColor(.blue)
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
                        [Color.blue.opacity(0.8), .black] :
                        [Color.blue.opacity(0.7), .white.opacity(0.1)]),
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
                    time: time,
                    title: title,
                    placeId: selectedPlaceId,
                    note: note.isEmpty ? nil : note
                )
            }
        } else {
            // 新規追加モード
            let newItem = PlanScheduleItem(
                time: time,
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
