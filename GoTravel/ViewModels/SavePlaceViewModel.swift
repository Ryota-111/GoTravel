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

    func save(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let coord = coordinate else {
            completion(.failure(NSError(domain: "Save", code: -1, userInfo: [NSLocalizedDescriptionKey: "座標がありません"])))
            return
        }
        isSaving = true

        var place = VisitedPlace(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            latitude: coord.latitude,
            longitude: coord.longitude,
            createdAt: Date(),
            visitedAt: visitedAt,
            category: category
        )

        if let image = image, let data = image.jpegData(compressionQuality: 0.85) {
            let fileName = "place_\(UUID().uuidString).jpg"
            do {
                try FileManager.saveImageDataToDocuments(data: data, named: fileName)
                place.localPhotoFileName = fileName
            } catch {
            }
        }

        FirestoreService.shared.save(place: place, image: nil) { result in
            DispatchQueue.main.async {
                self.isSaving = false
                switch result {
                case .success(_):
                    completion(.success(()))
                case .failure(let err):
                    self.error = err.localizedDescription
                    completion(.failure(err))
                }
            }
        }
    }
}
