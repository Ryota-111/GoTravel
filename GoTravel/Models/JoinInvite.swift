import Foundation
import Combine

/// 招待のリンク（3.8）。
///
/// 招待のメッセージに `https://travory-web.pages.dev/join#TRAVEL-XXXXXXXX` を入れる。
/// ページを開くと「Travory で開いて参加する」（`travory://join?code=…`）と App Store のボタンが出る。
/// 3.7 までは共有コードの文字だけで、Travory を持っていない人はアプリの探し方が分からなかった。
///
/// **共有コードは「#」の後ろに置く。** 共有コードは計画を編集できる合言葉なので、サーバーの記録や
/// LINE などのリンクの下見に渡さない（「#」の後ろはブラウザがサーバーへ送らない）
enum JoinInvite {

    /// 招待のページのリンク
    static func url(code: String) -> URL? {
        URL(string: "\(SharedWebPage.baseURL)/join#\(code)")
    }

    /// 開かれたリンクから共有コードを取り出す。招待のリンクでなければ nil。
    /// `travory://join?code=TRAVEL-…` と、のちに Universal Links にしたときの `https://…/join#TRAVEL-…` の両方
    static func code(from url: URL) -> String? {
        let raw: String?
        if url.scheme == "travory", url.host == "join" {
            raw = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "code" }?.value
                ?? url.pathComponents.dropFirst().first
        } else if url.scheme == "https", url.path == "/join" || url.path == "/join/" {
            raw = url.fragment
        } else {
            raw = nil
        }
        guard let raw else { return nil }
        let code = JoinTravelPlanView.normalizeShareCode(raw.removingPercentEncoding ?? raw)
        guard code.wholeMatch(of: /(TRAVEL|PLAN)-[A-Z0-9]{8}/) != nil else { return nil }
        return code
    }
}

/// 招待のリンクから開かれたときに、参加の画面へ渡す（ログインの前に開かれても、ログイン後に出す）
final class JoinInviteInbox: ObservableObject {
    static let shared = JoinInviteInbox()

    struct Pending: Identifiable, Equatable {
        let id = UUID()
        let code: String
    }

    @Published var pending: Pending?

    func open(code: String) {
        pending = Pending(code: code)
    }
}
