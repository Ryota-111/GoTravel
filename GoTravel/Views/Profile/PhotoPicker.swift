import SwiftUI
import PhotosUI
import UIKit

struct PhotoPicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    var onComplete: (UIImage) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let parent: PhotoPicker
        init(_ parent: PhotoPicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true, completion: nil)
            guard let itemProvider = results.first?.itemProvider else { return }
            if itemProvider.canLoadObject(ofClass: UIImage.self) {
                itemProvider.loadObject(ofClass: UIImage.self) { reading, error in
                    if let image = reading as? UIImage {
                        DispatchQueue.main.async {
                            self.parent.onComplete(image)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Multi Photo Picker
/// 複数枚をまとめて選べるピッカー。選択順を保ったまま返す
struct MultiPhotoPicker: UIViewControllerRepresentable {
    var selectionLimit: Int = 0   // 0 は無制限
    var onComplete: ([UIImage]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = selectionLimit
        config.selection = .ordered
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let parent: MultiPhotoPicker
        init(_ parent: MultiPhotoPicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard !results.isEmpty else {
                parent.onComplete([])
                return
            }

            // 並列に読み込まれるため、選択順を保てるよう添字付きで受け取る
            var loaded: [Int: UIImage] = [:]
            let lock = NSLock()
            let group = DispatchGroup()

            for (index, result) in results.enumerated() {
                let itemProvider = result.itemProvider
                guard itemProvider.canLoadObject(ofClass: UIImage.self) else { continue }

                group.enter()
                itemProvider.loadObject(ofClass: UIImage.self) { reading, _ in
                    defer { group.leave() }
                    guard let image = reading as? UIImage else { return }
                    lock.lock()
                    loaded[index] = image
                    lock.unlock()
                }
            }

            group.notify(queue: .main) {
                let images = loaded.keys.sorted().compactMap { loaded[$0] }
                self.parent.onComplete(images)
            }
        }
    }
}
