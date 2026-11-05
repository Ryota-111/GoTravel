import Testing
import Foundation
import UIKit
@testable import GoTravel

/// 画像から予約を読む（Vision の文字認識 → メールと同じ読み取り）
struct ReservationImageTextReaderTests {

    private func box(_ text: String, x: CGFloat, y: CGFloat, width: CGFloat = 0.3, height: CGFloat = 0.03) -> ReservationImageTextReader.TextBox {
        .init(text: text, frame: CGRect(x: x, y: y, width: width, height: height))
    }

    @Test("左右に離れたラベルと値を、同じ行にまとめる（上の行から順に）")
    func layoutJoinsLabelAndValue() {
        let boxes = [
            box("K7Q2PX", x: 0.6, y: 0.795),       // 値は少しずれて認識されることがある
            box("予約番号", x: 0.05, y: 0.80),
            box("2026年10月6日", x: 0.6, y: 0.70),
            box("出発日", x: 0.05, y: 0.70),
            box("SKY 111便", x: 0.05, y: 0.90)
        ]
        #expect(ReservationImageTextReader.layout(boxes) == "SKY 111便\n予約番号\tK7Q2PX\n出発日\t2026年10月6日")
    }

    @Test("確認画面の画像から、予約番号・便名・日時を読み取れる", .timeLimit(.minutes(1)))
    func readsRenderedConfirmationScreen() async throws {
        let rows: [(String, String)] = [
            ("便名", "SKY 111便"),
            ("出発", "神戸 07:30"),
            ("到着", "那覇 09:35"),
            ("搭乗日", "2026年10月6日"),
            ("予約番号", "K7Q2PX"),
            ("お支払金額", "12,800円")
        ]
        let image = render(rows)
        let text = try await ReservationImageTextReader.text(from: image)
        let drafts = ReservationEmailParser.parse(text)

        #expect(drafts.first?.kind == .flight, "\(text)")
        #expect(drafts.first?.transportNumber == "SKY111", "\(text)")
        #expect(drafts.first?.confirmationNumber == "K7Q2PX", "\(text)")
        #expect(drafts.first?.start?.day == 6, "\(text)")
        #expect(drafts.first?.cost == 12800, "\(text)")
    }

    @Test("韓国語・繁体字を足しても、日本語の画面の読み取りが変わらない（3.4）", .timeLimit(.minutes(1)))
    func addingLanguagesKeepsJapanese() async throws {
        let rows: [(String, String)] = [
            ("宿泊施設", "ホテルオークラ京都"),
            ("チェックイン", "2026年11月21日 15:00"),
            ("チェックアウト", "2026年11月23日 11:00"),
            ("予約番号", "JR4471882"),
            ("お支払い合計", "38,400円")
        ]
        let image = render(rows)
        let before = ReservationEmailParser.parse(try await ReservationImageTextReader.text(from: image, languages: ["ja-JP", "en-US"]))
        let text = try await ReservationImageTextReader.text(from: image)
        let after = ReservationEmailParser.parse(text)

        #expect(after.first?.confirmationNumber == "JR4471882", "\(text)")
        #expect(after.first?.start?.day == 21, "\(text)")
        #expect(after.first?.cost == 38400, "\(text)")
        #expect(after.first?.title == before.first?.title, "\(text)")
        #expect(after.first?.confirmationNumber == before.first?.confirmationNumber)
        #expect(after.first?.start == before.first?.start)
        #expect(after.first?.end == before.first?.end)
    }

    @Test("韓国の航空会社の画面（ハングル）から、便名・予約番号・空港を読める（3.4）", .timeLimit(.minutes(1)))
    func readsKoreanScreen() async throws {
        let rows: [(String, String)] = [
            ("예약번호", "K7Q2LM"),
            ("항공편", "BX141"),
            ("출발", "후쿠오카 FUK 2026.12.20 10:30"),
            ("도착", "부산 PUS 2026.12.20 11:25")
        ]
        let text = try await ReservationImageTextReader.text(from: render(rows))
        let drafts = ReservationEmailParser.parse(text)

        #expect(text.contains("예약번호"), "\(text)")
        #expect(drafts.first?.transportNumber == "BX141", "\(text)")
        #expect(drafts.first?.confirmationNumber == "K7Q2LM", "\(text)")
        #expect(drafts.first?.arrivalPlace == "釜山空港", "\(text)")
    }

    @Test("台湾の航空会社の画面（繁体字）から、便名・予約番号・空港を読める（3.4）", .timeLimit(.minutes(1)))
    func readsTraditionalChineseScreen() async throws {
        let rows: [(String, String)] = [
            ("訂位代號", "XYZ789"),
            ("航班", "JX801"),
            ("出發", "成田 NRT 2026/12/20 09:30"),
            ("抵達", "臺北桃園 TPE 2026/12/20 12:40")
        ]
        let text = try await ReservationImageTextReader.text(from: render(rows))
        let drafts = ReservationEmailParser.parse(text)

        #expect(drafts.first?.transportNumber == "JX801", "\(text)")
        #expect(drafts.first?.confirmationNumber == "XYZ789", "\(text)")
        #expect(drafts.first?.departurePlace == "成田空港", "\(text)")
        #expect(drafts.first?.arrivalPlace == "台北桃園空港", "\(text)")
    }

    /// スマホの確認画面のように、ラベルを左、値を右に並べた画像を作る
    private func render(_ rows: [(String, String)]) -> CGImage {
        let size = CGSize(width: 1170, height: 160 + rows.count * 110)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let font = UIFont.systemFont(ofSize: 48)
            for (index, row) in rows.enumerated() {
                let y = CGFloat(80 + index * 110)
                (row.0 as NSString).draw(at: CGPoint(x: 60, y: y), withAttributes: [.font: font, .foregroundColor: UIColor.darkGray])
                (row.1 as NSString).draw(at: CGPoint(x: 600, y: y), withAttributes: [.font: font, .foregroundColor: UIColor.black])
            }
        }
        return image.cgImage!
    }
}
