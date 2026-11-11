import Testing
import Foundation
@testable import GoTravel

/// 予定の添付（3.5）。ファイル名から、どの予定の添付かを読み分ける
struct ScheduleAttachmentStoreTests {

    @Test("ファイル名に予定の id と名前を入れ、名前に使えない文字は除く")
    func fileName() {
        let name = ScheduleAttachmentStore.fileName(itemId: "ITEM-1", name: "eチケット/往路:便", fileExtension: "pdf",
                                                    date: Date(timeIntervalSince1970: 1_000))
        #expect(name.hasPrefix("ITEM-1__0000001000000"))
        #expect(name.hasSuffix("__eチケット往路便.pdf"))
        #expect(ScheduleAttachmentStore.itemId(of: name) == "ITEM-1")
        #expect(ScheduleAttachment(fileName: name).displayName == "eチケット往路便.pdf")
        #expect(ScheduleAttachment(fileName: name).isPDF)
    }

    @Test("予定ごとに足した順で分け、関係ないファイルは入れない")
    func group() {
        let first = ScheduleAttachmentStore.fileName(itemId: "A", name: "写真", fileExtension: "jpg", date: Date(timeIntervalSince1970: 1))
        let second = ScheduleAttachmentStore.fileName(itemId: "A", name: "控え", fileExtension: "pdf", date: Date(timeIntervalSince1970: 2))
        let other = ScheduleAttachmentStore.fileName(itemId: "B", name: "地図", fileExtension: "png", date: Date(timeIntervalSince1970: 3))
        let grouped = ScheduleAttachmentStore.group(fileNames: [second, other, first, ".DS_Store", "memo.txt", "A__x__y.txt"])
        #expect(grouped["A"]?.map(\.fileName) == [first, second])
        #expect(grouped["B"]?.count == 1)
        #expect(grouped.count == 2)
    }

    @Test("長すぎる名前は切る。区切りの文字が名前に入っていても読み分けられる")
    func longAndSeparatorNames() {
        let long = String(repeating: "あ", count: 100)
        let name = ScheduleAttachmentStore.fileName(itemId: "A", name: long, fileExtension: "pdf", date: Date())
        #expect(ScheduleAttachment(fileName: name).displayName == String(repeating: "あ", count: 60) + ".pdf")

        let tricky = ScheduleAttachmentStore.fileName(itemId: "A", name: "a__b", fileExtension: "pdf", date: Date())
        #expect(ScheduleAttachmentStore.itemId(of: tricky) == "A")
        #expect(ScheduleAttachment(fileName: tricky).displayName == "a_b.pdf")
    }
}
