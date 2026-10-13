import Testing
import Foundation
import CoreData
import CloudKit
@testable import GoTravel

/// データの診断。旅行計画が見当たらないときに、どこにあるのかを正しく言い当てること
@MainActor
struct DataDiagnosticsTests {

    // MARK: - 判定

    private func report(local: DataDiagnostics.LocalCounts = .init(),
                        status: CKAccountStatus? = .available,
                        cloud: DataDiagnostics.CloudResult) -> DataDiagnostics.Report {
        DataDiagnostics.Report(userId: "me", accountStatus: status, local: local, cloud: cloud,
                               backupCount: nil, backupSavedAt: nil, log: [])
    }

    private func counts(travel: Int = 0, trash: Int = 0, other: Int = 0) -> DataDiagnostics.CloudCounts {
        var counts = DataDiagnostics.CloudCounts()
        counts.travelPlans = travel
        counts.trashedTravelPlans = trash
        counts.otherUserTravelPlans = other
        return counts
    }

    @Test("端末にあれば問題なし。iCloud のほうが多ければ読み込み途中")
    func localPlans() {
        var local = DataDiagnostics.LocalCounts()
        local.travelPlans = 3
        #expect(report(local: local, cloud: .counted(counts(travel: 3))).verdict == .fine(count: 3))
        #expect(report(local: local, cloud: .failed("x")).verdict == .fine(count: 3))
        #expect(report(local: local, cloud: .counted(counts(travel: 5))).verdict == .partiallyLoaded(local: 3, cloud: 5))
    }

    @Test("端末に別の ID の旅行計画があれば、それを先に知らせる")
    func otherUser() {
        var local = DataDiagnostics.LocalCounts()
        local.otherUserTravelPlans = ["old": 2]
        #expect(report(local: local, cloud: .counted(counts())).verdict == .otherUser(count: 2))
    }

    @Test("ゴミ箱にだけあるときは、ゴミ箱を案内する")
    func trash() {
        var local = DataDiagnostics.LocalCounts()
        local.trashedTravelPlans = 1
        #expect(report(local: local, cloud: .counted(counts())).verdict == .inTrash(count: 1))
    }

    @Test("iCloud が使えないときは、iCloud の確認を案内する")
    func unavailable() {
        #expect(report(status: .temporarilyUnavailable, cloud: .skipped).verdict == .iCloudUnavailable)
        #expect(report(status: .noAccount, cloud: .skipped).verdict == .iCloudUnavailable)
    }

    @Test("端末が空で iCloud にあれば、iCloud に残っていると知らせる")
    func cloudHasData() {
        #expect(report(cloud: .counted(counts(travel: 4))).verdict == .cloudHasData(count: 4))
        #expect(report(cloud: .counted(counts(other: 2))).verdict == .cloudHasData(count: 2))
    }

    @Test("iCloud にも無いとき・削除されたとき・確かめられないとき")
    func cloudMissing() {
        #expect(report(cloud: .counted(counts())).verdict == .cloudEmpty)
        #expect(report(cloud: .zoneMissing).verdict == .cloudEmpty)
        #expect(report(cloud: .zoneDeleted).verdict == .cloudDeleted)
        #expect(report(cloud: .failed("CKErrorDomain 4")).verdict == .unknown)
    }

    // MARK: - 端末の中を数える・取り戻す

