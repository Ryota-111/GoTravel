import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage
import UIKit
import CoreLocation

final class FirestoreService {
    static let shared = FirestoreService()

    private let db: Firestore
    private let storage: Storage
    
    private init() {
        db = Firestore.firestore()
        storage = Storage.storage()

        let settings = db.settings
        settings.cacheSettings = PersistentCacheSettings()
        db.settings = settings
    }
    
    private func placesCollectionRef(for uid: String) -> CollectionReference {
        db.collection("users").document(uid).collection("places")
    }
    
    func save(place: VisitedPlace, image: UIImage?, completion: @escaping (Result<VisitedPlace, Error>) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            DispatchQueue.main.async {
                completion(.failure(NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "ログインしていません"])))
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
                "createdAt": Timestamp(date: placeToSave.createdAt)
            ]
            
            if let notes = placeToSave.notes { dict["notes"] = notes }
            if let visited = placeToSave.visitedAt { dict["visitedAt"] = Timestamp(date: visited) }
            if let url = placeToSave.photoURL { dict["photoURL"] = url }
            if let local = localFileName { dict["localPhotoFileName"] = local }
            if let address = placeToSave.address { dict["address"] = address }
            if let tags = placeToSave.tags { dict["tags"] = tags }
            
            docRef.setData(dict) { err in
                DispatchQueue.main.async {
                    if let err = err {
                        completion(.failure(err))
                    } else {
                        var resultPlace = placeToSave
                        resultPlace.localPhotoFileName = localFileName
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
                completion(.failure(NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "ログインしていません"])))
            }
            return nil
        }
        
        return placesCollectionRef(for: uid)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    completion(.failure(error)); return
                }
                guard let docs = snapshot?.documents else {
                    completion(.success([])); return
                }
                let places: [VisitedPlace] = docs.compactMap { doc in
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
                    
                    return VisitedPlace(id: id,
                                        title: title,
                                        notes: notes,
                                        latitude: latitude,
                                        longitude: longitude,
                                        createdAt: createdAt,
                                        visitedAt: visitedAt,
                                        photoURL: photoURL,
                                        localPhotoFileName: localFileName,
                                        address: address,
                                        tags: tags)
                }
                completion(.success(places))
            }
    }
    
    func delete(place: VisitedPlace, completion: @escaping (Error?) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid,
              let id = place.id else { completion(NSError(domain: "Firestore", code: -1, userInfo: nil)); return }
        placesCollectionRef(for: uid).document(id).delete { err in
            completion(err)
        }
    }
    
    private func plansCollectionRef(for uid: String) -> CollectionReference {
        db.collection("users").document(uid).collection("plans")
    }

    func deletePlannedPlace(place: PlannedPlace, completion: @escaping (Error?) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid,
              let id = place.id else { completion(NSError(domain: "Firestore", code: -2, userInfo: nil)); return }
        plansCollectionRef(for: uid).document(id).delete { err in
            completion(err)
        }
    }

    // MARK: - TravelPlan Methods

    private func travelPlansCollectionRef(for uid: String) -> CollectionReference {
        db.collection("users").document(uid).collection("travelPlans")
    }

    func saveTravelPlan(_ plan: TravelPlan, completion: @escaping (Result<TravelPlan, Error>) -> Void) {
        print("🔵 FirestoreService: saveTravelPlan開始")
        guard let uid = Auth.auth().currentUser?.uid else {
            print("❌ FirestoreService: ユーザーが認証されていません")
            DispatchQueue.main.async {
                completion(.failure(NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "ログインしていません"])))
            }
            return
        }
        print("✅ FirestoreService: ユーザー認証OK - UID: \(uid)")

        let docRef = travelPlansCollectionRef(for: uid).document(plan.id ?? UUID().uuidString)
        var planToSave = plan
        planToSave.id = docRef.documentID
        planToSave.userId = uid

        print("📝 FirestoreService: ドキュメントID: \(docRef.documentID)")

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

        print("📦 FirestoreService: 保存するデータ: \(dict)")

        docRef.setData(dict) { err in
            DispatchQueue.main.async {
                if let err = err {
                    print("❌ FirestoreService: 保存失敗 - \(err.localizedDescription)")
                    completion(.failure(err))
                } else {
                    print("✅ FirestoreService: Firestore保存成功")
                    completion(.success(planToSave))
                }
            }
        }
    }

    func observeTravelPlans(completion: @escaping (Result<[TravelPlan], Error>) -> Void) -> ListenerRegistration? {
        guard let uid = Auth.auth().currentUser?.uid else {
            DispatchQueue.main.async {
                completion(.failure(NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "ログインしていません"])))
            }
            return nil
        }

        return travelPlansCollectionRef(for: uid)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                guard let docs = snapshot?.documents else {
                    completion(.success([]))
                    return
                }

                let plans: [TravelPlan] = docs.compactMap { doc in
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

                    return TravelPlan(
                        id: id,
                        title: title,
                        startDate: startDate,
                        endDate: endDate,
                        destination: destination,
                        localImageFileName: localImageFileName,
                        cardColor: cardColor,
                        createdAt: createdAt,
                        userId: userId
                    )
                }
                completion(.success(plans))
            }
    }

    func deleteTravelPlan(_ plan: TravelPlan, completion: @escaping (Error?) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid,
              let id = plan.id else {
            completion(NSError(domain: "Firestore", code: -1, userInfo: nil))
            return
        }

        travelPlansCollectionRef(for: uid).document(id).delete { err in
            DispatchQueue.main.async {
                completion(err)
            }
        }
    }

    // MARK: - Local Image Storage Methods

    func saveTravelPlanImageLocally(_ image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        print("💾 FirestoreService: ローカル画像保存開始")

        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            print("❌ FirestoreService: 画像データの変換に失敗")
            completion(.failure(NSError(domain: "Image", code: -1, userInfo: [NSLocalizedDescriptionKey: "画像データの変換に失敗しました"])))
            return
        }

        let fileName = "travelPlan_\(UUID().uuidString).jpg"

        do {
            try FileManager.saveImageDataToDocuments(data: imageData, named: fileName)
            print("✅ FirestoreService: ローカル画像保存成功 - \(fileName)")
            completion(.success(fileName))
        } catch {
            print("❌ FirestoreService: ローカル画像保存失敗 - \(error.localizedDescription)")
            completion(.failure(error))
        }
    }

    func deleteTravelPlanImageLocally(_ fileName: String) {
        print("🗑️ FirestoreService: ローカル画像削除 - \(fileName)")
        do {
            try FileManager.removeDocumentFile(named: fileName)
            print("✅ FirestoreService: ローカル画像削除成功")
        } catch {
            print("❌ FirestoreService: ローカル画像削除失敗 - \(error.localizedDescription)")
        }
    }

    // MARK: - Plan Methods (予定計画)

    private func plansCollectionRefV2(for uid: String) -> CollectionReference {
        db.collection("users").document(uid).collection("plans")
    }

    func savePlan(_ plan: Plan, completion: @escaping (Result<Plan, Error>) -> Void) {
        print("🔵 FirestoreService: savePlan開始")
        guard let uid = Auth.auth().currentUser?.uid else {
            print("❌ FirestoreService: ユーザーが認証されていません")
            DispatchQueue.main.async {
                completion(.failure(NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "ログインしていません"])))
            }
            return
        }
        print("✅ FirestoreService: ユーザー認証OK - UID: \(uid)")

        let docRef = plansCollectionRefV2(for: uid).document(plan.id)
        var planToSave = plan
        planToSave.id = docRef.documentID
        planToSave.userId = uid

        print("📝 FirestoreService: ドキュメントID: \(docRef.documentID)")

        var dict: [String: Any] = [
            "title": planToSave.title,
            "startDate": Timestamp(date: planToSave.startDate),
            "endDate": Timestamp(date: planToSave.endDate),
            "createdAt": Timestamp(date: planToSave.createdAt),
            "userId": uid
        ]

        // placesの配列をマップ形式に変換
        let placesArray: [[String: Any]] = planToSave.places.map { place in
            var placeDict: [String: Any] = [
                "name": place.name,
                "latitude": place.latitude,
                "longitude": place.longitude
            ]
            if let address = place.address { placeDict["address"] = address }
            if let id = place.id { placeDict["id"] = id }
            return placeDict
        }
        dict["places"] = placesArray

        if let localImageFileName = planToSave.localImageFileName { dict["localImageFileName"] = localImageFileName }
        if let colorHex = planToSave.cardColorHex { dict["cardColorHex"] = colorHex }

        print("📦 FirestoreService: 保存するデータ: \(dict)")

        docRef.setData(dict) { err in
            DispatchQueue.main.async {
                if let err = err {
                    print("❌ FirestoreService: 保存失敗 - \(err.localizedDescription)")
                    completion(.failure(err))
                } else {
                    print("✅ FirestoreService: Firestore保存成功")
                    completion(.success(planToSave))
                }
            }
        }
    }

    func observePlans(completion: @escaping (Result<[Plan], Error>) -> Void) -> ListenerRegistration? {
        guard let uid = Auth.auth().currentUser?.uid else {
            DispatchQueue.main.async {
                completion(.failure(NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "ログインしていません"])))
            }
            return nil
        }

        return plansCollectionRefV2(for: uid)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                guard let docs = snapshot?.documents else {
                    completion(.success([]))
                    return
                }

                let plans: [Plan] = docs.compactMap { doc in
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

                    // placesの配列を取得
                    var places: [PlannedPlace] = []
                    if let placesArray = d["places"] as? [[String: Any]] {
                        places = placesArray.compactMap { placeDict in
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

                    return Plan(
                        id: id,
                        title: title,
                        startDate: startDate,
                        endDate: endDate,
                        places: places,
                        cardColor: cardColor,
                        localImageFileName: localImageFileName,
                        userId: userId,
                        createdAt: createdAt
                    )
                }
                completion(.success(plans))
            }
    }

    func deletePlan(_ plan: Plan, completion: @escaping (Error?) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(NSError(domain: "Firestore", code: -1, userInfo: nil))
            return
        }

        plansCollectionRefV2(for: uid).document(plan.id).delete { err in
            DispatchQueue.main.async {
                completion(err)
            }
        }
    }

    func savePlanImageLocally(_ image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        print("💾 FirestoreService: ローカル画像保存開始")

        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            print("❌ FirestoreService: 画像データの変換に失敗")
            completion(.failure(NSError(domain: "Image", code: -1, userInfo: [NSLocalizedDescriptionKey: "画像データの変換に失敗しました"])))
            return
        }

        let fileName = "plan_\(UUID().uuidString).jpg"

        do {
            try FileManager.saveImageDataToDocuments(data: imageData, named: fileName)
            print("✅ FirestoreService: ローカル画像保存成功 - \(fileName)")
            completion(.success(fileName))
        } catch {
            print("❌ FirestoreService: ローカル画像保存失敗 - \(error.localizedDescription)")
            completion(.failure(error))
        }
    }

}
