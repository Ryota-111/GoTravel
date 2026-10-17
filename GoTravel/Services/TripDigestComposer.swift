import AVFoundation
import Photos
import UIKit
import CoreImage

/// 旅のダイジェストの動画を作る（Travory Pro）。
///
/// 写真は少しずつ寄っていく2秒の動画にし、動画は真ん中の2秒を切り出して、順につなぐ。
/// 時刻と場所の文字を重ね、縦長（1080 × 1920）の mp4 に書き出す。端末の中だけで作り、どこにも上げない
enum TripDigestComposer {

    static let renderSize = CGSize(width: 1080, height: 1920)
    static let fps: Int32 = 30

    /// 時刻・場所の文字を置く位置
    enum TextPosition: String, CaseIterable, Identifiable {
        case bottomLeft
        case center
        case topRight

        var id: String { rawValue }

        var name: String {
            switch self {
            case .bottomLeft: return "左下"
            case .center: return "真ん中"
            case .topRight: return "右上"
            }
        }

        var systemImage: String {
            switch self {
            case .bottomLeft: return "arrow.down.left.square"
            case .center: return "square.dashed.inset.filled"
            case .topRight: return "arrow.up.right.square"
            }
        }
    }

    /// つなぐ素材1つ
    struct Item {
        enum Media {
            case image(UIImage)
            case video(AVAsset)
        }
        var media: Media
        var clip: TripDigest.Clip
    }

    enum ComposeError: LocalizedError {
        case noAccess
        case empty
        case failed

        var errorDescription: String? {
            switch self {
            case .noAccess: return "写真へのアクセスが許可されていません。設定アプリの「Travory」→「写真」から許可してください。"
            case .empty: return "この期間に撮った写真や動画が見つかりませんでした。"
            case .failed: return "動画を作れませんでした。もう一度お試しください。"
            }
        }
    }

    // MARK: カメラロール

