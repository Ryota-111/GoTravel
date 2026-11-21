import Testing
import Foundation
@testable import GoTravel

/// 招待のリンク（3.8）
struct JoinInviteTests {

    @Test("共有コードはリンクの「#」の後ろに置く（サーバーへ送られない部分）")
    func urlKeepsCodeInFragment() throws {
        let url = try #require(JoinInvite.url(code: "TRAVEL-ABCD1234"))
        #expect(url.path == "/join")
        #expect(url.fragment == "TRAVEL-ABCD1234")
        #expect(url.query == nil)
    }

    @Test("「Travory で開く」のリンクから、旅行とカレンダーの共有コードを取り出す")
    func codeFromAppLink() throws {
        #expect(JoinInvite.code(from: try #require(URL(string: "travory://join?code=TRAVEL-ABCD1234"))) == "TRAVEL-ABCD1234")
        #expect(JoinInvite.code(from: try #require(URL(string: "travory://join?code=plan-wxyz5678"))) == "PLAN-WXYZ5678")
        #expect(JoinInvite.code(from: try #require(URL(string: "https://travory-web.pages.dev/join#TRAVEL-ABCD1234"))) == "TRAVEL-ABCD1234")
    }

    @Test("招待でないリンクや、形の合わないコードは使わない")
    func rejectsOtherLinks() throws {
        #expect(JoinInvite.code(from: try #require(URL(string: "travory://shared"))) == nil)
        #expect(JoinInvite.code(from: try #require(URL(string: "travory://join?code=hello"))) == nil)
        #expect(JoinInvite.code(from: try #require(URL(string: "https://travory-web.pages.dev/v/abc/def"))) == nil)
    }
}
