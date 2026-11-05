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
        #expect(draft.transportNumber == "ANA993")
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

extension ReservationEmailParserTests {
    @Test("便名はメールに書かれたとおりにする（スカイマークを BC に直さない）")
    func flightNumberKeepsWrittenForm() {
        #expect(ReservationEmailParser.flightNumbers(in: "2026年10月06日　SKY 111便").map(\.number) == ["SKY111"])
        #expect(ReservationEmailParser.flightNumbers(in: "スカイマーク 111便").map(\.number) == ["SKY111"])
        #expect(ReservationEmailParser.flightNumbers(in: "AIRDO 15便").map(\.number) == ["AIRDO15"])
        // 同じ便の書き方の揺れは1便として数える
        #expect(ReservationEmailParser.flightNumbers(in: "ANA 027便\nANA27便").count == 1)
    }
}

// MARK: - 12時間制と英語の文面（3.4）

extension ReservationEmailParserTests {
    private func hm(_ text: String) -> [String] {
        ReservationEmailParser.timeMatches(in: text).map { String(format: "%02d:%02d", $0.hour, $0.minute) }
    }

    @Test("午前・午後と AM・PM を24時間制に直す")
    func twelveHourClock() {
        #expect(hm("午後6時") == ["18:00"])
        #expect(hm("午後 6時半") == ["18:30"])
        #expect(hm("午前10時30分") == ["10:30"])
        #expect(hm("3:00 PM") == ["15:00"])
        #expect(hm("11:15am") == ["11:15"])
        #expect(hm("12:30 a.m.") == ["00:30"])
        #expect(hm("12:00 PM") == ["12:00"])
        #expect(hm("7pm") == ["19:00"])
        #expect(hm("18:00") == ["18:00"])
        // 「2 PM」より前の数字や、ほかの英単語は時刻にしない
        #expect(hm("Room 204 PMS") == [])
    }

    @Test("英語の日付：年なし・序数・数字だけの書き方")
    func englishDates() {
        func ymd(_ text: String) -> [String] {
            ReservationEmailParser.dateTimeEvents(in: text, referenceDate: today).map {
                String(format: "%04d-%02d-%02d", $0.components.year!, $0.components.month!, $0.components.day!)
            }
        }
        #expect(ymd("Mon, Oct 6") == ["2026-10-06"])
        #expect(ymd("Sat 10th October") == ["2026-10-10"])
        #expect(ymd("October 6th, 2026") == ["2026-10-06"])
        #expect(ymd("6 Oct, 2026") == ["2026-10-06"])
        // 13以上の数があれば、どちらが日か決まる
        #expect(ymd("10/25/2026") == ["2026-10-25"])
        #expect(ymd("25.10.2026") == ["2026-10-25"])
        // 本文の中の1つで決まれば、ほかの日付もそれに合わせる
        #expect(ymd("Check-in 03/10/2026 Check-out 13/10/2026") == ["2026-10-03", "2026-10-13"])
        // 決まらなければ、今日に近い先の日付になるほう（今日は 2026年9月30日）
        #expect(ymd("10/06/2026") == ["2026-10-06"])
        // 「Mark」は月ではない
        #expect(ymd("Mark 12") == [])
    }

    @Test("英語の宿：チェックインの午後の時刻と、泊数")
    func englishHotel() throws {
        let text = """
        Your booking is confirmed
        Booked on Sep 20, 2026
        Property name: Harbor View Hotel
        Check-in: Thu, Oct 8, 2026 from 3:00 PM
        2 nights
        Confirmation number: 4471829
        """
        let draft = try #require(ReservationEmailParser.parse(text, referenceDate: today).first)

        #expect(draft.kind == .hotel)
        #expect(draft.title == "Harbor View Hotel")
        #expect(ymdhm(draft.start) == "2026-10-08 15:00")
        #expect(ymdhm(draft.end) == "2026-10-10")
        #expect(draft.confirmationNumber == "4471829")
    }

    @Test("英語のレストラン：予約の日付と夜の時刻（受付日は使わない）")
    func englishRestaurant() throws {
        let text = """
        Reservation confirmed at Bistro Lune
        Order date: Sep 28, 2026
        Table for 2
        Date: Fri, Oct 9
        Time: 7:30 PM
        """
        let draft = try #require(ReservationEmailParser.parse(text, referenceDate: today).first)

        #expect(draft.kind == .restaurant)
        #expect(ymdhm(draft.start) == "2026-10-09 19:30")
    }

    @Test("日本語のレストラン：午後の時刻")
    func japaneseAfternoon() throws {
        let text = """
        ご来店日時：10月9日(金) 午後6時半
        レストラン名：ビストロ月
        """
        let draft = try #require(ReservationEmailParser.parse(text, referenceDate: today).first)
        #expect(ymdhm(draft.start) == "2026-10-09 18:30")
        #expect(draft.title == "ビストロ月")
    }
}
