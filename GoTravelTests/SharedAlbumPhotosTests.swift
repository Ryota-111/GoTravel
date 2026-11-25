import Testing
import Foundation
@testable import GoTravel

/// 共有した旅行のアルバムの写真（3.8、ご要望から）
struct SharedAlbumPhotosTests {

    private func remote(_ key: String, by user: String, at seconds: TimeInterval = 0) -> SharedAlbumPhotos.RemotePhoto {
        .init(key: key, addedBy: user, createdAt: Date(timeIntervalSince1970: seconds))
    }

    @Test("ファイル名のキーは、アルバムの id を除いた後ろの部分。人によってアルバムの id が違っても同じ写真になる")
    func keyIgnoresAlbumId() {
        #expect(SharedAlbumPhotos.key(fileName: "ALBUM-1_ABC-123.jpg") == "ABC-123")
        #expect(SharedAlbumPhotos.key(fileName: SharedAlbumPhotos.fileName(key: "ABC-123", albumId: "ALBUM-2")) == "ABC-123")
        #expect(SharedAlbumPhotos.key(fileName: "old.jpg") == "old")
    }

    @Test("共有をオンにしていなければ、今までの写真を載せない。同行者の写真は載った順に取り込む")
    func noUploadUntilEnabled() {
        let plan = SharedAlbumPhotos.plan(localKeys: ["mine1"],
                                          remote: [remote("b", by: "friend", at: 2), remote("a", by: "friend", at: 1)],
                                          known: [:], dismissed: [], uploadsEnabled: false, userId: "me")
        #expect(plan.upload.isEmpty)
        #expect(plan.download == ["a", "b"])
    }

    @Test("オンにすると、まだ載っていない自分の写真を載せる")
    func uploadWhenEnabled() {
        let plan = SharedAlbumPhotos.plan(localKeys: ["mine1", "a"], remote: [remote("a", by: "friend")],
                                          known: ["a": "friend"], dismissed: [], uploadsEnabled: true, userId: "me")
        #expect(plan.upload == ["mine1"])
        #expect(plan.download.isEmpty)
    }

    @Test("同行者が共有から消した写真は、手元からも外す。自分の写真は外さない")
    func removedByOwner() {
        let plan = SharedAlbumPhotos.plan(localKeys: ["a", "mine1"], remote: [],
                                          known: ["a": "friend", "mine1": "me"], dismissed: [],
                                          uploadsEnabled: true, userId: "me")
        #expect(plan.removeLocal == ["a"])
        // 前に載っていた自分の写真は、別の端末で共有をやめただけかもしれないので、載せ直さない
        #expect(plan.upload.isEmpty)
    }

    @Test("自分のアルバムから消した同行者の写真は、もう取り込まない")
    func dismissedStaysAway() {
        let plan = SharedAlbumPhotos.plan(localKeys: [], remote: [remote("a", by: "friend")],
                                          known: ["a": "friend"], dismissed: ["a"], uploadsEnabled: false, userId: "me")
        #expect(plan.download.isEmpty)
    }

    @Test("アルバムに並んでいるのにファイルが無い写真は、取り直す")
    func refetchMissingFile() {
        let plan = SharedAlbumPhotos.plan(localKeys: ["a"], missingFileKeys: ["a"], remote: [remote("a", by: "me")],
                                          known: ["a": "me"], dismissed: [], uploadsEnabled: true, userId: "me")
        #expect(plan.refetch == ["a"])
        #expect(plan.upload.isEmpty)
    }

    @Test("消したとき、自分の写真は共有から消し、同行者の写真は取り込まないようにする")
    func removal() {
        let result = SharedAlbumPhotos.removal(keys: ["mine1", "a"], known: ["mine1": "me", "a": "friend"], userId: "me")
        #expect(result.deleteRemote == ["mine1"])
        #expect(result.dismiss == ["a"])
    }
}
