import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage
import UIKit
import CoreLocation

// MARK: - Firestore Service
final class FirestoreService {

    // MARK: - Properties
    static let shared = FirestoreService()

    private let db: Firestore
    private let storage: Storage

    // MARK: - Initialization
    private init() {
        db = Firestore.firestore()
        storage = Storage.storage()

        let settings = db.settings
        settings.cacheSettings = PersistentCacheSettings()
        db.settings = settings
    }

    // MARK: - Collection References
    private func placesCollectionRef(for uid: String) -> CollectionReference {
        db.collection("users").document(uid).collection("places")
    }

    private func plansCollectionRef(for uid: String) -> CollectionReference {
        db.collection("users").document(uid).collection("plans")
    }

    private func travelPlansCollectionRef(for uid: String) -> CollectionReference {
        db.collection("users").document(uid).collection("travelPlans")
    }

    // MARK: - Visited Places Methods
    func save(place: VisitedPlace, image: UIImage?, completion: @escaping (Result<VisitedPlace, Error>) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            DispatchQueue.main.async {
                completion(.failure(APIClientError.authenticationError))
            }
            return
        }

        let docRef = placesCollectionRef(for: uid).document(place.id ?? UUID().uuidString)
        var placeToSave = place
        placeToSave.id = docRef.documentID

