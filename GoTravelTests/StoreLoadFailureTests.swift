import Testing
import Foundation
import CoreData
@testable import GoTravel

/// データを開けなかったとき（3.8。3.6 までは起動した瞬間に落ちていた）
struct StoreLoadFailureTests {

    @Test("元のエラーと SQLite の番号をたどって、番号だけを送る（ファイルの場所などの説明文は送らない）")
    func summarizesErrorChain() {
        let sqlite = NSError(domain: NSSQLiteErrorDomain, code: 13,
                             userInfo: [NSFilePathErrorKey: "/var/mobile/Containers/Data/secret.sqlite"])
        let error = NSError(domain: NSCocoaErrorDomain, code: 134110,
                            userInfo: [NSUnderlyingErrorKey: sqlite,
                                       NSLocalizedDescriptionKey: "/var/mobile/Containers/Data/secret.sqlite"])
        let failure = StoreLoadFailure(error, availableCapacity: 2_500_000_000)

        #expect(failure.underlying == ["NSSQLiteErrorDomain 13"])
        #expect(failure.diagnosticText.contains("エラー: NSCocoaErrorDomain 134110"))
        #expect(failure.diagnosticText.contains("元のエラー: NSSQLiteErrorDomain 13"))
        #expect(failure.diagnosticText.contains("空き容量: 約 2.5GB"))
        #expect(!failure.diagnosticText.contains("secret"))
        #expect(failure.shortCode == "NSCocoaErrorDomain 134110 / NSSQLiteErrorDomain 13")
    }

    @Test("SQLite が「いっぱい」と言うか、空きが 200MB を切っていたら、空き容量の案内を出す")
    func lowStorage() {
        #expect(StoreLoadFailure(domain: NSCocoaErrorDomain, code: 134110, underlying: ["NSSQLiteErrorDomain 13"]).looksLikeLowStorage)
        #expect(StoreLoadFailure(domain: NSCocoaErrorDomain, code: 256, availableCapacity: 150_000_000).looksLikeLowStorage)
        #expect(!StoreLoadFailure(domain: NSCocoaErrorDomain, code: 256, availableCapacity: 5_000_000_000).looksLikeLowStorage)
        #expect(!StoreLoadFailure(domain: NSCocoaErrorDomain, code: 256).looksLikeLowStorage)
    }

    @Test("空き容量は、だいたいの大きさだけにする")
    func capacityLabel() {
        #expect(StoreLoadFailure.capacityLabel(40_000_000) == "100MB 未満")
        #expect(StoreLoadFailure.capacityLabel(450_000_000) == "約 400MB")
        #expect(StoreLoadFailure.capacityLabel(12_340_000_000) == "約 12.3GB")
    }

    @Test("端末のロックで読めなかったとき（SQLite の 23）は、それと分かる（開発者には送らない）")
    func deviceLocked() {
        #expect(StoreLoadFailure(domain: NSCocoaErrorDomain, code: 256, underlying: ["NSSQLiteErrorDomain 23"]).isDeviceLocked)
        #expect(!StoreLoadFailure(domain: NSCocoaErrorDomain, code: 256, underlying: ["NSSQLiteErrorDomain 4618"]).isDeviceLocked)
    }
}
