import Testing
import UIKit
@testable import GoTravel

/// 旅のダイジェストの文字の書体（3.5。Pro）
@Suite(.serialized)
struct DigestFontTests {

    @Test("どの書体も端末に入っていて、ふつう以外はふつうと違う書体になる")
    func fontsResolve() {
        let system = UIFont.systemFont(ofSize: 40, weight: .bold).fontName
        for font in DigestFont.allCases {
            let bold = font.font(ofSize: 40, weight: .bold)
            let light = font.font(ofSize: 40, weight: .regular)
            #expect(bold.pointSize == 40)
            if font == .standard {
                #expect(!font.isPro)
            } else {
                #expect(font.isPro)
                #expect(bold.fontName != system, "\(font.name) が端末に無い")
                #expect(light.fontName != UIFont.systemFont(ofSize: 40).fontName)
            }
        }
    }

    @Test("Pro の書体は Pro の機能に数え、Pro をやめると「ふつう」に戻る")
    func proGate() {
        let defaults = UserDefaults.standard
        let saved = defaults.string(forKey: DigestFont.storageKey)
        defer { defaults.set(saved, forKey: DigestFont.storageKey) }

        defaults.set(DigestFont.mincho.rawValue, forKey: DigestFont.storageKey)
        #expect(DigestFinish.proFeatures.contains("「明朝」の書体"))
        DigestFinish.dropPro()
        #expect(DigestFont.current == .standard)
        #expect(!DigestFinish.proFeatures.contains { $0.hasSuffix("の書体") })
    }

    @Test("書体ごとに、コマの文字を描ける（見本を書き出す）")
    func renderSamples() throws {
        let defaults = UserDefaults.standard
        let saved = defaults.string(forKey: DigestFont.storageKey)
        defer { defaults.set(saved, forKey: DigestFont.storageKey) }
        let clip = TripDigest.Clip(sourceId: "s", dayNumber: 2, date: Date(), timeText: "14:05", placeName: "首里城 Shuri Castle")
        let context = CIContext()
        // 見本はテストの一時フォルダに書き出す（目で確かめるとき用）
        let out: String? = (NSTemporaryDirectory() as NSString).appendingPathComponent("digest-font-samples")
        try FileManager.default.createDirectory(atPath: out!, withIntermediateDirectories: true)
        for font in DigestFont.allCases {
            defaults.set(font.rawValue, forKey: DigestFont.storageKey)
            let overlay = try #require(TripDigestComposer.overlayImage(for: clip, title: "沖縄旅行", subtitle: "2026/12/20 〜 12/23",
                                                                      position: .bottomLeft))
            let background = CIImage(color: CIColor(red: 0.4, green: 0.45, blue: 0.5)).cropped(to: overlay.extent)
            let cg = try #require(context.createCGImage(overlay.composited(over: background), from: overlay.extent))
            let url = URL(fileURLWithPath: out!).appendingPathComponent("\(font.rawValue).png")
            try #require(UIImage(cgImage: cg).pngData()).write(to: url)
            print("DIGEST_FONT_SAMPLE \(url.path)")
        }
    }

    @Test("行の高い書体でも、1行に入る文字は縮めない（エレガントで日付が小さくなっていた）")
    func doesNotShrinkTallFonts() throws {
        let defaults = UserDefaults.standard
        let saved = defaults.string(forKey: DigestFont.storageKey)
        defer { defaults.set(saved, forKey: DigestFont.storageKey) }
        let clip = TripDigest.Clip(sourceId: "s", dayNumber: 2, date: Date(), timeText: "14:05", placeName: nil)
        func inkHeight(_ font: DigestFont) throws -> Int {
            defaults.set(font.rawValue, forKey: DigestFont.storageKey)
            let overlay = try #require(TripDigestComposer.overlayImage(for: clip, title: nil, subtitle: "", position: .center))
            let cg = try #require(CIContext().createCGImage(overlay, from: overlay.extent))
            // 白い文字のある行の数（影や暗い面は数えない）
            let data = try #require(cg.dataProvider?.data as Data?)
            let width = cg.width, bytesPerRow = cg.bytesPerRow
            return (0..<cg.height).filter { y in
                (0..<width).contains { x in
                    let i = y * bytesPerRow + x * 4
                    return data[i] > 240 && data[i + 1] > 240 && data[i + 2] > 240 && data[i + 3] > 240
                }
            }.count
        }
        let standard = try inkHeight(.standard)
        for font in [DigestFont.elegant, .mincho, .typewriter, .maru] {
            #expect(Double(try inkHeight(font)) > Double(standard) * 0.6, "\(font.name) の文字が小さすぎる")        }
    }
}
