import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import MapKit
import UIKit

// MARK: - 旅のダイジェストの仕上げ（3.2）
//
// ほかの Vlog アプリと比べて足りなかった3つ。
// - 最初の題名のカード（旅行名・Day・日付・行き先）
// - 最後の地図のカード（その日の行程を番号つきのピンと線で）
// - 音楽（アプリに入れた曲を下に敷き、最後はだんだん小さくする）

extension TripDigestComposer {

    /// 最初のカードに出す文字
    struct Opening {
        var title: String
        var subtitle: String
        var destination: String?
    }

    /// 題名のカードの長さ
    static let openingSeconds = 2.4

    /// 題名のカードの、その時点での見え方。
    /// 0〜0.35秒で文字が下から出て、1.0〜1.5秒で消える。1.0秒から1.4秒かけてゆっくりぼかしと暗さが抜け、最後のコマでは
    /// 1コマ目の最初の絵そのものになる（つなぎ目が見えない）
    struct OpeningLook: Equatable {
        /// ぼかし（0〜1。1 で一番ぼかす）
        var blur: Double
        /// 文字の濃さ（0〜1）
        var textAlpha: Double
        /// 文字が下から上がってくる残り（0〜1。1 で一番下）
        var textRise: Double

        static func at(_ time: Double) -> OpeningLook {
            func smooth(_ from: Double, _ to: Double) -> Double {
                let x = min(max((time - from) / (to - from), 0), 1)
                return x * x * (3 - 2 * x)
            }
            let textIn = smooth(0, 0.35)
            return OpeningLook(blur: 1 - smooth(1.0, openingSeconds),
                               textAlpha: textIn * (1 - smooth(1.0, 1.5)),
                               textRise: 1 - textIn)
        }
    }

