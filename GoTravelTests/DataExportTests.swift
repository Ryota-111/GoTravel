import Testing
import Foundation
import CoreData
@testable import GoTravel

/// データの書き出し・読み込み（3.0）。読み込みで消えない・2重にならない・古いファイルも読めること
@MainActor
struct DataExportTests {

    private func makeContext() throws -> NSManagedObjectContext {
        let model = CoreDataManager.shared.persistentContainer.managedObjectModel
        let container = NSPersistentContainer(name: "ExportTest", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError { throw loadError }
        return container.viewContext
    }

    private let start = Date(timeIntervalSince1970: 1_790_000_000)

    private func trip(_ id: String, title: String = "沖縄旅行", updatedAt: Date? = nil, shared: Bool = false) -> TravelPlan {
        var plan = TravelPlan(id: id, title: title, startDate: start, endDate: start.addingTimeInterval(86_400),
                              destination: "沖縄", userId: "old", updatedAt: updatedAt ?? start)
        if shared {
            plan.isShared = true
            plan.shareCode = "TRAVEL-ABCDEFGH"
            plan.sharedWith = ["old", "friend"]
            plan.ownerId = "old"
        }
        plan.reservations = [Reservation(kind: .flight, title: "羽田 → 那覇", date: start, confirmationNumber: "ABC123")]
        return plan
    }

    private func export(travelPlans: [TravelPlan] = [], plans: [Plan] = [], places: [VisitedPlace] = []) -> TravoryExport {
        var export = TravoryExport()
        export.travelPlans = travelPlans.map { .init(plan: $0, deletedAt: nil) }
        export.plans = plans
        export.places = places
        return export
    }

    // MARK: - 読み込みの決まり

    @Test("旅行計画は、無ければ足し、ファイルが新しく共有していなければ置き換え、共有していれば触らない")
    func travelPlanRule() {
        #expect(TravoryImportRule.travelPlanAction(fileUpdatedAt: start, localUpdatedAt: nil, localIsShared: false) == .add)
        #expect(TravoryImportRule.travelPlanAction(fileUpdatedAt: start.addingTimeInterval(10), localUpdatedAt: start, localIsShared: false) == .replace)
        #expect(TravoryImportRule.travelPlanAction(fileUpdatedAt: start, localUpdatedAt: start.addingTimeInterval(10), localIsShared: false) == .keep)
        #expect(TravoryImportRule.travelPlanAction(fileUpdatedAt: start.addingTimeInterval(10), localUpdatedAt: start, localIsShared: true) == .keep)
    }

    @Test("読み込んだ旅行計画は、今の人の共有していない計画になる")
    func detached() {
        let plan = TravoryImportRule.detached(trip("a", shared: true), userId: "me")
        #expect(plan.userId == "me")
        #expect(plan.isShared == false)
        #expect(plan.shareCode == nil)
        #expect(plan.sharedWith.isEmpty)
        #expect(plan.ownerId == nil)
    }

    // MARK: - 読み込む

    @Test("端末に無いものを足し、あるものはそのまま。読み込みで消えるものは無い")
    func applyAddsMissing() throws {
        let context = try makeContext()
        _ = TravelPlanEntity.create(from: TravoryImportRule.detached(trip("keep", title: "手元の計画", updatedAt: start.addingTimeInterval(100)), userId: "me"), context: context)
        _ = TravelPlanEntity.create(from: TravoryImportRule.detached(trip("local-only", title: "手元にだけある"), userId: "me"), context: context)
        try context.save()

        let file = export(
            travelPlans: [trip("keep", title: "古いファイルの計画"), trip("new", title: "新しく足す")],
            plans: [Plan(id: "p", title: "歯医者", startDate: start, endDate: start, places: [], planType: .daily)],
            places: [VisitedPlace(id: "v", title: "首里城", latitude: 26.2, longitude: 127.7)]
        )
        let result = DataExportService.apply(file, userId: "me", context: context)
        #expect(result.added == 3)
        #expect(result.kept == 1)

        let plans = try TravelPlanEntity.fetchByUser(userId: "me", context: context).map { $0.toTravelPlan() }
        #expect(Set(plans.compactMap(\.id)) == ["keep", "local-only", "new"])
        #expect(plans.first { $0.id == "keep" }?.title == "手元の計画")
        #expect(plans.first { $0.id == "new" }?.reservations.first?.confirmationNumber == "ABC123")
        #expect(try PlanEntity.fetchById(id: "p", context: context)?.userId == "me")
        #expect(try VisitedPlaceEntity.fetchById(id: "v", context: context)?.userId == "me")

        // 同じファイルをもう一度読んでも2重にならない
        let again = DataExportService.apply(file, userId: "me", context: context)
        #expect(again.added == 0)
        #expect(try TravelPlanEntity.fetchByUser(userId: "me", context: context).count == 3)
    }

    @Test("ファイルの内容に戻すと、手元のほうが新しくてもファイルの内容になる。手元にだけあるものは残る")
    func restoreReplacesNewerLocal() throws {
        let context = try makeContext()
        _ = TravelPlanEntity.create(from: TravoryImportRule.detached(trip("keep", title: "あとで直した計画", updatedAt: start.addingTimeInterval(100)), userId: "me"), context: context)
        _ = TravelPlanEntity.create(from: TravoryImportRule.detached(trip("local-only", title: "手元にだけある"), userId: "me"), context: context)
        try context.save()

        let now = start.addingTimeInterval(1_000)
        let file = export(travelPlans: [trip("keep", title: "書き出したときの計画")])
        let result = DataExportService.apply(file, userId: "me", context: context, mode: .restore, now: now)
        #expect(result.replaced == 1)

        let plans = try TravelPlanEntity.fetchByUser(userId: "me", context: context).map { $0.toTravelPlan() }
        #expect(plans.first { $0.id == "keep" }?.title == "書き出したときの計画")
        #expect(plans.first { $0.id == "keep" }?.updatedAt == now)
        #expect(plans.contains { $0.id == "local-only" })

        // 同じ中身なら置き換えない
        let again = DataExportService.apply(file, userId: "me", context: context, mode: .restore, now: now.addingTimeInterval(10))
        #expect(again.replaced == 0)
        #expect(again.kept == 1)
    }

    @Test("共有中の旅行計画を戻すと、共有の情報は手元のまま、自分が今直したことになる（同行者にとどく）")
    func restoreSharedTrip() {
        var local = trip("s", title: "同行者が直した計画", updatedAt: start.addingTimeInterval(100), shared: true)
        local.userId = "me"
        local.shareCode = "TRAVEL-LOCALCOD"
        local.sharedWith = ["old", "friend", "me"]
        var file = trip("s", title: "書き出したときの計画")
        file.shareCode = "TRAVEL-OLDCODE1"
        let now = start.addingTimeInterval(1_000)

        let restored = TravoryImportRule.restored(file, over: local, userId: "me", now: now)
        #expect(restored.title == "書き出したときの計画")
        #expect(restored.isShared)
        #expect(restored.shareCode == "TRAVEL-LOCALCOD")
        #expect(restored.sharedWith == ["old", "friend", "me"])
        #expect(restored.ownerId == "old")
        #expect(restored.lastEditedBy == "me")
        #expect(restored.updatedAt == now)
    }

    @Test("予定を戻すと、中身はファイルの内容、カテゴリは手元のまま。同じ中身なら置き換えない")
    func restorePlan() {
        let now = start.addingTimeInterval(1_000)
        var local = Plan(id: "p", title: "あとで直した予定", startDate: start, endDate: start, places: [], planType: .outing)
            .withSharing(categoryId: "family", lastEditedBy: "friend", updatedAt: start.addingTimeInterval(100))
        local.userId = "me"
        let file = Plan(id: "p", title: "書き出したときの予定", startDate: start, endDate: start, places: [], planType: .outing)

        let restored = TravoryImportRule.restored(file, over: local, userId: "me", now: now)
        #expect(restored?.title == "書き出したときの予定")
        #expect(restored?.categoryId == "family")
        #expect(restored?.lastEditedBy == "me")
        #expect(restored?.updatedAt == now)

        var same = local
        same.lastEditedBy = nil
        same.updatedAt = nil
        same.categoryId = nil
        #expect(TravoryImportRule.restored(same, over: local, userId: "me", now: now) == nil)
    }

    @Test("ゴミ箱に入っていた旅行計画は、ゴミ箱に入ったまま戻る")
    func applyKeepsTrash() throws {
        let context = try makeContext()
        var file = TravoryExport()
        file.travelPlans = [.init(plan: trip("t"), deletedAt: start)]
        DataExportService.apply(file, userId: "me", context: context)
        #expect(try TravelPlanEntity.fetchById(id: "t", context: context)?.deletedAt == start)
    }

    @Test("持ち物の候補は、同じ名前のものを2重にしない")
    func presetsDeduplicated() throws {
        let context = try makeContext()
        let existing = PackingPresetEntity(context: context)
        existing.id = "x"
        existing.name = "充電器"
        existing.kind = PackingItem.Kind.packing.rawValue
        existing.userId = "me"
        try context.save()

        var file = TravoryExport()
        file.packingPresets = [
            .init(id: "y", name: "充電器", kind: PackingItem.Kind.packing.rawValue, order: 0, createdAt: nil),
            .init(id: "z", name: "傘", kind: PackingItem.Kind.packing.rawValue, order: 1, createdAt: nil)
        ]
        DataExportService.apply(file, userId: "me", context: context)
        let names = try PackingPresetEntity.fetchByUser(userId: "me", context: context).compactMap(\.name).sorted()
        #expect(names == ["傘", "充電器"])
    }

    // MARK: - ファイル

    @Test("書き出したファイルを開くと、同じ中身が読める")
    func fileRoundTrip() throws {
        var base = export(travelPlans: [trip("a")])
        base.userId = "me"
        let url = try DataExportService.writeFile(base, includesImages: false, now: start)
        #expect(url.pathExtension == "travory")
        let opened = try DataExportService.open(url)
        defer { try? FileManager.default.removeItem(at: opened.folder) }
        #expect(opened.export.travelPlans.first?.plan.title == "沖縄旅行")
        #expect(opened.export.travelPlans.first?.plan.reservations.first?.confirmationNumber == "ABC123")
        // ファイルには利用者の ID を入れない
        #expect(opened.export.userId == nil)
    }

    @Test("Travory のファイルでなければ読み込めないと伝える")
    func rejectsOtherFiles() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("not-travory-\(UUID().uuidString).txt")
        try "hello".write(to: url, atomically: true, encoding: .utf8)
        #expect(throws: DataExportService.ExportError.self) { try DataExportService.open(url) }
    }

