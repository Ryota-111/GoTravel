import AVFoundation
import Photos
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// 旅のダイジェストの動画を作る（Travory Pro）。
///
/// 写真は少しずつ寄っていく2秒の動画にし、動画は真ん中の2秒を切り出して、順につなぐ。
/// 時刻と場所の文字を重ね、縦長（1080 × 1920）の mp4 に書き出す。端末の中だけで作り、どこにも上げない
enum TripDigestComposer {

    /// 書き出す大きさ。選んでいる画面の形（縦長・正方形・横長。3.2）で変わる
    static var renderSize: CGSize { DigestShape.current.size }
    /// 横 ÷ 縦（見本の枠に使う）
    static var aspectRatio: CGFloat { renderSize.width / renderSize.height }
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
            if Task.isCancelled { break }
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
    /// 途中でやめられる（呼んだ Task を cancel すると `CancellationError` を投げる）
    /// - Parameters:
    ///   - title: 最初のコマに大きく出す題名（旅行名と日付）
    ///   - watermark: 右下に小さく「Travory」を入れる（無料のとき）
    ///   - endCard: 最後に1秒「Travory」の印を入れる（無料のとき）
    ///   - opening: 最初に題名のカードを入れる（3.2）。入れるときは、1コマ目に題名を重ねない
    ///   - mapCard: 最後（印の前）に入れる地図のカード（3.2。経路が伸びていく）
    ///   - music: 下に敷く曲（3.2）。動画より短ければくり返し、最後はだんだん小さくする
    ///   - keepsOriginalSound: 動画のコマの音を残すか。曲を敷くときは小さめにする
    ///   - edits: コマごとのトリミングと、動画を何秒目から使うか（写真・動画の id ごと。3.2）
    ///   - look: 色味（3.2）。題名のカードの背景にもかける
    static func compose(_ items: [Item], title: String, subtitle: String, fileName: String,
                        textPosition: TextPosition = .bottomLeft,
                        watermark: Bool = false,
                        endCard: Bool = false,
                        opening: Opening? = nil,
                        mapCard: MapCard? = nil,
                        music: URL? = nil,
                        keepsOriginalSound: Bool = true,
                        edits: [String: DigestClipEdit] = [:],
                        look: DigestLook = .natural,
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

        /// 絵を書いた動画を、今の位置に足す（題名・地図のカード）
        func appendSegment(_ name: String, seconds: Double, draw: (Int, Int) -> CIImage?) async throws {
            let url = work.appendingPathComponent("\(name).mov")
            try await writeSegment(to: url, seconds: seconds, draw: draw)
            let segment = AVURLAsset(url: url)
            guard let track = try await segment.loadTracks(withMediaType: .video).first else { return }
            let duration = try await segment.load(.duration)
            try videoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: track, at: cursor)
            cursor = CMTimeAdd(cursor, duration)
        }

        /// 題名のカードの文字（コマごとに描かず、1枚を動かして使う）
        let openingText = opening.flatMap(openingTextImage)
        /// 1コマの秒数（3.2で選べるようにした）
        let clipSeconds = TripDigest.clipSeconds
        /// 1コマ目の文字を出し切るまでのコマ数（題名のカードのあと、文字がいきなり出ないように）
        let overlayFadeFrames = 0.4 * Double(fps)