    /// 題名のカードの1コマ。background は1コマ目の最初の絵（画面いっぱいに広げたもの）
    static func openingFrame(background: CIImage, text: CIImage?, time: Double) -> CIImage {
        let look = OpeningLook.at(time)
        let canvas = CGRect(origin: .zero, size: renderSize)
        var scene = background
        if look.blur > 0.01 {
            scene = background.clampedToExtent()
                .applyingGaussianBlur(sigma: 36 * look.blur)
                .cropped(to: canvas)
            let dim = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 0.42 * look.blur)).cropped(to: canvas)
            scene = dim.composited(over: scene)
        }
        guard let text else { return scene }
        // CIImage は上が +y。下から上がってくるので、はじめは少し下げておく
        let risen = text.transformed(by: CGAffineTransform(translationX: 0, y: -36 * look.textRise))
        return scene.applyingOverlay(risen, alpha: look.textAlpha)
    }

    /// 題名のカードの止まった見本（文字がいちばん見えているところ）。背景が無ければ暗い色の上に
    static func openingImage(_ opening: Opening, background: CIImage?) -> CIImage? {
        let base = background.map { fill($0, zoom: 1).composited(over: .black) }
            ?? CIImage(color: CIColor(red: 0.08, green: 0.09, blue: 0.12)).cropped(to: CGRect(origin: .zero, size: renderSize))
        return openingFrame(background: base, text: openingTextImage(opening), time: 0.7)
    }

    /// 題名のカードの文字だけ（地は透明）。行き先・題名・短い線・日付
    static func openingTextImage(_ opening: Opening) -> CIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let W = renderSize.width, H = renderSize.height
        let text = UIGraphicsImageRenderer(size: renderSize, format: format).image { context in
            let style = NSMutableParagraphStyle()
            style.alignment = .center
            style.lineBreakMode = .byWordWrapping
            let shadow = NSShadow()
            shadow.shadowColor = UIColor.black.withAlphaComponent(0.45)
            shadow.shadowBlurRadius = 12
            func draw(_ string: String, size: CGFloat, weight: UIFont.Weight, alpha: CGFloat, top: CGFloat,
                      lines: Int = 1, kern: CGFloat = 0) -> CGFloat {
                var fontSize = size
                func attrs() -> [NSAttributedString.Key: Any] {
                    [.font: UIFont.systemFont(ofSize: fontSize, weight: weight),
                     .foregroundColor: UIColor.white.withAlphaComponent(alpha),
                     .paragraphStyle: style, .shadow: shadow, .kern: kern]
                }
                let width = W - 140
                var box = (string as NSString).boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                                            options: [.usesLineFragmentOrigin], attributes: attrs(), context: nil)
                while box.height > fontSize * 1.3 * CGFloat(lines) && fontSize > size * 0.35 {
                    fontSize -= 2
                    box = (string as NSString).boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                                            options: [.usesLineFragmentOrigin], attributes: attrs(), context: nil)
                }
                let height = ceil(box.height)
                (string as NSString).draw(with: CGRect(x: 70, y: top, width: width, height: height),
                                          options: [.usesLineFragmentOrigin], attributes: attrs(), context: nil)
                return height
            }

            var top = H * 0.36
            if let destination = opening.destination, !destination.isEmpty {
                top += draw(destination.uppercased(), size: 40, weight: .semibold, alpha: 0.85, top: top, kern: 6) + 28
            }
            top += draw(opening.title, size: 104, weight: .heavy, alpha: 1, top: top, lines: 2) + 30
            // 題名と日付の間の短い線
            context.cgContext.setFillColor(UIColor.white.withAlphaComponent(0.8).cgColor)
            context.cgContext.fill(CGRect(x: W / 2 - 40, y: top, width: 80, height: 4))
            top += 34
            _ = draw(opening.subtitle, size: 44, weight: .semibold, alpha: 0.92, top: top)
        }
        return text.cgImage.map { CIImage(cgImage: $0) }
    }

    // MARK: 地図のカード

    /// 地図のカード。画面いっぱいの地図に、回った順に経路が伸びていき、着いたところで番号のピンが出る。
    /// 文字はほかのコマと同じ部品（`overlayImage`）で、選んだ位置に出す
    struct MapCard {
        static let seconds = 3.0
        /// 場所の名前の札を付ける上限（多いと地図が埋まる）
        static let maxLabels = 6
        /// 経路を引き終えるまで（そのあとは止めて見せる）
        static let drawStart = 0.25, drawEnd = 2.2

        let map: UIImage
        /// 場所の位置（絵の左上から）
        let points: [CGPoint]
        let names: [String]
        let overlay: CIImage?

        /// i 番目のピンが出る時刻
        func arrival(_ i: Int) -> Double {
            guard points.count > 1 else { return Self.drawStart }
            return Self.drawStart + (Self.drawEnd - Self.drawStart) * Double(i) / Double(points.count - 1)
        }

        func frame(at time: Double) -> CIImage? {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = true
            let blue = UIColor.systemBlue, orange = UIColor.systemOrange
            let image = UIGraphicsImageRenderer(size: renderSize, format: format).image { context in
                let cg = context.cgContext
                map.draw(in: CGRect(origin: .zero, size: renderSize))

                // 経路（白い点線）。今いる区間は途中まで
                if points.count >= 2, time > Self.drawStart {
                    let path = UIBezierPath()
                    path.move(to: points[0])
                    for i in 1..<points.count {
                        let from = arrival(i - 1), to = arrival(i)
                        if time >= to {
                            path.addLine(to: points[i])
                        } else {
                            let x = (time - from) / (to - from)
                            let a = points[i - 1], b = points[i]
                            path.addLine(to: CGPoint(x: a.x + (b.x - a.x) * x, y: a.y + (b.y - a.y) * x))
                            break
                        }
                    }
                    path.lineWidth = 9
                    path.lineCapStyle = .round
                    path.lineJoinStyle = .round
                    path.setLineDash([0.1, 20], count: 2, phase: 0)
                    cg.setShadow(offset: .zero, blur: 6, color: UIColor.black.withAlphaComponent(0.5).cgColor)
                    UIColor.white.withAlphaComponent(0.95).setStroke()
                    path.stroke()
                    cg.setShadow(offset: .zero, blur: 0, color: nil)
                }

                // ピンと名前の札。着いた瞬間に少し大きく出て、元の大きさに戻る
                for (i, center) in points.enumerated() {
                    let elapsed = time - arrival(i)
                    guard elapsed >= 0 else { continue }
                    let x = min(elapsed / 0.25, 1)
                    let pop = 1 + 0.25 * sin(x * .pi) * (1 - x)
                    let appear = min(elapsed / 0.12, 1)
                    let radius = 32 * CGFloat(pop) * CGFloat(0.4 + 0.6 * appear)
                    let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
                    cg.setAlpha(CGFloat(appear))
                    cg.setShadow(offset: CGSize(width: 0, height: 4), blur: 10, color: UIColor.black.withAlphaComponent(0.4).cgColor)
                    (i == points.count - 1 ? orange : blue).setFill()
                    UIBezierPath(ovalIn: rect).fill()
                    cg.setShadow(offset: .zero, blur: 0, color: nil)
                    UIColor.white.setStroke()
                    let ring = UIBezierPath(ovalIn: rect.insetBy(dx: 3, dy: 3))
                    ring.lineWidth = 5
                    ring.stroke()
                    let number = "\(i + 1)" as NSString
                    let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 30 * CGFloat(pop), weight: .bold),
                                                                .foregroundColor: UIColor.white]
                    let size = number.size(withAttributes: attrs)
                    number.draw(at: CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2), withAttributes: attrs)

                    if i < names.count {
                        drawLabel(names[i], next: center, alpha: appear)
                    }
                    cg.setAlpha(1)
                }
            }
            guard let cg = image.cgImage else { return nil }
            return CIImage(cgImage: cg).applyingOverlay(overlay)
        }

        /// ピンの横の名前の札（右に入らなければ左に）
        private func drawLabel(_ name: String, next center: CGPoint, alpha: Double) {
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 30, weight: .semibold),
                                                        .foregroundColor: UIColor.white]
            let maxText: CGFloat = 360
            let textSize = (name as NSString).boundingRect(with: CGSize(width: maxText, height: 40),
                                                           options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                                                           attributes: attrs, context: nil).size
            let chip = CGSize(width: ceil(min(textSize.width, maxText)) + 28, height: 52)
            var x = center.x + 44
            if x + chip.width > renderSize.width - 24 { x = center.x - 44 - chip.width }
            let rect = CGRect(x: max(x, 24), y: center.y - chip.height / 2, width: chip.width, height: chip.height)
            UIColor.black.withAlphaComponent(0.55).setFill()
            UIBezierPath(roundedRect: rect, cornerRadius: chip.height / 2).fill()
            let style = NSMutableParagraphStyle()
            style.lineBreakMode = .byTruncatingTail
            var textAttrs = attrs
            textAttrs[.paragraphStyle] = style
            (name as NSString).draw(in: CGRect(x: rect.minX + 14, y: rect.midY - textSize.height / 2,
                                               width: rect.width - 28, height: textSize.height),
                                    withAttributes: textAttrs)
        }
    }

    /// 地図のカードを作る（地図を読む）。電波が無いなどで読めなければ nil（カードを入れずに作る）
    /// - Parameters:
    ///   - caption: 小さい1行（「Day 2」）
    ///   - headline: 大きい文字（行き先や旅行名）
    static func mapCard(stops: [TripDigest.MapStop], caption: String, headline: String,
                        position: TextPosition, watermark: Bool) async -> MapCard? {
        guard !stops.isEmpty else { return nil }
        let W = renderSize.width, H = renderSize.height
        // 経路を置く範囲。文字の位置と重ならないところ
        let area: CGRect = {
            switch position {
            case .bottomLeft: return CGRect(x: W * 0.14, y: H * 0.12, width: W * 0.72, height: H * 0.5)
            case .topRight: return CGRect(x: W * 0.14, y: H * 0.36, width: W * 0.72, height: H * 0.5)
            case .center: return CGRect(x: W * 0.14, y: H * 0.1, width: W * 0.72, height: H * 0.5)
            }
        }()
        let options = MKMapSnapshotter.Options()
        options.mapRect = mapRect(fitting: stops, into: area)
        options.size = renderSize
        options.scale = 1
        // 写真のあいだに入れてもなじむよう、色を抑えた暗い地図にする
        let configuration = MKStandardMapConfiguration(emphasisStyle: .muted)
        configuration.pointOfInterestFilter = .excludingAll
        options.preferredConfiguration = configuration
        options.traitCollection = UITraitCollection(userInterfaceStyle: .dark)
        guard let snapshot = try? await MKMapSnapshotter(options: options).start() else { return nil }

        let points = stops.map { snapshot.point(for: CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)) }
        let overlay = overlayImage(caption: caption, headline: headline, title: nil, subtitle: "",
                                   position: position, watermark: watermark, centerTop: 0.7)
        return MapCard(map: snapshot.image, points: points,
                       names: stops.count <= MapCard.maxLabels ? stops.map(\.name) : [],
                       overlay: overlay)
    }

    /// 全部の場所が area（絵の中の範囲）に収まる地図の範囲。1か所だけなら、その周り1.5kmほど
    private static func mapRect(fitting stops: [TripDigest.MapStop], into area: CGRect) -> MKMapRect {
        let mapPoints = stops.map { MKMapPoint(CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)) }
        let minX = mapPoints.map(\.x).min()!, maxX = mapPoints.map(\.x).max()!
        let minY = mapPoints.map(\.y).min()!, maxY = mapPoints.map(\.y).max()!
        let minimum = 1500 * MKMapPointsPerMeterAtLatitude(stops[0].latitude)
        // 絵の1点あたりの地図の長さ
        let perPixel = max(max(maxX - minX, minimum) / area.width, max(maxY - minY, minimum) / area.height)
        let width = renderSize.width * perPixel, height = renderSize.height * perPixel
        let centerX = (minX + maxX) / 2, centerY = (minY + maxY) / 2
        return MKMapRect(x: centerX - area.midX * perPixel, y: centerY - area.midY * perPixel, width: width, height: height)
    }
}

