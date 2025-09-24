import Foundation
import CoreLocation

struct VisitedPlace: Identifiable, Codable, Hashable {
    var id: String?
    var title: String
    var notes: String?
    var latitude: Double
    var longitude: Double
    var createdAt: Date
    var visitedAt: Date?
    var photoURL: String?
    var localPhotoFileName: String?
    var address: String?
    var tags: [String]?
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(id: String? = nil,
         title: String,
         notes: String? = nil,
         latitude: Double,
         longitude: Double,
         createdAt: Date = Date(),
         visitedAt: Date? = nil,
         photoURL: String? = nil,
         localPhotoFileName: String? = nil,
         address: String? = nil,
         tags: [String]? = nil) {
        self.id = id
        self.title = title
        self.notes = notes
        self.latitude = latitude
        self.longitude = longitude
        self.createdAt = createdAt
        self.visitedAt = visitedAt
        self.photoURL = photoURL
        self.localPhotoFileName = localPhotoFileName
        self.address = address
        self.tags = tags
    }
}
