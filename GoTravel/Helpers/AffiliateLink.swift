import Foundation

/// 提携先（アソビュー / A8.net）へのリンク。
///
/// A8.net の管理画面で発行したリンクをここに1つだけ置く。
/// 生成コードは `<a href="https://px.a8.net/svt/ejp?a8mat=...">` の形なので、
/// **href の中のURLだけ**を貼ること。
///
/// - 未設定（空文字）のあいだは、アプリ内に導線が一切出ない。
///   貼り忘れてリンク切れが表示される事故を防ぐため。
/// - **掲載する場合はプライバシーポリシー §3.4 の
///   "The App does NOT display advertisements." を先に修正する必要がある。**
/// - 景品表示法（ステマ規制）により、リンクの近くに広告であることの表示が必須。
///   表示は `AffiliateLinkRow` が担っている。
enum AffiliateLink {

    /// アソビューへのアフィリエイトリンク（A8.net で発行したもの）
    private static let asoviewBaseURLString = ""

    /// 導線を出すかどうか。リンクが設定されていなければ出さない
    static var isAsoviewAvailable: Bool {
        !asoviewBaseURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 施設名や地名で検索した結果ページへ送る。
    ///
    /// アソビュー内の商品ページを施設名から特定する手段（API・商品DB）が
    /// 提供されていないため、**商品ページへの直リンクはできない**。
    /// A8.net の `a8ejpredirect` に検索URLを渡し、検索結果を出す形にしている。
    /// 検索結果が0件になりうるので、UIの文言は「探す」に留めること。
    static func asoviewSearchURL(keyword: String) -> URL? {
        let base = asoviewBaseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base.isEmpty else { return nil }

        let trimmedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKeyword.isEmpty else { return URL(string: base) }

        // 遷移先URL自体をクエリの値として渡すので、二重にエンコードする必要がある
        guard let encodedKeyword = trimmedKeyword.addingPercentEncoding(
            withAllowedCharacters: .alphanumerics
        ) else { return URL(string: base) }

        let target = "https://www.asoview.com/search/?keyword=\(encodedKeyword)"

        guard let encodedTarget = target.addingPercentEncoding(
            withAllowedCharacters: .alphanumerics
        ) else { return URL(string: base) }

        let separator = base.contains("?") ? "&" : "?"
        return URL(string: "\(base)\(separator)a8ejpredirect=\(encodedTarget)")
    }
}
