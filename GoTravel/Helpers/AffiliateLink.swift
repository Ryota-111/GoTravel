import Foundation

/// 提携先（アソビュー / A8.net）へのリンク。
///
/// A8.net の商品リンクは `px.a8.net` を経由する形で発行される。
///
/// ```
/// https://px.a8.net/svt/ejp?a8mat=<識別子>&a8ejpredirect=<エンコードした遷移先>
/// ```
///
/// `a8ejpredirect` の遷移先はこちらで組み立てられるので、
/// 任意の地名・施設名で検索できる。
///
/// **クリック後に着地するURL（`asoview.com/...?a8=...`）を貼ってはいけない。**
/// あの `a8=` はクリックごとに発行される一時的なトークンで、
/// 同じリンクを踏んでも毎回変わる。着地URLを直接埋め込むと
/// A8の計測を経由しないため、成果が一切記録されない。
///
/// - 未設定（空文字）のあいだは、アプリ内に導線が一切出ない。
/// - **掲載する場合はプライバシーポリシー §3.4 の
///   "The App does NOT display advertisements." を先に修正する必要がある。**
/// - 景品表示法（ステマ規制）により広告であることの表示が必須。
///   表示は `AffiliateLinkRow` が担っているので、提携リンクは必ずあれを通す。
enum AffiliateLink {

    /// A8.net の管理画面で発行した商品リンク（生成コードの `href` の中身）を
    /// **そのまま**貼る。`a8ejpredirect` は付いたままでよく、こちらで差し替える
    private static let asoviewGeneratedLink = ""

    /// 遷移先は提携先ドメイン内に固定する。
    /// 広告主URL以外へのリンクは提携解除の対象になるため、
    /// ユーザー入力を混ぜるのはキーワードの値だけに限る
    private static let asoviewSearchBase = "https://www.asoview.com/search/"

    static var isAsoviewAvailable: Bool {
        !asoviewGeneratedLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 地名や施設名で検索した結果ページへ送る。
    ///
    /// アソビュー内の商品ページを施設名から特定する手段（API・商品DB）が
    /// 無いため、商品ページへの直リンクはできない。検索結果を出す形にしている。
    /// 0件になりうるので、UIの文言は「探す」に留めること。
    static func asoviewSearchURL(keyword: String) -> URL? {
        let link = asoviewGeneratedLink.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !link.isEmpty else { return nil }

        // 記号をすべてエンコードする。`&` や `+` を含む地名でURLが壊れないようにする
        let trimmedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        let encodedKeyword = trimmedKeyword
            .addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""

        let target = encodedKeyword.isEmpty
            ? asoviewSearchBase
            : "\(asoviewSearchBase)?keyword=\(encodedKeyword)"

        // クエリの値として渡すので、遷移先URL全体をもう一度エンコードする
        guard let encodedTarget = target
            .addingPercentEncoding(withAllowedCharacters: .alphanumerics) else { return nil }

        // a8mat は "+" を含み、URLComponents で組み直すと壊れる。
        // 発行されたリンクの文字列をそのまま使い、遷移先だけ差し替える
        var base = link
        if let range = link.range(of: "a8ejpredirect=") {
            base = String(link[..<range.lowerBound])
        }
        if !base.hasSuffix("?") && !base.hasSuffix("&") {
            base += base.contains("?") ? "&" : "?"
        }

        return URL(string: base + "a8ejpredirect=" + encodedTarget)
    }
}
