import Foundation
import Combine
import CoreData
import SwiftUI

/// 「よく使う持ち物」などの候補を持つ。
///
/// 候補はコードに直書きされた9個の固定リストだった。人によって要る物は違うので、
/// 自分で足したり消したりできるようにした。旅行ごとではなくユーザーに紐づくので、
/// 一度整えれば次の旅行でもそのまま使える。
///
/// 作りは `PlaceCategoryManager` / `PlanTagManager` に合わせてある。
final class PackingPresetManager: NSObject, ObservableObject {
    static let shared = PackingPresetManager()

    @Published private(set) var presets: [PackingItem.Kind: [Preset]] = [:]

    struct Preset: Identifiable, Equatable {
        let id: String
        var name: String
        var kind: PackingItem.Kind
        var order: Int
    }

    private let context: NSManagedObjectContext
    private var fetchedResultsController: NSFetchedResultsController<PackingPresetEntity>?
    private var currentUserId: String?

    private override init() {
        self.context = CoreDataManager.shared.viewContext
        super.init()
    }

    /// 初回に入れておく候補。
    /// 空のリストに何を書けばいいか分からないと、そこで手が止まる
    static let defaults: [PackingItem.Kind: [String]] = [
        .packing: ["充電器", "モバイルバッテリー", "常備薬", "歯ブラシ",
                   "着替え", "洗面用具", "傘", "身分証", "現金"],
        .souvenir: ["家族へ", "職場へ", "友人へ", "自分用", "お菓子", "ご当地限定"],
        .wish: ["名物を食べる", "温泉に入る", "景色を見に行く",
                "写真を撮る", "地元の店をのぞく", "何もしない時間"]
    ]

    // MARK: - Setup

    /// ユーザーが確定したタイミングで呼ぶ。二重セットアップは行わない
    func setup(userId: String) {
        guard currentUserId != userId else { return }
        currentUserId = userId

        setupFetchedResultsController(userId: userId)
        seedDefaultsIfNeeded(userId: userId)
    }

    private func setupFetchedResultsController(userId: String) {
        let request: NSFetchRequest<PackingPresetEntity> = PackingPresetEntity.fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@", userId)
        request.sortDescriptors = PackingPresetEntity.defaultSortDescriptors

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
            updatePresets()
        } catch {
        }
    }

    private func updatePresets() {
        var grouped: [PackingItem.Kind: [Preset]] = [:]

        for entity in fetchedResultsController?.fetchedObjects ?? [] {
            guard
                let id = entity.id,
                let name = entity.name,
                let kind = PackingItem.Kind(rawValue: entity.kind ?? "")
            else { continue }

            grouped[kind, default: []].append(
                Preset(id: id, name: name, kind: kind, order: Int(entity.order))
            )
        }

        presets = grouped
    }

    /// 初回だけ既定の候補を入れる。
    ///
    /// **1件でも入っていれば何もしない。** 全部消したユーザーに毎回
    /// 復活させると、消した意味が無くなる
    private func seedDefaultsIfNeeded(userId: String) {
        guard !CoreDataManager.isEmptyDataMode else { return }

        let seededKey = "PackingPresetsSeeded_v1"
        guard !UserDefaults.standard.bool(forKey: seededKey) else { return }

        // 他の端末で作ったぶんが同期で降りてきている場合もあるので、実物を見る
        let existing = (try? PackingPresetEntity.fetchByUser(userId: userId, context: context)) ?? []
        guard existing.isEmpty else {
            UserDefaults.standard.set(true, forKey: seededKey)
            return
        }

        for kind in PackingItem.Kind.allCases {
            for (index, name) in (Self.defaults[kind] ?? []).enumerated() {
                let entity = PackingPresetEntity(context: context)
                entity.id = UUID().uuidString
                entity.name = name
                entity.kind = kind.rawValue
                entity.order = Int32(index)
                entity.createdAt = Date()
                entity.userId = userId
            }
        }

        CoreDataManager.shared.saveContext()
        UserDefaults.standard.set(true, forKey: seededKey)
        updatePresets()
    }

    // MARK: - 読み出し

    func presets(for kind: PackingItem.Kind) -> [Preset] {
        presets[kind] ?? []
    }

    func names(for kind: PackingItem.Kind) -> [String] {
        presets(for: kind).map(\.name)
    }

    // MARK: - 編集

    /// 同じ名前を二重に足さない。候補が重複していても選べないだけで意味がない
    func add(name: String, kind: PackingItem.Kind) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let userId = currentUserId else { return }
        guard !names(for: kind).contains(trimmed) else { return }

        let entity = PackingPresetEntity(context: context)
        entity.id = UUID().uuidString
        entity.name = trimmed
        entity.kind = kind.rawValue
        entity.order = Int32((presets(for: kind).map(\.order).max() ?? -1) + 1)
        entity.createdAt = Date()
        entity.userId = userId

        CoreDataManager.shared.saveContext()
        updatePresets()
    }

    func rename(_ preset: Preset, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let entity = try? PackingPresetEntity.fetchById(id: preset.id, context: context)
        else { return }

        entity.name = trimmed
        CoreDataManager.shared.saveContext()
        updatePresets()
    }

    func delete(_ preset: Preset) {
        guard let entity = try? PackingPresetEntity.fetchById(id: preset.id, context: context) else { return }
        context.delete(entity)
        CoreDataManager.shared.saveContext()
        updatePresets()
    }

    func move(kind: PackingItem.Kind, from source: IndexSet, to destination: Int) {
        var list = presets(for: kind)
        list.move(fromOffsets: source, toOffset: destination)

        for (index, preset) in list.enumerated() {
            if let entity = try? PackingPresetEntity.fetchById(id: preset.id, context: context) {
                entity.order = Int32(index)
            }
        }

        CoreDataManager.shared.saveContext()
        updatePresets()
    }

    /// 消しすぎて空になった人が戻せるようにする
    func restoreDefaults(for kind: PackingItem.Kind) {
        for name in Self.defaults[kind] ?? [] {
            add(name: name, kind: kind)
        }
    }
}

// MARK: - NSFetchedResultsControllerDelegate

extension PackingPresetManager: NSFetchedResultsControllerDelegate {
    /// 他の端末から降ってきた変更もここに来る
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        updatePresets()
    }
}
