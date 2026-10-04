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
