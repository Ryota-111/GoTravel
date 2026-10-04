import Testing
import Foundation
@testable import GoTravel

/// 共有メニューの拡張とアプリの間の、受け取り箱のファイル名の決まり
struct SharedImportInboxTests {

    @Test("ファイル名の頭のミリ秒から、送った時刻を読む")
    func readsSentDateFromFileName() {
        let url = URL(fileURLWithPath: "/tmp/SharedImportInbox/1790000000123-6F1C2A4B-1111-2222-3333-444455556666.txt")
        #expect(SharedImportInbox.sentDate(of: url) == Date(timeIntervalSince1970: 1_790_000_000.123))
    }

    @Test("決まりに合わない名前のファイルは読まない")
    func ignoresUnknownNames() {
        #expect(SharedImportInbox.sentDate(of: URL(fileURLWithPath: "/tmp/memo.txt")) == nil)
        #expect(SharedImportInbox.sentDate(of: URL(fileURLWithPath: "/tmp/.DS_Store")) == nil)
    }
}