// MARK: - 色味

extension DigestLook {
    /// 色味をかける（1コマの絵に。大きさは変えない）
    nonisolated func apply(to image: CIImage) -> CIImage {
        switch self {
        case .natural:
            return image
        case .film:
            // 黒を少し浮かせ、色を抑えて、ほんのり黄色く
            let curve = CIFilter.toneCurve()
            curve.inputImage = image
            curve.point0 = CGPoint(x: 0, y: 0.07)
            curve.point1 = CGPoint(x: 0.25, y: 0.25)
            curve.point2 = CGPoint(x: 0.5, y: 0.51)
            curve.point3 = CGPoint(x: 0.75, y: 0.76)
            curve.point4 = CGPoint(x: 1, y: 0.95)
            let colors = CIFilter.colorControls()
            colors.inputImage = curve.outputImage
            colors.saturation = 0.82
            colors.contrast = 0.97
            return Self.tint(colors.outputImage ?? image, red: 1.03, blue: 0.94)
        case .warm:
            let colors = CIFilter.colorControls()
            colors.inputImage = Self.tint(image, red: 1.07, blue: 0.9)
            colors.saturation = 1.08
            return colors.outputImage ?? image
        case .crisp:
            let vibrance = CIFilter.vibrance()
            vibrance.inputImage = image
            vibrance.amount = 0.35
            let colors = CIFilter.colorControls()
            colors.inputImage = vibrance.outputImage
            colors.contrast = 1.08
            colors.brightness = 0.01
            return Self.tint(colors.outputImage ?? image, red: 0.99, blue: 1.02)
        case .mono:
            let mono = CIFilter.photoEffectMono()
            mono.inputImage = image
            return mono.outputImage ?? image
        }
    }