    @Test("古い・知らない項目のあるファイルも読め、読めない1件だけを飛ばす")
    func lenientDecoding() throws {
        let json = """
        {"formatVersion": 9, "unknownField": 1,
         "plans": [{"broken": true},
                   {"id":"p","title":"歯医者","startDate":"2026-10-10T00:00:00Z","endDate":"2026-10-10T00:00:00Z","places":[],"createdAt":"2026-10-01T00:00:00Z"}]}
        """
        let export = try TravoryExport.decoder().decode(TravoryExport.self, from: Data(json.utf8))
        #expect(export.plans.map(\.title) == ["歯医者"])
        #expect(export.travelPlans.isEmpty)
    }

    @Test("写真の場所は、決まったフォルダの下で、上の階層へ出ないものだけ受け付ける")
    func safeImagePaths() {
        #expect(DataExportService.isSafeImagePath("Documents/a.jpg"))
        #expect(DataExportService.isSafeImagePath("Albums/japan/b.jpg"))
        #expect(!DataExportService.isSafeImagePath("Documents/../Library/x"))
        #expect(!DataExportService.isSafeImagePath("/etc/passwd"))
        #expect(!DataExportService.isSafeImagePath("Library/x.jpg"))
    }

    // MARK: - 毎日の控え

    @Test("毎日の控えは、空なら書かず、直近3日分を残し、その人の分だけを返す")
    func snapshots() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("snap-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        var mine = export(travelPlans: [trip("a")])
        mine.userId = "me"
        #expect(!LocalSnapshotStore.save(TravoryExport(), now: start, folder: folder))

        for day in 0..<5 {
            LocalSnapshotStore.save(mine, now: start.addingTimeInterval(Double(day) * 86_400), folder: folder)
        }
        #expect(LocalSnapshotStore.all(folder: folder).count == LocalSnapshotStore.keepDays)
        #expect(LocalSnapshotStore.latest(userId: "me", folder: folder)?.savedAt == start.addingTimeInterval(4 * 86_400))
        #expect(LocalSnapshotStore.latest(userId: "someone", folder: folder) == nil)
    }

    @Test("控えから戻せるのは、iCloud にデータが無いと確かめられたときだけ")
    func restoreOnlyWhenCloudEmpty() {
        #expect(DataDiagnostics.canRestoreFromSnapshot(.cloudEmpty))
        #expect(DataDiagnostics.canRestoreFromSnapshot(.cloudDeleted))
        #expect(!DataDiagnostics.canRestoreFromSnapshot(.cloudHasData(count: 3)))
        #expect(!DataDiagnostics.canRestoreFromSnapshot(.iCloudUnavailable))
        #expect(!DataDiagnostics.canRestoreFromSnapshot(.unknown))
    }
}
