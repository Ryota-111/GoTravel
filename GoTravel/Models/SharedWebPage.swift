import Foundation

// MARK: - 共有した旅行計画をウェブで見る（3.5）
//
// 「Android の友達と共有できない」「ウェブからも見たい」というご意見から。
// 共有画面で「ウェブでも見られるようにする」をオンにした旅行だけ、公式サイトの
// `https://travory-web.pages.dev/s/<共有コード>` で、アプリが無くても（Android でも）見られる。見るだけで、直せない。
//
// オン・オフは共有レコード（パブリックDBの `SharedTravelPlan`）の `webViewEnabled`（1 / 0）に持つ。
// - アプリの共有の保存（`applySharedPlanFields`）はこの項目に触らないので、ほかの人が予定を直しても消えない
// - 共有をやめるとレコードごと消えるので、オフに戻る
// - **Production へのスキーマの反映が要る**（`docs/設計_ウェブで見る.md`）。反映していないと、オンにする保存だけが失敗する
// ページはサイトの側（`travory-web` の `functions/`）がサーバーで組み立てる。オフの旅行は「見られません」になる

enum SharedWebPage {
    /// 共有レコードの項目名
    static let fieldKey = "webViewEnabled"

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

    /// 見るページの URL
    static func url(for shareCode: String, baseURL: String = baseURL) -> URL? {
        URL(string: "\(baseURL)/s/\(shareCode)")
    }

    // MARK: 画面を開いたときにすぐ出すための覚え書き（本当の値は共有レコード）

    private static func cacheKey(_ planId: String) -> String { "sharedWebPage.enabled.\(planId)" }

    static func cachedEnabled(planId: String, defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: cacheKey(planId))
    }

    static func cache(_ enabled: Bool, planId: String, defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: cacheKey(planId))
    }

    /// 共有レコードの値を読む（無ければオフ）
    static func isEnabled(_ value: Any?) -> Bool {
        (value as? NSNumber)?.intValue == 1 || (value as? Int) == 1 || (value as? Int64) == 1
    }
}
