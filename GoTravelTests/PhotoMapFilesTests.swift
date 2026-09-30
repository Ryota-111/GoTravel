import Testing
import Foundation
@testable import GoTravel

/// フォトマップの写真の並び。
///
/// 県の読み違えや代表の入れ替えの誤りは、地図に別の県の写真が出たり、
/// 移し替えで写真が消えたりすることにつながる
struct PhotoMapFilesTests {

    @Test("新しいファイル名と 2.7 までのファイル名の両方から県を読める")
    func readsPrefectureFromBothFormats() {
        let newName = PhotoMapFiles.newFileName(for: .okinawa)

        #expect(newName.hasPrefix("okinawa__"))
        #expect(PhotoMapFiles.prefecture(of: newName) == .okinawa)
        #expect(PhotoMapFiles.prefecture(of: "tokyo.jpg") == .tokyo)
        #expect(PhotoMapFiles.prefecture(of: "unknown__abc.jpg") == nil)
    }

    @Test("県ごとに並びの順のまま分け、先頭が代表になる")
    func groupsInOrder() {
        let files = ["tokyo__a.jpg", "kyoto__b.jpg", "tokyo__c.jpg"]

        #expect(PhotoMapFiles.photos(of: .tokyo, in: files) == ["tokyo__a.jpg", "tokyo__c.jpg"])
        #expect(PhotoMapFiles.cover(of: .tokyo, in: files) == "tokyo__a.jpg")
        #expect(PhotoMapFiles.prefectureCount(in: files) == 2)
    }

    @Test("代表にすると、同じ県の中で先頭に来て、他の県の並びは変わらない")
    func makingCoverKeepsOthers() {
        let files = ["kyoto__x.jpg", "tokyo__a.jpg", "osaka__y.jpg", "tokyo__b.jpg"]

        let result = PhotoMapFiles.makingCover("tokyo__b.jpg", in: files)

        #expect(result == ["kyoto__x.jpg", "tokyo__b.jpg", "tokyo__a.jpg", "osaka__y.jpg"])
        #expect(PhotoMapFiles.cover(of: .tokyo, in: result) == "tokyo__b.jpg")
    }

    @Test("県ごとの上限まで足せる")
    func remainingSlots() {
        let files = (0..<28).map { "tokyo__\($0).jpg" }

        #expect(PhotoMapFiles.remainingSlots(for: .tokyo, in: files) == 2)
        #expect(PhotoMapFiles.remainingSlots(for: .kyoto, in: files) == PhotoMapFiles.maxPhotosPerPrefecture)
    }

    /// 別の端末で移し替え済みの並びが同期されてきていても、どちらの写真も残す
    @Test("2.7 までの県の一覧は、既存の並びに足し合わせる")
    func mergesLegacyWithoutLosing() {
        let synced = ["tokyo.jpg", "kyoto__b.jpg"]

        let merged = PhotoMapFiles.mergingLegacy(prefectures: ["tokyo", "osaka", "nowhere"], into: synced)

        #expect(merged == ["tokyo.jpg", "kyoto__b.jpg", "osaka.jpg"])
    }
}
