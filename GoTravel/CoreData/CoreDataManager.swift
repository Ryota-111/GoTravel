import Foundation
import CoreData
import CloudKit
import Combine

/// Core DataとCloudKitの自動同期を管理するマネージャー
class CoreDataManager: ObservableObject {
    static let shared = CoreDataManager()

    /// 端末の中のデータを開けなかったときの理由（3.8）。開けていれば nil。
    /// 3.6 までは開けないと落としていた。いまは `GoTravelApp` がこれを見て「開けませんでした」の画面を出す
    @Published private(set) var storeLoadFailure: StoreLoadFailure?

    #if DEBUG
    /// CloudKit の Development 環境にレコードタイプを作るためのスイッチ。
    ///
    /// エンティティを新しく追加した直後に一度だけ true にしてデバッグ実行し、
    /// CloudKit Console の Development に CD_〜 が並んだら false に戻す。
    /// ダミーレコードの作成と削除を行うため起動に数十秒かかる。
    /// リリースビルドには含まれないので本番の動作には影響しない。
    ///
    /// deploy 済み: `TaskEntity` と `PhotoAssetEntity`（2026年8月31日）、
    /// `PackingPresetEntity`（2026年9月5日）、`TravelPlanEntity.deletedAt`（2026年9月26日）、
    /// `TravelPlanEntity.memoText`（2026年10月4日）。
    /// 3.0 で足したもの（**2026年10月15日に deploy 済み**）：`TravelPlanEntity.memosJSON`、`PlanEntity` の
    /// categoryId・lastEditedBy・updatedAt、`PlanTagEntity.categoryId`、新しいエンティティ `PlanCategoryEntity`。
    /// 手順は `docs/設計_3.0.md` 6章。
    ///
    /// 既存のエンティティに項目を足したときも、同じ手順で Production に反映すること。
    /// 反映しないままリリースすると、その書き出しが Production で失敗し、同期全体が止まる
    private static let initializesCloudKitSchemaOnLaunch = false
    #endif

