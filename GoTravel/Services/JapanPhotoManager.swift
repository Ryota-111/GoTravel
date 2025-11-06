import Foundation
import UIKit

// MARK: - Japan Photo Manager
class JapanPhotoManager {
    static let shared = JapanPhotoManager()

    private let fileManager = FileManager.default
    private let userDefaultsKey = "JapanPhotoPrefectures"

    private var photosDirectory: URL {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        let photosDir = documentsDirectory.appendingPathComponent("JapanPhotos")

        if !fileManager.fileExists(atPath: photosDir.path) {
            try? fileManager.createDirectory(at: photosDir, withIntermediateDirectories: true)
        }

        return photosDir
    }

    // MARK: - Save Photo
    func savePhoto(_ image: UIImage, for prefecture: String) -> Bool {
        let fileName = "\(prefecture).jpg"
        let fileURL = photosDirectory.appendingPathComponent(fileName)

        guard let data = image.jpegData(compressionQuality: 0.8) else {
            return false
        }

        do {
            try data.write(to: fileURL)
            savePrefectureToList(prefecture)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Load Photo
    func loadPhoto(for prefecture: String) -> UIImage? {
        let fileName = "\(prefecture).jpg"
        let fileURL = photosDirectory.appendingPathComponent(fileName)

        guard let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }

        return image
    }

    // MARK: - Delete Photo
    func deletePhoto(for prefecture: String) -> Bool {
        let fileName = "\(prefecture).jpg"
        let fileURL = photosDirectory.appendingPathComponent(fileName)

        do {
            try fileManager.removeItem(at: fileURL)
            removePrefectureFromList(prefecture)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Load All Photos
    func loadAllPhotos() -> [String: UIImage] {
        var photos: [String: UIImage] = [:]
        let savedPrefectures = getSavedPrefectures()

        for prefecture in savedPrefectures {
            if let image = loadPhoto(for: prefecture) {
                photos[prefecture] = image
            }
        }

        return photos
    }

    // MARK: - Prefecture List Management
    private func savePrefectureToList(_ prefecture: String) {
        var prefectures = getSavedPrefectures()
        if !prefectures.contains(prefecture) {
            prefectures.append(prefecture)
            UserDefaults.standard.set(prefectures, forKey: userDefaultsKey)
        }
    }

    private func removePrefectureFromList(_ prefecture: String) {
        var prefectures = getSavedPrefectures()
        prefectures.removeAll { $0 == prefecture }
        UserDefaults.standard.set(prefectures, forKey: userDefaultsKey)
    }

    private func getSavedPrefectures() -> [String] {
        return UserDefaults.standard.stringArray(forKey: userDefaultsKey) ?? []
    }
}
