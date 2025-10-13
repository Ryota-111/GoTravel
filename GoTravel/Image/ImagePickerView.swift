import SwiftUI
import PhotosUI
import UIKit

struct ImagePickerView: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType = .photoLibrary
    @Binding var image: UIImage?
    @Environment(\.presentationMode) private var presentationMode

    func makeUIViewController(context: Context) -> UIViewController {
        if sourceType == .camera {
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.delegate = context.coordinator
            picker.allowsEditing = false
            return picker
        } else {
            var config = PHPickerConfiguration()
            config.filter = .images
            config.selectionLimit = 1
            let picker = PHPickerViewController(configuration: config)
            picker.delegate = context.coordinator
            return picker
        }
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) { }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, PHPickerViewControllerDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePickerView
        init(_ parent: ImagePickerView) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.presentationMode.wrappedValue.dismiss()
            print("📱 ImagePickerView: PHPicker終了 - results count: \(results.count)")
            guard let item = results.first else {
                print("⚠️ ImagePickerView: 画像が選択されませんでした")
                return
            }
            if item.itemProvider.canLoadObject(ofClass: UIImage.self) {
                item.itemProvider.loadObject(ofClass: UIImage.self) { (obj, error) in
                    if let img = obj as? UIImage {
                        print("✅ ImagePickerView: 画像ロード成功 - サイズ: \(img.size)")
                        DispatchQueue.main.async {
                            self.parent.image = img
                            print("🔄 ImagePickerView: バインディングに画像を設定")
                        }
                    } else {
                        print("❌ ImagePickerView: 画像ロード失敗 - error: \(error?.localizedDescription ?? "不明")")
                    }
                }
            }
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            parent.presentationMode.wrappedValue.dismiss()
            if let img = info[.originalImage] as? UIImage {
                DispatchQueue.main.async { self.parent.image = img }
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}
