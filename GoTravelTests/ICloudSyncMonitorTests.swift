import Testing
import Foundation
import CloudKit
@testable import GoTravel

/// iCloud が使えない・保存できていないときの知らせ方
struct ICloudSyncMonitorTests {

    @Test("サインインしていない・確認待ち・機能制限は知らせる")
    func accountProblems() {
        #expect(ICloudSyncMonitor.problem(for: .noAccount) == .notSignedIn)
        #expect(ICloudSyncMonitor.problem(for: .temporarilyUnavailable) == .temporarilyUnavailable)
        #expect(ICloudSyncMonitor.problem(for: .restricted) == .restricted)
    }

    @Test("使えるとき・分からないとき（圏外など）は知らせない")
    func noAlarmWhenAvailableOrUnknown() {
        #expect(ICloudSyncMonitor.problem(for: .available) == nil)
        #expect(ICloudSyncMonitor.problem(for: .couldNotDetermine) == nil)
        #expect(ICloudSyncMonitor.problem(for: nil) == nil)
    }

    @Test("容量がいっぱいのエラーを見分ける（まとめて送ったうちの一部でも）")
    func quotaErrors() {
        #expect(ICloudSyncMonitor.isQuotaError(CKError(.quotaExceeded)))
        let partial = CKError(.partialFailure, userInfo: [
            CKPartialErrorsByItemIDKey: [CKRecord.ID(recordName: "a"): CKError(.quotaExceeded)]
        ])
        #expect(ICloudSyncMonitor.isQuotaError(partial))
        #expect(!ICloudSyncMonitor.isQuotaError(CKError(.networkUnavailable)))
        #expect(!ICloudSyncMonitor.isQuotaError(nil))
    }
}
