import Foundation
import Combine
import UIKit
import CoreData

/// TravelPlan管理用ViewModel（Core Data + CloudKit自動同期版）
final class TravelPlanViewModel: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var travelPlans: [TravelPlan] = []
    @Published var planImages: [String: UIImage] = [:] // planId: image
    @Published var isLoading: Bool = false

    // MARK: - Private Properties
    private let context: NSManagedObjectContext
    private var fetchedResultsController: NSFetchedResultsController<TravelPlanEntity>?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    override init() {
        self.context = CoreDataManager.shared.viewContext
        super.init()
    }

    // MARK: - Core Data Fetch

    /// 指定ユーザーのTravelPlanを取得（Core Dataから）
    func setupFetchedResultsController(userId: String) {

        let fetchRequest: NSFetchRequest<TravelPlanEntity> = TravelPlanEntity.fetchRequest()

        // ユーザーIDでフィルタリング（自分のプランのみ）
        // 注: sharedWithはBinaryデータなので、NSPredicateで直接フィルタリングできない
        // 共有されたプランは、updateTravelPlans()でメモリ内フィルタリング
        fetchRequest.predicate = NSPredicate(format: "userId == %@ OR ownerId == %@", userId, userId)

        // 開始日で降順ソート
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]

        fetchedResultsController = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )

        fetchedResultsController?.delegate = self

        do {
            try fetchedResultsController?.performFetch()
            updateTravelPlans()
        } catch {
        }
    }

    /// FetchedResultsControllerの結果をtravelPlans配列に変換
    private func updateTravelPlans() {
        guard let entities = fetchedResultsController?.fetchedObjects else {
            travelPlans = []
            return
        }

        travelPlans = entities.map { $0.toTravelPlan() }

        // ローカル画像を読み込み
        loadLocalImages()
    }

    /// ローカルファイルシステムから画像を読み込む
    private func loadLocalImages() {
        for plan in travelPlans {
            guard let fileName = plan.localImageFileName,
                  let planId = plan.id else { continue }

            if let image = FileManager.documentsImage(named: fileName) {
                planImages[planId] = image
            }
        }
    }

    // MARK: - CRUD Operations

    /// TravelPlanを追加（Core Dataに保存 → 自動的にCloudKitと同期）
    @MainActor
    func add(_ plan: TravelPlan, userId: String, image: UIImage? = nil) {

        var planToSave = plan
        planToSave.userId = userId

        // 画像をローカルに保存
        if let image = image {
            let fileName = "travel_plan_\(UUID().uuidString).jpg"
            if let imageData = image.jpegData(compressionQuality: 0.7) {
                do {
                    try FileManager.saveImageDataToDocuments(data: imageData, named: fileName)
                    planToSave.localImageFileName = fileName
                } catch {
                }
            }
        }

        // Core Dataに保存
        context.perform {
            _ = TravelPlanEntity.create(from: planToSave, context: self.context)
            CoreDataManager.shared.saveContext()

            // 通知をスケジュール
            DispatchQueue.main.async {
                NotificationService.shared.scheduleTravelPlanNotifications(for: planToSave)
            }
        }
    }

    /// TravelPlanを更新（Core Dataに保存 → 自動的にCloudKitと同期）
    @MainActor
    func update(_ plan: TravelPlan, userId: String, image: UIImage? = nil) {

        guard let planId = plan.id else {
            return
        }

        var planToSave = plan
        planToSave.updatedAt = Date()

        // 画像を保存（新しい画像がある場合）
        if let image = image {
            // 古い画像を削除
            if let oldFileName = plan.localImageFileName {
                try? FileManager.removeDocumentFile(named: oldFileName)
            }

            // 新しい画像を保存
            let fileName = "travel_plan_\(UUID().uuidString).jpg"
            if let imageData = image.jpegData(compressionQuality: 0.7) {
                do {
                    try FileManager.saveImageDataToDocuments(data: imageData, named: fileName)
                    planToSave.localImageFileName = fileName
                } catch {
                }
            }
        }

        // Core Dataを更新
        context.perform {
            do {
                if let entity = try TravelPlanEntity.fetchById(id: planId, context: self.context) {
                    entity.update(from: planToSave)
                    CoreDataManager.shared.saveContext()

                    // 通知を更新
                    DispatchQueue.main.async {
                        NotificationService.shared.scheduleTravelPlanNotifications(for: planToSave)
                    }
                }
            } catch {
            }
        }
    }

    /// TravelPlanを削除（Core Dataから削除 → 自動的にCloudKitと同期）
    @MainActor
    func delete(_ plan: TravelPlan, userId: String? = nil) {

        guard let planId = plan.id else {
            return
        }

        // 通知をキャンセル
        NotificationService.shared.cancelTravelPlanNotifications(for: planId)

        // ローカル画像を削除
        if let fileName = plan.localImageFileName {
            try? FileManager.removeDocumentFile(named: fileName)
        }

        // Core Dataから削除
        context.perform {
            do {
                if let entity = try TravelPlanEntity.fetchById(id: planId, context: self.context) {
                    self.context.delete(entity)
                    CoreDataManager.shared.saveContext()
                }
            } catch {
            }
        }
    }

    // MARK: - Image Loading

    /// 特定のTravelPlanの画像を取得（ローカルファイルから）
    func loadImage(for planId: String) async -> UIImage? {
        // キャッシュをチェック
        if let cached = planImages[planId] {
            return cached
        }

        // プランを検索して画像ファイル名を取得
        guard let plan = travelPlans.first(where: { $0.id == planId }),
              let fileName = plan.localImageFileName else {
            return nil
        }

        // ローカルファイルから読み込み
        if let image = FileManager.documentsImage(named: fileName) {
            await MainActor.run {
                self.planImages[planId] = image
            }
            return image
        }

        return nil
    }

    // MARK: - Sharing Methods

    /// 共有コードを更新
    func updateShareCode(planId: String, shareCode: String, userId: String) {
        guard var plan = travelPlans.first(where: { $0.id == planId }) else { return }

        plan.isShared = true
        plan.shareCode = shareCode
        plan.ownerId = plan.userId
        plan.updatedAt = Date()

        update(plan, userId: userId)
    }

    /// 共有コードでプランに参加
    func joinPlanByShareCode(_ shareCode: String, userId: String, completion: @escaping (Result<TravelPlan, Error>) -> Void) {
        context.perform {
            do {
                // Core Dataで共有コードを検索
                guard let entity = try TravelPlanEntity.fetchByShareCode(shareCode: shareCode, context: self.context) else {
                    DispatchQueue.main.async {
                        completion(.failure(APIClientError.notFound))
                    }
                    return
                }

                var plan = entity.toTravelPlan()

                // 現在のユーザーをsharedWith配列に追加
                if !plan.sharedWith.contains(userId) {
                    plan.sharedWith.append(userId)
                    plan.updatedAt = Date()

                    // Core Dataを更新
                    entity.update(from: plan)
                    CoreDataManager.shared.saveContext()

                    DispatchQueue.main.async {
                        completion(.success(plan))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.success(plan))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
}

// MARK: - NSFetchedResultsControllerDelegate

extension TravelPlanViewModel: NSFetchedResultsControllerDelegate {
    /// Core Dataの変更を検知してUIを自動更新
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        DispatchQueue.main.async {
            self.updateTravelPlans()
        }
    }
}