        for (index, item) in items.enumerated() {
            try Task.checkCancellation()
            // 1コマ目（読めずに飛ばしたコマは数えない）
            let isFirst = cursor == .zero
            let fadesIn = isFirst && opening != nil
            // 題名のカードを入れたときは、1コマ目に題名を重ねない
            let overlay = overlayImage(for: item.clip, title: isFirst && opening == nil ? title : nil, subtitle: subtitle,
                                       position: textPosition, watermark: watermark)
            func overlayAlpha(_ frame: Int) -> Double { fadesIn ? min(1, Double(frame) / overlayFadeFrames) : 1 }
            let segmentURL = work.appendingPathComponent("\(index).mov")
            var audioSource: (track: AVAssetTrack, range: CMTimeRange)?
            /// このコマの最初の絵（題名のカードは、これにピントが合って終わる）
            var firstFrame: CIImage?
            let edit = edits[item.clip.sourceId] ?? DigestClipEdit()
            switch item.media {
            case .image(let image):
                guard let cg = image.cgImage else { continue }
                let source = CIImage(cgImage: cg)
                firstFrame = frameImage(source, edit: edit, look: look)
                try await writeSegment(to: segmentURL, seconds: clipSeconds) { frame, frames in
                    // 写真は少しずつ寄っていく
                    let motion = 1 + 0.06 * Double(frame) / Double(max(frames - 1, 1))
                    return frameImage(source, edit: edit, look: look, motion: motion)
                        .applyingOverlay(overlay, alpha: overlayAlpha(frame))
                }
            case .video(let video):
                guard let source = try await video.loadTracks(withMediaType: .video).first else { continue }
                let total = try await video.load(.duration)
                // 決めていなければ真ん中を使う（撮りはじめと撮り終わりはぶれやすい）
                let used = edit.videoRange(duration: total.seconds, length: clipSeconds)
                let range = CMTimeRange(start: CMTime(seconds: used.start, preferredTimescale: 600),
                                        duration: CMTime(seconds: used.length, preferredTimescale: 600))
                let frames = try await readFrames(of: video, track: source, range: range)
                guard !frames.isEmpty else { continue }
                firstFrame = frameImage(frames[0], edit: edit, look: look)
                try await writeSegment(to: segmentURL, seconds: used.length) { frame, total in
                    let index = min(frames.count - 1, Int(Double(frame) / Double(max(total, 1)) * Double(frames.count)))
                    return frameImage(frames[index], edit: edit, look: look)
                        .applyingOverlay(overlay, alpha: overlayAlpha(frame))
                }
                if keepsOriginalSound, let audio = try await video.loadTracks(withMediaType: .audio).first {
                    audioSource = (audio, range)
                }
            }

            let segment = AVURLAsset(url: segmentURL)
            guard let segmentTrack = try await segment.loadTracks(withMediaType: .video).first else { continue }
            let segmentDuration = try await segment.load(.duration)
            // 題名のカードは1コマ目の前に入れる。ぼかした1コマ目の最初の絵から始まり、最後にピントが合う
            if fadesIn, let firstFrame {
                try await appendSegment("opening", seconds: openingSeconds) { frame, frames in
                    openingFrame(background: firstFrame, text: openingText,
                                 time: openingSeconds * Double(frame) / Double(max(frames - 1, 1)))
                }
            }
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

        if let mapCard {
            try await appendSegment("map", seconds: MapCard.seconds) { frame, frames in
                mapCard.frame(at: MapCard.seconds * Double(frame) / Double(max(frames - 1, 1)))
            }
        }

        // 無料のときは、最後に1秒「Travory」の印を入れる（右下の小さな文字とあわせて。Pro は印なし）
        if endCard, let card = endCardImage() {
            let url = work.appendingPathComponent("end.mov")
            try await writeSegment(to: url, seconds: 1) { _, _ in card }
            let segment = AVURLAsset(url: url)
            if let track = try await segment.loadTracks(withMediaType: .video).first {
                let duration = try await segment.load(.duration)
                try videoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: track, at: cursor)
                cursor = CMTimeAdd(cursor, duration)
            }
        }

