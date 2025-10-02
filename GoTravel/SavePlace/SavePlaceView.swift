import SwiftUI
import MapKit

struct SavePlaceView: View {

    // MARK: - Properties
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var vm: SavePlaceViewModel
    @State private var showImagePicker: Bool = false
    @State private var showPhotoSourceActionSheet: Bool = false
    @State private var pickerSource: UIImagePickerController.SourceType = .photoLibrary

    // MARK: - Computed Properties
    private var isSaveDisabled: Bool {
        vm.title.trimmingCharacters(in: .whitespaces).isEmpty || vm.isSaving || vm.coordinate == nil
    }

    // MARK: - Body
    var body: some View {
        NavigationView {
            Form {
                placeInfoSection
                photoSection

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
            .actionSheet(isPresented: $showPhotoSourceActionSheet) {
                photoSourceActionSheet
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePickerView(sourceType: pickerSource, image: $vm.image)
            }
        }
    }

    // MARK: - View Components
    private var placeInfoSection: some View {
        Section(header: Text("場所")) {
            TextField("タイトル", text: $vm.title)
            TextField("思い出", text: $vm.notes)
            DatePicker("訪問日", selection: $vm.visitedAt, displayedComponents: .date)
        }
    }

    private var photoSection: some View {
        Section(header: Text("写真")) {
            if let image = vm.image {
                selectedPhotoView(image: image)
            } else {
                addPhotoButton
            }
        }
    }

    private func selectedPhotoView(image: UIImage) -> some View {
        VStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 240)
                .cornerRadius(8)
            HStack {
                replacePhotoButton
                Spacer()
                deletePhotoButton
            }
        }
    }

    private var addPhotoButton: some View {
        Button("写真を追加") {
            showPhotoSourceActionSheet = true
        }
    }

    private var replacePhotoButton: some View {
        Button("写真を差し替え") {
            showPhotoSourceActionSheet = true
        }
    }

    private var deletePhotoButton: some View {
        Button("削除") {
            vm.image = nil
        }
        .foregroundColor(.red)
    }

    private func errorSection(error: String) -> some View {
        Section {
            Text(error).foregroundColor(.red)
        }
    }

    private var saveButton: some View {
        Button(action: savePlace) {
            if vm.isSaving {
                ProgressView()
            } else {
                Text("保存")
            }
        }
        .disabled(isSaveDisabled)
    }

    private var cancelButton: some View {
        Button("キャンセル") {
            presentationMode.wrappedValue.dismiss()
        }
    }

    private var photoSourceActionSheet: ActionSheet {
        ActionSheet(title: Text("写真を選択"), buttons: [
            .default(Text("写真ライブラリ")) {
                selectPhotoSource(.photoLibrary)
            },
            .default(Text("カメラ")) {
                selectPhotoSource(.camera)
            },
            .cancel()
        ])
    }

    // MARK: - Actions
    private func savePlace() {
        vm.save { _ in
            presentationMode.wrappedValue.dismiss()
        }
    }

    private func selectPhotoSource(_ source: UIImagePickerController.SourceType) {
        pickerSource = source
        showImagePicker = true
    }
}

struct SavePlaceView_Previews: PreviewProvider {
    static var previews: some View {
        let vm = SavePlaceViewModel(coord: CLLocationCoordinate2D(latitude: 35.0, longitude: 139.0))
        return SavePlaceView(vm: vm)
    }
}
