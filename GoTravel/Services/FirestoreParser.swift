import Foundation
import FirebaseFirestore
import SwiftUI

// MARK: - Firestore Parser
struct FirestoreParser {

    // MARK: - TravelPlan Parsing
    static func parseTravelPlan(from doc: QueryDocumentSnapshot) -> TravelPlan? {
        let d = doc.data()
        let id = doc.documentID
        let title = d["title"] as? String ?? ""
        let destination = d["destination"] as? String ?? ""
        let localImageFileName = d["localImageFileName"] as? String
        let userId = d["userId"] as? String
        let latitude = d["latitude"] as? Double
        let longitude = d["longitude"] as? Double

        var startDate = Date()
        if let ts = d["startDate"] as? Timestamp { startDate = ts.dateValue() }

        var endDate = Date()
        if let ts = d["endDate"] as? Timestamp { endDate = ts.dateValue() }

        var createdAt = Date()
        if let ts = d["createdAt"] as? Timestamp { createdAt = ts.dateValue() }

        var cardColor: Color? = nil
        if let hex = d["cardColorHex"] as? String {
            cardColor = Color(hex: hex)
        }

        var daySchedules: [DaySchedule] = []
        if let daySchedulesArray = d["daySchedules"] as? [[String: Any]] {
            daySchedules = daySchedulesArray.compactMap { FirestoreSerializationHelper.parseDaySchedule(from: $0) }
        }

        var packingItems: [PackingItem] = []
        if let packingItemsArray = d["packingItems"] as? [[String: Any]] {
            packingItems = packingItemsArray.compactMap { FirestoreSerializationHelper.parsePackingItem(from: $0) }
        }

        // Parse sharing fields
        let isShared = d["isShared"] as? Bool ?? false
        let shareCode = d["shareCode"] as? String
        let sharedWith = d["sharedWith"] as? [String] ?? []
        let ownerId = d["ownerId"] as? String
        let lastEditedBy = d["lastEditedBy"] as? String

        var updatedAt = Date()
        if let ts = d["updatedAt"] as? Timestamp { updatedAt = ts.dateValue() }

        #if DEBUG
        print("📖 [Firestore] Parsing travel plan (QueryDocumentSnapshot):")
        print("   Destination: \(destination)")
        if let lat = latitude, let lon = longitude {
            print("   Parsed coordinates: (\(lat), \(lon))")
        } else {
            print("   Parsed coordinates: nil")
        }
        #endif

        return TravelPlan(
            id: id,
            title: title,
            startDate: startDate,
            endDate: endDate,
            destination: destination,
            latitude: latitude,
            longitude: longitude,
            localImageFileName: localImageFileName,
            cardColor: cardColor,
            createdAt: createdAt,
            userId: userId,
            daySchedules: daySchedules,
            packingItems: packingItems,
            isShared: isShared,
            shareCode: shareCode,
            sharedWith: sharedWith,
            ownerId: ownerId,
            lastEditedBy: lastEditedBy,
            updatedAt: updatedAt
        )
    }

