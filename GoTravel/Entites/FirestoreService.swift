import Foundation
import FirebaseFirestore
import FirebaseAuth
import UIKit
import CoreLocation

final class FirestoreService {
    static let shared = FirestoreService()

    private let db: Firestore

    private init() {
        db = Firestore.firestore()

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
        guard let uid = Auth.auth().currentUser?.uid, let id = place.id else { completion(NSError(domain: "Firestore", code: -1, userInfo: nil)); return }
        placesCollectionRef(for: uid).document(id).delete { err in
            completion(err)
        }
    }
}
