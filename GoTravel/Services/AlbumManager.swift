import Foundation
import SwiftUI
import Combine
import CoreData
import ImageIO
import UniformTypeIdentifiers

// MARK: - Album Manager
/// アルバムのメタ情報は Core Data（CloudKit 自動同期）で管理し、
/// 写真の実体は Documents に置いてファイル名だけを記録する。
/// これは VisitedPlace の画像と同じ方式。
final class AlbumManager: NSObject, ObservableObject {
    static let shared = AlbumManager()

    @Published var albums: [Album] = []

    private let fileManager = FileManager.default
    private let context: NSManagedObjectContext
    private var fetchedResultsController: NSFetchedResultsController<AlbumEntity>?
    private var currentUserId: String?

    /// 旧バージョンの UserDefaults 保存分を一度だけ Core Data へ移す
    private let legacyAlbumsKey = "SavedAlbums"
    private let migrationDoneKey = "AlbumsMigratedToCoreData_v1"

    /// サムネイルの一辺の最大ピクセル数（グリッド表示用）
    private let thumbnailMaxPixel: CGFloat = 400
    /// 保存時に長辺をこのサイズまで縮小する（原寸のままだと容量とメモリを圧迫する）
    private let storedImageMaxPixel: CGFloat = 2048

    private let thumbnailCache = NSCache<NSString, UIImage>()

    private var albumsDirectory: URL {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        let albumsDir = documentsDirectory.appendingPathComponent("Albums")

        if !fileManager.fileExists(atPath: albumsDir.path) {
            try? fileManager.createDirectory(at: albumsDir, withIntermediateDirectories: true)
        }

        return albumsDir
    }

    private override init() {
        self.context = CoreDataManager.shared.viewContext
        super.init()
        thumbnailCache.countLimit = 300
    }

    // MARK: - Setup

    /// ユーザーが確定したタイミングで呼ぶ。二重セットアップは行わない
    func setup(userId: String) {
        guard currentUserId != userId else { return }
        currentUserId = userId

        migrateLegacyAlbumsIfNeeded(userId: userId)
        setupFetchedResultsController(userId: userId)
        initializeDefaultAlbums(userId: userId)
    }

    private func setupFetchedResultsController(userId: String) {
        let request: NSFetchRequest<AlbumEntity> = AlbumEntity.fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@", userId)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]

        let controller = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        controller.delegate = self
        fetchedResultsController = controller

        do {
            try controller.performFetch()
            updateAlbums()
        } catch {
        }
    }

    private func updateAlbums() {
        albums = fetchedResultsController?.fetchedObjects?.map { $0.toAlbum() } ?? []
    }

    // MARK: - Migration

    private func migrateLegacyAlbumsIfNeeded(userId: String) {
        guard !UserDefaults.standard.bool(forKey: migrationDoneKey) else { return }

        // 移行対象がない場合だけ、ここで「済み」にして終える
        guard let data = UserDefaults.standard.data(forKey: legacyAlbumsKey) else {
            UserDefaults.standard.set(true, forKey: migrationDoneKey)
            return
        }

        // デコードに失敗した場合はフラグを立てず、次回の起動でやり直せるようにする
        guard let legacyAlbums = try? JSONDecoder().decode([Album].self, from: data) else {
            return
        }

        guard !legacyAlbums.isEmpty else {
            UserDefaults.standard.set(true, forKey: migrationDoneKey)
            return
        }

        for var album in legacyAlbums {
            album.userId = userId
            // 同じIDが既にある場合は移行済みとみなす
            if (try? AlbumEntity.fetchById(id: album.id, context: context)) != nil {
                continue
            }
            _ = AlbumEntity.create(from: album, context: context)
        }
        CoreDataManager.shared.saveContext()

        UserDefaults.standard.set(true, forKey: migrationDoneKey)

        // 移行が済んでから元データを消す（写真ファイルはそのまま使う）
        UserDefaults.standard.removeObject(forKey: legacyAlbumsKey)
    }

