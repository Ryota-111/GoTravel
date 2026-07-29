import Foundation
import CoreData
import CloudKit

/// Core DataとCloudKitの自動同期を管理するマネージャー
class CoreDataManager {
    static let shared = CoreDataManager()

    #if DEBUG
    /// CloudKit の Development 環境にレコードタイプを作るためのスイッチ。
    ///
    /// エンティティを新しく追加した直後に一度だけ true にしてデバッグ実行し、
    /// CloudKit Console の Development に CD_〜 が並んだら false に戻す。
    /// ダミーレコードの作成と削除を行うため起動に数十秒かかる。
    /// リリースビルドには含まれないので本番の動作には影響しない。
    private static let initializesCloudKitSchemaOnLaunch = false
    #endif

    // MARK: - Properties

    /// NSPersistentCloudKitContainer - Core DataとCloudKitを自動同期
    lazy var persistentContainer: NSPersistentCloudKitContainer = {
        let container = NSPersistentCloudKitContainer(name: "GoTravelModel")

        // CloudKit同期の設定
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve persistent store description")
        }

        // CloudKitコンテナIDを設定
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: "iCloud.com.gmail.taismryotasis.Travory"
        )

        // リモート変更通知を有効化
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        // エンティティ追加などのモデル変更を自動で移行する（失敗すると起動時に落ちるため明示する）
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true

        // 永続ストアをロード
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                // 本番環境ではエラーハンドリングを適切に行う
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }

        }

        #if DEBUG
        // 新しいエンティティは CloudKit にレコードタイプが無いと同期されないため、
        // 開発中に一度だけスキーマを作成する
        if CoreDataManager.initializesCloudKitSchemaOnLaunch {
            do {
                try container.initializeCloudKitSchema(options: [])
                print("[CoreDataManager] CloudKit schema initialized. スイッチを false に戻してください。")
            } catch {
                print("[CoreDataManager] CloudKit schema initialization failed: \(error)")
            }
        }
        #endif

        // ViewContextの設定
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        // リモート変更の監視を開始
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRemoteChange(_:)),
            name: .NSPersistentStoreRemoteChange,
            object: container.persistentStoreCoordinator
        )

        return container
    }()

    /// メインスレッドで使用するViewContext
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }

    // MARK: - Initialization

    private init() {
    }

    // MARK: - Remote Change Handling

    @objc private func handleRemoteChange(_ notification: Notification) {

        // UIを更新するために通知を送信
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .coreDataDidUpdate, object: nil)
        }
    }

    // MARK: - Save Context

    /// メインコンテキストを保存
    func saveContext() {
        let context = viewContext

        if context.hasChanges {
            do {
                try context.save()
                // CloudKitに自動的に同期される
            } catch {
                _ = error as NSError
            }
        }
    }

    /// バックグラウンドコンテキストで処理を実行
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        persistentContainer.performBackgroundTask(block)
    }

    // MARK: - Batch Operations

    /// すべてのデータを削除（開発・デバッグ用）
    func deleteAllData() {
        let entities = persistentContainer.managedObjectModel.entities

        for entity in entities {
            guard let entityName = entity.name else { continue }

            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

            do {
                try viewContext.execute(batchDeleteRequest)
            } catch {
            }
        }

        saveContext()
    }

    /// 指定ユーザーの全データを削除（アカウント削除用）
    /// NSBatchDeleteRequestはCloudKitへ同期されないため、オブジェクト単位で削除する
    func deleteAllUserData(userId: String) {
        let entityPredicates: [(String, NSPredicate)] = [
            ("PlanEntity", NSPredicate(format: "userId == %@", userId)),
            ("VisitedPlaceEntity", NSPredicate(format: "userId == %@", userId)),
            ("TravelPlanEntity", NSPredicate(format: "userId == %@ OR ownerId == %@", userId, userId))
        ]

        for (entityName, predicate) in entityPredicates {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
            fetchRequest.predicate = predicate

            do {
                let objects = try viewContext.fetch(fetchRequest)
                for object in objects {
                    viewContext.delete(object)
                }
            } catch {
            }
        }

        saveContext()
    }

    // MARK: - CloudKit Status

    /// CloudKitアカウントの状態を確認
    func checkCloudKitStatus() async -> Bool {
        let container = CKContainer(identifier: "iCloud.com.gmail.taismryotasis.Travory")

        do {
            let status = try await container.accountStatus()

            switch status {
            case .available:
                return true
            case .noAccount:
                return false
            case .restricted:
                return false
            case .couldNotDetermine:
                return false
            case .temporarilyUnavailable:
                return false
            @unknown default:
                return false
            }
        } catch {
            return false
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Core Dataが更新された時に送信される通知
    static let coreDataDidUpdate = Notification.Name("coreDataDidUpdate")
}
