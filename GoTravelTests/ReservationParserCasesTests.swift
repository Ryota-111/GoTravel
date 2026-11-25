import Testing
import Foundation
@testable import GoTravel

/// いろいろな形の予約の読み取り（3.8）。往復・乗り継ぎ・日またぎ・便名が後ろ・宿・バス・船・駐車場・管理用の日付。
/// 「誤った値を入れない」「別の便の値を混ぜない」を確かめる
struct ReservationParserCasesTests {

    static let samples: [(String, String)] = [
    ("往復JAL", """
    ご搭乗便のご案内
    予約番号：4K7Q2P
    【往路】2026年12月1日(火)
    JAL 903便　羽田(08:00) → 那覇(10:45)
    【復路】2026年12月4日(金)
    JAL 918便　那覇(18:30) → 羽田(21:05)
    お支払期限：2026年11月20日
    """),
    ("乗り継ぎ3区間EN", """
    Booking reference: ZX8K2L
    Flight 1: NH 211  Tokyo Haneda (HND) 10:30 - Frankfurt (FRA) 16:20  Mon, 7 Dec 2026
    Flight 2: LH 1234  Frankfurt (FRA) 18:00 - Rome (FCO) 19:55  Mon, 7 Dec 2026
    Flight 3: AZ 1715  Rome (FCO) 08:10 - Naples (NAP) 09:00  Tue, 8 Dec 2026
    """),
    ("日またぎ", """
    予約番号：SQ9K1B
    12月1日(火) SQ 637便
    羽田 22:00 発
    12月2日(水) 05:30 シンガポール 着
    """),
    ("便名が後半", """
    ご予約ありがとうございます。
    ご出発日：2026年12月10日
    出発：新千歳空港 09:00
    到着：羽田空港 10:35
    予約番号：BC7788
    ご利用便：ADO 12便
    """),
    ("宿_チェックアウトだけ", """
    ご予約内容
    予約番号：H8812345
    チェックアウト：2026年12月3日 10:00
    """),
    ("宿_泊数", """
    宿泊施設：湯の宿 さくら
    チェックイン：2026年12月1日 15:00
    宿泊数：2泊
    予約番号：778812
    部屋番号：305
    """),
    ("宿_名前ラベルなし", """
    ホテル雅 京都四条
    ご宿泊日 2026年12月1日（火）〜 2026年12月3日（木）
    予約番号 RJ-55821
    電話番号 075-123-4567
    """),
    ("高速バス", """
    高速バス 予約確認
    予約番号：WB12345678
    乗車日：2026年12月5日
    新宿バスタ 23:10 発 → 大阪梅田 7:20 着
    """),
    ("フェリー", """
    フェリーご予約
    予約番号：F-200341
    出航日時：2026年12月8日 19:30
    大洗港 → 苫小牧港
    """),
    ("駐車場", """
    駐車場予約
    予約番号：P5512
    入庫：2026年12月1日 7:00
    出庫：2026年12月4日 22:00
    """),
    ("レストラン_受付日だけ前", """
    予約受付日：2026年11月1日
    ご来店日時：2026年12月24日 19:00
    人数：2名
    予約番号：R-88213
    """),
    ("電話だけ", """
    ご予約番号
    お問い合わせ 03-1234-5678
    ご利用日：2026年12月1日
    """),
    ]


