import Foundation
import Combine
import UIKit
import CoreLocation

final class SavePlaceViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var notes: String = ""
    @Published var image: UIImage?
    @Published var visitedAt: Date = Date()
    @Published var category: PlaceCategory = .other
    @Published var isSaving: Bool = false
    @Published var error: String?

    let coordinate: CLLocationCoordinate2D?

    init(coord: CLLocationCoordinate2D?) {
        self.coordinate = coord
    }

    func save(userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let coord = coordinate else {
            completion(.failure(NSError(domain: "Save", code: -1, userInfo: [NSLocalizedDescriptionKey: "座標がありません"])))
            return
        }
        isSaving = true

        let place = VisitedPlace(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            latitude: coord.latitude,
            longitude: coord.longitude,
            createdAt: Date(),
            visitedAt: visitedAt,
            category: category
        )

        // CloudKitに保存
        print("🟢 [SavePlaceViewModel] Starting CloudKit save")
        print("🟢 [SavePlaceViewModel] - has image: \(image != nil)")

        Task {
            do {
                let savedPlace = try await CloudKitService.shared.saveVisitedPlace(
                    place,
                    userId: userId,
                    image: self.image
                )

                await MainActor.run {
                    print("✅ [SavePlaceViewModel] CloudKit save completed")
                    print("✅ [SavePlaceViewModel] - saved place ID: \(savedPlace.id ?? "nil")")
                    self.isSaving = false
                    completion(.success(()))
                }
            } catch {
                await MainActor.run {
                    print("❌ [SavePlaceViewModel] CloudKit save failed: \(error.localizedDescription)")
                    self.isSaving = false
                    self.error = error.localizedDescription
                    completion(.failure(error))
                }
            }
        }
    }
}
