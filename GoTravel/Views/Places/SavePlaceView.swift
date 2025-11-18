import SwiftUI
import MapKit

struct SavePlaceView: View {

    // MARK: - Properties
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject var vm: SavePlaceViewModel

    // MARK: - Computed Properties
    private var isSaveDisabled: Bool {
        vm.title.trimmingCharacters(in: .whitespaces).isEmpty || vm.isSaving || vm.coordinate == nil
    }

    // MARK: - Body
    var body: some View {
        NavigationView {
            Form {
                placeInfoSection

                if let error = vm.error {
                    errorSection(error: error)
                }
            }
            .navigationTitle("場所を保存")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    saveButton
                }
                ToolbarItem(placement: .cancellationAction) {
                    cancelButton
                }
            }
        }
    }

    // MARK: - View Components
    private var placeInfoSection: some View {
        Section(header: Text("場所")) {
            TextField("タイトル", text: $vm.title)

            TextEditor(text: $vm.notes)
                .frame(minHeight: 80)

            DatePicker("訪問日", selection: $vm.visitedAt, displayedComponents: .date)

            Picker("カテゴリー", selection: $vm.category) {
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
    }

    private func errorSection(error: String) -> some View {
        Section {
            Text(error)
                .foregroundColor(.red)
        }
    }

    private var saveButton: some View {
        Button("保存") {
            print("🔴 [SavePlaceView] Save button pressed")
            print("🔴 [SavePlaceView] - authVM.userId: \(authVM.userId ?? "nil")")

            guard let userId = authVM.userId else {
                print("❌ [SavePlaceView] userId is nil, cannot save")
                return
            }

            print("🔴 [SavePlaceView] Calling vm.save with userId: \(userId)")
            vm.save(userId: userId) { result in
                switch result {
                case .success:
                    print("✅ [SavePlaceView] Save completed successfully")
                    presentationMode.wrappedValue.dismiss()
                case .failure(let error):
                    print("❌ [SavePlaceView] Save failed: \(error.localizedDescription)")
                    break
                }
            }
        }
        .disabled(isSaveDisabled)
    }

    private var cancelButton: some View {
        Button("キャンセル") {
            presentationMode.wrappedValue.dismiss()
        }
    }
}