    private static let reference: Date = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar.date(from: DateComponents(year: 2026, month: 11, day: 1))!
    }()

    private func parse(_ name: String) -> [ReservationDraft] {
        let text = Self.samples.first { $0.0 == name }!.1
        return ReservationEmailParser.parse(text, referenceDate: Self.reference)
    }

    private func at(_ month: Int, _ day: Int, _ hour: Int? = nil, _ minute: Int? = nil) -> DateComponents {
        DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute)
    }

    private func dayTime(_ c: DateComponents?) -> [Int?] { [c?.month, c?.day, c?.hour, c?.minute] }

    @Test("往復：日付だけの行は、次の行の便のもの")
    func roundTrip() {
        let drafts = parse("往復JAL")
        #expect(drafts.count == 2)
        #expect(drafts[0].transportNumber == "JAL903")
        #expect(dayTime(drafts[0].start) == [12, 1, 8, 0])
        #expect(dayTime(drafts[0].arrival) == [12, 1, 10, 45])
        #expect(drafts[0].departurePlace == "羽田空港")
        #expect(dayTime(drafts[1].start) == [12, 4, 18, 30])
        #expect(drafts[1].departurePlace == "那覇空港")
    }

    @Test("乗り継ぎ3区間：便ごとの空港と時刻。表に無い空港も「都市 (コード)」で読む")
    func threeLegs() {
        let drafts = parse("乗り継ぎ3区間EN")
        #expect(drafts.map(\.transportNumber) == ["NH211", "LH1234", "AZ1715"])
        #expect(drafts[1].departurePlace == "Frankfurt (FRA)")
        #expect(drafts[1].arrivalPlace == "Rome (FCO)")
        #expect(dayTime(drafts[1].start) == [12, 7, 18, 0])
        #expect(dayTime(drafts[2].start) == [12, 8, 8, 10])
        #expect(drafts[2].departurePlace == "Rome (FCO)")
    }

    @Test("日をまたぐ便：到着の日付が書いてあればその日")
    func overnight() {
        let draft = parse("日またぎ")[0]
        #expect(dayTime(draft.start) == [12, 1, 22, 0])
        #expect(dayTime(draft.arrival) == [12, 2, 5, 30])
    }

    @Test("便名が本文の後ろ：予約番号を便名にしない。前に書いてある日時を使う")
    func flightNumberLater() {
        let drafts = parse("便名が後半")
        #expect(drafts.count == 1)
        #expect(drafts[0].transportNumber == "ADO12")
        #expect(drafts[0].confirmationNumber == "BC7788")
        #expect(dayTime(drafts[0].start) == [12, 10, 9, 0])
        #expect(dayTime(drafts[0].arrival) == [12, 10, 10, 35])
    }

    @Test("到着の日付が無く、到着の時刻が出発より早いときは、到着を空ける")
    func arrivalEarlierThanDeparture() {
        let text = """
        予約番号：KL0099
        2026年12月1日 KL 862便
        成田 21:30 → Amsterdam (AMS) 04:55
        """
        let draft = ReservationEmailParser.parse(text, referenceDate: Self.reference)[0]
        #expect(dayTime(draft.start) == [12, 1, 21, 30])
        #expect(draft.arrival == nil)
    }

    @Test("宿：チェックアウトだけ・泊数・名前のラベルなし。部屋番号・電話番号を予約番号にしない")
    func hotels() {
        #expect(parse("宿_チェックアウトだけ")[0].end == at(12, 3, 10, 0))
        let nights = parse("宿_泊数")[0]
        #expect(nights.end.map { [$0.month, $0.day] } == [12, 3])
        #expect(nights.confirmationNumber == "778812")
        let unlabeled = parse("宿_名前ラベルなし")[0]
        #expect(unlabeled.title == "ホテル雅 京都四条")
        #expect(unlabeled.confirmationNumber == "RJ-55821")
    }

    @Test("高速バス・フェリー：種類と発着地")
    func busAndFerry() {
        let bus = parse("高速バス")[0]
        #expect(bus.kind == .bus)
        #expect(bus.departurePlace == "新宿バスタ")
        #expect(bus.arrivalPlace == "大阪梅田")
        #expect(dayTime(bus.start) == [12, 5, 23, 10])
        #expect(bus.arrival == nil)   // 翌朝着。何日後かは書いていないので空ける
        let ferry = parse("フェリー")[0]
        #expect(ferry.kind == .ferry)
        #expect(ferry.departurePlace == "大洗港")
        #expect(ferry.arrivalPlace == "苫小牧港")
    }

    @Test("駐車場：入庫と出庫")
    func parking() {
        let draft = parse("駐車場")[0]
        #expect(draft.kind == .parking)
        #expect(draft.start == at(12, 1, 7, 0))
        #expect(draft.end == at(12, 4, 22, 0))
    }

    @Test("受付日より、来店日時を使う。電話番号を予約番号にしない")
    func administrativeAndPhone() {
        #expect(parse("レストラン_受付日だけ前")[0].start == at(12, 24, 19, 0))
        #expect(parse("電話だけ")[0].confirmationNumber == nil)
    }

    @Test("新幹線：出発地に「号」を入れない。時刻がかっこに入る書き方も読む（3.8）")
    func trainPlaces() {
        for text in ["2026年12月1日\nのぞみ21号東京→新大阪", "2026年12月1日\nひかり633号　東京(10:03)→新大阪(12:57)",
                     "2026年12月1日\nのぞみ 21号 東京 10:00発 → 新大阪 12:30着"] {
            let draft = ReservationEmailParser.parse(text, referenceDate: Self.reference)[0]
            #expect(draft.departurePlace == "東京", "\(text)")
            #expect(draft.arrivalPlace == "新大阪", "\(text)")
        }
        #expect(ReservationEmailParser.placeName("21号東京") == "東京")
        #expect(ReservationEmailParser.placeName("新大阪着") == "新大阪")
    }

    @Test("Booking.com の「◯◯ へのチェックインは」から宿の名前を読む。カーシェアの「課金予定料金」を金額にする（3.8）")
    func bookingNameAndCarShareCost() {
        let hotel = """
        Booking.com
           予約番号： 6016073582
           [checkmark.png] フレックステイイン新浦安 へのチェックインは11月1日(日)
        予約内容
           チェックイン 2026年11月1日日曜日 （14:00～00:00）
           チェックアウト 2026年11月2日月曜日 （10:00まで）
        """
        #expect(ReservationEmailParser.parse(hotel, referenceDate: Self.reference)[0].title == "フレックステイイン新浦安")
        let car = """
        【Times CAR】予約登録完了
        ■予約番号
        236260173
        ■利用開始日時
        2026/11/18 10:30
        ■返却予定日時
        2026/11/18 19:45
        ■課金予定料金
        5500円
        """
        #expect(ReservationEmailParser.parse(car, referenceDate: Self.reference)[0].cost == 5500)
    }

    @Test("Wallet の搭乗券：ロゴの社名と時刻をつなげて便名にしない。年の無い搭乗日とローマ字の空港も読む（3.8）")
    func walletBoardingPass() {
        let text = "出発時刻\t搭乗日\nSKY\t09:20\t12/23\nKOBE\tHANEDA\n神戸\t羽田\n便名\t出発時刻\t到着時刻\t運航状況\nSKY102\t09:20\t10:25\n搭乗者名\t座席\n8G"
        let drafts = ReservationEmailParser.parse(text, referenceDate: Self.reference)
        #expect(drafts.count == 1)
        #expect(drafts.first?.transportNumber == "SKY102")
        #expect(drafts.first?.departurePlace == "神戸空港")
        #expect(drafts.first?.arrivalPlace == "羽田空港")
        #expect(drafts.first?.start?.month == 12)
        #expect(drafts.first?.start?.day == 23)
        #expect(drafts.first?.start?.hour == 9)
        #expect(drafts.first?.arrival?.hour == 10)
    }

    @Test("宿：字のあいだを空けた「合　計」と、到着予定時刻を読む。名前の＜＞は〈〉に戻す（3.8）")
    func hotelSpacedTotal() {
        let text = """
        【ホテル名】：アパホテル＜六本木SIX＞
        【宿泊日】：2026年12月23日（水）～2026年12月24日（木）
        【泊数】：1泊
        【到着予定時刻】：18:00
        【宿泊代金】：12,000円
        【クーポン割引金額】：0
        【合\t計】：12,000円（諸税・サービス料込）
        """
        let draft = ReservationEmailParser.parse(text, referenceDate: Self.reference).first
        #expect(draft?.kind == .hotel)
        #expect(draft?.title == "アパホテル〈六本木SIX〉")
        #expect(draft?.start?.hour == 18)
        #expect(draft?.cost == 12000)
    }

    @Test("年の無い「2/1」は、日付の見出しが無ければ日付にしない")
    func shortDateNeedsLabel() {
        let events = ReservationEmailParser.dateTimeEvents(in: "大人 2/1室あたり 割合 3/4", referenceDate: Self.reference)
        #expect(events.isEmpty)
    }

    @Test("搭乗券のローマ字の行が片方しか読めなくても、左右に並んだ空港の行から出発・到着を決める（3.8）")
    func boardingPassPartialRomaji() {
        let text = "SKY\t09:20\t12/23\nHANEDA\n神戸\t羽田\n便名\t出発時刻\t到着時刻\nSKY102\t09:20\t10:25"
        let draft = ReservationEmailParser.parse(text, referenceDate: Self.reference).first
        #expect(draft?.departurePlace == "神戸空港")
        #expect(draft?.arrivalPlace == "羽田空港")
    }
}
