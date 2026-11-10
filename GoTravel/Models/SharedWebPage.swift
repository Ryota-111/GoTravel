import Foundation

// MARK: - 共有した旅行計画をウェブで見る（3.5）
//
// 「Android の友達と共有できない」「ウェブからも見たい」というご意見から。
// 共有画面で「ウェブでも見られるようにする」をオンにした旅行だけ、公式サイトの
// `https://travory-web.pages.dev/v/<計画のID>/<見る用の合言葉>` で、アプリが無くても（Android でも）見られる。見るだけで、直せない。
//
// **リンクに共有コードを入れない。** 共有コードは「共有に参加」の合言葉で、参加すると直せる。
// 見るだけのつもりで送ったリンクから、直せる人が増えてはいけない（ultrareview の指摘）。
// 見る用の合言葉（`webViewToken`）はオンにするたびに作り直し、オフにすると消す。オフにすれば前のリンクはもう開けない。
//
// オン・オフは共有レコード（パブリックDBの `SharedTravelPlan`）の `webViewEnabled`（1 / 0）と `webViewToken` に持つ。
// - アプリの共有の保存（`applySharedPlanFields`）はこの項目に触らないので、ほかの人が予定を直しても消えない
// - 共有をやめるとレコードごと消えるので、オフに戻る
// - **Production へのスキーマの反映が要る**（`docs/設計_ウェブで見る.md`）。反映していないと、オンにする保存だけが失敗する
// ページはサイトの側（`travory-web` の `functions/`）がサーバーで組み立てる。オフの旅行は「見られません」になる

enum SharedWebPage {
    /// 共有レコードの項目名
    static let fieldKey = "webViewEnabled"
    /// 見る用の合言葉（共有コードとは別。オンにするたびに作り直す）
    static let tokenKey = "webViewToken"

    /// 本番のサイト（App Store の版。iCloud の Production を読む）
    static let productionBaseURL = "https://travory-web.pages.dev"
    /// テスト用のサイト（Xcode から動かした版。iCloud の Development を読む）。
    /// travory-web の `dev` ブランチを push すると、Cloudflare がここへ出す
    static let developmentBaseURL = "https://dev.travory-web.pages.dev"

    /// Xcode から動かした版は Development の iCloud に書くので、それを読めるテスト用のサイトを開く
    static var baseURL: String {
        #if DEBUG
        developmentBaseURL
        #else
        productionBaseURL
        #endif
    }

    /// 見るページの URL。共有コードは入れない
    static func url(planId: String, token: String, baseURL: String = baseURL) -> URL? {
        URL(string: "\(baseURL)/v/\(planId)/\(token)")
    }

    /// 見る用の合言葉を新しく作る（英数字24文字。当てずっぽうでは当たらない長さ）
    static func newToken() -> String {
        let letters = Array("ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789")
        var generator = SystemRandomNumberGenerator()
        return String((0..<24).map { _ in letters[Int(generator.next(upperBound: UInt64(letters.count)))] })
    }

    /// 共有レコードの値から、見る用の合言葉を読む。オフ・合言葉が無いときは nil
    static func token(enabled: Any?, token: Any?) -> String? {
        guard isEnabled(enabled), let token = token as? String, !token.isEmpty else { return nil }
        return token
    }

    // MARK: 画面を開いたときにすぐ出すための覚え書き（本当の値は共有レコード）

    private static func cacheKey(_ planId: String) -> String { "sharedWebPage.token.\(planId)" }

    /// 覚えている合言葉（nil ならオフ）
    static func cachedToken(planId: String, defaults: UserDefaults = .standard) -> String? {
        defaults.string(forKey: cacheKey(planId))
    }

    static func cache(token: String?, planId: String, defaults: UserDefaults = .standard) {
        if let token { defaults.set(token, forKey: cacheKey(planId)) } else { defaults.removeObject(forKey: cacheKey(planId)) }
    }

    /// 共有レコードの値を読む（無ければオフ）
    static func isEnabled(_ value: Any?) -> Bool {
        (value as? NSNumber)?.intValue == 1 || (value as? Int) == 1 || (value as? Int64) == 1
    }
}
