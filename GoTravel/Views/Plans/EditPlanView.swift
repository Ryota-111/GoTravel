import SwiftUI
import MapKit

struct EditPlanView: View {
    let plan: Plan
    let viewModel: PlansViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var title: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var time: Date?
    @State private var description: String
    @State private var linkURL: String
    @State private var planType: PlanType
    @State private var places: [PlannedPlace]
    @State private var isSaving = false
    @State private var showAddPlace = false
    
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
        _places = State(initialValue: plan.places)
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
                
                if planType == .outing {
                    Section(header: HStack {
                        Text("訪問場所 (\(places.count))")
                        Spacer()
                        Button(action: {
                            showAddPlace = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                Text("追加")
                            }
                            .font(.subheadline)
                        }
                    }) {
                        Text("デバッグ: places.count = \(places.count)")
                            .font(.caption)
                            .foregroundColor(.orange)
                        
                        if places.isEmpty {
                            Text("場所が登録されていません")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        } else {
                            ForEach(places) { place in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(place.name)
                                            .font(.body)
                                        if let address = place.address {
                                            Text(address)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "mappin.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            .onDelete(perform: deletePlaces)
                        }
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
            .sheet(isPresented: $showAddPlace) {
                PlaceSearchView(onPlaceSelected: { selectedPlace in
                    addPlace(selectedPlace)
                    showAddPlace = false
                })
            }
        }
    }
    
    private func deletePlaces(at offsets: IndexSet) {
        places.remove(atOffsets: offsets)
    }
    
    private func addPlace(_ place: PlannedPlace) {
        places.append(place)
    }
    
    private func saveChanges() {
        isSaving = true
        
        var updatedPlan = plan
        updatedPlan.title = title.trimmingCharacters(in: .whitespaces)
        updatedPlan.startDate = startDate
        updatedPlan.endDate = endDate
        updatedPlan.planType = planType
        updatedPlan.places = places
        
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
        
        if let userId = authVM.userId {
            viewModel.update(updatedPlan, userId: userId)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSaving = false
            dismiss()
        }
    }
}