    // MARK: - Album Management

    func createAlbum(title: String, type: AlbumType = .custom, travelPlanId: String? = nil, isDefaultAlbum: Bool = false) {
        guard let userId = currentUserId else { return }

        let album = Album(
            title: title,
            coverColor: type.coverColor,
            icon: type.icon,
            travelPlanId: travelPlanId,
            isDefaultAlbum: isDefaultAlbum,
            type: type,
            userId: userId
        )
        _ = AlbumEntity.create(from: album, context: context)
        CoreDataManager.shared.saveContext()
    }

    func createTravelPlanAlbum(from travelPlan: TravelPlan) {
        guard let userId = currentUserId else { return }

        if let planId = travelPlan.id, albums.contains(where: { $0.travelPlanId == planId }) {
            return
        }

        let album = Album(
            title: travelPlan.title,
            coverColor: Album.resolvedPlanColor(for: travelPlan),
            icon: "airplane.departure",
            travelPlanId: travelPlan.id,
            isDefaultAlbum: false,
            type: .travel,
            userId: userId
        )
        _ = AlbumEntity.create(from: album, context: context)
        CoreDataManager.shared.saveContext()
    }

    /// 保存済みの内容を基に更新するので、古いスナップショットで他の変更を巻き戻さない
    private func mutateAlbum(id: String, _ mutate: (inout Album) -> Void) {
        guard let entity = try? AlbumEntity.fetchById(id: id, context: context) else { return }

        var album = entity.toAlbum()
        mutate(&album)
        album.updatedAt = Date()
        entity.update(from: album)
        CoreDataManager.shared.saveContext()
    }

    /// タイトル・色・アイコンの変更
    func updateAlbumDetails(id: String, title: String? = nil, coverColor: Color? = nil, icon: String? = nil) {
        mutateAlbum(id: id) { album in
            if let title, !title.trimmingCharacters(in: .whitespaces).isEmpty {
                album.title = title
            }
            if let coverColor {
                album.coverColor = coverColor
            }
            if let icon {
                album.icon = icon
            }
        }
    }

    func deleteAlbum(_ album: Album) {
        // 既定アルバムは削除させない
        guard !album.isDefaultAlbum else { return }

        for fileName in album.photoFileNames {
            deletePhotoFile(fileName: fileName)
        }

        if let entity = try? AlbumEntity.fetchById(id: album.id, context: context) {
            context.delete(entity)
            CoreDataManager.shared.saveContext()
        }
    }

    /// 旅行計画の削除に追従してアルバムも片付ける
    func deleteAlbums(forTravelPlanId travelPlanId: String) {
        let request: NSFetchRequest<AlbumEntity> = AlbumEntity.fetchRequest()
        request.predicate = NSPredicate(format: "travelPlanId == %@", travelPlanId)

        guard let entities = try? context.fetch(request) else { return }

        for entity in entities {
            for fileName in entity.toAlbum().photoFileNames {
                deletePhotoFile(fileName: fileName)
            }
            context.delete(entity)
        }
        CoreDataManager.shared.saveContext()
    }

    /// アカウント削除時に全アルバムと写真を消す
    func deleteAllData(userId: String) {
        let request: NSFetchRequest<AlbumEntity> = AlbumEntity.fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@", userId)

        guard let entities = try? context.fetch(request) else { return }

        for entity in entities {
            for fileName in entity.toAlbum().photoFileNames {
                deletePhotoFile(fileName: fileName)
            }
            context.delete(entity)
        }
        CoreDataManager.shared.saveContext()

        thumbnailCache.removeAllObjects()
        currentUserId = nil
        fetchedResultsController = nil
        albums = []
    }

    // MARK: - Photo Management

    func addPhotos(_ images: [UIImage], to albumId: String) {
        guard !images.isEmpty else { return }

        var newFileNames: [String] = []
        for image in images {
            let fileName = "\(albumId)_\(UUID().uuidString).jpg"
            if savePhoto(image, fileName: fileName) {
                newFileNames.append(fileName)
            }
        }

        guard !newFileNames.isEmpty else { return }

        mutateAlbum(id: albumId) { album in
            album.photoFileNames.append(contentsOf: newFileNames)
        }
    }

