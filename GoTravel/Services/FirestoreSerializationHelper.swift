import Foundation
import FirebaseFirestore
import SwiftUI

// MARK: - Firestore Serialization Helper
struct FirestoreSerializationHelper {

    // MARK: - Serialization Methods
    static func serializeDaySchedules(_ daySchedules: [DaySchedule]) -> [[String: Any]] {
        daySchedules.map { daySchedule in
            var dayDict: [String: Any] = [
                "id": daySchedule.id,
                "dayNumber": daySchedule.dayNumber,
                "date": Timestamp(date: daySchedule.date)
            ]

            let scheduleItemsArray: [[String: Any]] = daySchedule.scheduleItems.map { item in
                var itemDict: [String: Any] = [
                    "id": item.id,
                    "time": Timestamp(date: item.time),
                    "title": item.title
                ]
                if let location = item.location { itemDict["location"] = location }
                if let notes = item.notes { itemDict["notes"] = notes }
                if let latitude = item.latitude { itemDict["latitude"] = latitude }
                if let longitude = item.longitude { itemDict["longitude"] = longitude }
                if let cost = item.cost { itemDict["cost"] = cost }
                if let mapURL = item.mapURL { itemDict["mapURL"] = mapURL }
                if let linkURL = item.linkURL { itemDict["linkURL"] = linkURL }
                return itemDict
            }
            dayDict["scheduleItems"] = scheduleItemsArray

            return dayDict
        }
    }

    static func serializePackingItems(_ packingItems: [PackingItem]) -> [[String: Any]] {
        packingItems.map { item in
            [
                "id": item.id,
                "name": item.name,
                "isChecked": item.isChecked
            ]
        }
    }

    static func serializePlaces(_ places: [PlannedPlace]) -> [[String: Any]] {
        places.map { place in
            var placeDict: [String: Any] = [
                "id": place.id,
                "name": place.name,
                "latitude": place.latitude,
                "longitude": place.longitude
            ]
            if let address = place.address { placeDict["address"] = address }
            return placeDict
        }
    }

    // MARK: - Parsing Methods
    static func parseDaySchedule(from dayDict: [String: Any]) -> DaySchedule? {
        guard let id = dayDict["id"] as? String,
              let dayNumber = dayDict["dayNumber"] as? Int,
              let dateTimestamp = dayDict["date"] as? Timestamp else {
            return nil
        }

        var scheduleItems: [ScheduleItem] = []
        if let itemsArray = dayDict["scheduleItems"] as? [[String: Any]] {
            scheduleItems = itemsArray.compactMap { parseScheduleItem(from: $0) }
        }

        return DaySchedule(
            id: id,
            dayNumber: dayNumber,
            date: dateTimestamp.dateValue(),
            scheduleItems: scheduleItems
        )
    }

    static func parseScheduleItem(from itemDict: [String: Any]) -> ScheduleItem? {
        guard let itemId = itemDict["id"] as? String,
              let timeTimestamp = itemDict["time"] as? Timestamp,
              let title = itemDict["title"] as? String else {
            return nil
        }
        let location = itemDict["location"] as? String
        let notes = itemDict["notes"] as? String
        let latitude = itemDict["latitude"] as? Double
        let longitude = itemDict["longitude"] as? Double
        let cost = itemDict["cost"] as? Double
        let mapURL = itemDict["mapURL"] as? String
        let linkURL = itemDict["linkURL"] as? String

        return ScheduleItem(
            id: itemId,
            time: timeTimestamp.dateValue(),
            title: title,
            location: location,
            notes: notes,
            latitude: latitude,
            longitude: longitude,
            cost: cost,
            mapURL: mapURL,
            linkURL: linkURL
        )
    }

    static func parsePackingItem(from itemDict: [String: Any]) -> PackingItem? {
        guard let id = itemDict["id"] as? String,
              let name = itemDict["name"] as? String,
              let isChecked = itemDict["isChecked"] as? Bool else {
            return nil
        }

        return PackingItem(id: id, name: name, isChecked: isChecked)
    }

    static func parsePlannedPlace(from placeDict: [String: Any]) -> PlannedPlace? {
        guard let name = placeDict["name"] as? String,
              let latitude = placeDict["latitude"] as? Double,
              let longitude = placeDict["longitude"] as? Double else {
            return nil
        }

        let address = placeDict["address"] as? String
        let id = placeDict["id"] as? String ?? UUID().uuidString

        return PlannedPlace(
            id: id,
            name: name,
            latitude: latitude,
            longitude: longitude,
            address: address
        )
    }
}