    private func makeContext() throws -> NSManagedObjectContext {
        let model = CoreDataManager.shared.persistentContainer.managedObjectModel
        let container = NSPersistentContainer(name: "DiagnosticsTest", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError { throw loadError }
        return container.viewContext
    }

    @discardableResult
    private func insertTravelPlan(_ context: NSManagedObjectContext, userId: String?, ownerId: String? = nil,
                                  deleted: Bool = false) -> NSManagedObject {
        let object = NSEntityDescription.insertNewObject(forEntityName: "TravelPlanEntity", into: context)
        object.setValue(UUID().uuidString, forKey: "id")
        object.setValue(userId, forKey: "userId")
        object.setValue(ownerId, forKey: "ownerId")
        object.setValue(deleted ? Date() : nil, forKey: "deletedAt")
        return object
    }

    @Test("端末の中を、自分・ゴミ箱・別の ID に分けて数える。共有で参加したものは自分の分")
    func countsLocal() throws {
        let context = try makeContext()
        insertTravelPlan(context, userId: "me")
        insertTravelPlan(context, userId: "me", ownerId: "friend")   // 共有で参加した
        insertTravelPlan(context, userId: "me", deleted: true)
        insertTravelPlan(context, userId: "old")
        insertTravelPlan(context, userId: "old")
        try context.save()

        let counts = DataDiagnostics.countLocal(userId: "me", context: context)
        #expect(counts.travelPlans == 2)
        #expect(counts.trashedTravelPlans == 1)
        #expect(counts.otherUserTravelPlans == ["old": 2])
    }

    @Test("別の ID の分を今の人に付け替える。共有で参加した旅行の持ち主は変えない")
    func adoptsOtherUserData() throws {
        let context = try makeContext()
        let own = insertTravelPlan(context, userId: "old", ownerId: "old")
        let joined = insertTravelPlan(context, userId: "old", ownerId: "friend")
        try context.save()

        let changed = DataDiagnostics.adoptOtherUserData(into: "me", context: context)
        #expect(changed == 2)
        #expect(own.value(forKey: "userId") as? String == "me")
        #expect(own.value(forKey: "ownerId") as? String == "me")
        #expect(joined.value(forKey: "userId") as? String == "me")
        #expect(joined.value(forKey: "ownerId") as? String == "friend")
        #expect(DataDiagnostics.countLocal(userId: "me", context: context).travelPlans == 2)
    }

    // MARK: - 送る文

    @Test("送る文に、判定・件数・記録が入り、ID は末尾だけ")
    func text() {
        var local = DataDiagnostics.LocalCounts()
        local.otherUserTravelPlans = ["001234.abcdefabcdef.0999": 1]
        var r = DataDiagnostics.Report(userId: "001234.abcdefabcdef.1234", accountStatus: .available, local: local,
                                       cloud: .counted(counts(travel: 2)), backupCount: nil, backupSavedAt: nil,
                                       log: [.init(kind: .import, date: Date(), succeeded: false, error: "CKErrorDomain 25")])
        r.date = Date()
        let text = DataDiagnostics.text(for: r)
        #expect(text.contains("判定: otherUser(1)"))
        #expect(text.contains("ID末尾: f.1234"))
        #expect(text.contains("f.0999=1"))
        #expect(text.contains("iCloud内: 旅行2"))
        #expect(text.contains("import NG CKErrorDomain 25"))
        #expect(!text.contains("abcdefabcdef"))
    }
}

/// 同期の記録
struct SyncDiagnosticsLogTests {

    private func defaults() -> UserDefaults {
        let name = "SyncDiagnosticsLogTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test("旅行計画の件数は、減ったときと 0 から戻ったときだけ残す")
    func planCount() {
        let d = defaults()
        SyncDiagnosticsLog.recordPlanCount(5, defaults: d)   // 最初は比べる相手が無い
        SyncDiagnosticsLog.recordPlanCount(6, defaults: d)   // 増えた
        SyncDiagnosticsLog.recordPlanCount(0, defaults: d)   // 消えた
        SyncDiagnosticsLog.recordPlanCount(6, defaults: d)   // 戻った
        #expect(SyncDiagnosticsLog.entries(defaults: d).compactMap(\.detail) == ["6 → 0", "0 → 6"])
    }

    @Test("成功が続く同期は最後の1件だけ、失敗はすべて残す")
    func collapsesSuccesses() {
        let d = defaults()
        let start = Date(timeIntervalSince1970: 0)
        SyncDiagnosticsLog.record(kind: .import, date: start, succeeded: true, error: nil, defaults: d)
        SyncDiagnosticsLog.record(kind: .import, date: start.addingTimeInterval(1), succeeded: true, error: nil, defaults: d)
        SyncDiagnosticsLog.record(kind: .export, date: start.addingTimeInterval(2), succeeded: false, error: "e", defaults: d)
        SyncDiagnosticsLog.record(kind: .export, date: start.addingTimeInterval(3), succeeded: false, error: "e", defaults: d)
        let entries = SyncDiagnosticsLog.entries(defaults: d)
        #expect(entries.count == 3)
        #expect(entries.first?.date == start.addingTimeInterval(1))
    }

    @Test("アカウントの状態は変わったときだけ残し、古いものから捨てる")
    func accountAndLimit() {
        let d = defaults()
        SyncDiagnosticsLog.recordAccount(.available, defaults: d)
        SyncDiagnosticsLog.recordAccount(.available, defaults: d)
        SyncDiagnosticsLog.recordAccount(.temporarilyUnavailable, defaults: d)
        #expect(SyncDiagnosticsLog.entries(defaults: d).compactMap(\.detail) == ["available", "temporarilyUnavailable"])

        for i in 0..<(SyncDiagnosticsLog.limit + 5) {
            SyncDiagnosticsLog.record(kind: .export, date: Date(timeIntervalSince1970: Double(i)),
                                      succeeded: false, error: "\(i)", defaults: d)
        }
        #expect(SyncDiagnosticsLog.entries(defaults: d).count == SyncDiagnosticsLog.limit)
    }
}
