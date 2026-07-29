import Foundation
import Combine
import CoreData

struct CustomPlaceCategory: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var icon: String
    var isDefault: Bool = false

    static let defaults: [CustomPlaceCategory] = [
        CustomPlaceCategory(id: "hotel",       name: "ホテル",     icon: "bed.double.fill",  isDefault: true),
        CustomPlaceCategory(id: "restaurant",  name: "レストラン", icon: "fork.knife",       isDefault: true),
        CustomPlaceCategory(id: "sightseeing", name: "風景",       icon: "mountain.2.fill",  isDefault: true)
    ]

    /// 定義が見つからないカテゴリーの表示用。
    /// IDをそのまま名前に出すとUUIDが画面に出てしまうため、専用の見た目を返す
    static func unknown(id: String) -> CustomPlaceCategory {
        CustomPlaceCategory(id: id, name: "未分類", icon: "mappin.circle.fill")
    }
}

/// カスタムカテゴリーは Core Data（CloudKit 自動同期）で管理する。
/// 端末ローカルに置くと、別端末で場所のカテゴリー名が解決できなくなるため。
final class PlaceCategoryManager: NSObject, ObservableObject {
    static let shared = PlaceCategoryManager()

    @Published var categories: [CustomPlaceCategory] = CustomPlaceCategory.defaults

    private let context: NSManagedObjectContext
    private var fetchedResultsController: NSFetchedResultsController<PlaceCategoryEntity>?
    private var currentUserId: String?

    /// 旧バージョンの UserDefaults 保存分を一度だけ Core Data へ移す
    private let legacyKey = "custom_place_categories_v1"
    private let migrationDoneKey = "PlaceCategoriesMigratedToCoreData_v1"

    private override init() {
        self.context = CoreDataManager.shared.viewContext
        super.init()
    }

    // MARK: - Setup

    func setup(userId: String) {
        guard currentUserId != userId else { return }
        currentUserId = userId

        migrateLegacyCategoriesIfNeeded(userId: userId)
        setupFetchedResultsController(userId: userId)
    }

    private func setupFetchedResultsController(userId: String) {
        let request: NSFetchRequest<PlaceCategoryEntity> = PlaceCategoryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@", userId)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]

        let controller = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        controller.delegate = self
        fetchedResultsController = controller

        do {
            try controller.performFetch()
            updateCategories()
        } catch {
        }
    }

    private func updateCategories() {
        let custom = fetchedResultsController?.fetchedObjects?.map { $0.toCategory() } ?? []
        categories = CustomPlaceCategory.defaults + custom
    }

    // MARK: - Migration

    private func migrateLegacyCategoriesIfNeeded(userId: String) {
        guard !UserDefaults.standard.bool(forKey: migrationDoneKey) else { return }

        // 移行対象がない場合だけ、ここで「済み」にして終える
        guard let data = UserDefaults.standard.data(forKey: legacyKey) else {
            UserDefaults.standard.set(true, forKey: migrationDoneKey)
            return
        }

        // デコードに失敗した場合はフラグを立てず、次回の起動でやり直せるようにする
        guard let saved = try? JSONDecoder().decode([CustomPlaceCategory].self, from: data) else {
            return
        }

        let custom = saved.filter { !$0.isDefault }

        for category in custom {
            if (try? PlaceCategoryEntity.fetchById(id: category.id, context: context)) != nil {
                continue
            }
            _ = PlaceCategoryEntity.create(from: category, userId: userId, context: context)
        }
        if !custom.isEmpty {
            CoreDataManager.shared.saveContext()
        }

        UserDefaults.standard.set(true, forKey: migrationDoneKey)

        // 移行が済んでから元データを消す
        UserDefaults.standard.removeObject(forKey: legacyKey)
    }

    // MARK: - CRUD

    func add(_ category: CustomPlaceCategory) {
        guard let userId = currentUserId else { return }
        guard (try? PlaceCategoryEntity.fetchById(id: category.id, context: context)) == nil else { return }

        _ = PlaceCategoryEntity.create(from: category, userId: userId, context: context)
        CoreDataManager.shared.saveContext()
    }

    func delete(_ category: CustomPlaceCategory) {
        guard !category.isDefault else { return }
        guard let entity = try? PlaceCategoryEntity.fetchById(id: category.id, context: context) else { return }

        context.delete(entity)
        CoreDataManager.shared.saveContext()
    }

    func category(for id: String) -> CustomPlaceCategory {
        categories.first { $0.id == id } ?? CustomPlaceCategory.unknown(id: id)
    }

    /// アカウント削除時に全カテゴリーを消す
    func deleteAllData(userId: String) {
        let request: NSFetchRequest<PlaceCategoryEntity> = PlaceCategoryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@", userId)

        if let entities = try? context.fetch(request) {
            for entity in entities {
                context.delete(entity)
            }
            CoreDataManager.shared.saveContext()
        }

        currentUserId = nil
        fetchedResultsController = nil
        categories = CustomPlaceCategory.defaults
    }
}

// MARK: - NSFetchedResultsControllerDelegate

extension PlaceCategoryManager: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        DispatchQueue.main.async {
            self.updateCategories()
        }
    }
}
