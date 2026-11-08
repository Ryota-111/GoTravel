import Foundation
import Combine
import UIKit
import CoreLocation

final class SavePlaceViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var notes: String = ""
    @Published var linkURL: String = ""
    @Published var image: UIImage?
    @Published var visitedAt: Date? = nil
    /// 地図の検索で選んだ場所の住所。無ければ保存するときに位置から調べる（3.5。前は住所を残していなかった）
    var address: String?
    @Published var categoryId: String = "hotel"
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

        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let link = linkURL.trimmingCharacters(in: .whitespacesAndNewlines)

        // Core Dataに保存

        Task { @MainActor in
            var address = self.address
            if address?.isEmpty ?? true {
                address = await AddressLookup.address(latitude: coord.latitude, longitude: coord.longitude)
            }
            let place = VisitedPlace(
                title: title,
                notes: notes,
                latitude: coord.latitude,
                longitude: coord.longitude,
                createdAt: Date(),
                visitedAt: self.visitedAt,
                address: address,
                linkURL: link.isEmpty ? nil : link,
                categoryId: self.categoryId
            )
            placesVM.add(place, userId: userId, image: self.image)
            self.isSaving = false
            completion(.success(()))
        }
    }
}
