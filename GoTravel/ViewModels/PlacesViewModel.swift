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
}
