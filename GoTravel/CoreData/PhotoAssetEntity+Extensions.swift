import Foundation
import CoreData

/// PhotoAssetEntity - Core Data Entity
///
/// 写真の実体を預かるための入れ物。**表示にはこれを使わない。**
///
/// 写真はこれまで端末の Documents にしか無く、機種変更で消えていた。
/// 実体をここに入れておくと、他のデータと同じ CloudKit 自動同期に相乗りして
/// 別の端末にも降りてくる。`imageData` は外部ストレージを許可してあるので、
/// 中身は sqlite の外のファイルに置かれ、CloudKit へは CKAsset として渡る。
///
/// 画面から読むときは今までどおりローカルのファイルを見る。
/// ファイルが無いときだけここから書き戻す（`PhotoSyncService.restoreIfMissing`）。
/// 表示のたびに Core Data を触らないのは、一覧のスクロールが重くなるため。
@objc(PhotoAssetEntity)
public class PhotoAssetEntity: NSManagedObject {
    @NSManaged public var id: String?
    /// 保存されているファイル名。ローカルのファイル名と同じものを入れる
    @NSManaged public var fileName: String?
    /// どのフォルダのファイルか。`PhotoFolder` の rawValue
    @NSManaged public var folder: String?
    @NSManaged public var imageData: Data?
    @NSManaged public var userId: String?
    @NSManaged public var createdAt: Date?
}

// MARK: - 保存先

/// 写真の置き場所。アプリには2か所ある
enum PhotoFolder: String {
    /// Documents 直下。旅行計画のカバー、場所の写真、プロフィール画像
    case documents
    /// Documents/Albums。アルバムの写真
    case albums
    /// Documents/JapanPhotos。日本全国フォトマップの、都道府県ごとの写真
    case japanPhotos
}

// MARK: - Fetch Request

extension PhotoAssetEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<PhotoAssetEntity> {
        return NSFetchRequest<PhotoAssetEntity>(entityName: "PhotoAssetEntity")
    }

    /// ファイル名は保存時に UUID で作られるので、フォルダ内で重複しない。
    /// それでも同じ名前が2件できたときのために、最初の1件だけ返す
    static func fetch(fileName: String,
                      folder: PhotoFolder,
                      userId: String,
                      context: NSManagedObjectContext) throws -> PhotoAssetEntity? {
        let request = fetchRequest()
        request.predicate = NSPredicate(
            format: "fileName == %@ AND folder == %@ AND userId == %@",
            fileName, folder.rawValue, userId
        )
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    /// そのユーザーが預けてある写真のファイル名。
    /// 実体まで読み込むと全部メモリに載るので、名前だけを取る
    static func fetchStoredFileNames(folder: PhotoFolder,
                                     userId: String,
                                     context: NSManagedObjectContext) throws -> Set<String> {
        let request = NSFetchRequest<NSDictionary>(entityName: "PhotoAssetEntity")
        request.resultType = .dictionaryResultType
        request.propertiesToFetch = ["fileName"]
        request.predicate = NSPredicate(
            format: "folder == %@ AND userId == %@", folder.rawValue, userId
        )

        let rows = try context.fetch(request)
        return Set(rows.compactMap { $0["fileName"] as? String })
    }
}
