import Testing
import Foundation
import UIKit
import SwiftUI
@testable import GoTravel

/// 旅の思い出をつくる（3.8）のテンプレートを、見本の写真で全部書き出す（見た目を確かめるため）。
/// 書き出し先は環境変数 `MEMORY_GALLERY_DIR`（`TEST_RUNNER_MEMORY_GALLERY_DIR=... xcodebuild test ...`）。
/// 渡されていなければ何もしないので、ふだんのテストでは動かない
@MainActor
struct MemoryGalleryTests {
    nonisolated static var directory: String? { ProcessInfo.processInfo.environment["MEMORY_GALLERY_DIR"].flatMap { $0.isEmpty ? nil : $0 } }

    func photo(_ i: Int) -> UIImage {
        let palettes: [[UIColor]] = [
            [UIColor(red: 0.45, green: 0.75, blue: 0.98, alpha: 1), UIColor(red: 0.1, green: 0.65, blue: 0.75, alpha: 1), UIColor(red: 0.95, green: 0.9, blue: 0.75, alpha: 1)],
            [UIColor(red: 0.98, green: 0.6, blue: 0.3, alpha: 1), UIColor(red: 0.85, green: 0.3, blue: 0.4, alpha: 1), UIColor(red: 0.2, green: 0.15, blue: 0.3, alpha: 1)],
            [UIColor(red: 0.6, green: 0.85, blue: 0.95, alpha: 1), UIColor(red: 0.2, green: 0.55, blue: 0.3, alpha: 1), UIColor(red: 0.85, green: 0.8, blue: 0.6, alpha: 1)],
        ]
        let p = palettes[i % palettes.count]
        let size = CGSize(width: 1200, height: i % 2 == 0 ? 900 : 1500)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: p.map(\.cgColor) as CFArray, locations: [0, 0.6, 1])!
            ctx.cgContext.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            UIColor.white.withAlphaComponent(0.6).setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: size.width * 0.65, y: size.height * 0.12, width: 160, height: 160))
        }
    }

    @Test(.enabled(if: directory != nil)) func gallery() throws {
        var images: [String: UIImage] = [:]
        var photos: [MemoryPhoto] = []
        for i in 0..<9 { images["a\(i)"] = photo(i); photos.append(MemoryPhoto(assetId: "a\(i)", date: Date())) }
        var base = MemoryProject(planId: "p", kind: .photoDump, templateId: "", aspect: .story)
        base.photos = photos
        base.subtitle = "2026.11.15 – 11.17"
        base.badge = "3 DAYS"
        let out = URL(fileURLWithPath: Self.directory ?? NSTemporaryDirectory())
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        for template in MemoryTemplate.all {
            var project = base
            project.kind = template.kind
            project.templateId = template.id
            switch template.kind {
            case .photoDump:
                project.title = "Okinawa Trip"; project.note = "Good Memories ♡"; project.detail = "Okinawa"
            case .poster:
                project.title = "Okinawa"; project.note = "A Journey to Remember"; project.detail = "26.2124° N  ·  127.6792° E"
            case .diary:
                project.title = "Okinawa Trip"
                project.pages = [DiaryPage(dayNumber: 1, date: Date(), headline: "はじめての沖縄、最高のスタート！", entries: [
                    DiaryEntry(time: Date(), text: "初めての沖縄そば！", photo: photos[0]),
                    DiaryEntry(time: Date().addingTimeInterval(9000), text: "海が綺麗すぎた…♡", photo: photos[1]),
                    DiaryEntry(time: Date().addingTimeInterval(18000), text: "予定になかったカフェに寄り道", photo: photos[2]),
                    DiaryEntry(time: Date().addingTimeInterval(27000), text: "夕日を見ながらドライブ", photo: photos[3]),
                ])]
            }
            for aspect in [MemoryAspect.story, .feed] {
                project.aspect = aspect
                let image = MemoryRenderer.render(templateId: template.id, project: project, images: images, showsWatermark: true)
                try image?.jpegData(compressionQuality: 0.7)?.write(to: out.appendingPathComponent("\(template.id)-\(aspect.rawValue).jpg"))
            }
        }
        // 日本語の題
        var jp = base; jp.kind = .photoDump; jp.templateId = "dump.polaroid"; jp.title = "沖縄の旅"; jp.note = "また行きたい"; jp.detail = "沖縄"
        try MemoryRenderer.render(templateId: jp.templateId, project: jp, images: images, showsWatermark: false)?
            .jpegData(compressionQuality: 0.7)?.write(to: out.appendingPathComponent("dump.polaroid-jp.jpg"))
    }
}
