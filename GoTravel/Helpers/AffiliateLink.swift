import Foundation

/// 提携先（アソビュー / A8.net）へのリンク。
///
/// A8.net の管理画面で生成したリンクをここに1つだけ置く。
/// 生成コードは `<a href="https://px.a8.net/svt/ejp?a8mat=...">` の形なので、
/// **href の中のURLだけ**を貼ること。
///
/// - 未設定（空文字）のあいだは、アプリ内に導線が一切出ない。
///   貼り忘れてリンク切れが表示される事故を防ぐため。
/// - 掲載する場合はプライバシーポリシー §3.4 の
///   "The App does NOT display advertisements." を先に修正する必要がある。
enum AffiliateLink {

    /// アソビューへのアフィリエイトリンク。A8.net で生成したものを貼る
    private static let asoviewURLString = ""

    /// 導線を出すかどうか。リンクが設定されていなければ出さない
    static var isAsoviewAvailable: Bool {
        asoviewURL != nil
    }

    static var asoviewURL: URL? {
        let trimmed = asoviewURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }

    /// 目的地のページへ直接飛ばしたい場合に使う。
    ///
    /// A8.net のリンクは `a8ejpredirect` に遷移先URLを渡すと、
    /// 提携先サイト内の任意のページへ送れる。
    /// アソビュー側のエリア別URLの形式が確認できたら、
    /// ここで組み立てて `asoviewURL` の代わりに使う。
    /// 形式が不明なまま推測で組むとリンク切れになるので、現状はトップページへ送る。
    static func asoviewURL(forDestination destination: String) -> URL? {
        asoviewURL
    }
}
