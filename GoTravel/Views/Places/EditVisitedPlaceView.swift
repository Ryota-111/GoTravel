import SwiftUI

struct EditVisitedPlaceView: View {
    let place: VisitedPlace
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var placesVM = PlacesViewModel()
    @Environment(\.presentationMode) var presentationMode

    @State private var title: String
    @State private var notes: String
    @State private var selectedCategoryId: String
    @State private var visitedDate: Date
    @State private var isSaving = false

    init(place: VisitedPlace) {
        self.place = place
        _title = State(initialValue: place.title)
        _notes = State(initialValue: place.notes ?? "")
        _selectedCategoryId = State(initialValue: place.categoryId)
        _visitedDate = State(initialValue: place.visitedAt ?? place.createdAt)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("基本情報")) {
                    TextField("タイトル", text: $title)

                    DatePicker("訪問日", selection: $visitedDate, displayedComponents: .date)
                }

                Section(header: Text("カテゴリー")) {
                    Picker("カテゴリー", selection: $selectedCategoryId) {
                        ForEach(PlaceCategoryManager.shared.categories) { category in
                            HStack {
                                Image(systemName: category.icon)
                                Text(category.name)
                            }
                            .tag(category.id)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section(header: Text("メモ")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }

                Section(header: Text("場所情報")) {
                    if let address = place.address {
                        HStack {
                            Text("住所")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(address)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
            }
            .navigationTitle("訪問地を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        presentationMode.wrappedValue.dismiss()
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
        guard let userId = authVM.userId else { return }
        isSaving = true

        var updatedPlace = place
        updatedPlace.title = title.trimmingCharacters(in: .whitespaces)
        updatedPlace.notes = notes.trimmingCharacters(in: .whitespaces).isEmpty ? nil : notes.trimmingCharacters(in: .whitespaces)
        updatedPlace.categoryId = selectedCategoryId
        updatedPlace.visitedAt = visitedDate

        Task { @MainActor in
            placesVM.update(updatedPlace, userId: userId, image: nil)
            isSaving = false
            presentationMode.wrappedValue.dismiss()
        }
    }
}
