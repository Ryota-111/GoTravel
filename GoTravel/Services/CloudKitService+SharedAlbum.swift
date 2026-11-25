import Foundation
import CloudKit
import os

// MARK: - 共有した旅行のアルバムの写真（3.8）
//
// レコードタイプ `SharedTripPhoto`、レコード ID は `tripphoto_<キー>`（`SharedAlbumPhotos`）。
// - `planId`（String・QUERYABLE）：どの旅行の写真か
// - `addedBy`（String・QUERYABLE）：載せた人。退会のときに自分の写真を引く
// - `photoKey`（String）：写真のキー
// - `image`（Asset）：長辺 2048px に縮めた JPEG
//
// **Production への反映が要る**（`docs/設計_アルバムの共有.md`）。書き込みの権限は `SharedTravelPlan` と同じ設定にする
// （持ち主が共有をやめたときに、ほかの人が載せた写真も消すため）
extension CloudKitService {

    private var albumPublicDB: CKDatabase {
        CKContainer(identifier: "iCloud.com.gmail.taismryotasis.Travory").publicCloudDatabase
    }

    private static let albumLogger = Logger(subsystem: "com.gmail.taismryotasis.Travory", category: "sharing")

    /// 載っている写真の一覧。写真そのものは降ろさない（一覧のたびに全部の写真を降ろさないため）
    func fetchSharedAlbumPhotos(planId: String) async throws -> [SharedAlbumPhotos.RemotePhoto] {
        try await queryAlbumPhotos(NSPredicate(format: "planId == %@", planId))
    }

    /// 写真を降ろす。降ろせたものだけ、キー → 一時ファイルの中身で返す
    func fetchSharedAlbumImages(keys: [String]) async throws -> [String: Data] {
        guard !keys.isEmpty else { return [:] }
        var images: [String: Data] = [:]
        // 一度にたくさん頼むと大きくなりすぎるので、少しずつ
        for chunk in keys.chunked(into: 10) {
            let ids = chunk.map { CKRecord.ID(recordName: SharedAlbumPhotos.recordName(key: $0)) }
            let results = try await albumPublicDB.records(for: ids, desiredKeys: ["image", "photoKey"])
            for (id, result) in results {
                guard let record = try? result.get(),
                      let asset = record["image"] as? CKAsset, let url = asset.fileURL,
                      let data = try? Data(contentsOf: url) else { continue }
                let key = record["photoKey"] as? String
                    ?? String(id.recordName.dropFirst("tripphoto_".count))
                images[key] = data
            }
        }
        return images
    }

    /// 写真を載せる。載せられたキーを返す
    func uploadSharedAlbumPhotos(_ photos: [(key: String, file: URL)], planId: String, userId: String) async throws -> [String] {
        var saved: [String] = []
        for chunk in photos.chunked(into: 5) {
            let records = chunk.map { photo -> CKRecord in
                let record = CKRecord(recordType: SharedAlbumPhotos.recordType,
                                      recordID: CKRecord.ID(recordName: SharedAlbumPhotos.recordName(key: photo.key)))
                record["planId"] = planId
                record["addedBy"] = userId
                record["photoKey"] = photo.key
                record["image"] = CKAsset(fileURL: photo.file)
                return record
            }
            let (results, _) = try await albumPublicDB.modifyRecords(saving: records, deleting: [],
                                                                     savePolicy: .allKeys)
            for (id, result) in results {
                switch result {
                case .success:
                    saved.append(String(id.recordName.dropFirst("tripphoto_".count)))
                case .failure(let error):
                    Self.albumLogger.error("アルバムの写真を載せられなかった id=\(id.recordName, privacy: .public) error=\(String(describing: error), privacy: .public)")
                }
            }
        }
        return saved
    }

    /// 写真を共有から消す（無いものは消せたことにする）
    func deleteSharedAlbumPhotos(keys: [String]) async throws {
        guard !keys.isEmpty else { return }
        for chunk in keys.chunked(into: 100) {
            let ids = chunk.map { CKRecord.ID(recordName: SharedAlbumPhotos.recordName(key: $0)) }
            let (_, results) = try await albumPublicDB.modifyRecords(saving: [], deleting: ids)
            for (id, result) in results {
                if case .failure(let error) = result,
                   (error as? CKError)?.code != .unknownItem {
                    Self.albumLogger.error("アルバムの写真を消せなかった id=\(id.recordName, privacy: .public) error=\(String(describing: error), privacy: .public)")
                }
            }
        }
    }

    /// その旅行に載っている写真をすべて消す（持ち主が共有をやめた・旅行を消したとき）
    func deleteAllSharedAlbumPhotos(planId: String) async throws {
        let keys = try await fetchSharedAlbumPhotos(planId: planId).map(\.key)
        try await deleteSharedAlbumPhotos(keys: keys)
    }

    /// 自分が載せた写真をすべて消す（退会のとき）
    func deleteSharedAlbumPhotos(addedBy userId: String) async throws {
        let keys = try await queryAlbumPhotos(NSPredicate(format: "addedBy == %@", userId)).map(\.key)
        try await deleteSharedAlbumPhotos(keys: keys)
    }

    private func queryAlbumPhotos(_ predicate: NSPredicate) async throws -> [SharedAlbumPhotos.RemotePhoto] {
        let query = CKQuery(recordType: SharedAlbumPhotos.recordType, predicate: predicate)
        let keys = ["planId", "addedBy", "photoKey"]
        var photos: [SharedAlbumPhotos.RemotePhoto] = []
        var results: [(CKRecord.ID, Result<CKRecord, Error>)]
        var cursor: CKQueryOperation.Cursor?
        do {
            (results, cursor) = try await albumPublicDB.records(matching: query, desiredKeys: keys, resultsLimit: 200)
        } catch let error as CKError where error.code == .unknownItem {
            // まだ誰も写真を載せていない（レコードタイプが無い）。0枚として進め、最初の1枚を載せられるようにする。
            // 載せないと Development にレコードタイプができず、ずっと失敗し続ける
            return []
        }
        while true {
            for (_, result) in results {
                guard let record = try? result.get(),
                      let key = record["photoKey"] as? String,
                      let addedBy = record["addedBy"] as? String else { continue }
                photos.append(.init(key: key, addedBy: addedBy, createdAt: record.creationDate))
            }
            guard let next = cursor else { break }
            (results, cursor) = try await albumPublicDB.records(continuingMatchFrom: next, desiredKeys: keys,
                                                                resultsLimit: 200)
        }
        return photos
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}
