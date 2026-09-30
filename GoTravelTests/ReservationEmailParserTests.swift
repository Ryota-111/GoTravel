import Testing
import Foundation
@testable import GoTravel

/// 予約確認メールの読み取りの、決まりごとの確かめ。
///
/// **ここの文面は、書き方の決まりを確かめるために作った短い見本。**
/// 実際のメールでの精度は `ReservationEmailSampleTests` で測る
struct ReservationEmailParserTests {

    /// 2026年9月30日
    private let today = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 9, day: 30))!

    private func ymdhm(_ c: DateComponents?) -> String? {
        guard let c, let y = c.year, let m = c.month, let d = c.day else { return nil }
        guard let h = c.hour else { return String(format: "%04d-%02d-%02d", y, m, d) }
        return String(format: "%04d-%02d-%02d %02d:%02d", y, m, d, h, c.minute ?? 0)
    }

    @Test("全角の英数字は半角にし、カタカナはそのまま")
    func normalizes() {
        #expect(ReservationEmailParser.normalized("ＡＮＡ１２３便　ホテル") == "ANA123便 ホテル")
    }

    @Test("予約番号は、ラベルと同じ行でも次の行でも拾う")
    func confirmationNumbers() {
        #expect(ReservationEmailParser.confirmationNumber(in: "予約番号：AB12CD") == "AB12CD")
        #expect(ReservationEmailParser.confirmationNumber(in: "【確認番号】\n  XYZ-7788") == "XYZ-7788")
        #expect(ReservationEmailParser.confirmationNumber(in: "Booking reference: QW3RTY") == "QW3RTY")
    }

    @Test("片道の便：便名・出発と到着の時刻・空港")
    func oneWayFlight() throws {
        let text = """
        ご搭乗便のご案内
        2026年10月6日(火)
        ANA 993便
        羽田 07:00 発 → 那覇 09:40 着
        予約番号 1234ABCD
        """
        let draft = try #require(ReservationEmailParser.parse(text, referenceDate: today).first)

        #expect(draft.kind == .flight)
        #expect(draft.transportNumber == "NH993")
        #expect(ymdhm(draft.start) == "2026-10-06 07:00")
        #expect(ymdhm(draft.arrival) == "2026-10-06 09:40")
        #expect(draft.departurePlace == "羽田空港")
        #expect(draft.arrivalPlace == "那覇空港")
        #expect(draft.confirmationNumber == "1234ABCD")
    }

    @Test("往復の便は2件に分ける")
    func roundTrip() {
        let text = """
        往路 2026年10月6日 JL915 羽田 08:00 → 那覇 10:45
        復路 2026年10月9日 JL920 那覇 18:00 → 羽田 20:30
        予約番号 H5K2P9
        """
        let drafts = ReservationEmailParser.parse(text, referenceDate: today)

        #expect(drafts.map(\.transportNumber) == ["JL915", "JL920"])
        #expect(drafts.map { ymdhm($0.start) } == ["2026-10-06 08:00", "2026-10-09 18:00"])
        #expect(drafts.last?.departurePlace == "那覇空港")
    }

    @Test("宿：名前・チェックイン・チェックアウト")
    func hotel() throws {
        let text = """
        ご予約ありがとうございます。
        宿泊施設：ハレクラニ沖縄
        チェックイン：2026年10月6日(火) 15:00
        チェックアウト：2026年10月9日(金) 11:00
        予約番号：RT12345678
        """
        let draft = try #require(ReservationEmailParser.parse(text, referenceDate: today).first)

        #expect(draft.kind == .hotel)
        #expect(draft.title == "ハレクラニ沖縄")
        #expect(ymdhm(draft.start) == "2026-10-06 15:00")
        #expect(ymdhm(draft.end) == "2026-10-09 11:00")
        #expect(draft.confirmationNumber == "RT12345678")
    }

    @Test("「2泊」とだけ書いてある宿は、チェックインから数える。年が無ければ補う")
    func hotelWithNights() throws {
        let text = """
        ■宿泊日 10月6日 2泊
        ■チェックイン 15:00
        ■チェックアウト 10:00
        """
        let draft = try #require(ReservationEmailParser.parse(text, referenceDate: today).first)

        #expect(ymdhm(draft.start) == "2026-10-06 15:00")
        #expect(ymdhm(draft.end) == "2026-10-08 10:00")
        #expect(draft.guessedYear)
    }

    @Test("年を補うとき、とうに過ぎた日付なら来年とみなす")
    func infersNextYear() {
        let december = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 12, day: 20))!

        #expect(ReservationEmailParser.inferredYear(month: 1, day: 5, referenceDate: december) == 2027)
        #expect(ReservationEmailParser.inferredYear(month: 12, day: 25, referenceDate: december) == 2026)
    }

    @Test("新幹線：列車名・区間・時刻")
    func train() throws {
        let text = """
        乗車日 2026年10月6日
        のぞみ21号 東京→新大阪
        東京 09:00発 新大阪 11:27着
        7号車 3番D席
        """
        let draft = try #require(ReservationEmailParser.parse(text, referenceDate: today).first)

        #expect(draft.kind == .train)
        #expect(draft.transportNumber == "のぞみ21号")
        #expect(ymdhm(draft.start) == "2026-10-06 09:00")
        #expect(ymdhm(draft.arrival) == "2026-10-06 11:27")
        #expect(draft.departurePlace == "東京")
        #expect(draft.arrivalPlace == "新大阪")
    }

    @Test("レンタカー：貸出と返却")
    func rentalCar() throws {
        let text = """
        レンタカーご予約内容
        貸出日時 2026/10/06 10:00
        返却日時 2026/10/09 17:00
        予約番号 R-778899
        """
        let draft = try #require(ReservationEmailParser.parse(text, referenceDate: today).first)

        #expect(draft.kind == .rentalCar)
        #expect(ymdhm(draft.start) == "2026-10-06 10:00")
        #expect(ymdhm(draft.end) == "2026-10-09 17:00")
        #expect(draft.confirmationNumber == "R-778899")
    }
}