    func addPhoto(_ image: UIImage, to album: Album) {
        addPhotos([image], to: album.id)
    }

    func removePhoto(fileName: String, from album: Album) {
        removePhotos(fileNames: [fileName], from: album.id)
    }

    /// 複数枚をまとめて削除する（保存は1回で済ませる）
    func removePhotos(fileNames: [String], from albumId: String) {
        guard !fileNames.isEmpty else { return }

        for fileName in fileNames {
            deletePhotoFile(fileName: fileName)
        }

        let targets = Set(fileNames)
        mutateAlbum(id: albumId) { album in
            album.photoFileNames.removeAll { targets.contains($0) }
        }
    }

    /// 写真の並び替え
    func reorderPhotos(in albumId: String, from source: IndexSet, to destination: Int) {
        mutateAlbum(id: albumId) { album in
            album.photoFileNames.move(fromOffsets: source, toOffset: destination)
        }
    }

    /// 写真を別のアルバムへ移す
    func movePhoto(fileName: String, from sourceAlbumId: String, to destinationAlbumId: String) {
        guard sourceAlbumId != destinationAlbumId else { return }

        mutateAlbum(id: sourceAlbumId) { album in
            album.photoFileNames.removeAll { $0 == fileName }
        }
        mutateAlbum(id: destinationAlbumId) { album in
            album.photoFileNames.append(fileName)
        }
    }

    // MARK: - Photo Loading

    /// 原寸の画像。全画面表示など本当に必要な場面だけで使う
    func loadPhoto(fileName: String) -> UIImage? {
        let fileURL = albumsDirectory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    /// グリッド表示用の縮小画像。ImageIO で必要なサイズだけデコードし、結果をキャッシュする
    func thumbnail(fileName: String) -> UIImage? {
        if let cached = thumbnailCache.object(forKey: fileName as NSString) {
            return cached
        }

        let fileURL = albumsDirectory.appendingPathComponent(fileName)
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

    /// 先頭から指定枚数のサムネイルを返す（アルバムカードの表紙用）
    func recentThumbnails(from album: Album, limit: Int = 4) -> [UIImage] {
        Array(album.photoFileNames.suffix(limit)).compactMap { thumbnail(fileName: $0) }
    }

    // MARK: - Photo Files

    private func savePhoto(_ image: UIImage, fileName: String) -> Bool {
        let fileURL = albumsDirectory.appendingPathComponent(fileName)

        let resized = downscaled(image, maxPixel: storedImageMaxPixel)
        guard let data = resized.jpegData(compressionQuality: 0.8) else { return false }

        do {
            try data.write(to: fileURL)
            return true
        } catch {
            return false
        }
    }

    private func deletePhotoFile(fileName: String) {
        let fileURL = albumsDirectory.appendingPathComponent(fileName)
        try? fileManager.removeItem(at: fileURL)
        thumbnailCache.removeObject(forKey: fileName as NSString)
    }

    /// 長辺が maxPixel を超える場合だけ縮小する
    private func downscaled(_ image: UIImage, maxPixel: CGFloat) -> UIImage {
        let longestSide = max(image.size.width, image.size.height)
        guard longestSide > maxPixel else { return image }

        let scale = maxPixel / longestSide
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    // MARK: - Default Albums

    private func initializeDefaultAlbums(userId: String) {
        // 種別で判定するのでタイトルを変更されても重複作成されない
        guard !albums.contains(where: { $0.type == .japan }) else { return }
        createAlbum(title: AlbumType.japan.title, type: .japan, isDefaultAlbum: true)
    }
}

// MARK: - NSFetchedResultsControllerDelegate

extension AlbumManager: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        DispatchQueue.main.async {
            self.updateAlbums()
        }
    }
}