        func saveDocument(withLocalFileName localFileName: String?) {
            var dict: [String: Any] = [
                "title": placeToSave.title,
                "latitude": placeToSave.latitude,
                "longitude": placeToSave.longitude,
                "createdAt": Timestamp(date: placeToSave.createdAt),
                "category": placeToSave.category.rawValue,
                "userId": uid
            ]

            if let notes = placeToSave.notes { dict["notes"] = notes }
            if let visited = placeToSave.visitedAt { dict["visitedAt"] = Timestamp(date: visited) }
            if let url = placeToSave.photoURL { dict["photoURL"] = url }
            if let local = localFileName { dict["localPhotoFileName"] = local }
            if let address = placeToSave.address { dict["address"] = address }
            if let tags = placeToSave.tags { dict["tags"] = tags }
            if let travelPlanId = placeToSave.travelPlanId { dict["travelPlanId"] = travelPlanId }

            docRef.setData(dict) { err in
                DispatchQueue.main.async {
                    if let err = err {
                        completion(.failure(APIClientError.firestoreError(err)))
                    } else {
                        var resultPlace = placeToSave
                        resultPlace.localPhotoFileName = localFileName
                        resultPlace.userId = uid
                        completion(.success(resultPlace))
                    }
                }
            }
        }
        saveDocument(withLocalFileName: placeToSave.localPhotoFileName)
    }

    func observePlaces(completion: @escaping (Result<[VisitedPlace], Error>) -> Void) -> ListenerRegistration? {
        guard let uid = Auth.auth().currentUser?.uid else {
            DispatchQueue.main.async {
                completion(.failure(APIClientError.authenticationError))
            }
            return nil
        }

        return placesCollectionRef(for: uid)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    completion(.failure(APIClientError.firestoreError(error)))
                    return
                }
                guard let docs = snapshot?.documents else {
                    completion(.success([]))
                    return
                }
                let places: [VisitedPlace] = docs.compactMap { doc in
                    self.parseVisitedPlace(from: doc)
                }
                completion(.success(places))
            }
    }

    func update(place: VisitedPlace, completion: @escaping (Result<VisitedPlace, Error>) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid,
              let id = place.id else {
            DispatchQueue.main.async {
                completion(.failure(APIClientError.authenticationError))
            }
            return
        }

        var dict: [String: Any] = [
            "title": place.title,
            "latitude": place.latitude,
            "longitude": place.longitude,
            "category": place.category.rawValue,
            "userId": uid
        ]

        if let notes = place.notes { dict["notes"] = notes }
        if let visited = place.visitedAt { dict["visitedAt"] = Timestamp(date: visited) }
        if let photoURL = place.photoURL { dict["photoURL"] = photoURL }
        if let localFileName = place.localPhotoFileName { dict["localPhotoFileName"] = localFileName }
        if let address = place.address { dict["address"] = address }
        if let tags = place.tags { dict["tags"] = tags }
        if let travelPlanId = place.travelPlanId { dict["travelPlanId"] = travelPlanId }

        placesCollectionRef(for: uid).document(id).updateData(dict) { err in
            DispatchQueue.main.async {
                if let err = err {
                    completion(.failure(APIClientError.firestoreError(err)))
                } else {
                    completion(.success(place))
                }
            }
        }
    }

    func delete(place: VisitedPlace, completion: @escaping (Error?) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid,
              let id = place.id else {
            completion(APIClientError.authenticationError)
            return
        }
        placesCollectionRef(for: uid).document(id).delete { err in
            completion(err)
        }
    }

    func deletePlannedPlace(place: PlannedPlace, completion: @escaping (Error?) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid,
              let id = place.id else {
            completion(APIClientError.authenticationError)
            return
        }
        plansCollectionRef(for: uid).document(id).delete { err in
            completion(err)
        }
    }

    // MARK: - Travel Plan Methods
    func saveTravelPlan(_ plan: TravelPlan, completion: @escaping (Result<TravelPlan, Error>) -> Void) {
        print("FirestoreService: saveTravelPlan開始")
        guard let uid = Auth.auth().currentUser?.uid else {
            print("FirestoreService: ユーザーが認証されていません")
            DispatchQueue.main.async {
                completion(.failure(APIClientError.authenticationError))
            }
            return
        }
        print("FirestoreService: ユーザー認証OK - UID: \(uid)")

        let docRef = travelPlansCollectionRef(for: uid).document(plan.id ?? UUID().uuidString)
        var planToSave = plan
        planToSave.id = docRef.documentID
        planToSave.userId = uid

        print("FirestoreService: ドキュメントID: \(docRef.documentID)")

        var dict: [String: Any] = [
            "title": planToSave.title,
            "startDate": Timestamp(date: planToSave.startDate),
            "endDate": Timestamp(date: planToSave.endDate),
            "destination": planToSave.destination,
            "createdAt": Timestamp(date: planToSave.createdAt),
            "userId": uid
        ]

        if let localImageFileName = planToSave.localImageFileName { dict["localImageFileName"] = localImageFileName }
        if let colorHex = planToSave.cardColorHex { dict["cardColorHex"] = colorHex }

        dict["daySchedules"] = FirestoreSerializationHelper.serializeDaySchedules(planToSave.daySchedules)
        dict["packingItems"] = FirestoreSerializationHelper.serializePackingItems(planToSave.packingItems)

        print("FirestoreService: 保存するデータ: \(dict)")

        docRef.setData(dict) { err in
            DispatchQueue.main.async {
                if let err = err {
                    print("FirestoreService: 保存失敗 - \(err.localizedDescription)")
                    completion(.failure(APIClientError.firestoreError(err)))
                } else {
                    print("FirestoreService: Firestore保存成功")
                    completion(.success(planToSave))
                }
            }
        }
    }

    func observeTravelPlans(completion: @escaping (Result<[TravelPlan], Error>) -> Void) -> ListenerRegistration? {
        guard let uid = Auth.auth().currentUser?.uid else {
            DispatchQueue.main.async {
                completion(.failure(APIClientError.authenticationError))
            }
            return nil
        }

        return travelPlansCollectionRef(for: uid)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    completion(.failure(APIClientError.firestoreError(error)))
                    return
                }
                guard let docs = snapshot?.documents else {
                    completion(.success([]))
                    return
                }

                let plans: [TravelPlan] = docs.compactMap { doc in
                    FirestoreParser.parseTravelPlan(from: doc)
                }
                completion(.success(plans))
            }
    }

    func deleteTravelPlan(_ plan: TravelPlan, completion: @escaping (Error?) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid,
              let id = plan.id else {
            completion(APIClientError.authenticationError)
            return
        }

        travelPlansCollectionRef(for: uid).document(id).delete { err in
            DispatchQueue.main.async {
                completion(err)
            }
        }
    }

    // MARK: - Plan Methods (予定計画)
    func savePlan(_ plan: Plan, completion: @escaping (Result<Plan, Error>) -> Void) {
        print("FirestoreService: savePlan開始")
        guard let uid = Auth.auth().currentUser?.uid else {
            print("FirestoreService: ユーザーが認証されていません")
            DispatchQueue.main.async {
                completion(.failure(APIClientError.authenticationError))
            }
            return
        }
        print("FirestoreService: ユーザー認証OK - UID: \(uid)")

        let docRef = plansCollectionRef(for: uid).document(plan.id)
        var planToSave = plan
        planToSave.id = docRef.documentID
        planToSave.userId = uid

        print("FirestoreService: ドキュメントID: \(docRef.documentID)")

        var dict: [String: Any] = [
            "title": planToSave.title,
            "startDate": Timestamp(date: planToSave.startDate),
            "endDate": Timestamp(date: planToSave.endDate),
            "createdAt": Timestamp(date: planToSave.createdAt),
            "userId": uid,
            "planType": planToSave.planType.rawValue
        ]

        dict["places"] = serializePlaces(planToSave.places)

        if let localImageFileName = planToSave.localImageFileName { dict["localImageFileName"] = localImageFileName }
        if let colorHex = planToSave.cardColorHex { dict["cardColorHex"] = colorHex }
        if let time = planToSave.time { dict["time"] = Timestamp(date: time) }
        if let description = planToSave.description { dict["description"] = description }
        if let linkURL = planToSave.linkURL { dict["linkURL"] = linkURL }

        print("FirestoreService: 保存するデータ: \(dict)")

        docRef.setData(dict) { err in
            DispatchQueue.main.async {
                if let err = err {
                    print("FirestoreService: 保存失敗 - \(err.localizedDescription)")
                    completion(.failure(APIClientError.firestoreError(err)))
                } else {
                    print("FirestoreService: Firestore保存成功")
                    completion(.success(planToSave))
                }
            }
        }
    }

    func observePlans(completion: @escaping (Result<[Plan], Error>) -> Void) -> ListenerRegistration? {
        guard let uid = Auth.auth().currentUser?.uid else {
            DispatchQueue.main.async {
                completion(.failure(APIClientError.authenticationError))
            }
            return nil
        }

        return plansCollectionRef(for: uid)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    completion(.failure(APIClientError.firestoreError(error)))
                    return
                }
                guard let docs = snapshot?.documents else {
                    completion(.success([]))
                    return
                }

                let plans: [Plan] = docs.compactMap { doc in
                    self.parsePlan(from: doc)
                }
                completion(.success(plans))
            }
    }

    func deletePlan(_ plan: Plan, completion: @escaping (Error?) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(APIClientError.authenticationError)
            return
        }

        plansCollectionRef(for: uid).document(plan.id).delete { err in
            DispatchQueue.main.async {
                completion(err)
            }
        }
    }

    // MARK: - Local Image Storage Methods
    func saveTravelPlanImageLocally(_ image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        print("FirestoreService: ローカル画像保存開始")

        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            print("FirestoreService: 画像データの変換に失敗")
            completion(.failure(APIClientError.parseError))
            return
        }

        let fileName = "travelPlan_\(UUID().uuidString).jpg"

        do {
            try FileManager.saveImageDataToDocuments(data: imageData, named: fileName)
            print("FirestoreService: ローカル画像保存成功 - \(fileName)")
            completion(.success(fileName))
        } catch {
            print("FirestoreService: ローカル画像保存失敗 - \(error.localizedDescription)")
            completion(.failure(APIClientError.storageError(error)))
        }
    }

    func deleteTravelPlanImageLocally(_ fileName: String) {
        print("FirestoreService: ローカル画像削除 - \(fileName)")
        do {
            try FileManager.removeDocumentFile(named: fileName)
            print("FirestoreService: ローカル画像削除成功")
        } catch {
            print("FirestoreService: ローカル画像削除失敗 - \(error.localizedDescription)")
        }
    }

    func savePlanImageLocally(_ image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        print("FirestoreService: ローカル画像保存開始")

        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            print("FirestoreService: 画像データの変換に失敗")
            completion(.failure(APIClientError.parseError))
            return
        }

        let fileName = "plan_\(UUID().uuidString).jpg"

        do {
            try FileManager.saveImageDataToDocuments(data: imageData, named: fileName)
            print("FirestoreService: ローカル画像保存成功 - \(fileName)")
            completion(.success(fileName))
        } catch {
            print("FirestoreService: ローカル画像保存失敗 - \(error.localizedDescription)")
            completion(.failure(APIClientError.storageError(error)))
        }
    }

    // MARK: - Serialization Helpers
    private func serializeDaySchedules(_ daySchedules: [DaySchedule]) -> [[String: Any]] {
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

    private func serializePackingItems(_ packingItems: [PackingItem]) -> [[String: Any]] {
        packingItems.map { item in
            [
                "id": item.id,
                "name": item.name,
                "isChecked": item.isChecked
            ]
        }
    }

    private func serializePlaces(_ places: [PlannedPlace]) -> [[String: Any]] {
        places.map { place in
            var placeDict: [String: Any] = [
                "name": place.name,
                "latitude": place.latitude,
                "longitude": place.longitude
            ]
            if let address = place.address { placeDict["address"] = address }
            if let id = place.id { placeDict["id"] = id }
            return placeDict
        }
    }

    // MARK: - Parsing Helpers
    private func parseVisitedPlace(from doc: QueryDocumentSnapshot) -> VisitedPlace? {
        let d = doc.data()
        let id = doc.documentID
        let title = d["title"] as? String ?? ""
        let notes = d["notes"] as? String
        let latitude = d["latitude"] as? Double ?? 0
        let longitude = d["longitude"] as? Double ?? 0
        var createdAt = Date()
        if let ts = d["createdAt"] as? Timestamp { createdAt = ts.dateValue() }
        var visitedAt: Date? = nil
        if let vts = d["visitedAt"] as? Timestamp { visitedAt = vts.dateValue() }
        let photoURL = d["photoURL"] as? String
        let localFileName = d["localPhotoFileName"] as? String
        let address = d["address"] as? String
        let tags = d["tags"] as? [String]
        let categoryStr = d["category"] as? String ?? "other"
        let category = PlaceCategory(rawValue: categoryStr) ?? .other
        let travelPlanId = d["travelPlanId"] as? String
        let userId = d["userId"] as? String

        return VisitedPlace(
            id: id,
            title: title,
            notes: notes,
            latitude: latitude,
            longitude: longitude,
            createdAt: createdAt,
            visitedAt: visitedAt,
            photoURL: photoURL,
            localPhotoFileName: localFileName,
            address: address,
            tags: tags,
            category: category,
            travelPlanId: travelPlanId,
            userId: userId
        )
    }

    private func parseTravelPlan(from doc: QueryDocumentSnapshot) -> TravelPlan? {
        let d = doc.data()
        let id = doc.documentID
        let title = d["title"] as? String ?? ""
        let destination = d["destination"] as? String ?? ""
        let localImageFileName = d["localImageFileName"] as? String
        let userId = d["userId"] as? String

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
            daySchedules = daySchedulesArray.compactMap { parseDaySchedule(from: $0) }
        }

        var packingItems: [PackingItem] = []
        if let packingItemsArray = d["packingItems"] as? [[String: Any]] {
            packingItems = packingItemsArray.compactMap { parsePackingItem(from: $0) }
        }

        return TravelPlan(
            id: id,
            title: title,
            startDate: startDate,
            endDate: endDate,
            destination: destination,
            localImageFileName: localImageFileName,
            cardColor: cardColor,
            createdAt: createdAt,
            userId: userId,
            daySchedules: daySchedules,
            packingItems: packingItems
        )
    }

    private func parseDaySchedule(from dayDict: [String: Any]) -> DaySchedule? {
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

    private func parseScheduleItem(from itemDict: [String: Any]) -> ScheduleItem? {
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

    private func parsePackingItem(from itemDict: [String: Any]) -> PackingItem? {
        guard let id = itemDict["id"] as? String,
              let name = itemDict["name"] as? String,
              let isChecked = itemDict["isChecked"] as? Bool else {
            return nil
        }

        return PackingItem(id: id, name: name, isChecked: isChecked)
    }

    private func parsePlan(from doc: QueryDocumentSnapshot) -> Plan? {
        let d = doc.data()
        let id = doc.documentID
        let title = d["title"] as? String ?? ""
        let localImageFileName = d["localImageFileName"] as? String
        let userId = d["userId"] as? String

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

        var places: [PlannedPlace] = []
        if let placesArray = d["places"] as? [[String: Any]] {
            places = placesArray.compactMap { parsePlannedPlace(from: $0) }
        }

        let planTypeStr = d["planType"] as? String ?? "outing"
        let planType = PlanType(rawValue: planTypeStr) ?? .outing

        var time: Date? = nil
        if let ts = d["time"] as? Timestamp { time = ts.dateValue() }

        let description = d["description"] as? String
        let linkURL = d["linkURL"] as? String

        return Plan(
            id: id,
            title: title,
            startDate: startDate,
            endDate: endDate,
            places: places,
            cardColor: cardColor,
            localImageFileName: localImageFileName,
            userId: userId,
            createdAt: createdAt,
            planType: planType,
            time: time,
            description: description,
            linkURL: linkURL
        )
    }

    private func parsePlannedPlace(from placeDict: [String: Any]) -> PlannedPlace? {
        guard let name = placeDict["name"] as? String,
              let latitude = placeDict["latitude"] as? Double,
              let longitude = placeDict["longitude"] as? Double else {
            return nil
        }
        let address = placeDict["address"] as? String
        let placeId = placeDict["id"] as? String
        return PlannedPlace(
            id: placeId,
            name: name,
            latitude: latitude,
            longitude: longitude,
            address: address
        )
    }
}
