import Foundation

/// 提携先（アソビュー / A8.net）へのリンク。
///
/// A8.net の商品リンクは、`px.a8.net` を経由するのではなく
/// **遷移先URLに `a8=` という追跡パラメータを付けた直リンク**として発行される。
///
/// ```
/// https://www.asoview.com/search/?keyword=%E6%9D%B1%E4%BA%AC&a8=<トークン>
/// ```
///
/// キーワードは通常のクエリなので、`a8=` を保ったまま差し替えれば
/// 任意の地名・施設名で検索できる。
///
/// - 未設定（空文字）のあいだは、アプリ内に導線が一切出ない。
/// - **掲載する場合はプライバシーポリシー §3.4 の
///   "The App does NOT display advertisements." を先に修正する必要がある。**
/// - 景品表示法（ステマ規制）により広告であることの表示が必須。
///   表示は `AffiliateLinkRow` が担っているので、提携リンクは必ずあれを通す。
enum AffiliateLink {

    /// A8.net の商品リンクに付く追跡パラメータ（`a8=` の値）。
    /// 管理画面で発行したリンクから、`a8=` より後ろの値だけを貼る
    private static let asoviewTrackingToken = "pwyQew5093Csj480j-gW0tI9Cba263ybr-6W5PCMTWG09tyDF3B8Ety0EPAOBOR6fWl3kSy8fwyQYs00000019330001"

    /// 遷移先は提携先ドメイン内に固定する。
    /// 広告主URL以外へのリンクは提携解除の対象になるため、
    /// ユーザー入力を混ぜるのはキーワードの値だけに限る
    private static let asoviewSearchBase = "https://www.asoview.com/search/"

    static var isAsoviewAvailable: Bool {
        !asoviewTrackingToken.isEmpty
    }

    /// 地名や施設名で検索した結果ページへ送る。
    ///
    /// アソビュー内の商品ページを施設名から特定する手段（API・商品DB）が
    /// 無いため、商品ページへの直リンクはできない。検索結果を出す形にしている。
    /// 0件になりうるので、UIの文言は「探す」に留めること。
    static func asoviewSearchURL(keyword: String) -> URL? {
        guard !asoviewTrackingToken.isEmpty else { return nil }

        var query = "a8=\(asoviewTrackingToken)"

        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty,
           // 記号をすべてエンコードする。`&` や `+` を含む地名でURLが壊れないようにする
           let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .alphanumerics) {
            query = "keyword=\(encoded)&" + query
        }

        return URL(string: "\(asoviewSearchBase)?\(query)")
    }
}
