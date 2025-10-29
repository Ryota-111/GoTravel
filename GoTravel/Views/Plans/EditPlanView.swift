import SwiftUI

struct EditPlanView: View {
    let plan: Plan
    let viewModel: PlansViewModel
    @Environment(\.dismiss) var dismiss

    @State private var title: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var time: Date?
    @State private var description: String
    @State private var linkURL: String
    @State private var planType: PlanType
    @State private var isSaving = false

    init(plan: Plan, viewModel: PlansViewModel) {
        self.plan = plan
        self.viewModel = viewModel
        _title = State(initialValue: plan.title)
        _startDate = State(initialValue: plan.startDate)
        _endDate = State(initialValue: plan.endDate)
        _time = State(initialValue: plan.time)
        _description = State(initialValue: plan.description ?? "")
        _linkURL = State(initialValue: plan.linkURL ?? "")
        _planType = State(initialValue: plan.planType)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("基本情報")) {
                    TextField("タイトル", text: $title)

                    Picker("プランタイプ", selection: $planType) {
                        Text("おでかけ").tag(PlanType.outing)
                        Text("日常").tag(PlanType.daily)
                    }
                    .pickerStyle(.segmented)
                }

                Section(header: Text("日時")) {
                    DatePicker("開始日", selection: $startDate, displayedComponents: .date)

                    if planType == .outing {
                        DatePicker("終了日", selection: $endDate, displayedComponents: .date)
                    } else {
                        DatePicker("終了日", selection: $endDate, displayedComponents: .date)
                    }

                    if planType == .daily {
                        Toggle("時間を設定", isOn: Binding(
                            get: { time != nil },
                            set: { newValue in
                                if newValue {
                                    time = Date()
                                } else {
                                    time = nil
                                }
                            }
                        ))

                        if time != nil {
                            DatePicker("時間", selection: Binding(
                                get: { time ?? Date() },
                                set: { time = $0 }
                            ), displayedComponents: .hourAndMinute)
                        }
                    }
                }

                if planType == .daily {
                    Section(header: Text("予定内容")) {
                        TextEditor(text: $description)
                            .frame(minHeight: 100)
                    }

                    Section(header: Text("関連リンク")) {
                        TextField("URL", text: $linkURL)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                    }
                }

                Section(header: Text("場所")) {
                    HStack {
                        Text("登録された場所")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(plan.places.count)件")
                    }
                }
            }
            .navigationTitle("プランを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveChanges()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
    }

    private func saveChanges() {
        isSaving = true

        var updatedPlan = plan
        updatedPlan.title = title.trimmingCharacters(in: .whitespaces)
        updatedPlan.startDate = startDate
        updatedPlan.endDate = endDate
        updatedPlan.planType = planType

        if planType == .daily {
            updatedPlan.time = time
            let trimmedDesc = description.trimmingCharacters(in: .whitespaces)
            updatedPlan.description = trimmedDesc.isEmpty ? nil : trimmedDesc
            let trimmedLink = linkURL.trimmingCharacters(in: .whitespaces)
            updatedPlan.linkURL = trimmedLink.isEmpty ? nil : trimmedLink
        } else {
            updatedPlan.time = nil
            updatedPlan.description = nil
            updatedPlan.linkURL = nil
        }

        viewModel.update(updatedPlan)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSaving = false
            dismiss()
        }
    }
}
