import Foundation
import CoreData
import SwiftUI

/// AlbumEntity - Core Data Entity
@objc(AlbumEntity)
public class AlbumEntity: NSManagedObject {
    @NSManaged public var id: String?
    @NSManaged public var title: String?
    @NSManaged public var icon: String?
    @NSManaged public var albumType: String?
    @NSManaged public var coverColorHex: String?
    @NSManaged public var photoFileNamesData: Data?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var travelPlanId: String?
    @NSManaged public var isDefaultAlbum: Bool
    @NSManaged public var userId: String?
}

// MARK: - Fetch Request

extension AlbumEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<AlbumEntity> {
        return NSFetchRequest<AlbumEntity>(entityName: "AlbumEntity")
    }

    /// ユーザーIDでフィルタリング
    static func fetchByUser(userId: String, context: NSManagedObjectContext) throws -> [AlbumEntity] {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@", userId)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        return try context.fetch(request)
    }

    /// IDで検索
    static func fetchById(id: String, context: NSManagedObjectContext) throws -> AlbumEntity? {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }
}

// MARK: - Conversion: Entity ⇔ Album

extension AlbumEntity {
    func toAlbum() -> Album {
        var photoFileNames: [String] = []
        if let data = photoFileNamesData {
            photoFileNames = (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }

        var coverColor: Color? = nil
        if let hex = coverColorHex {
            coverColor = Color(hex: hex)
        }

        let type = AlbumType(rawValue: albumType ?? "") ?? .custom

        return Album(
            id: id ?? UUID().uuidString,
            title: title ?? "",
            photoFileNames: photoFileNames,
            coverColor: coverColor,
            icon: icon ?? type.icon,
            createdAt: createdAt ?? Date(),
            updatedAt: updatedAt ?? Date(),
            travelPlanId: travelPlanId,
            isDefaultAlbum: isDefaultAlbum,
            type: type,
            userId: userId
        )
    }

    func update(from album: Album) {
        self.id = album.id
        self.title = album.title
        self.icon = album.icon
        self.albumType = album.type.rawValue
        self.coverColorHex = album.coverColorHex
        self.photoFileNamesData = try? JSONEncoder().encode(album.photoFileNames)
        self.createdAt = album.createdAt
        self.updatedAt = album.updatedAt
        self.travelPlanId = album.travelPlanId
        self.isDefaultAlbum = album.isDefaultAlbum
        self.userId = album.userId
    }

    static func create(from album: Album, context: NSManagedObjectContext) -> AlbumEntity {
        let entity = AlbumEntity(context: context)
        entity.update(from: album)
        return entity
    }
}
