import SwiftUI

struct SaveAsVisitedView: View {
    let plannedPlace: PlannedPlace
    let travelPlanTitle: String
    let travelPlanId: String?

    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var notes: String = ""
    @State private var selectedCategory: PlaceCategory = .other
    @State private var visitedDate: Date = Date()
    @State private var isSaving = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("場所情報")) {
                    HStack {
                        Text("場所名")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(plannedPlace.name)
                    }

                    if let address = plannedPlace.address {
                        HStack {
                            Text("住所")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(address)
                                .multilineTextAlignment(.trailing)
                                .font(.caption)
                        }
                    }
                }

                Section(header: Text("訪問情報")) {
                    HStack {
                        Text("旅行タイトル")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(travelPlanTitle)
                    }

                    DatePicker("訪問日", selection: $visitedDate, displayedComponents: .date)
                }

                Section(header: Text("カテゴリー")) {
                    Picker("カテゴリー", selection: $selectedCategory) {
                        ForEach(PlaceCategory.allCases) { category in
                            HStack {
                                Image(systemName: category.iconName)
                                Text(category.displayName)
                            }
                            .tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section(header: Text("メモ（任意）")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("訪問地として保存")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveVisitedPlace()
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    private func saveVisitedPlace() {
        guard let userId = authVM.userId else { return }
        isSaving = true

        let visitedPlace = VisitedPlace(
            from: plannedPlace,
            travelPlanTitle: travelPlanTitle,
            travelPlanId: travelPlanId,
            visitedDate: visitedDate,
            notes: notes.trimmingCharacters(in: .whitespaces).isEmpty ? nil : notes.trimmingCharacters(in: .whitespaces),
            category: selectedCategory
        )

        Task {
            do {
                _ = try await CloudKitService.shared.saveVisitedPlace(visitedPlace, userId: userId, image: nil)
                await MainActor.run {
                    isSaving = false
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    print("❌ Failed to save place: \(error)")
                }
            }
        }
    }
}