    /// 赤と青の強さを変える（1 より大きいと強く）
    nonisolated private static func tint(_ image: CIImage, red: CGFloat, blue: CGFloat) -> CIImage {
        let matrix = CIFilter.colorMatrix()
        matrix.inputImage = image
        matrix.rVector = CIVector(x: red, y: 0, z: 0, w: 0)
        matrix.bVector = CIVector(x: 0, y: 0, z: blue, w: 0)
        return matrix.outputImage ?? image
    }
}

// MARK: - 音楽

/// ダイジェストに敷く曲。アプリに `DigestMusic_<名前>.m4a`（mp3・caf も可）として入れたものを使う。
///
/// 曲はアプリに入れて配る（ほかのアプリでの使用・配布が許された曲だけを入れること）。
/// 1曲も入っていなければ、音楽の選択は出さない
enum TripDigestMusic {
    struct Track: Identifiable, Hashable {
        var id: String { fileName }
        let fileName: String
        let name: String
        let url: URL
    }

    static let filePrefix = "DigestMusic_"

    static let tracks: [Track] = {
        ["m4a", "mp3", "caf"]
            .flatMap { Bundle.main.urls(forResourcesWithExtension: $0, subdirectory: nil) ?? [] }
            .filter { $0.lastPathComponent.hasPrefix(filePrefix) }
            .map { url in
                let base = url.deletingPathExtension().lastPathComponent
                let name = String(base.dropFirst(filePrefix.count))
                    .replacingOccurrences(of: "_", with: " ")
                    // 並び順のための先頭の番号（「01 」）は見せない
                    .replacingOccurrences(of: #"^\d+\s*"#, with: "", options: .regularExpression)
                return Track(fileName: url.lastPathComponent, name: name, url: url)
            }
            .sorted { $0.fileName < $1.fileName }
    }()

    static func track(id: String?) -> Track? {
        guard let id else { return nil }
        return tracks.first { $0.id == id }
    }
}
