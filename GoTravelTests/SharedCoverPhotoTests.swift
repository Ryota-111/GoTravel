import Testing
import Foundation
@testable import GoTravel

/// 共有した旅行のヘッダー写真のルール（`docs/設計_ヘッダー写真の共有.md`）
struct SharedCoverPhotoTests {

    // MARK: - 載せるか

    @Test("写真を変えたら、変えた写真として載せる（全員がこの写真になる）")
    func uploadsExplicitChange() {
        let version = SharedCoverPhoto.uploadVersion(changedLocally: true, remoteVersion: "init-A", hasLocalPhoto: true)
        #expect(version.map(SharedCoverPhoto.isExplicit) == true)
    }

    @Test("まだ誰の写真も載っていなければ、最初の1枚として載せる")
    func uploadsInitialPhoto() {
        let version = SharedCoverPhoto.uploadVersion(changedLocally: false, remoteVersion: nil, hasLocalPhoto: true)
        #expect(version?.hasPrefix("init-") == true)
    }

    @Test("ほかの人の写真が載っていれば、自分の前からの写真では上書きしない")
    func doesNotOverwriteOthersWithOldPhoto() {
        #expect(SharedCoverPhoto.uploadVersion(changedLocally: false, remoteVersion: "init-A", hasLocalPhoto: true) == nil)
        #expect(SharedCoverPhoto.uploadVersion(changedLocally: false, remoteVersion: "set-A", hasLocalPhoto: true) == nil)
    }

    @Test("写真が無ければ載せない")
    func noPhotoNoUpload() {
        #expect(SharedCoverPhoto.uploadVersion(changedLocally: true, remoteVersion: nil, hasLocalPhoto: false) == nil)
    }

    // MARK: - 取り込むか

    @Test("誰かが写真を変えたら、自分の写真があっても全員その写真になる")
    func adoptsExplicitChange() {
        #expect(SharedCoverPhoto.adoption(remoteVersion: "set-B", adoptedVersion: "init-A", hasLocalPhoto: true) == .adopt)
    }

    @Test("最初の1枚は、写真を入れていない人にだけ出す。自分で入れていた人は自分の写真のまま")
    func initialPhotoOnlyForThoseWithoutPhoto() {
        #expect(SharedCoverPhoto.adoption(remoteVersion: "init-A", adoptedVersion: nil, hasLocalPhoto: false) == .adopt)
        #expect(SharedCoverPhoto.adoption(remoteVersion: "init-A", adoptedVersion: nil, hasLocalPhoto: true) == .keepOwn)
    }

    @Test("もう使っている（見た）版なら何もしない")
    func sameVersionDoesNothing() {
        #expect(SharedCoverPhoto.adoption(remoteVersion: "set-B", adoptedVersion: "set-B", hasLocalPhoto: true) == .none)
        #expect(SharedCoverPhoto.adoption(remoteVersion: nil, adoptedVersion: nil, hasLocalPhoto: false) == .none)
    }

    @Test("自分で写真を変えてまだ送れていなければ、届いた写真で上書きしない")
    func localPendingChangeWins() {
        #expect(SharedCoverPhoto.adoption(remoteVersion: "set-B", adoptedVersion: "init-A",
                                          hasLocalPhoto: true, changedLocally: true) == .none)
    }
}
