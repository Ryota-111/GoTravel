import Foundation
import UIKit
import ImageIO

// MARK: - Japan Photo Manager
/// 日本全国フォトマップの写真のファイルを扱う。
///
/// **どの県にどの写真があるかは、ここでは持たない。** フォトマップはアルバム（種類 `.japan`）で、
/// 写真の並びはアルバムの `photoFileNames` にある（`docs/設計_フォトマップ.md`）。
/// ここはファイルの読み書きと、iCloud への預け入れ（Pro）だけを受け持つ。
///
/// 2.7 までは県ごとに1枚で、写真のある県の一覧を `UserDefaults` に持っていた。
/// その一覧は同期されず、入れ直すと地図が空に戻り得た。`legacyPrefectures` は
/// 移し替えのためだけに残している
final class JapanPhotoManager {
    static let shared = JapanPhotoManager()

    private let fileManager = FileManager.default
    private let legacyPrefecturesKey = "JapanPhotoPrefectures"

    private let thumbnailMaxPixel: CGFloat = 400
    private let thumbnailCache = NSCache<NSString, UIImage>()

    private init() {}

    private var photosDirectory: URL {
        PhotoFolder.japanPhotos.url()
    }

    // MARK: - 書く・消す

    /// 写真を保存して、ファイル名を返す。書けなければ nil
    func store(_ image: UIImage, for prefecture: Prefecture) -> String? {
        guard let data = image.storedPhotoData() else { return nil }

        let fileName = PhotoMapFiles.newFileName(for: prefecture)
        do {
            try data.write(to: photosDirectory.appendingPathComponent(fileName))
        } catch {
            return nil
        }
        // 書き込めてから預ける。Pro を持っていなければ何もしない
        PhotoSyncService.shared.store(data: data, fileName: fileName, folder: .japanPhotos)
        return fileName
    }

    /// 写真のファイルを消す。ローカルに無くても預け先には在りうるので、必ず消しに行く
    func removeFile(_ fileName: String) {
        try? fileManager.removeItem(at: photosDirectory.appendingPathComponent(fileName))
        PhotoSyncService.shared.remove(fileName: fileName, folder: .japanPhotos)
        thumbnailCache.removeObject(forKey: fileName as NSString)
    }

    // MARK: - 読む

    func loadImage(_ fileName: String) -> UIImage? {
        // ファイルが無いときだけ、預けてあるものから書き戻す
        PhotoSyncService.shared.restoreIfMissing(fileName: fileName, folder: .japanPhotos)
        guard let data = try? Data(contentsOf: photosDirectory.appendingPathComponent(fileName)) else {
            return nil
        }
        return UIImage(data: data)
    }

    /// 一覧や地図用。必要なサイズだけデコードしてキャッシュする
    func thumbnail(_ fileName: String) -> UIImage? {
        if let cached = thumbnailCache.object(forKey: fileName as NSString) {
            return cached
        }

        let fileURL = photosDirectory.appendingPathComponent(fileName)
        PhotoSyncService.shared.restoreIfMissing(fileName: fileName, folder: .japanPhotos)

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
        thumbnailCache.setObject(image, forKey: fileName as NSString)
        return image
    }

    /// アルバムカードの表紙用。最近足した順
    func recentThumbnails(in album: Album, limit: Int = 4) -> [UIImage] {
        Array(album.photoFileNames.suffix(limit)).compactMap { thumbnail($0) }
    }

    // MARK: - 2.7 までのデータ

    /// 2.7 までの、写真のある県の一覧（`UserDefaults`）。移し替えのためだけに読む
    var legacyPrefectures: [String] {
        UserDefaults.standard.stringArray(forKey: legacyPrefecturesKey) ?? []
    }
}
