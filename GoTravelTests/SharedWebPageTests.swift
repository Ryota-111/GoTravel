import Testing
import Foundation
@testable import GoTravel

/// 共有した旅行計画をウェブで見る（3.5）
struct SharedWebPageTests {

    @Test("見るページの URL は公式サイトの /s/<共有コード>")
    func url() {
        #expect(SharedWebPage.url(for: "TRAVEL-AB12CD34", baseURL: SharedWebPage.productionBaseURL)?.absoluteString
                == "https://travory-web.pages.dev/s/TRAVEL-AB12CD34")
    }

    @Test("Xcode から動かした版は、Development を読むテスト用のサイトを開く")
    func debugURL() {
        #if DEBUG
        #expect(SharedWebPage.baseURL == "https://dev.travory-web.pages.dev")
        #else
        #expect(SharedWebPage.baseURL == "https://travory-web.pages.dev")
        #endif
    }

    @Test("共有レコードの値は 1 のときだけオン。無い・0・ほかの値はオフ")
    func enabledValue() {
        #expect(SharedWebPage.isEnabled(NSNumber(value: 1)))
        #expect(SharedWebPage.isEnabled(Int64(1)))
        #expect(!SharedWebPage.isEnabled(NSNumber(value: 0)))
        #expect(!SharedWebPage.isEnabled(nil))
        #expect(!SharedWebPage.isEnabled("1"))
    }

    @Test("画面を開いたときの覚え書きは、旅行ごと")
    func cache() throws {
        let defaults = try #require(UserDefaults(suiteName: "SharedWebPageTests"))
        defaults.removePersistentDomain(forName: "SharedWebPageTests")
        SharedWebPage.cache(true, planId: "a", defaults: defaults)
        #expect(SharedWebPage.cachedEnabled(planId: "a", defaults: defaults))
        #expect(!SharedWebPage.cachedEnabled(planId: "b", defaults: defaults))
    }
}
