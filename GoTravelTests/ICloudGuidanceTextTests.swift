import Testing
import Foundation
import CloudKit
@testable import GoTravel

/// 共有で失敗したとき、iCloud の確認手順を出すか「通信環境」の案内を出すか
struct ICloudGuidanceTextTests {

    @Test("サインインしていない・一時的に使えない・書き込みを断られたときは iCloud の案内を出す")
    func accountProblems() {
        #expect(ICloudGuidanceText.isAccountProblem(CKError(.notAuthenticated)))
        #expect(ICloudGuidanceText.isAccountProblem(CKError(.permissionFailure)))
        #expect(ICloudGuidanceText.isAccountProblem(CKError(.accountTemporarilyUnavailable)))
    }

    @Test("通信の失敗などは iCloud の案内にしない")
    func otherErrors() {
        #expect(!ICloudGuidanceText.isAccountProblem(CKError(.networkUnavailable)))
        #expect(!ICloudGuidanceText.isAccountProblem(URLError(.notConnectedToInternet)))
    }
}