    static func requestAccess() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return status == .authorized || status == .limited
    }

    /// 旅行の期間に撮った写真・動画（スクリーンショットは除く）
    static func sources(for plan: TravelPlan, calendar: Calendar = .current) -> (sources: [TripDigest.Source], assets: [String: PHAsset]) {
        let start = calendar.startOfDay(for: plan.startDate)
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: plan.endDate)) ?? plan.endDate
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate < %@", start as NSDate, end as NSDate)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let result = PHAsset.fetchAssets(with: options)
        var sources: [TripDigest.Source] = []
        var assets: [String: PHAsset] = [:]
        result.enumerateObjects { asset, _, _ in
            guard asset.mediaType == .image || asset.mediaType == .video,
                  !asset.mediaSubtypes.contains(.photoScreenshot),
                  let date = asset.creationDate else { return }
            assets[asset.localIdentifier] = asset
            sources.append(TripDigest.Source(id: asset.localIdentifier, date: date, isVideo: asset.mediaType == .video,
                                             duration: asset.duration,
                                             latitude: asset.location?.coordinate.latitude,
                                             longitude: asset.location?.coordinate.longitude))
        }
        return (sources, assets)
    }

    /// 選んだコマの写真・動画を読み込む（iCloud にあるものは取ってくる）
    static func loadItems(_ clips: [TripDigest.Clip], assets: [String: PHAsset]) async -> [Item] {
        var items: [Item] = []
        for clip in clips {
            guard let asset = assets[clip.sourceId] else { continue }
            if asset.mediaType == .video, let video = await requestVideo(asset) {
                items.append(Item(media: .video(video), clip: clip))
            } else if let image = await requestImage(asset) {
                items.append(Item(media: .image(image), clip: clip))
            }
        }
        return items
    }

    private static func requestImage(_ asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.resizeMode = .fast
            PHImageManager.default().requestImage(for: asset, targetSize: renderSize, contentMode: .aspectFill,
                                                  options: options) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }

    private static func requestVideo(_ asset: PHAsset) async -> AVAsset? {
        await withCheckedContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .mediumQualityFormat
            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
                continuation.resume(returning: avAsset)
            }
        }
    }

    // MARK: つなぐ

    /// 1コマずつ、縦長の2秒の動画に作り直して（文字もここで焼き込む）、最後に順につなぐ。
    /// 文字を Core Animation で重ねるやり方はシミュレーターで落ちるうえ、縦に撮った動画の向きも
    /// コマごとに直す必要があるので、1コマずつ自分で描く
    /// - Parameter title: 最初のコマに大きく出す題名（旅行名と日付）
    static func compose(_ items: [Item], title: String, subtitle: String, fileName: String,
                        textPosition: TextPosition = .bottomLeft,
                        progress: @escaping @Sendable (Double) -> Void = { _ in }) async throws -> URL {
        guard !items.isEmpty else { throw ComposeError.empty }
        let work = FileManager.default.temporaryDirectory.appendingPathComponent("digest-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: work) }

        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        else { throw ComposeError.failed }
        var audioTrack: AVMutableCompositionTrack?
        var cursor = CMTime.zero

        for (index, item) in items.enumerated() {
            let overlay = overlayImage(for: item.clip, title: index == 0 ? title : nil, subtitle: subtitle,
                                       position: textPosition)
            let segmentURL = work.appendingPathComponent("\(index).mov")
            var audioSource: (track: AVAssetTrack, range: CMTimeRange)?
            switch item.media {
            case .image(let image):
                try await writeSegment(to: segmentURL, seconds: TripDigest.clipSeconds) { frame, frames in
                    guard let cg = image.cgImage else { return nil }
                    let zoom = 1 + 0.06 * Double(frame) / Double(max(frames - 1, 1))
                    return fill(CIImage(cgImage: cg), zoom: zoom).composited(over: .black)
                        .applyingOverlay(overlay)
                }
            case .video(let video):
                guard let source = try await video.loadTracks(withMediaType: .video).first else { continue }
                let total = try await video.load(.duration)
                let length = CMTimeMinimum(CMTime(seconds: TripDigest.clipSeconds, preferredTimescale: 600), total)
                // 動画は真ん中を使う（撮りはじめと撮り終わりはぶれやすい）
                let start = CMTimeMaximum(.zero, CMTimeMultiplyByRatio(CMTimeSubtract(total, length), multiplier: 1, divisor: 2))
                let range = CMTimeRange(start: start, duration: length)
                let frames = try await readFrames(of: video, track: source, range: range)
                guard !frames.isEmpty else { continue }
                try await writeSegment(to: segmentURL, seconds: length.seconds) { frame, total in
                    let index = min(frames.count - 1, Int(Double(frame) / Double(max(total, 1)) * Double(frames.count)))
                    return fill(frames[index], zoom: 1).composited(over: .black).applyingOverlay(overlay)
                }
                if let audio = try await video.loadTracks(withMediaType: .audio).first {
                    audioSource = (audio, range)
                }
            }

            let segment = AVURLAsset(url: segmentURL)
            guard let segmentTrack = try await segment.loadTracks(withMediaType: .video).first else { continue }
            let segmentDuration = try await segment.load(.duration)
            try videoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: segmentDuration), of: segmentTrack, at: cursor)
            if let audioSource {
                if audioTrack == nil {
                    audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
                }
                let range = CMTimeRange(start: audioSource.range.start,
                                        duration: CMTimeMinimum(audioSource.range.duration, segmentDuration))
                try? audioTrack?.insertTimeRange(range, of: audioSource.track, at: cursor)
            }
            cursor = CMTimeAdd(cursor, segmentDuration)
            progress(Double(index + 1) / Double(items.count) * 0.85)
        }
        guard cursor > .zero else { throw ComposeError.failed }

        let output = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: output)
        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality)
        else { throw ComposeError.failed }
        try await session.export(to: output, as: .mp4)
        progress(1)
        return output
    }

    private static let ciContext = CIContext(options: [.cacheIntermediates: false])

    /// 縦長の画面いっぱいに広げる（はみ出したところは切る）
    static func fill(_ image: CIImage, zoom: Double) -> CIImage {
        let extent = image.extent
        let scale = max(renderSize.width / extent.width, renderSize.height / extent.height) * zoom
        let scaled = image
            .transformed(by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY))
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let offsetX = (renderSize.width - extent.width * scale) / 2
        let offsetY = (renderSize.height - extent.height * scale) / 2
        return scaled.transformed(by: CGAffineTransform(translationX: offsetX, y: offsetY))
            .cropped(to: CGRect(origin: .zero, size: renderSize))
    }

    /// 動画の、その範囲のコマを読む（縦に撮った動画は向きを直す）
    static func readFrames(of asset: AVAsset, track: AVAssetTrack, range: CMTimeRange) async throws -> [CIImage] {
        let transform = try await track.load(.preferredTransform)
        let orientation = orientation(of: transform)
        let reader = try AVAssetReader(asset: asset)
        reader.timeRange = range
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ])
        output.alwaysCopiesSampleData = false
        reader.add(output)
        guard reader.startReading() else { throw ComposeError.failed }
        var frames: [CIImage] = []
        while let sample = output.copyNextSampleBuffer() {
            guard let buffer = CMSampleBufferGetImageBuffer(sample) else { continue }
            // 読んだ画素を持ち続けると次の読み込みが詰まるので、縮めてから写しを取っておく
            let image = CIImage(cvPixelBuffer: buffer).oriented(orientation)
            let small = image.transformed(by: CGAffineTransform(scaleX: 0.5, y: 0.5))
            if let cg = ciContext.createCGImage(small, from: small.extent) {
                frames.append(CIImage(cgImage: cg))
            }
        }
        return frames
    }

    private static func orientation(of t: CGAffineTransform) -> CGImagePropertyOrientation {
        switch (t.a, t.b, t.c, t.d) {
        case (0, 1, -1, 0): return .right
        case (0, -1, 1, 0): return .left
        case (-1, 0, 0, -1): return .down
        default: return .up
        }
    }

    /// 2秒の縦長の動画を書く。各コマの絵は `draw(コマ番号, コマ数)` が返す
    static func writeSegment(to url: URL, seconds: Double,
                             draw: (Int, Int) -> CIImage?) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: renderSize.width,
            AVVideoHeightKey: renderSize.height
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: renderSize.width,
            kCVPixelBufferHeightKey as String: renderSize.height
        ])
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let frames = max(Int(seconds * Double(fps)), 1)
        for frame in 0..<frames {
            while !input.isReadyForMoreMediaData { try await Task.sleep(nanoseconds: 2_000_000) }
            guard let image = draw(frame, frames), let pool = adaptor.pixelBufferPool else { throw ComposeError.failed }
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
            guard let buffer else { throw ComposeError.failed }
            ciContext.render(image, to: buffer, bounds: CGRect(origin: .zero, size: renderSize),
                             colorSpace: CGColorSpaceCreateDeviceRGB())
            adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: fps))
        }
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw ComposeError.failed }
    }

    // MARK: 文字

    /// 「Day 2   14:05」と場所の名前を、選んだ位置に置く。最初のコマには題名を大きく出す。
    /// 場所の名前は省略しない（1行に入らなければ、入るまで文字を小さくする）
    static func overlayImage(for clip: TripDigest.Clip, title: String?, subtitle: String,
                             position: TextPosition = .bottomLeft) -> CIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let W = renderSize.width, H = renderSize.height
        let margin: CGFloat = 72
        let image = UIGraphicsImageRenderer(size: renderSize, format: format).image { context in
            let cg = context.cgContext
            // 文字のあたりを少し暗くして、白い文字を読めるようにする
            let dark = UIColor.black.withAlphaComponent(0.5).cgColor, clear = UIColor.black.withAlphaComponent(0).cgColor
            let space = CGColorSpaceCreateDeviceRGB()
            switch position {
            case .bottomLeft:
                if let g = CGGradient(colorsSpace: space, colors: [clear, dark] as CFArray, locations: [0, 1]) {
                    cg.drawLinearGradient(g, start: CGPoint(x: 0, y: H - 640), end: CGPoint(x: 0, y: H), options: [])
                }
            case .topRight:
                if let g = CGGradient(colorsSpace: space, colors: [dark, clear] as CFArray, locations: [0, 1]) {
                    cg.drawLinearGradient(g, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: 640), options: [])
                }
            case .center:
                cg.setFillColor(UIColor.black.withAlphaComponent(0.22).cgColor)
                cg.fill(CGRect(origin: .zero, size: renderSize))
            }

            let shadow = NSShadow()
            shadow.shadowColor = UIColor.black.withAlphaComponent(0.5)
            shadow.shadowBlurRadius = 10
            func attributes(_ size: CGFloat, _ weight: UIFont.Weight, _ align: NSTextAlignment) -> [NSAttributedString.Key: Any] {
                let style = NSMutableParagraphStyle()
                style.alignment = align
                style.lineBreakMode = .byWordWrapping
                return [.font: UIFont.systemFont(ofSize: size, weight: weight), .foregroundColor: UIColor.white,
                        .paragraphStyle: style, .shadow: shadow]
            }
            /// 幅に収まるよう、lines 行に入るまで文字を小さくする。描いた高さを返す
            @discardableResult
            func draw(_ text: String, size: CGFloat, weight: UIFont.Weight, align: NSTextAlignment,
                      width: CGFloat, origin: CGPoint, lines: Int = 1, fromBottom: Bool = false) -> CGFloat {
                var fontSize = size
                var attrs = attributes(fontSize, weight, align)
                var box = (text as NSString).boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                                          options: [.usesLineFragmentOrigin], attributes: attrs, context: nil)
                while box.height > fontSize * 1.25 * CGFloat(lines) && fontSize > size * 0.3 {
                    fontSize -= 2
                    attrs = attributes(fontSize, weight, align)
                    box = (text as NSString).boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                                          options: [.usesLineFragmentOrigin], attributes: attrs, context: nil)
                }
                let height = ceil(box.height)
                let y = fromBottom ? origin.y - height : origin.y
                (text as NSString).draw(with: CGRect(x: origin.x, y: y, width: width, height: height),
                                        options: [.usesLineFragmentOrigin], attributes: attrs, context: nil)
                return height
            }

            let timeText = "Day \(clip.dayNumber)   \(clip.timeText)"
            let width = W - margin * 2
            switch position {
            case .bottomLeft:
                // 下から積む：場所の名前（2行まで）、その上に時刻
                var bottom = H - 150
                if let place = clip.placeName {
                    bottom -= draw(place, size: 64, weight: .bold, align: .left, width: width,
                                   origin: CGPoint(x: margin, y: bottom), fromBottom: true) + 8
                }
                draw(timeText, size: 44, weight: .semibold, align: .left, width: width,
                     origin: CGPoint(x: margin, y: bottom), fromBottom: true)
            case .topRight:
                var top: CGFloat = 170
                top += draw(timeText, size: 44, weight: .semibold, align: .right, width: width,
                            origin: CGPoint(x: margin, y: top)) + 8
                if let place = clip.placeName {
                    draw(place, size: 64, weight: .bold, align: .right, width: width,
                         origin: CGPoint(x: margin, y: top))
                }
            case .center:
                // 最初のコマは題名の下に置く
                var top: CGFloat = title == nil ? H * 0.44 : H * 0.56
                top += draw(timeText, size: 44, weight: .semibold, align: .center, width: width,
                            origin: CGPoint(x: margin, y: top)) + 8
                if let place = clip.placeName {
                    draw(place, size: 64, weight: .bold, align: .center, width: width,
                         origin: CGPoint(x: margin, y: top))
                }
            }

            if let title {
                let top = H * (position == .center ? 0.34 : 0.38)
                let used = draw(title, size: 96, weight: .heavy, align: .center, width: W - 120,
                                origin: CGPoint(x: 60, y: top), lines: 2)
                draw(subtitle, size: 44, weight: .semibold, align: .center, width: W - 120,
                     origin: CGPoint(x: 60, y: top + used + 16))
            }
        }
        return image.cgImage.map { CIImage(cgImage: $0) }
    }
}

private extension CIImage {
    func applyingOverlay(_ overlay: CIImage?) -> CIImage {
        guard let overlay else { return self }
        return overlay.composited(over: self)
    }
}
