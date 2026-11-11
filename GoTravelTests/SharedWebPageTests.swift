import Testing
import Foundation
@testable import GoTravel

/// 共有した旅行計画をウェブで見る（3.5）
struct SharedWebPageTests {

    @Test("見るページの URL は /v/<計画のID>/<見る用の合言葉>。共有コード（参加の合言葉）は入れない")
    func url() {
        #expect(SharedWebPage.url(planId: "PLAN-1", token: "abc", baseURL: SharedWebPage.productionBaseURL)?.absoluteString
                == "https://travory-web.pages.dev/v/PLAN-1/abc")
    }

    @Test("見る用の合言葉は毎回ちがう英数字24文字")
    func token() {
        let a = SharedWebPage.newToken()
        let b = SharedWebPage.newToken()
        #expect(a.count == 24)
        #expect(a != b)
        #expect(a.allSatisfy { $0.isLetter || $0.isNumber })
        #expect(SharedWebPage.token(enabled: NSNumber(value: 1), token: "abc") == "abc")
        #expect(SharedWebPage.token(enabled: NSNumber(value: 0), token: "abc") == nil)
        #expect(SharedWebPage.token(enabled: NSNumber(value: 1), token: nil) == nil)
        #expect(SharedWebPage.token(enabled: NSNumber(value: 1), token: "") == nil)
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
        SharedWebPage.cache(token: "t1", planId: "a", defaults: defaults)
        #expect(SharedWebPage.cachedToken(planId: "a", defaults: defaults) == "t1")
        #expect(SharedWebPage.cachedToken(planId: "b", defaults: defaults) == nil)
        SharedWebPage.cache(token: nil, planId: "a", defaults: defaults)
        #expect(SharedWebPage.cachedToken(planId: "a", defaults: defaults) == nil)
    }
}
