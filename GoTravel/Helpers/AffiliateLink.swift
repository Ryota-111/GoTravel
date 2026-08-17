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
    private static let asoviewGeneratedLink = "https://px.a8.net/svt/ejp?a8mat=4B9ZD9+2P1ODU+455G+BW8O2&a8ejpredirect=https%3A%2F%2Fwww.asoview.com%2Fsearch%2F%3Fkeyword%3D%E6%9D%B1%E4%BA%AC"

    static var isAsoviewAvailable: Bool {
        !asoviewGeneratedLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 座標から都道府県を確定して、アソビューのページへのリンクを作る。
    ///
    /// 行き先の文字列から推測するより確実。地名の表記ゆれ（「京都市」「嵐山」など）や
    /// 「東京都」に「京都」が含まれる問題を踏まないうえ、
    /// 国外かどうかも国コードで判定できる。
    /// 座標が無いプランのために、文字列での判定も残してある。
    static func asoviewURL(
        latitude: Double?,
        longitude: Double?,
        fallbackText: String
    ) async -> URL? {
        guard isAsoviewAvailable else { return nil }

        if let latitude, let longitude,
           let prefecture = await AsoviewArea.prefecture(latitude: latitude, longitude: longitude) {
            return asoviewURL(forDestination: prefecture)
        }

        return asoviewURL(forDestination: fallbackText)
    }

    /// 行き先の都道府県ページへ送る。
    ///
    /// アソビューの検索はクエリのキーワードを受け取らず、`?keyword=` を付けても
    /// 常に全件が返る（実際に確認済み）。行き先を絞るには
    /// `https://www.asoview.com/<ローマ字>/` のパス形式を使う必要がある。
    static func asoviewURL(forDestination destination: String) -> URL? {
        let link = asoviewGeneratedLink.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !link.isEmpty else { return nil }
        guard let target = AsoviewArea.url(matching: destination)?.absoluteString else { return nil }

        // クエリの値として渡すので遷移先URL全体をエンコードする。
        // 予約されていない文字（-._~）は残し、A8の出力と同じ形にする
        guard let encodedTarget = target
            .addingPercentEncoding(withAllowedCharacters: Self.unreserved) else { return nil }

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

    /// RFC 3986 の unreserved。これ以外はエンコードする
    private static let unreserved: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "-._~")
        return set
    }()
}
