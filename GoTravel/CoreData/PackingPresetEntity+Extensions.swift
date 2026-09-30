import Foundation
import CoreData

/// PackingPresetEntity - Core Data Entity
///
/// リストが空のときに出る「よく使う持ち物」の候補。
/// 以前はコードに直書きした9個の固定リストで、
/// **人によって要る物が違うのに編集できなかった。**
///
/// お土産・やりたいことの候補も同じ入れ物に入れて `kind` で分ける。
/// 旅行ごとではなくユーザーに紐づくので、全部の旅行で使い回せる。
@objc(PackingPresetEntity)
public class PackingPresetEntity: NSManagedObject {
    @NSManaged public var id: String?
    @NSManaged public var name: String?
    /// `PackingItem.Kind` の rawValue
    @NSManaged public var kind: String?
    @NSManaged public var order: Int32
    @NSManaged public var createdAt: Date?
    @NSManaged public var userId: String?
}

// MARK: - Fetch Request

extension PackingPresetEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<PackingPresetEntity> {
        return NSFetchRequest<PackingPresetEntity>(entityName: "PackingPresetEntity")
    }

    /// 並べた順が主。別々の端末で同時に作ると order が同じ値になりうるので、
    /// 作成日で必ず決着がつくようにしておく（`PlanTagEntity` と同じ考え方）
    static var defaultSortDescriptors: [NSSortDescriptor] {
        [
            NSSortDescriptor(key: "order", ascending: true),
            NSSortDescriptor(key: "createdAt", ascending: true)
        ]
    }

    static func fetchByUser(userId: String, context: NSManagedObjectContext) throws -> [PackingPresetEntity] {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@", userId)
        request.sortDescriptors = defaultSortDescriptors
        return try context.fetch(request)
    }

    static func fetchById(id: String, context: NSManagedObjectContext) throws -> PackingPresetEntity? {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }
}