        // 曲を敷く。短ければくり返し、最初は少しずつ大きく、最後の1.5秒でだんだん小さくする。
        // 動画のコマの音は、曲の邪魔にならないよう小さめにする
        var mixParameters: [AVMutableAudioMixInputParameters] = []
        if let music {
            let musicAsset = AVURLAsset(url: music)
            if let source = try? await musicAsset.loadTracks(withMediaType: .audio).first,
               let musicTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                let length = try await musicAsset.load(.duration)
                var at = CMTime.zero
                while CMTimeCompare(at, cursor) < 0 && CMTimeCompare(length, .zero) > 0 {
                    let piece = CMTimeMinimum(length, CMTimeSubtract(cursor, at))
                    try musicTrack.insertTimeRange(CMTimeRange(start: .zero, duration: piece), of: source, at: at)
                    at = CMTimeAdd(at, piece)
                }
                let parameters = AVMutableAudioMixInputParameters(track: musicTrack)
                let fadeIn = CMTime(seconds: 0.5, preferredTimescale: 600)
                let fadeOut = CMTime(seconds: min(1.5, cursor.seconds / 3), preferredTimescale: 600)
                parameters.setVolumeRamp(fromStartVolume: 0, toEndVolume: 0.8, timeRange: CMTimeRange(start: .zero, duration: fadeIn))
                parameters.setVolumeRamp(fromStartVolume: 0.8, toEndVolume: 0,
                                         timeRange: CMTimeRange(start: CMTimeSubtract(cursor, fadeOut), duration: fadeOut))
                mixParameters.append(parameters)
                if let audioTrack {
                    let original = AVMutableAudioMixInputParameters(track: audioTrack)
                    original.setVolume(0.45, at: .zero)
                    mixParameters.append(original)
                }
            }
        }

        try Task.checkCancellation()
        let output = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: output)
        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality)
        else { throw ComposeError.failed }
        if !mixParameters.isEmpty {
            let mix = AVMutableAudioMix()
            mix.inputParameters = mixParameters
            session.audioMix = mix
        }
        try await session.export(to: output, as: .mp4)
        progress(1)
        return output
    }

    private static let ciContext = CIContext(options: [.cacheIntermediates: false])

    /// 画面いっぱいに広げる（はみ出したところは切る）。focus（左上が 0）が画面の真ん中に来るよう寄せるが、
    /// 写真の外が見えるところまでは寄せない
    static func fill(_ image: CIImage, zoom: Double, focus: CGPoint = CGPoint(x: 0.5, y: 0.5)) -> CIImage {
        fill(image, zoom: zoom, focus: focus, canvas: renderSize)
    }

    /// canvas の大きさに広げる（見本の動画のように、作る処理の外からも使う）
    nonisolated static func fill(_ image: CIImage, zoom: Double, focus: CGPoint, canvas: CGSize) -> CIImage {
        let extent = image.extent
        let size = DigestClipEdit.filledSize(of: extent.size, in: canvas, zoom: zoom)
        let origin = DigestClipEdit.origin(of: extent.size, in: canvas, zoom: zoom, focus: focus)
        let scale = size.width / extent.width
        // CIImage は下が 0 なので、上からの位置を下からに直す
        return image
            .transformed(by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY))
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .transformed(by: CGAffineTransform(translationX: origin.x, y: canvas.height - origin.y - size.height))
            .cropped(to: CGRect(origin: .zero, size: canvas))
    }

    /// 1コマの絵：トリミングして画面いっぱいに広げ、色味をかける。motion は写真を少しずつ寄せる倍率
    static func frameImage(_ source: CIImage, edit: DigestClipEdit = DigestClipEdit(), look: DigestLook = .natural,
                           motion: Double = 1) -> CIImage {
        frameImage(source, edit: edit, look: look, motion: motion, canvas: renderSize)
    }

    nonisolated static func frameImage(_ source: CIImage, edit: DigestClipEdit, look: DigestLook,
                                       motion: Double, canvas: CGSize) -> CIImage {
        let filled = fill(source, zoom: edit.zoom * motion, focus: CGPoint(x: edit.focusX, y: edit.focusY), canvas: canvas)
        return look.apply(to: filled.composited(over: .black)).cropped(to: CGRect(origin: .zero, size: canvas))
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
            if Task.isCancelled {
                writer.cancelWriting()
                throw CancellationError()
            }
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
    /// 場所の名前は省略しない（1行に入らなければ、入るまで文字を小さくする）。
    /// watermark なら右下に小さく「Travory」を入れる（左下の文字より下に置くので重ならない）
    static func overlayImage(for clip: TripDigest.Clip, title: String?, subtitle: String,
                             position: TextPosition = .bottomLeft, watermark: Bool = false) -> CIImage? {
        overlayImage(caption: "Day \(clip.dayNumber)   \(clip.timeText)", headline: clip.placeName,
                     title: title, subtitle: subtitle, position: position, watermark: watermark)
    }

    /// コマの文字（小さい1行 `caption` と、大きい `headline`）を選んだ位置に置く。地図のカードも同じ見た目にするため分けた。
    /// - Parameter centerTop: 真ん中のときの文字の上端（画面の高さに対する割合）。地図のカードは経路と重ならないよう下げる
    static func overlayImage(caption: String, headline: String?, title: String?, subtitle: String,
                             position: TextPosition = .bottomLeft, watermark: Bool = false,
                             centerTop: CGFloat? = nil) -> CIImage? {
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

            let timeText = caption
            let width = W - margin * 2
            switch position {
            case .bottomLeft:
                // 下から積む：場所の名前（2行まで）、その上に時刻
                var bottom = H - 150
                if let place = headline {
                    bottom -= draw(place, size: 64, weight: .bold, align: .left, width: width,
                                   origin: CGPoint(x: margin, y: bottom), fromBottom: true) + 8
                }
                draw(timeText, size: 44, weight: .semibold, align: .left, width: width,
                     origin: CGPoint(x: margin, y: bottom), fromBottom: true)
            case .topRight:
                var top: CGFloat = 170
                top += draw(timeText, size: 44, weight: .semibold, align: .right, width: width,
                            origin: CGPoint(x: margin, y: top)) + 8
                if let place = headline {
                    draw(place, size: 64, weight: .bold, align: .right, width: width,
                         origin: CGPoint(x: margin, y: top))
                }
            case .center:
                // 最初のコマは題名の下に置く
                var top: CGFloat = centerTop.map { H * $0 } ?? (title == nil ? H * 0.44 : H * 0.56)
                top += draw(timeText, size: 44, weight: .semibold, align: .center, width: width,
                            origin: CGPoint(x: margin, y: top)) + 8
                if let place = headline {
                    draw(place, size: 64, weight: .bold, align: .center, width: width,
                         origin: CGPoint(x: margin, y: top))
                }
            }

            if watermark {
                draw("Travory", size: 34, weight: .semibold, align: .right, width: width,
                     origin: CGPoint(x: margin, y: H - 72), fromBottom: true)
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

extension TripDigestComposer {
    /// 最後の印（暗い地に「Travory」）
    static func endCardImage() -> CIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: renderSize, format: format).image { context in
            UIColor(white: 0.08, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: renderSize))
            let style = NSMutableParagraphStyle()
            style.alignment = .center
            func draw(_ text: String, font: UIFont, color: UIColor, y: CGFloat) {
                (text as NSString).draw(in: CGRect(x: 0, y: y, width: renderSize.width, height: font.lineHeight * 1.3),
                                        withAttributes: [.font: font, .foregroundColor: color, .paragraphStyle: style])
            }
            let titleFont = UIFont.systemFont(ofSize: 110, weight: .bold)
            draw("Travory", font: titleFont, color: .white, y: renderSize.height * 0.42)
            draw("旅のしおりと旅行記録", font: .systemFont(ofSize: 44, weight: .medium),
                 color: UIColor(white: 1, alpha: 0.7), y: renderSize.height * 0.42 + titleFont.lineHeight * 1.3 + 10)
        }
        return image.cgImage.map { CIImage(cgImage: $0) }
    }
}

extension CIImage {
    /// 文字などを重ねる。alpha が 1 より小さければ薄く重ねる（だんだん出すとき）
    func applyingOverlay(_ overlay: CIImage?, alpha: Double = 1) -> CIImage {
        guard let overlay, alpha > 0 else { return self }
        let covered = overlay.composited(over: self)
        guard alpha < 1 else { return covered }
        let dissolve = CIFilter.dissolveTransition()
        dissolve.inputImage = self
        dissolve.targetImage = covered
        dissolve.time = Float(alpha)
        return dissolve.outputImage ?? covered
    }
}