    // Support DocumentSnapshot as well
    static func parseTravelPlan(from doc: DocumentSnapshot) -> TravelPlan? {
        guard let d = doc.data() else { return nil }
        let id = doc.documentID
        let title = d["title"] as? String ?? ""
        let destination = d["destination"] as? String ?? ""
        let localImageFileName = d["localImageFileName"] as? String
        let userId = d["userId"] as? String
        let latitude = d["latitude"] as? Double
        let longitude = d["longitude"] as? Double

        var startDate = Date()
        if let ts = d["startDate"] as? Timestamp { startDate = ts.dateValue() }

        var endDate = Date()
        if let ts = d["endDate"] as? Timestamp { endDate = ts.dateValue() }

        var createdAt = Date()
        if let ts = d["createdAt"] as? Timestamp { createdAt = ts.dateValue() }

        var cardColor: Color? = nil
        if let hex = d["cardColorHex"] as? String {
            cardColor = Color(hex: hex)
        }

        var daySchedules: [DaySchedule] = []
        if let daySchedulesArray = d["daySchedules"] as? [[String: Any]] {
            daySchedules = daySchedulesArray.compactMap { FirestoreSerializationHelper.parseDaySchedule(from: $0) }
        }

        var packingItems: [PackingItem] = []
        if let packingItemsArray = d["packingItems"] as? [[String: Any]] {
            packingItems = packingItemsArray.compactMap { FirestoreSerializationHelper.parsePackingItem(from: $0) }
        }

        // Parse sharing fields
        let isShared = d["isShared"] as? Bool ?? false
        let shareCode = d["shareCode"] as? String
        let sharedWith = d["sharedWith"] as? [String] ?? []
        let ownerId = d["ownerId"] as? String
        let lastEditedBy = d["lastEditedBy"] as? String

        var updatedAt = Date()
        if let ts = d["updatedAt"] as? Timestamp { updatedAt = ts.dateValue() }

        #if DEBUG
        print("📖 [Firestore] Parsing travel plan (DocumentSnapshot):")
        print("   Destination: \(destination)")
        if let lat = latitude, let lon = longitude {
            print("   Parsed coordinates: (\(lat), \(lon))")
        } else {
            print("   Parsed coordinates: nil")
        }
        #endif

        return TravelPlan(
            id: id,
            title: title,
            startDate: startDate,
            endDate: endDate,
            destination: destination,
            latitude: latitude,
            longitude: longitude,
            localImageFileName: localImageFileName,
            cardColor: cardColor,
            createdAt: createdAt,
            userId: userId,
            daySchedules: daySchedules,
            packingItems: packingItems,
            isShared: isShared,
            shareCode: shareCode,
            sharedWith: sharedWith,
            ownerId: ownerId,
            lastEditedBy: lastEditedBy,
            updatedAt: updatedAt
        )
    }

    // MARK: - Plan Parsing
    static func parsePlan(from doc: QueryDocumentSnapshot) -> Plan? {
        let d = doc.data()
        let id = doc.documentID
        let title = d["title"] as? String ?? ""
        let localImageFileName = d["localImageFileName"] as? String
        let description = d["description"] as? String
        let linkURL = d["linkURL"] as? String
        let userId = d["userId"] as? String

        var startDate = Date()
        if let ts = d["startDate"] as? Timestamp { startDate = ts.dateValue() }

        var endDate = Date()
        if let ts = d["endDate"] as? Timestamp { endDate = ts.dateValue() }

        var createdAt = Date()
        if let ts = d["createdAt"] as? Timestamp { createdAt = ts.dateValue() }

        var time: Date? = nil
        if let ts = d["time"] as? Timestamp { time = ts.dateValue() }

        let planTypeRaw = d["planType"] as? String ?? "outing"
        let planType = PlanType(rawValue: planTypeRaw) ?? .outing

        var places: [PlannedPlace] = []
        if let placesArray = d["places"] as? [[String: Any]] {
            places = placesArray.compactMap { FirestoreSerializationHelper.parsePlannedPlace(from: $0) }
        }

        return Plan(
            id: id,
            title: title,
            startDate: startDate,
            endDate: endDate,
            places: places,
            localImageFileName: localImageFileName,
            userId: userId,
            createdAt: createdAt,
            planType: planType,
            time: time,
            description: description,
            linkURL: linkURL
        )
    }

    // MARK: - VisitedPlace Parsing
    static func parseVisitedPlace(from doc: QueryDocumentSnapshot) -> VisitedPlace? {
        let d = doc.data()
        let id = doc.documentID
        let title = d["title"] as? String ?? ""
        let latitude = d["latitude"] as? Double ?? 0.0
        let longitude = d["longitude"] as? Double ?? 0.0
        let notes = d["notes"] as? String
        let photoURL = d["photoURL"] as? String
        let localPhotoFileName = d["localPhotoFileName"] as? String
        let address = d["address"] as? String
        let tags = d["tags"] as? [String]
        let userId = d["userId"] as? String
        let travelPlanId = d["travelPlanId"] as? String

        var createdAt = Date()
        if let ts = d["createdAt"] as? Timestamp { createdAt = ts.dateValue() }

        var visitedAt: Date? = nil
        if let ts = d["visitedAt"] as? Timestamp { visitedAt = ts.dateValue() }

        let categoryRaw = d["category"] as? String ?? "other"
        let category = PlaceCategory(rawValue: categoryRaw) ?? .other

        return VisitedPlace(
            id: id,
            title: title,
            notes: notes,
            latitude: latitude,
            longitude: longitude,
            createdAt: createdAt,
            visitedAt: visitedAt,
            photoURL: photoURL,
            localPhotoFileName: localPhotoFileName,
            address: address,
            tags: tags,
            category: category,
            travelPlanId: travelPlanId,
            userId: userId
        )
    }
}
