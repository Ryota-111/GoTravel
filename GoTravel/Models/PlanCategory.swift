import Foundation
import Combine
import CoreData
import SwiftUI

// MARK: - カテゴリ（カレンダー）（3.0）
//
// 2.9 までは Travory のカレンダーは1つだけだった。カテゴリを増やすと、カレンダー自体が増える
// （「自分用」「家族」「友達」のように）。カテゴリごとに、自分だけで使うか、相手と共有して
// 一緒に編集するかを分けられる（`docs/設計_3.0.md` 5章）。
//
// - 予定（おでかけ・日常・記念日）はどれか1つのカテゴリに入る。`Plan.categoryId` が nil なら「自分用」
// - タグはカテゴリごとに持つ。共有したカテゴリのタグは、メンバー全員で同じものを使う
// - 旅行計画はカテゴリに入れない（今までどおり1件ずつ共有する）
// - 「自分用」は実体を持たない（id は nil）。2.9 までの予定とタグは、すべて「自分用」に入る

struct PlanCategory: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var colorHex: String?
    var order: Int = 0
    /// 共有中か
    var isShared = false
    /// 共有コード（"PLAN-XXXXXXXX"）
    var shareCode: String?
    /// 共有を始めた人
    var ownerId: String?
    /// メンバー（持ち主も含む）
    var sharedWith: [String] = []

    /// 「自分用」の名前（実体を持たない既定のカテゴリ）
    static let personalName = "自分用"

    var color: Color {
        Color(hex: colorHex ?? PlanTagPalette.fallbackHex(forTagId: id)) ?? .gray
    }

    func isOwner(userId: String) -> Bool {
        ownerId == userId
    }

    init(id: String = UUID().uuidString, name: String, colorHex: String? = nil, order: Int = 0,
         isShared: Bool = false, shareCode: String? = nil, ownerId: String? = nil, sharedWith: [String] = []) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.order = order
        self.isShared = isShared
        self.shareCode = shareCode
        self.ownerId = ownerId
        self.sharedWith = sharedWith
    }

    enum CodingKeys: String, CodingKey {
        case id, name, colorHex, order, isShared, shareCode, ownerId, sharedWith
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        colorHex = try c.decodeIfPresent(String.self, forKey: .colorHex)
        order = try c.decodeIfPresent(Int.self, forKey: .order) ?? 0
        isShared = try c.decodeIfPresent(Bool.self, forKey: .isShared) ?? false
        shareCode = try c.decodeIfPresent(String.self, forKey: .shareCode)
        ownerId = try c.decodeIfPresent(String.self, forKey: .ownerId)
        sharedWith = try c.decodeIfPresent([String].self, forKey: .sharedWith) ?? []
    }
}

/// カレンダータブで、どのカテゴリを見ているか
enum PlanCategorySelection: Hashable, Codable {
    /// すべてのカテゴリを重ねて見る
    case all
    /// 自分用
    case personal
    /// そのカテゴリ
    case category(String)

    /// その予定を表示するか
    func includes(categoryId: String?) -> Bool {
        switch self {
        case .all: return true
        case .personal: return categoryId == nil
        case .category(let id): return categoryId == id
        }
    }

    /// 旅行計画と iPhone の予定を出すか（カテゴリに入らないので、「すべて」と「自分用」でだけ出す）
    var showsUncategorized: Bool {
        switch self {
        case .all, .personal: return true
        case .category: return false
        }
    }

    /// 新しい予定を入れるカテゴリ（「すべて」を見ているときは自分用）
    var categoryIdForNewPlan: String? {
        if case .category(let id) = self { return id }
        return nil
    }

    /// 保存用の文字（"all" / "personal" / "category:<id>"）
    var storageKey: String {
        switch self {
        case .all: return "all"
        case .personal: return "personal"
        case .category(let id): return "category:\(id)"
        }
    }

    init(storageKey: String) {
        if storageKey == "personal" {
            self = .personal
        } else if storageKey.hasPrefix("category:") {
            self = .category(String(storageKey.dropFirst("category:".count)))
        } else {
            self = .all
        }
    }
}

// MARK: - Core Data

@objc(PlanCategoryEntity)
public class PlanCategoryEntity: NSManagedObject {
    @NSManaged public var id: String?
    @NSManaged public var name: String?
    @NSManaged public var colorHex: String?
    @NSManaged public var order: Int32
    @NSManaged public var isShared: Bool
    @NSManaged public var shareCode: String?
    @NSManaged public var ownerId: String?
    @NSManaged public var sharedWithData: Data?
    @NSManaged public var createdAt: Date?
    @NSManaged public var userId: String?
}

