import Foundation
import UIKit
import Combine
import ImageIO

// MARK: - Japan Photo Manager
/// 日本全国フォトマップの写真は都道府県ごとに1枚だけ保持するため、
/// アルバムの photoFileNames ではなくここで独自に管理している
final class JapanPhotoManager: ObservableObject {
    static let shared = JapanPhotoManager()

    /// 写真が登録されている都道府県。アルバムカードの枚数表示もこれを見る
    @Published private(set) var savedPrefectures: [String] = []

    private let fileManager = FileManager.default
    private let userDefaultsKey = "JapanPhotoPrefectures"

    private let thumbnailMaxPixel: CGFloat = 400
    private let thumbnailCache = NSCache<NSString, UIImage>()

    private init() {
        savedPrefectures = getSavedPrefectures()
    }

    var photoCount: Int { savedPrefectures.count }

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
            // 同じ都道府県を撮り直した場合に古いサムネイルが残らないようにする
            thumbnailCache.removeObject(forKey: prefecture as NSString)
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

    // MARK: - Thumbnails

    /// アルバムカードの表紙用。必要なサイズだけデコードしてキャッシュする
    func thumbnail(for prefecture: String) -> UIImage? {
        if let cached = thumbnailCache.object(forKey: prefecture as NSString) {
            return cached
        }

        let fileURL = photosDirectory.appendingPathComponent("\(prefecture).jpg")
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: thumbnailMaxPixel
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        let image = UIImage(cgImage: cgImage)
        thumbnailCache.setObject(image, forKey: prefecture as NSString)
        return image
    }

    /// 直近に登録された順にサムネイルを返す
    func recentThumbnails(limit: Int = 4) -> [UIImage] {
        Array(savedPrefectures.suffix(limit)).compactMap { thumbnail(for: $0) }
    }

    // MARK: - Prefecture List Management
    private func savePrefectureToList(_ prefecture: String) {
        var prefectures = getSavedPrefectures()
        if !prefectures.contains(prefecture) {
            prefectures.append(prefecture)
            UserDefaults.standard.set(prefectures, forKey: userDefaultsKey)
        }
        publishPrefectures(prefectures)
    }

    private func removePrefectureFromList(_ prefecture: String) {
        var prefectures = getSavedPrefectures()
        prefectures.removeAll { $0 == prefecture }
        UserDefaults.standard.set(prefectures, forKey: userDefaultsKey)
        thumbnailCache.removeObject(forKey: prefecture as NSString)
        publishPrefectures(prefectures)
    }

    private func publishPrefectures(_ prefectures: [String]) {
        if Thread.isMainThread {
            savedPrefectures = prefectures
        } else {
            DispatchQueue.main.async { self.savedPrefectures = prefectures }
        }
    }

    private func getSavedPrefectures() -> [String] {
        return UserDefaults.standard.stringArray(forKey: userDefaultsKey) ?? []
    }
}
