import Foundation
import CoreLocation

struct PlannedPlace: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var latitude: Double
    var longitude: Double
    var address: String?
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