extension PlanCategoryEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<PlanCategoryEntity> {
        NSFetchRequest<PlanCategoryEntity>(entityName: "PlanCategoryEntity")
    }

    static func fetchById(id: String, context: NSManagedObjectContext) throws -> PlanCategoryEntity? {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    func toCategory() -> PlanCategory {
        PlanCategory(id: id ?? UUID().uuidString, name: name ?? "", colorHex: colorHex, order: Int(order),
                     isShared: isShared, shareCode: shareCode, ownerId: ownerId,
                     sharedWith: sharedWithData.flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? [])
    }

    func update(from category: PlanCategory, userId: String) {
        id = category.id
        name = category.name
        colorHex = category.colorHex
        order = Int32(category.order)
        isShared = category.isShared
        shareCode = category.shareCode
        ownerId = category.ownerId
        sharedWithData = category.sharedWith.isEmpty ? nil : try? JSONEncoder().encode(category.sharedWith)
        self.userId = userId
        if createdAt == nil { createdAt = Date() }
    }
}

// MARK: - 管理

/// カテゴリの一覧（Core Data、CloudKit で自分の端末どうしは同期する）
final class PlanCategoryManager: NSObject, ObservableObject {
    static let shared = PlanCategoryManager()

    @Published private(set) var categories: [PlanCategory] = []

    private let context: NSManagedObjectContext
    private var controller: NSFetchedResultsController<PlanCategoryEntity>?
    private(set) var userId: String?

    private override init() {
        context = CoreDataManager.shared.viewContext
        super.init()
    }

    func setup(userId: String) {
        guard self.userId != userId else { return }
        self.userId = userId
        let request = PlanCategoryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@", userId)
        request.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true),
                                   NSSortDescriptor(key: "createdAt", ascending: true)]
        let controller = NSFetchedResultsController(fetchRequest: request, managedObjectContext: context,
                                                    sectionNameKeyPath: nil, cacheName: nil)
        controller.delegate = self
        self.controller = controller
        try? controller.performFetch()
        reload()
    }

    private func reload() {
        categories = controller?.fetchedObjects?.map { $0.toCategory() } ?? []
    }

    func category(for id: String?) -> PlanCategory? {
        guard let id else { return nil }
        return categories.first { $0.id == id }
    }

    /// 表示名（nil は「自分用」）
    func name(for id: String?) -> String {
        category(for: id)?.name ?? PlanCategory.personalName
    }

    @discardableResult
    func add(name: String, colorHex: String?) -> PlanCategory? {
        guard let userId else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let category = PlanCategory(name: trimmed, colorHex: colorHex,
                                    order: (categories.map(\.order).max() ?? -1) + 1)
        let entity = PlanCategoryEntity(context: context)
        entity.update(from: category, userId: userId)
        CoreDataManager.shared.saveContext()
        reload()
        return category
    }

    /// 同じ id のカテゴリを作るか、あれば書き換える（共有したカテゴリに参加したとき・同期のときも使う）
    func upsert(_ category: PlanCategory) {
        guard let userId else { return }
        let entity = (try? PlanCategoryEntity.fetchById(id: category.id, context: context)) ?? PlanCategoryEntity(context: context)
        entity.update(from: category, userId: userId)
        CoreDataManager.shared.saveContext()
        reload()
    }

    /// カテゴリを消す。入っていた予定とタグは「自分用」へ移す（消してしまわない）
    func delete(_ category: PlanCategory) {
        guard let userId, let entity = try? PlanCategoryEntity.fetchById(id: category.id, context: context) else { return }
        moveContentsToPersonal(categoryId: category.id, userId: userId)
        context.delete(entity)
        CoreDataManager.shared.saveContext()
        reload()
    }

    /// カテゴリの予定とタグを「自分用」へ移す（共有をやめた・抜けた・消したとき）
    func moveContentsToPersonal(categoryId: String, userId: String) {
        let plans = PlanEntity.fetchRequest() as NSFetchRequest<PlanEntity>
        plans.predicate = NSPredicate(format: "userId == %@ AND categoryId == %@", userId, categoryId)
        for entity in (try? context.fetch(plans)) ?? [] {
            entity.categoryId = nil
        }
        let tags = PlanTagEntity.fetchRequest()
        tags.predicate = NSPredicate(format: "userId == %@ AND categoryId == %@", userId, categoryId)
        for entity in (try? context.fetch(tags)) ?? [] {
            entity.categoryId = nil
        }
        CoreDataManager.shared.saveContext()
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        var reordered = categories
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, category) in reordered.enumerated() where category.order != index {
            var updated = category
            updated.order = index
            upsert(updated)
        }
    }

    func deleteAllData(userId: String) {
        let request = PlanCategoryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@", userId)
        for entity in (try? context.fetch(request)) ?? [] { context.delete(entity) }
        CoreDataManager.shared.saveContext()
        categories = []
        self.userId = nil
        controller = nil
    }
}

extension PlanCategoryManager: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        DispatchQueue.main.async { self.reload() }
    }
}
