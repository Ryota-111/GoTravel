import SwiftUI

struct EditVisitedPlaceView: View {
    let place: VisitedPlace
    @Environment(\.presentationMode) var presentationMode

    @State private var title: String
    @State private var notes: String
    @State private var selectedCategory: PlaceCategory
    @State private var visitedDate: Date
    @State private var isSaving = false

    init(place: VisitedPlace) {
        self.place = place
        _title = State(initialValue: place.title)
        _notes = State(initialValue: place.notes ?? "")
        _selectedCategory = State(initialValue: place.category)
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
        isSaving = true

        var updatedPlace = place
        updatedPlace.title = title.trimmingCharacters(in: .whitespaces)
        updatedPlace.notes = notes.trimmingCharacters(in: .whitespaces).isEmpty ? nil : notes.trimmingCharacters(in: .whitespaces)
        updatedPlace.category = selectedCategory
        updatedPlace.visitedAt = visitedDate

        FirestoreService.shared.update(place: updatedPlace) { result in
            DispatchQueue.main.async {
                isSaving = false
                switch result {
                case .success:
                    print("✅ 訪問地の更新成功")
                    presentationMode.wrappedValue.dismiss()
                case .failure(let error):
                    print("❌ 訪問地の更新エラー: \(error.localizedDescription)")
                }
            }
        }
    }
}
