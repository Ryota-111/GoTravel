import Foundation
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth
import UIKit
import CoreLocation

final class FirestoreService {
    static let shared = FirestoreService()

    private let db: Firestore
    private let storage: Storage

    private init() {
        // 注意: FirebaseApp.configure() は App 起動時に実行しておくこと。
        // 例: App の init() で FirebaseApp.configure() を呼ぶ
        db = Firestore.firestore()
        storage = Storage.storage()

        // 永続化（ローカルキャッシュ）を有効にする安全な設定方法
        // 既存の settings を取得して変更し、再代入します。
        var settings = db.settings
        settings.isPersistenceEnabled = true
        db.settings = settings

        // 必要であればキャッシュサイズをカスタマイズ
        // settings.cacheSizeBytes = FirestoreCacheSizeUnlimited
        // db.settings = settings
    }

    private func placesCollectionRef(for uid: String) -> CollectionReference {
        db.collection("users").document(uid).collection("places")
    }

    // 保存（画像があれば先に Storage にアップロードしてから Firestore に辞書で setData）
    func save(place: VisitedPlace, image: UIImage?, completion: @escaping (Result<VisitedPlace, Error>) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "ログインしていません"])))
            return
        }

        let docRef = placesCollectionRef(for: uid).document(place.id ?? UUID().uuidString)
        var placeToSave = place
        placeToSave.id = docRef.documentID

        func saveDocument(withPhotoURL photoURL: String?) {
            var dict: [String: Any] = [
                "title": placeToSave.title,
                "latitude": placeToSave.latitude,
                "longitude": placeToSave.longitude,
                "createdAt": Timestamp(date: placeToSave.createdAt)
            ]

            if let notes = placeToSave.notes { dict["notes"] = notes }
            if let visited = placeToSave.visitedAt { dict["visitedAt"] = Timestamp(date: visited) }
            if let photo = photoURL { dict["photoURL"] = photo }
            if let address = placeToSave.address { dict["address"] = address }
            if let tags = placeToSave.tags { dict["tags"] = tags }

            docRef.setData(dict) { err in
                if let err = err {
                    completion(.failure(err))
                } else {
                    completion(.success(placeToSave))
                }
            }
        }

        if let image = image, let data = image.jpegData(compressionQuality: 0.8) {
            let storageRef = storage.reference().child("users/\(uid)/places/\(placeToSave.id!)/photo.jpg")
            let meta = StorageMetadata()
            meta.contentType = "image/jpeg"
            storageRef.putData(data, metadata: meta) { _, error in
                if let error = error {
                    completion(.failure(error)); return
                }
                storageRef.downloadURL { url, error in
                    if let url = url {
                        saveDocument(withPhotoURL: url.absoluteString)
                    } else if let error = error {
                        completion(.failure(error))
                    } else {
                        saveDocument(withPhotoURL: nil)
                    }
                }
            }
        } else {
            saveDocument(withPhotoURL: placeToSave.photoURL)
        }
    }

    // 取得（リアルタイム監視）
    func observePlaces(completion: @escaping (Result<[VisitedPlace], Error>) -> Void) -> ListenerRegistration? {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "ログインしていません"])))
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
