import Foundation
import Combine
import MapKit
import UIKit

final class PlacesViewModel: ObservableObject {
    @Published var places: [VisitedPlace] = []
    @Published var placeImages: [String: UIImage] = [:] // placeId: image

    private var refreshTask: Task<Void, Never>?

    init() {
        // CloudKitからのデータ取得は各Viewで明示的に呼び出す
    }

    deinit {
        refreshTask?.cancel()
    }

    // CloudKitからデータを取得（userIdが必要）
    func refreshFromCloudKit(userId: String? = nil) {
        print("🟡 [PlacesViewModel] Starting CloudKit refresh")
        print("🟡 [PlacesViewModel] - userId: \(userId ?? "nil")")
        refreshTask?.cancel()

        refreshTask = Task { @MainActor in
            guard let userId = userId else {
                print("❌ [PlacesViewModel] userId is nil, cannot fetch")
                return
            }

            do {
                print("🟡 [PlacesViewModel] Fetching from CloudKit...")
                let results = try await CloudKitService.shared.fetchVisitedPlaces(userId: userId)
                print("✅ [PlacesViewModel] Fetched \(results.count) places from CloudKit")

                // VisitedPlaceと画像を分離
                self.places = results.map { $0.place }

                // 画像をキャッシュ
                var imageCount = 0
                for result in results {
                    if let image = result.image, let placeId = result.place.id {
                        self.placeImages[placeId] = image
                        imageCount += 1
                    }
                }
                print("✅ [PlacesViewModel] Cached \(imageCount) images")
            } catch {
                print("❌ [PlacesViewModel] Failed to fetch from CloudKit: \(error)")
                print("❌ [PlacesViewModel] Error details: \(error.localizedDescription)")
                self.places = []
            }
        }
    }

    // 特定のPlaceの画像を取得
    func loadImage(for placeId: String) async -> UIImage? {
        // キャッシュをチェック
        if let cached = placeImages[placeId] {
            return cached
        }

        // CloudKitから取得
        do {
            let image = try await CloudKitService.shared.fetchVisitedPlaceImage(placeId: placeId)
            await MainActor.run {
                if let image = image {
                    self.placeImages[placeId] = image
                }
            }
            return image
        } catch {
            print("❌ [PlacesViewModel] Failed to load image: \(error)")
            return nil
        }
    }

    // MARK: - CRUD Operations

    @MainActor
    func add(_ place: VisitedPlace, userId: String, image: UIImage? = nil) {
        // 即座にローカルリストに追加（UI更新）
        places.append(place)
        print("✅ [PlacesViewModel] Added place to local list immediately")

        // バックグラウンドでCloudKitに保存
        Task {
            do {
                let savedPlace = try await CloudKitService.shared.saveVisitedPlace(place, userId: userId, image: image)
                print("✅ [PlacesViewModel] Place saved to CloudKit")

                // CloudKitから返された最新のプレイスでローカルを更新
                await MainActor.run {
                    if let index = self.places.firstIndex(where: { $0.id == place.id }) {
                        self.places[index] = savedPlace
                    }
                }
            } catch {
                print("❌ [PlacesViewModel] Failed to add place to CloudKit: \(error)")
                // エラーの場合、ローカルから削除
                await MainActor.run {
                    self.places.removeAll { $0.id == place.id }
                    if let placeId = place.id {
                        self.placeImages.removeValue(forKey: placeId)
                    }
                }
            }
        }
    }

    @MainActor
    func update(_ place: VisitedPlace, userId: String, image: UIImage? = nil) {
        // 即座にローカルリストを更新（UI更新）
        if let index = places.firstIndex(where: { $0.id == place.id }) {
            places[index] = place
        }
        print("✅ [PlacesViewModel] Updated place in local list immediately")

        // バックグラウンドでCloudKitに保存
        Task {
            do {
                let updatedPlace = try await CloudKitService.shared.saveVisitedPlace(place, userId: userId, image: image)
                print("✅ [PlacesViewModel] Place updated in CloudKit")

                // CloudKitから返された最新のプレイスでローカルを更新
                await MainActor.run {
                    if let index = self.places.firstIndex(where: { $0.id == place.id }) {
                        self.places[index] = updatedPlace
                    }
                }
            } catch {
                print("❌ [PlacesViewModel] Failed to update place in CloudKit: \(error)")
            }
        }
    }

    @MainActor
    func delete(_ place: VisitedPlace, userId: String? = nil) {
        // 即座にローカルリストから削除（UI更新）
        places.removeAll { $0.id == place.id }
        if let placeId = place.id {
            placeImages.removeValue(forKey: placeId)
        }
        print("✅ [PlacesViewModel] Removed place from local list immediately")

        // バックグラウンドでCloudKitから削除
        Task {
            do {
                if let placeId = place.id {
                    try await CloudKitService.shared.deleteVisitedPlace(placeId: placeId)
                    print("✅ [PlacesViewModel] Place deleted from CloudKit")
                }
            } catch {
                print("❌ [PlacesViewModel] Failed to delete place from CloudKit: \(error)")
                // エラーの場合、削除をロールバック
                if let userId = userId {
                    self.refreshFromCloudKit(userId: userId)
                }
            }
        }
    }
}
