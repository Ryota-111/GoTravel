import Foundation
import Combine
import CoreData
import SwiftUI

/// 予定につける自由タグ。
///
/// 「仕事」「遊び」「家族」のように、自分の生活の軸で予定を仕分けるためのもの。
/// **予定の分類はこれが本命**で、種別（おでかけ／日常／記念日）は
/// 作るときにどの項目を聞くかを決めるだけの入力上の区別でしかない。
///
/// 一覧の絞り込みと色による見分けを担うので、
/// 以前のような自由入力の文字列ではなく、名前と色を持つ実体として保存する
struct PlanTag: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    /// ユーザーが選んだ色。選ばずに作られた分は nil
    var colorHex: String? = nil
    /// 一覧の絞り込み行に並ぶ順。よく使うタグを左に寄せられるようにする
    var order: Int = 0

    var color: Color {
        let hex = colorHex ?? PlanTagPalette.fallbackHex(forTagId: id)
        return Color(hex: hex) ?? .gray
    }

    /// タグが1つも無い人に見せる作成候補。
    /// 何を入れる欄なのかは、空欄と説明文よりも実例のほうが早く伝わる。
    /// あくまで候補なので、押されるまでタグとしては作らない
    static let starterSuggestions: [String] = ["仕事", "遊び", "家族", "健康"]
}

/// タグは Core Data（CloudKit 自動同期）で管理する。
/// 端末ローカルに置くと、別端末で予定に付いたタグの名前と色が解決できなくなるため。
///
/// 作りは `PlaceCategoryManager` に揃えてある
final class PlanTagManager: NSObject, ObservableObject {
    static let shared = PlanTagManager()

    @Published var tags: [PlanTag] = []

    private let context: NSManagedObjectContext
    private var fetchedResultsController: NSFetchedResultsController<PlanTagEntity>?
    private var currentUserId: String?

    /// 自由入力の文字列だった頃のタグ（`PlanEntity.tagsData`）を一度だけ実体に移す
    private let migrationDoneKey = "PlanTagsMigratedToEntity_v1"

    private override init() {
        self.context = CoreDataManager.shared.viewContext
        super.init()
    }

    // MARK: - Setup

    func setup(userId: String) {
        guard currentUserId != userId else { return }
        currentUserId = userId

        migrateLegacyTagsIfNeeded(userId: userId)
        setupFetchedResultsController(userId: userId)
    }

