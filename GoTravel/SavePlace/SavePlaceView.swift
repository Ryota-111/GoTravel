import SwiftUI
import MapKit

struct SavePlaceView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var vm: SavePlaceViewModel

    // UI 用にローカルで管理するもの（画像ピッカー表示フラグ等）
    @State private var showImagePicker: Bool = false
    @State private var showPhotoSourceActionSheet: Bool = false
    @State private var pickerSource: UIImagePickerController.SourceType = .photoLibrary

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("場所")) {
                    TextField("タイトル", text: $vm.title)
                    TextField("メモ", text: $vm.notes)
                    DatePicker("訪問日", selection: $vm.visitedAt, displayedComponents: .date)
                }

                Section(header: Text("写真")) {
                    if let image = vm.image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 240)
                            .cornerRadius(8)
                        HStack {
                            Button("写真を差し替え") { showPhotoSourceActionSheet = true }
                            Spacer()
                            Button("削除") { vm.image = nil }
                                .foregroundColor(.red)
                        }
                    } else {
                        Button("写真を追加") { showPhotoSourceActionSheet = true }
                    }
                }

                if let error = vm.error {
                    Section { Text(error).foregroundColor(.red) }
                }
            }
            .navigationTitle("場所を保存")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        vm.save { _ in
                            presentationMode.wrappedValue.dismiss()
                        }
                    }) {
                        if vm.isSaving {
                            ProgressView()
                        } else {
                            Text("保存")
                        }
                    }
                    .disabled(vm.title.trimmingCharacters(in: .whitespaces).isEmpty || vm.isSaving || vm.coordinate == nil)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .actionSheet(isPresented: $showPhotoSourceActionSheet) {
                ActionSheet(title: Text("写真を選択"), buttons: [
                    .default(Text("写真ライブラリ")) {
                        pickerSource = .photoLibrary
                        showImagePicker = true
                    },
                    .default(Text("カメラ")) {
                        pickerSource = .camera
                        showImagePicker = true
                    },
                    .cancel()
                ])
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePickerView(sourceType: pickerSource, image: $vm.image)
            }
        }
    }
}

struct SavePlaceView_Previews: PreviewProvider {
    static var previews: some View {
        let vm = SavePlaceViewModel(coord: CLLocationCoordinate2D(latitude: 35.0, longitude: 139.0))
        return SavePlaceView(vm: vm)
    }
}
