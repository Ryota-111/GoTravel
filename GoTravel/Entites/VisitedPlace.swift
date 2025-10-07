import Foundation
import CoreLocation
import MapKit

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
    var category: PlaceCategory
    var travelPlanId: String?
    var userId: String?

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
         tags: [String]? = nil,
         category: PlaceCategory = .other,
         travelPlanId: String? = nil,
         userId: String? = nil) {
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
        self.category = category
        self.travelPlanId = travelPlanId
        self.userId = userId
    }

    // PlannedPlaceから作成
    init(from plannedPlace: PlannedPlace,
         travelPlanTitle: String,
         travelPlanId: String?,
         visitedDate: Date = Date(),
         notes: String? = nil,
         category: PlaceCategory = .other) {
        self.id = nil
        self.title = travelPlanTitle
        self.notes = notes
        self.latitude = plannedPlace.latitude
        self.longitude = plannedPlace.longitude
        self.createdAt = Date()
        self.visitedAt = visitedDate
        self.photoURL = nil
        self.localPhotoFileName = nil
        self.address = plannedPlace.address
        self.tags = nil
        self.category = category
        self.travelPlanId = travelPlanId
        self.userId = nil
    }
}

// MARK: - Place Category
enum PlaceCategory: String, CaseIterable, Codable, Identifiable {
    case hotel
    case camp
    case ship
    case flight
    case mountain
    case restaurant
    case sightseeing
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .hotel: return "Hotel"
        case .camp: return "Camp"
        case .ship: return "Ship"
        case .flight: return "Flight"
        case .mountain: return "Mountain"
        case .restaurant: return "Restaurant"
        case .sightseeing: return "Sightseeing"
        case .other: return "Other"
        }
    }

    var iconName: String {
        switch self {
        case .hotel: return "house.fill"
        case .camp: return "tent.fill"
        case .ship: return "ferry.fill"
        case .flight: return "airplane"
        case .mountain: return "mountain.2.fill"
        case .restaurant: return "fork.knife"
        case .sightseeing: return "photo.fill"
        case .other: return "mappin.circle.fill"
        }
    }
}