    private func setupFetchedResultsController(userId: String) {
        let request: NSFetchRequest<PlanTagEntity> = PlanTagEntity.fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@", userId)
        request.sortDescriptors = PlanTagEntity.defaultSortDescriptors

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
            updateTags()
        } catch {
        }
    }

    private func updateTags() {
        tags = fetchedResultsController?.fetchedObjects?.map { $0.toTag() } ?? []
    }

    // MARK: - Migration

    /// 旧データの移行。予定が持っていたタグ名を集めてタグの実体を作り、
    /// 予定側は名前ではなくIDを持つように書き換える。
    ///
    /// 移行元（`tagsData`）は移行後に必ず消す。
    /// 両方に値が残っていると、次にどちらを正とするか決められなくなる
    private func migrateLegacyTagsIfNeeded(userId: String) {
        // 空データモードでは走らせない。中身は空なのに「移行済み」の印だけが
        // 端末に残り、実データでの移行が二度と走らなくなる
        guard !CoreDataManager.isEmptyDataMode else { return }
        guard !UserDefaults.standard.bool(forKey: migrationDoneKey) else { return }

        // 取得に失敗した場合はフラグを立てず、次回の起動でやり直せるようにする
        guard let plans = try? PlanEntity.fetchByUser(userId: userId, context: context),
              let existingTags = try? PlanTagEntity.fetchByUser(userId: userId, context: context) else {
            return
        }

        // 別端末で移行済みのタグがすでに届いていることがある。
        // 同じ名前のタグを二重に作らないよう、名前から引けるようにしておく
        var idsByName: [String: String] = [:]
        for entity in existingTags {
            if let name = entity.name, let id = entity.id {
                idsByName[name] = id
            }
        }
        var nextOrder = existingTags.count

        let decoder = JSONDecoder()
        let encoder = JSONEncoder()
        var didChange = false

        for entity in plans {
            guard let data = entity.tagsData,
                  let names = try? decoder.decode([String].self, from: data),
                  !names.isEmpty else { continue }

            var ids: [String] = []
            for name in names {
                if let existing = idsByName[name] {
                    if !ids.contains(existing) { ids.append(existing) }
                    continue
                }

                let tag = PlanTag(
                    id: UUID().uuidString,
                    name: name,
                    colorHex: PlanTagPalette.hex(forIndex: nextOrder),
                    order: nextOrder
                )
                _ = PlanTagEntity.create(from: tag, userId: userId, context: context)
                idsByName[name] = tag.id
                ids.append(tag.id)
                nextOrder += 1
            }

            // 書けたときだけ移行元を消す。
            // 先に消してから書き損じると、タグ名がどこにも残らない
            guard let encoded = try? encoder.encode(ids) else { continue }
            entity.tagIDsData = encoded
            entity.tagsData = nil
            didChange = true
        }

        if didChange {
            CoreDataManager.shared.saveContext()
        }

        UserDefaults.standard.set(true, forKey: migrationDoneKey)
    }

    // MARK: - CRUD

    /// 名前からタグを作る。すでに同じ名前があればそれを返す。
    /// 「仕事」を2つ作れてしまうと、絞り込みの軸として使えなくなるため
    @discardableResult
    func add(name: String, colorHex: String? = nil) -> PlanTag? {
        guard let userId = currentUserId else { return nil }

        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        if let existing = tags.first(where: { $0.name == trimmed }) {
            return existing
        }

        let tag = PlanTag(
            id: UUID().uuidString,
            name: trimmed,
            colorHex: colorHex ?? PlanTagPalette.hex(forIndex: tags.count),
            order: (tags.map(\.order).max() ?? -1) + 1
        )
        _ = PlanTagEntity.create(from: tag, userId: userId, context: context)
        CoreDataManager.shared.saveContext()

        // 画面から続けて使えるよう、監視の反映を待たずに手元も更新しておく
        updateTags()
        return tag
    }

    func update(_ tag: PlanTag) {
        guard let userId = currentUserId else { return }
        guard let entity = try? PlanTagEntity.fetchById(id: tag.id, context: context) else { return }

        entity.update(from: tag, userId: userId)
        CoreDataManager.shared.saveContext()
        updateTags()
    }

    /// タグを消したら、予定側が持っているIDも一緒に外す。
    /// 残しておくと、名前も色も解決できないIDが予定にぶら下がったままになる
    func delete(_ tag: PlanTag) {
        guard let userId = currentUserId else { return }
        guard let entity = try? PlanTagEntity.fetchById(id: tag.id, context: context) else { return }

        context.delete(entity)
        removeTagIDFromPlans(tagId: tag.id, userId: userId)
        CoreDataManager.shared.saveContext()

        // 監視の反映を待たずに手元も更新する。
        // 追加だけ即時で削除は監視頼み、という差があると
        // 消したのに画面に残って見える
        updateTags()
    }

    private func removeTagIDFromPlans(tagId: String, userId: String) {
        guard let plans = try? PlanEntity.fetchByUser(userId: userId, context: context) else { return }

        let decoder = JSONDecoder()
        let encoder = JSONEncoder()

        for entity in plans {
            guard let data = entity.tagIDsData,
                  let ids = try? decoder.decode([String].self, from: data),
                  ids.contains(tagId) else { continue }

            let remaining = ids.filter { $0 != tagId }
            entity.tagIDsData = remaining.isEmpty ? nil : try? encoder.encode(remaining)
        }
    }

    /// 絞り込み行の並べ替え
    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        guard let userId = currentUserId else { return }

        var reordered = tags
        reordered.move(fromOffsets: source, toOffset: destination)

        for (index, tag) in reordered.enumerated() {
            guard let entity = try? PlanTagEntity.fetchById(id: tag.id, context: context) else { continue }
            var updated = tag
            updated.order = index
            entity.update(from: updated, userId: userId)
        }
        CoreDataManager.shared.saveContext()
        updateTags()
    }

    // MARK: - Lookup

    func tag(for id: String?) -> PlanTag? {
        guard let id else { return nil }
        return tags.first { $0.id == id }
    }

    /// 予定が持つIDを、今あるタグに解決する。
    /// 解決できなかったIDは黙って落とす（消されたタグを指しているだけなので）
    func tags(for ids: [String]) -> [PlanTag] {
        ids.compactMap { tag(for: $0) }
    }

    /// アカウント削除時に全タグを消す
    func deleteAllData(userId: String) {
        let request: NSFetchRequest<PlanTagEntity> = PlanTagEntity.fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@", userId)

        if let entities = try? context.fetch(request) {
            for entity in entities {
                context.delete(entity)
            }
            CoreDataManager.shared.saveContext()
        }

        currentUserId = nil
        fetchedResultsController = nil
        tags = []
    }
}

// MARK: - NSFetchedResultsControllerDelegate

extension PlanTagManager: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        DispatchQueue.main.async {
            self.updateTags()
        }
    }
}
