import Testing
import Foundation
import UIKit
@testable import GoTravel

/// PDF から予約を読む（3.6。Gmail の「印刷」から共有したメールや e チケット）
struct ReservationPDFTextReaderTests {

    private let lines = [
        "【予約確認】ご搭乗のご案内",
        "便名\tSKY 111便",
        "出発\t神戸 07:30",
        "到着\t那覇 09:35",
        "搭乗日\t2026年10月6日",
        "予約番号\tK7Q2PX",
        "お支払金額\t12,800円"
    ]

    @Test("文字の入った PDF（メールを印刷したもの）から、予約番号・便名を読み取れる")
    func readsTextPDF() async throws {
        let text = try await ReservationPDFTextReader.text(from: textPDF(lines))
        let drafts = ReservationEmailParser.parse(text)

        #expect(text.contains("K7Q2PX"), "\(text)")
        #expect(drafts.first?.kind == .flight, "\(text)")
        #expect(drafts.first?.transportNumber == "SKY111", "\(text)")
        #expect(drafts.first?.confirmationNumber == "K7Q2PX", "\(text)")
    }

    @Test("文字の入っていない PDF（スキャンしたもの）は、ページを画像にして読む", .timeLimit(.minutes(1)))
    func readsScannedPDF() async throws {
        let text = try await ReservationPDFTextReader.text(from: imageOnlyPDF(lines))
        #expect(text.contains("K7Q2PX"), "\(text)")
    }

    @Test("PDF でないものや、白紙の PDF は読めない")
    func rejectsUnreadable() async {
        await #expect(throws: ReservationPDFTextReader.ReadError.self) {
            try await ReservationPDFTextReader.text(from: Data("not a pdf".utf8))
        }
        await #expect(throws: ReservationPDFTextReader.ReadError.self) {
            try await ReservationPDFTextReader.text(from: textPDF([]))
        }
    }

    @Test("ページ番号だけのような短い文字は、文字が無いものとみなす")
    func shortTextIsNotEnough() {
        #expect(!ReservationPDFTextReader.hasEnoughText(" 1 / 2 \n"))
        #expect(ReservationPDFTextReader.hasEnoughText("予約番号 K7Q2PX 搭乗日 2026年10月6日"))
    }

    // MARK: - PDF を作る

    private let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)   // A4

    private func textPDF(_ lines: [String]) -> Data {
        UIGraphicsPDFRenderer(bounds: pageRect).pdfData { context in
            context.beginPage()
            draw(lines)
        }
    }

    /// 文字を画像にしてから貼った PDF（中に文字は入っていない）
    private func imageOnlyPDF(_ lines: [String]) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        let image = UIGraphicsImageRenderer(size: pageRect.size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(pageRect)
            draw(lines)
        }
        return UIGraphicsPDFRenderer(bounds: pageRect).pdfData { context in
            context.beginPage()
            image.draw(in: pageRect)
        }
    }

    private func draw(_ lines: [String]) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16),
            .foregroundColor: UIColor.black
        ]
        for (index, line) in lines.enumerated() {
            let columns = line.components(separatedBy: "\t")
            let y = 60 + CGFloat(index) * 32
            (columns[0] as NSString).draw(at: CGPoint(x: 50, y: y), withAttributes: attributes)
            if columns.count > 1 {
                (columns[1] as NSString).draw(at: CGPoint(x: 260, y: y), withAttributes: attributes)
            }
        }
    }
}
