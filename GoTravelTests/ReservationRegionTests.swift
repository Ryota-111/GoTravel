import Testing
import Foundation
@testable import GoTravel

/// 韓国・台湾への旅行の予約（3.4）。空港・航空会社・予約番号のラベルを、韓国語・繁体字でも読む
@MainActor
struct ReservationRegionTests {

    private func airports(_ text: String) -> [String] {
        ReservationEmailParser.airportMentions(in: text).map(\.name)
    }

    @Test("愛媛の「松山空港」を台北松山として読まない")
    func matsuyamaEhime() {
        #expect(airports("羽田空港 08:00 → 松山空港 09:30") == ["羽田空港", "松山空港"])
    }

    @Test("「台北松山空港」は台北松山だけ（台北＝桃園・松山＝愛媛にも当たっていた）")
    func taipeiSongshan() {
        #expect(airports("羽田 → 台北松山空港") == ["羽田空港", "台北松山空港"])
        #expect(airports("臺北松山 TSA") == ["台北松山空港", "台北松山空港"])
    }

    @Test("「台北」だけなら桃園、繁体字・空港コードでも読む")
    func taipeiTaoyuan() {
        #expect(airports("成田 NRT → 台北 TPE") == ["成田空港", "成田空港", "台北桃園空港", "台北桃園空港"])
        #expect(airports("臺北桃園國際機場") == ["台北桃園空港"])
        #expect(airports("高雄 → 関西") == ["高雄空港", "関西空港"])
    }

    @Test("韓国の空港をハングルでも読む")
    func koreanAirports() {
        #expect(airports("김해 → 제주") == ["釜山空港", "済州空港"])
        #expect(airports("인천국제공항 ICN") == ["仁川空港", "仁川空港"])
        #expect(airports("釜山 PUS → 福岡 FUK") == ["釜山空港", "釜山空港", "福岡空港", "福岡空港"])
    }

    @Test("「セブン」をセブ島の空港と読まない")
    func sevenIsNotCebu() {
        #expect(airports("セブン-イレブンで受け取り").isEmpty)
        #expect(airports("マクタン・セブ国際空港") == ["セブ空港"])
    }

    @Test("韓国・台湾の航空会社の便名を読む")
    func regionalAirlines() {
        let text = "BX163 福岡 → 釜山\nZE612 / RS702 / JX801 / YP731 / 7C1102"
        let numbers = ReservationEmailParser.flightNumbers(in: text).map(\.number)
        #expect(numbers == ["BX163", "ZE612", "RS702", "JX801", "YP731", "7C1102"])
    }

    @Test("予約番号のラベルを韓国語・中国語・英語の別の書き方でも読む")
    func confirmationLabels() {
        #expect(ReservationEmailParser.confirmationNumber(in: "예약번호: K7Q2LM") == "K7Q2LM")
        #expect(ReservationEmailParser.confirmationNumber(in: "예약 번호\nAB12CD") == "AB12CD")
        #expect(ReservationEmailParser.confirmationNumber(in: "訂位代號：XYZ789") == "XYZ789")
        #expect(ReservationEmailParser.confirmationNumber(in: "订单号: 20261105A") == "20261105A")
        #expect(ReservationEmailParser.confirmationNumber(in: "Record locator: QWE4RT") == "QWE4RT")
    }

    @Test("台湾行きの便を、出発・到着の空港まで読む")
    func taiwanFlight() {
        let text = """
        訂位代號：XYZ789
        2026年12月20日
        JX801 成田 NRT 09:30 → 台北桃園 TPE 12:40
        """
        let drafts = ReservationEmailParser.parse(text, referenceDate: Date(timeIntervalSince1970: 1_790_000_000))
        #expect(drafts.count == 1)
        #expect(drafts.first?.transportNumber == "JX801")
        #expect(drafts.first?.confirmationNumber == "XYZ789")
        #expect(drafts.first?.departurePlace == "成田空港")
        #expect(drafts.first?.arrivalPlace == "台北桃園空港")
    }

    // MARK: - スクリーンショットの見本で見つかった読み違い（3.4）

    @Test("写真で 0 が O に化けた便名を読む（SKYO25 → SKY025）")
    func ocrZeroAsLetterO() {
        let numbers = ReservationEmailParser.flightNumbers(in: "2022年9月2日/SKYO25/羽田18:40発").map(\.number)
        #expect(numbers == ["SKY025"])
        // 数字の無いものは便名にしない
        #expect(ReservationEmailParser.flightNumbers(in: "ANA OK").isEmpty)
    }

    @Test("「ソラシドエア（SNA）021便」と「東京（羽田）→沖縄」を読む")
    func solaseedStyle() {
        let text = """
        12月1日 ソラシドエア（SNA）021便
        東京（羽田）→沖縄
        06:40-09:40
        予約番号：3224
        """
        let drafts = ReservationEmailParser.parse(text, referenceDate: Date(timeIntervalSince1970: 1_790_000_000))
        #expect(drafts.first?.transportNumber == "SNA021")
        #expect(drafts.first?.departurePlace == "羽田空港")
        #expect(drafts.first?.arrivalPlace == "那覇空港")
        #expect(drafts.first?.confirmationNumber == "3224")
    }

    @Test("「沖縄」は矢印のそばのときだけ那覇空港として読む（「沖縄旅行」などは空港にしない）")
    func okinawaOnlyNearArrow() {
        #expect(airports("沖縄旅行のご案内") == [])
        #expect(airports("羽田 ⇒ 沖縄") == ["羽田空港", "那覇空港"])
    }

    @Test("「予約依頼番号」をラベルとして読む（ホットペッパーのリクエスト予約）")
    func requestNumberLabel() {
        #expect(ReservationEmailParser.confirmationNumber(in: "■予約依頼番号：R00000000") == "R00000000")
    }
}

