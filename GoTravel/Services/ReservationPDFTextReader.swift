import Foundation
import PDFKit
import UIKit

/// 予約確認メールを PDF にしたもの（Gmail の「印刷」から共有）や、e チケットの PDF から文字を読む（3.6）。
///
/// Gmail アプリには、メール1通を丸ごと共有する手段が「印刷 → 共有（PDF）」しかない、というご意見から。
///
/// - 文字の入った PDF（メールを印刷したもの・多くの e チケット）は、中の文字をそのまま読む
/// - 文字の入っていない PDF（紙をスキャンしたもの）は、初めの数ページを画像にして、
///   スクリーンショットと同じく端末の中で文字を読む（`ReservationImageTextReader`）
/// - **端末の中だけで読む。** PDF はどこにも送らない
enum ReservationPDFTextReader {

    enum ReadError: Error {
        case unreadable
        case noText
    }

    /// 中の文字を読むページ数。長い PDF（約款つきなど）でも、予約の内容は初めのほうにある
    static let maxTextPages = 10
    /// 画像にして読むページ数。1ページに数秒かかるので少なくする
    static let maxImagePages = 3

    static func text(at url: URL) async throws -> String {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { throw ReadError.unreadable }
        return try await text(from: data)
    }

    static func text(from data: Data) async throws -> String {
        guard let document = PDFDocument(data: data), document.pageCount > 0 else { throw ReadError.unreadable }
        // 鍵のかかった PDF は開けない（パスワードを聞く画面は作らない）
        guard !document.isLocked else { throw ReadError.unreadable }

        let embedded = embeddedText(of: document)
        if hasEnoughText(embedded) { return embedded }

        // 文字の入っていない PDF。ページを画像にして読む
        var pages: [String] = []
        for index in 0..<min(document.pageCount, maxImagePages) {
            guard let page = document.page(at: index), let image = render(page) else { continue }
            if let text = try? await ReservationImageTextReader.text(from: image) {
                pages.append(text)
            }
        }
        let recognized = pages.joined(separator: "\n")
        guard hasEnoughText(recognized) else { throw ReadError.noText }
        return recognized
    }

    /// PDF に入っている文字（初めの `maxTextPages` ページ）。ページの間は改行でつなぐ
    static func embeddedText(of document: PDFDocument) -> String {
        (0..<min(document.pageCount, maxTextPages))
            .compactMap { document.page(at: $0)?.string }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 予約として読むのに足りる文字があるか。
    /// スキャンした PDF でも、ページ番号やごく短い文字だけが入っていることがあるので、それは無いものとみなす
    static func hasEnoughText(_ text: String) -> Bool {
        text.unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) }.count >= 20
    }

    /// ページを、文字が読める大きさ（長い辺が 2400px くらい）の画像にする
    private static func render(_ page: PDFPage) -> CGImage? {
        let bounds = page.bounds(for: .mediaBox)
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        let scale = min(3, 2400 / max(bounds.width, bounds.height))
        let size = CGSize(width: (bounds.width * scale).rounded(), height: (bounds.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let cg = context.cgContext
            // PDF は左下が原点なので、上下を返してから描く
            cg.translateBy(x: 0, y: size.height)
            cg.scaleBy(x: scale, y: -scale)
            cg.translateBy(x: -bounds.minX, y: -bounds.minY)
            page.draw(with: .mediaBox, to: cg)
        }
        return image.cgImage
    }

    /// 受け取り箱や取り込み画面に出す、1ページ目の小さな絵
    static func thumbnail(at url: URL, side: CGFloat) -> UIImage? {
        guard let page = PDFDocument(url: url)?.page(at: 0) else { return nil }
        return page.thumbnail(of: CGSize(width: side, height: side), for: .mediaBox)
    }

    static func pageCount(at url: URL) -> Int {
        PDFDocument(url: url)?.pageCount ?? 0
    }
}
