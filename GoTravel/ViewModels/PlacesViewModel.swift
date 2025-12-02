import Foundation
import Combine
import MapKit
import UIKit
import CoreData

/// VisitedPlace管理用ViewModel（Core Data + CloudKit自動同期版）
final class PlacesViewModel: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var places: [VisitedPlace] = []
    @Published var placeImages: [String: UIImage] = [:] // placeId: image
    @Published var isLoading: Bool = false

    // MARK: - Private Properties
    private let context: NSManagedObjectContext
    private var fetchedResultsController: NSFetchedResultsController<VisitedPlaceEntity>?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    override init() {
        self.context = CoreDataManager.shared.viewContext
        super.init()
        print("🟡 [PlacesViewModel] Initialized with Core Data")
    }

    // MARK: - Core Data Fetch

    /// 指定ユーザーのVisitedPlaceを取得（Core Dataから）
    func setupFetchedResultsController(userId: String) {
        print("🟡 [PlacesViewModel] Setting up NSFetchedResultsController for userId: \(userId)")

        let fetchRequest: NSFetchRequest<VisitedPlaceEntity> = VisitedPlaceEntity.fetchRequest()

        // ユーザーIDでフィルタリング
        fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)

        // 訪問日で降順ソート
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "visitedAt", ascending: false)]

        fetchedResultsController = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )

        fetchedResultsController?.delegate = self

        do {
            try fetchedResultsController?.performFetch()
            updatePlaces()
            print("✅ [PlacesViewModel] Fetched \(places.count) places from Core Data")
        } catch {
            print("❌ [PlacesViewModel] Failed to fetch: \(error)")
        }
    }

    /// FetchedResultsControllerの結果をplaces配列に変換
    private func updatePlaces() {
        guard let entities = fetchedResultsController?.fetchedObjects else {
            places = []
            return
        }

        places = entities.map { $0.toVisitedPlace() }

        // ローカル画像を読み込み
        loadLocalImages()
    }

    /// ローカルファイルシステムから画像を読み込む
    private func loadLocalImages() {
        for place in places {
            guard let fileName = place.localPhotoFileName,
                  let placeId = place.id else { continue }

            if let image = FileManager.documentsImage(named: fileName) {
                placeImages[placeId] = image
            }
        }
    }

    // MARK: - CRUD Operations

    /// VisitedPlaceを追加（Core Dataに保存 → 自動的にCloudKitと同期）
    @MainActor
    func add(_ place: VisitedPlace, userId: String, image: UIImage? = nil) {
        print("🟡 [PlacesViewModel] Adding place to Core Data")

        var placeToSave = place
        placeToSave.userId = userId

        // 画像をローカルに保存
        if let image = image {
            let fileName = "visited_place_\(UUID().uuidString).jpg"
            if let imageData = image.jpegData(compressionQuality: 0.7) {
                do {
                    try FileManager.saveImageDataToDocuments(data: imageData, named: fileName)
                    placeToSave.localPhotoFileName = fileName
                    print("✅ [PlacesViewModel] Image saved locally: \(fileName)")
                } catch {
                    print("❌ [PlacesViewModel] Failed to save image: \(error)")
                }
            }
        }

        // Core Dataに保存
        context.perform {
            _ = VisitedPlaceEntity.create(from: placeToSave, context: self.context)
            CoreDataManager.shared.saveContext()
            print("✅ [PlacesViewModel] Place saved to Core Data (will auto-sync to CloudKit)")
        }
    }

    /// VisitedPlaceを更新（Core Dataに保存 → 自動的にCloudKitと同期）
    @MainActor
    func update(_ place: VisitedPlace, userId: String, image: UIImage? = nil) {
        print("🟡 [PlacesViewModel] Updating place in Core Data")

        guard let placeId = place.id else {
            print("❌ [PlacesViewModel] Place has no ID")
            return
        }

        var placeToSave = place
        placeToSave.userId = userId

        // 画像を保存（新しい画像がある場合）
        if let image = image {
            // 古い画像を削除
            if let oldFileName = place.localPhotoFileName {
                try? FileManager.removeDocumentFile(named: oldFileName)
            }

            // 新しい画像を保存
            let fileName = "visited_place_\(UUID().uuidString).jpg"
            if let imageData = image.jpegData(compressionQuality: 0.7) {
                do {
                    try FileManager.saveImageDataToDocuments(data: imageData, named: fileName)
                    placeToSave.localPhotoFileName = fileName
                    print("✅ [PlacesViewModel] New image saved locally: \(fileName)")
                } catch {
                    print("❌ [PlacesViewModel] Failed to save image: \(error)")
                }
            }
        }

        // Core Dataを更新
        context.perform {
            do {
                if let entity = try VisitedPlaceEntity.fetchById(id: placeId, context: self.context) {
                    entity.update(from: placeToSave)
                    CoreDataManager.shared.saveContext()
                    print("✅ [PlacesViewModel] Place updated in Core Data (will auto-sync to CloudKit)")
                }
            } catch {
                print("❌ [PlacesViewModel] Failed to fetch entity for update: \(error)")
            }
        }
    }

    /// VisitedPlaceを削除（Core Dataから削除 → 自動的にCloudKitと同期）
    @MainActor
    func delete(_ place: VisitedPlace, userId: String? = nil) {
        print("🟡 [PlacesViewModel] Deleting place from Core Data")

        guard let placeId = place.id else {
            print("❌ [PlacesViewModel] Place has no ID")
            return
        }

        // ローカル画像を削除
        if let fileName = place.localPhotoFileName {
            try? FileManager.removeDocumentFile(named: fileName)
        }

        // Core Dataから削除
        context.perform {
            do {
                if let entity = try VisitedPlaceEntity.fetchById(id: placeId, context: self.context) {
                    self.context.delete(entity)
                    CoreDataManager.shared.saveContext()
                    print("✅ [PlacesViewModel] Place deleted from Core Data (will auto-sync to CloudKit)")
                }
            } catch {
                print("❌ [PlacesViewModel] Failed to delete: \(error)")
            }
        }
    }

    // MARK: - Image Loading

    /// 特定のVisitedPlaceの画像を取得（ローカルファイルから）
    func loadImage(for placeId: String) async -> UIImage? {
        // キャッシュをチェック
        if let cached = placeImages[placeId] {
            return cached
        }

        // プレイスを検索して画像ファイル名を取得
        guard let place = places.first(where: { $0.id == placeId }),
              let fileName = place.localPhotoFileName else {
            return nil
        }

        // ローカルファイルから読み込み
        if let image = FileManager.documentsImage(named: fileName) {
            await MainActor.run {
                self.placeImages[placeId] = image
            }
            return image
        }

        return nil
    }
}

// MARK: - NSFetchedResultsControllerDelegate

extension PlacesViewModel: NSFetchedResultsControllerDelegate {
    /// Core Dataの変更を検知してUIを自動更新
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        print("🔄 [PlacesViewModel] Core Data changed, updating UI")
        DispatchQueue.main.async {
            self.updatePlaces()
        }
    }
}
