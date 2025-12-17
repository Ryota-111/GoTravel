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
    let placesVM: PlacesViewModel

    init(coord: CLLocationCoordinate2D?, placesVM: PlacesViewModel) {
        self.coordinate = coord
        self.placesVM = placesVM
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

        // Core Dataに保存
        print("🟢 [SavePlaceViewModel] Starting Core Data save")
        print("🟢 [SavePlaceViewModel] - has image: \(image != nil)")

        Task { @MainActor in
            placesVM.add(place, userId: userId, image: self.image)
            print("✅ [SavePlaceViewModel] Core Data save completed")
            self.isSaving = false
            completion(.success(()))
        }
    }
}
