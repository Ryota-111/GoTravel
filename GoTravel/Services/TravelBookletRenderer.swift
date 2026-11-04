import SwiftUI
import MapKit

/// 旅のしおりを PDF に書き出す（Travory Pro）。
///
/// 地図と写真を先に用意してから、1ページずつ SwiftUI の画面を PDF に描く。
/// 文字は画像にせず PDF の文字として描くので、印刷しても拡大してもにじまない
@MainActor
enum TravelBookletRenderer {

    struct Output: Hashable, Identifiable {
        let url: URL
        let pageCount: Int
        var id: URL { url }
    }

    static func render(plan: TravelPlan, options: TravelBooklet.Options, style: TravelBooklet.Style,
                       theme: ThemePreset, userId: String?) async throws -> Output {
        let pages = TravelBooklet.pages(for: plan, options: options, userId: userId)
        guard !pages.isEmpty else { throw BookletError.empty }

        // 地図（1日目のページにだけ載る）
        var maps: [Int: UIImage] = [:]
        let palette = BookletPalette.make(style, theme: theme)
        for page in pages {
            guard case let .day(dayNumber, _, true, _) = page,
                  let day = plan.daySchedulesInRange.first(where: { $0.dayNumber == dayNumber }) else { continue }
            let items = TravelPlanTextExporter.sortedByTime(day.scheduleItems)
            maps[dayNumber] = try? await mapImage(for: items, accent: UIColor(palette.accent))
        }

        let context = BookletContext(plan: plan, style: style, palette: palette, userId: userId,
                                     coverImage: options.includesCover ? coverImage(for: plan) : nil,
                                     maps: maps, pageCount: pages.count)

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(TravelBooklet.fileName(for: plan))
        try? FileManager.default.removeItem(at: url)
        var box = CGRect(origin: .zero, size: TravelBooklet.pageSize)
        guard let pdf = CGContext(url as CFURL, mediaBox: &box, [
            kCGPDFContextTitle as String: "\(plan.title)のしおり",
            kCGPDFContextCreator as String: "Travory"
        ] as CFDictionary) else { throw BookletError.failed }

        for (index, page) in pages.enumerated() {
            let renderer = ImageRenderer(content: BookletPageView(page: page, pageNumber: index + 1, context: context))
            renderer.proposedSize = ProposedViewSize(TravelBooklet.pageSize)
            pdf.beginPDFPage(nil)
            renderer.render { _, draw in draw(pdf) }
            pdf.endPDFPage()
        }
        pdf.closePDF()
        return Output(url: url, pageCount: pages.count)
    }

    enum BookletError: LocalizedError {
        case empty
        case failed

        var errorDescription: String? {
            switch self {
            case .empty: return "入れるものがありません。日程や持ち物を入れてから作ってください。"
            case .failed: return "しおりを作れませんでした。もう一度お試しください。"
            }
        }
    }

    // MARK: 写真

    /// 表紙の写真（自分で選んだ写真、なければ共有の相手が選んだ写真）
    static func coverImage(for plan: TravelPlan) -> UIImage? {
        if let name = plan.localImageFileName, let image = FileManager.documentsImage(named: name) {
            return image
        }
        if let url = plan.sharedCoverFileURL, let data = try? Data(contentsOf: url) {
            return UIImage(data: data)
        }
        return nil
    }

    // MARK: 地図

    /// その日の場所に、日程と同じ番号の印を付けた地図
    static func mapImage(for items: [ScheduleItem], accent: UIColor,
                         size: CGSize = CGSize(width: 356, height: 170)) async throws -> UIImage? {
        let numbered = items.filter(\.hasCoordinate)
        guard !numbered.isEmpty else { return nil }
        let coordinates = numbered.compactMap { item -> CLLocationCoordinate2D? in
            guard let lat = item.latitude, let lon = item.longitude else { return nil }
            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            // 壊れた座標が1つでもあると範囲が作れず、MapKit が落ちる
            return CLLocationCoordinate2DIsValid(coordinate) ? coordinate : nil
        }

        let options = MKMapSnapshotter.Options()
        // 日付変更線をまたぐ日（羽田からロサンゼルスへ飛ぶ日など）も囲めるよう、共通の範囲の決め方を使う。
        // 以前は経度の最小と最大から幅を出していて、幅が360度を超えると MapKit が例外を投げて落ちていた
        guard let region = MapRegionFitting.region(fitting: coordinates, minimumSpan: 0.02) else { return nil }
        options.region = region
        options.size = size
        options.scale = 3
        options.pointOfInterestFilter = .excludingAll
        options.traitCollection = UITraitCollection(userInterfaceStyle: .light)
        let snapshot = try await MKMapSnapshotter(options: options).start()

        return UIGraphicsImageRenderer(size: size).image { _ in
            snapshot.image.draw(at: .zero)
            for (index, coordinate) in coordinates.enumerated() {
                let point = snapshot.point(for: coordinate)
                let rect = CGRect(x: point.x - 9, y: point.y - 9, width: 18, height: 18)
                UIColor.white.setFill()
                UIBezierPath(ovalIn: rect.insetBy(dx: -2, dy: -2)).fill()
                accent.setFill()
                UIBezierPath(ovalIn: rect).fill()
                let text = "\(index + 1)" as NSString
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 10, weight: .bold),
                    .foregroundColor: UIColor.white
                ]
                let textSize = text.size(withAttributes: attributes)
                text.draw(at: CGPoint(x: point.x - textSize.width / 2, y: point.y - textSize.height / 2),
                          withAttributes: attributes)
            }
        }
    }
}