    /// スクリーンショット用の空っぽモード。
    ///
    /// App Store の画像を撮り直すときに、実データを消さずに「何も無い状態」を作るためのもの。
    /// **有効なときは保存先をメモリ内にして、実データのファイルにも CloudKit にも一切触らない。**
    /// アプリを終了すれば入力したデモデータは跡形もなく消える。
    ///
    /// 有効にする条件は次の2つを**両方**満たしたときだけ。
    /// - DEBUG ビルドであること（App Store 用のビルドでは存在しない分岐）
    /// - Xcode から起動引数 `-TravoryEmptyDataMode` を付けて実行すること
    ///
    /// 端末のホーム画面からアプリを叩いた場合は起動引数が付かないため、
    /// 通常どおり実データで起動する
    static var isEmptyDataMode: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-TravoryEmptyDataMode")
        #else
        return false
        #endif
    }

    // MARK: - Properties

    /// NSPersistentCloudKitContainer - Core DataとCloudKitを自動同期
    lazy var persistentContainer: NSPersistentCloudKitContainer = {
        let container = NSPersistentCloudKitContainer(name: "GoTravelModel")

        // CloudKit同期の設定
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve persistent store description")
        }

        if Self.isEmptyDataMode {
            // 保存先をメモリ内だけにする。実データの sqlite ファイルは開きもしない。
            // CloudKit も切るので、ここで作ったデモデータが同期されることも、
            // 逆に実データが降ってくることもない
            description.url = URL(fileURLWithPath: "/dev/null")
            description.cloudKitContainerOptions = nil
            print("[CoreDataManager] 空データモードで起動しました。実データには触れません。")
        } else {
            // CloudKitコンテナIDを設定
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: "iCloud.com.gmail.taismryotasis.Travory"
            )
        }

        // リモート変更通知を有効化
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        // エンティティ追加などのモデル変更を自動で移行する（失敗すると起動時に落ちるため明示する）
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true

        // 永続ストアをロード
        // 開けなくても落とさない（3.8）。3.6 までは fatalError で、起動した瞬間に落ち続ける人がいた。
        // 開けなかったことを覚えておき、画面で知らせて開き直せるようにする
        container.loadPersistentStores { [weak self] _, error in
            if let error = error as NSError? {
                self?.recordLoadFailure(error)
            }
        }

        #if DEBUG
        // 新しいエンティティは CloudKit にレコードタイプが無いと同期されないため、
        // 開発中に一度だけスキーマを作成する
        if CoreDataManager.initializesCloudKitSchemaOnLaunch && !Self.isEmptyDataMode {
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

    // MARK: - 開けなかったとき（3.8）

    /// データを開けているか。開けていないときに保存すると Core Data が例外で落ちるので、保存の前に見る
    var isStoreLoaded: Bool {
        !persistentContainer.persistentStoreCoordinator.persistentStores.isEmpty
    }

    /// 起動のはじめに1回呼ぶ。データを開き、開けなければ `storeLoadFailure` に理由が入る。
    /// 画面を組み立てる最中に開くと、そこで理由を書き換えることになるので、先に済ませておく
    func loadStoresIfNeeded() {
        _ = persistentContainer
        #if DEBUG
        // 「開けませんでした」の画面を確かめる（Xcode の起動引数 `-TravorySimulateStoreFailure`）。
        // 本当は開けているので、「もう一度開く」を押すとふつうの画面に戻る。開発者には送らない
        if ProcessInfo.processInfo.arguments.contains("-TravorySimulateStoreFailure") {
            storeLoadFailure = StoreLoadFailure(domain: NSCocoaErrorDomain, code: 134110,
                                                underlying: ["\(NSSQLiteErrorDomain) 13"],
                                                availableCapacity: Self.availableCapacity())
        }
        #endif
    }

    /// もう一度開く。「もう一度開く」を押したときや、ロックが解けたとき・アプリが前に出たときに呼ぶ。
    /// 開けたら true（`storeLoadFailure` も消える）
    @discardableResult
    func retryLoadingStores() -> Bool {
        let container = persistentContainer
        if isStoreLoaded {
            storeLoadFailure = nil
            return true
        }
        var failed: NSError?
        container.loadPersistentStores { _, error in
            failed = error as NSError?
        }
        if let failed {
            recordLoadFailure(failed)
            return false
        }
        storeLoadFailure = nil
        return true
    }

    private func recordLoadFailure(_ error: NSError) {
        let failure = StoreLoadFailure(error, availableCapacity: Self.availableCapacity())
        let isNew = storeLoadFailure != failure
        storeLoadFailure = failure
        // 同じ理由で開き直しに失敗するたびに送らない
        if isNew {
            DiagnosticsReporter.shared.report(failure.diagnosticText)
        }
    }

    private static func availableCapacity() -> Int64? {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let values = try? home.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage
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

    /// メインコンテキストを保存する。
    ///
    /// 戻り値は保存できたかどうか。
    /// **消す処理の前には必ずこれを見ること。** Core Data の検索は未保存の
    /// 変更も返すため、保存が失敗していても「在る」と判定されてしまう。
    /// それを根拠に元データを消すと、本当に失われる
    @discardableResult
    func saveContext() -> Bool {
        let context = viewContext

        guard context.hasChanges else { return true }
        // 開けていないまま保存すると、Core Data が例外で落ちる（3.8）
        guard isStoreLoaded else { return false }

        do {
            try context.save()
            // CloudKitに自動的に同期される
            return true
        } catch {
            #if DEBUG
            print("[CoreDataManager] 保存に失敗: \(error)")
            #endif
            return false
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
    ///
    /// 2.9 までは持ち物の候補・やることリスト・写真の記録が消えずに残っていた（退会としては不完全）
    func deleteAllUserData(userId: String) {
        let byUser = NSPredicate(format: "userId == %@", userId)
        let entityPredicates: [(String, NSPredicate)] = [
            ("PlanEntity", byUser),
            ("VisitedPlaceEntity", byUser),
            ("TravelPlanEntity", NSPredicate(format: "userId == %@ OR ownerId == %@", userId, userId)),
            ("PackingPresetEntity", byUser),
            ("TaskEntity", byUser),
            ("PhotoAssetEntity", byUser)
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

        // 次にサインインした人には、持ち物の候補をまた用意する
        UserDefaults.standard.removeObject(forKey: "PackingPresetsSeeded_v1")
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
