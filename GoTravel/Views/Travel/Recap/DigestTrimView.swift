import AVFoundation
import Photos
import SwiftUI

/// 1コマのトリミングと、動画のどこを使うかを決める画面（3.2）。
///
/// 枠は作る動画と同じ形。写真を指で動かして見せたいところを枠に入れ、2本指で広げると大きくできる。
/// 動画は下の帯で、使う範囲を選ぶ（3.9。ご要望から、始まりだけでなく終わりも選べるようにした）。
/// 両はしのつまみで始まりと終わりを、真ん中を動かすと長さはそのままで位置を変えられる。
/// 枠の中には、動かしているつまみの時点の絵を出す
struct DigestTrimView: View {
    let clip: TripDigest.Clip
    let asset: PHAsset?
    let look: DigestLook
    let onDone: (DigestClipEdit) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var edit: DigestClipEdit
    /// 指を置いたときの位置と倍率（動かした分を足す元）
    @State private var dragStart: DigestClipEdit?
    @State private var pinchStart: Double?
    @State private var source: UIImage?
    @State private var video: AVAsset?
    /// 動画の使う範囲（帯の値）
    @State private var start: Double = 0
    @State private var length: Double = 0
    /// 帯を動かしはじめたときの範囲（動かした分を足す元）
    @State private var rangeBase: (start: Double, length: Double)?
    /// 枠に出す絵の時点（動かしているつまみの位置）
    @State private var previewTime: Double = 0
    /// 帯の中に並べる、動画の小さな絵（写真アプリと同じように、どのあたりか分かるように）
    @State private var filmstrip: [UIImage] = []
    private static let filmstripCount = 10

    init(clip: TripDigest.Clip, asset: PHAsset?, edit: DigestClipEdit, look: DigestLook,
         onDone: @escaping (DigestClipEdit) -> Void) {
        self.clip = clip
        self.asset = asset
        self.look = look
        self.onDone = onDone
        _edit = State(initialValue: edit)
    }

    private var isVideo: Bool { asset?.mediaType == .video }
    private var duration: Double { asset?.duration ?? 0 }
    private var clipSeconds: Double { TripDigest.clipSeconds }
    /// 決めていないときの長さ（1コマの秒数。短い動画は全部）
    private var defaultLength: Double { min(clipSeconds, duration) }
    private var minLength: Double { min(DigestClipEdit.videoLengthRange.lowerBound, duration) }
    private var maxLength: Double { min(DigestClipEdit.videoLengthRange.upperBound, duration) }
    /// 範囲を選べる動画か（とても短い動画は全部使う）
    private var showsRange: Bool { isVideo && duration > DigestClipEdit.videoLengthRange.lowerBound + 0.1 }

    var body: some View {
        VStack(spacing: 18) {
            Text(isVideo ? "指で動かして見せたいところを枠に入れ、2本指で広げると大きくできます。下の帯で、動画のどこからどこまで使うかを選べます。"
                 : "指で動かして見せたいところを枠に入れ、2本指で広げると大きくできます。")
                .font(.footnote)
                .foregroundColor(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            cropFrame
                .padding(.horizontal, 28)
                .frame(maxHeight: .infinity)
            if showsRange {
                rangeBar
                    .padding(.horizontal, 24)
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("トリミング")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button("元に戻す") {
                    withAnimation(.easeOut(duration: 0.2)) {
                        // 並べ替えた位置は残す（ここで戻すのは見え方だけ）
                        var reset = DigestClipEdit()
                        reset.sortTime = edit.sortTime
                        edit = reset
                        let range = reset.videoRange(duration: duration, length: clipSeconds)
                        start = range.start
                        length = range.length
                        previewTime = start
                    }
                }
                .disabled(edit.isUntrimmed)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("決める") {
                    onDone(edit)
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
        .task { await load() }
        .task(id: previewTime) { await showFrame(at: previewTime) }
    }

    // MARK: 枠

    private var cropFrame: some View {
        Color(white: 0.12)
            .aspectRatio(TripDigestComposer.aspectRatio, contentMode: .fit)
            .overlay {
                GeometryReader { geo in
                    if let source {
                        let canvas = geo.size
                        let size = DigestClipEdit.filledSize(of: source.size, in: canvas, zoom: edit.zoom)
                        let origin = DigestClipEdit.origin(of: source.size, in: canvas, zoom: edit.zoom,
                                                           focus: CGPoint(x: edit.focusX, y: edit.focusY))
                        Image(uiImage: source)
                            .resizable()
                            .frame(width: size.width, height: size.height)
                            .position(x: origin.x + size.width / 2, y: origin.y + size.height / 2)
                            .gesture(drag(canvas: canvas, source: source.size)
                                .simultaneously(with: pinch(canvas: canvas, source: source.size)))
                    } else {
                        ProgressView().tint(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .overlay { thirds.allowsHitTesting(false) }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(.white.opacity(0.8), lineWidth: 1.5))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 動かしている間だけ出す、3分割の線
    private var thirds: some View {
        GeometryReader { geo in
            Path { path in
                for i in 1...2 {
                    let x = geo.size.width * CGFloat(i) / 3, y = geo.size.height * CGFloat(i) / 3
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geo.size.height))
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geo.size.width, y: y))
                }
            }
            .stroke(.white.opacity(0.45), lineWidth: 0.7)
        }
        .opacity(dragStart != nil || pinchStart != nil ? 1 : 0)
        .animation(.easeOut(duration: 0.15), value: dragStart != nil || pinchStart != nil)
    }

    private func drag(canvas: CGSize, source: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let base = dragStart ?? edit
                if dragStart == nil { dragStart = edit }
                let size = DigestClipEdit.filledSize(of: source, in: canvas, zoom: base.zoom)
                var next = edit
                // 指を右へ動かすと、写真の左のほうが見えてくる
                next.focusX = base.focusX - value.translation.width / size.width
                next.focusY = base.focusY - value.translation.height / size.height
                edit = next.clamped(source: source, canvas: canvas)
            }
            .onEnded { _ in dragStart = nil }
    }

    private func pinch(canvas: CGSize, source: CGSize) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let base = pinchStart ?? edit.zoom
                if pinchStart == nil { pinchStart = edit.zoom }
                var next = edit
                next.zoom = base * value.magnification
                edit = next.clamped(source: source, canvas: canvas)
            }
            .onEnded { _ in pinchStart = nil }
    }

    // MARK: 動画の使う範囲

    private var rangeBar: some View {
        VStack(spacing: 8) {
            HStack {
                Text("使う範囲")
                    .font(.footnote.weight(.semibold))
                Spacer()
                Text("\(Self.timeText(start)) 〜 \(Self.timeText(start + length))（\(String(format: "%.1f", length))秒）")
                    .font(.footnote.monospacedDigit())
            }
            .foregroundColor(.white)
            GeometryReader { geo in
                let width = max(geo.size.width, 1)
                let x0 = width * start / max(duration, 0.01)
                let x1 = width * (start + length) / max(duration, 0.01)
                ZStack(alignment: .leading) {
                    filmstripView
                        .frame(width: width, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    // 使わないところは暗くする
                    Rectangle()
                        .fill(.black.opacity(0.6))
                        .frame(width: max(x0, 0), height: 44)
                    Rectangle()
                        .fill(.black.opacity(0.6))
                        .frame(width: max(width - x1, 0), height: 44)
                        .offset(x: x1)
                    // 使う範囲。真ん中を動かすと、長さはそのままで位置が変わる
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(.white, lineWidth: 3)
                        .frame(width: max(x1 - x0, 4), height: 44)
                        .contentShape(Rectangle())
                        .offset(x: x0)
                        .gesture(rangeDrag(width: width, part: .middle))
                    handle(at: x0, part: .start, width: width)
                    handle(at: x1, part: .end, width: width)
                }
            }
            .frame(height: 44)
            HStack {
                Text(Self.timeText(0))
                Spacer()
                Text("動画の長さ \(Self.timeText(duration))")
            }
            .font(.caption2.monospacedDigit())
            .foregroundColor(.white.opacity(0.55))
        }
    }

    /// 帯の中の小さな絵。読めるまでは薄い灰色
    private var filmstripView: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(filmstrip.indices, id: \.self) { index in
                    Image(uiImage: filmstrip[index])
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width / CGFloat(max(filmstrip.count, 1)), height: geo.size.height)
                        .clipped()
                }
            }
        }
        .background(Color.white.opacity(0.14))
        .accessibilityHidden(true)
    }

    private enum RangePart { case start, end, middle }

    /// 始まり・終わりのつまみ（指で押さえやすいよう、見た目より広く反応する）
    private func handle(at x: CGFloat, part: RangePart, width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(.white)
            .frame(width: 12, height: 44)
            .overlay(Image(systemName: part == .start ? "chevron.compact.left" : "chevron.compact.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.black.opacity(0.6)))
            .frame(width: 36, height: 44)
            .contentShape(Rectangle())
            .offset(x: x - 18)
            .gesture(rangeDrag(width: width, part: part))
            .accessibilityElement()
            .accessibilityLabel(part == .start ? "使いはじめ" : "使い終わり")
            .accessibilityValue(Self.timeText(part == .start ? start : start + length))
            .accessibilityAdjustableAction { direction in
                let step = direction == .increment ? 0.5 : -0.5
                rangeBase = (start, length)
                moveRange(part: part, by: step)
                rangeBase = nil
            }
    }

    private func rangeDrag(width: CGFloat, part: RangePart) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if rangeBase == nil { rangeBase = (start, length) }
                moveRange(part: part, by: Double(value.translation.width / width) * duration)
            }
            .onEnded { _ in rangeBase = nil }
    }

    /// 帯を動かした分（秒）だけ、始まり・終わり・全体を動かす。長さは 0.5〜10秒、動画の外には出さない
    private func moveRange(part: RangePart, by delta: Double) {
        guard let base = rangeBase else { return }
        let end = base.start + base.length
        switch part {
        case .start:
            let newStart = min(max(base.start + delta, max(0, end - maxLength)), end - minLength)
            start = newStart
            length = end - newStart
            previewTime = start
        case .end:
            let newEnd = min(max(end + delta, base.start + minLength), min(duration, base.start + maxLength))
            start = base.start
            length = newEnd - base.start
            previewTime = max(start, newEnd - 0.05)
        case .middle:
            start = min(max(base.start + delta, 0), max(0, duration - base.length))
            length = base.length
            previewTime = start
        }
        edit.videoStart = start
        // 1コマの秒数と同じ長さなら覚えない（あとで1コマの秒数を変えたときに合わせて変わるように）
        edit.videoLength = abs(length - defaultLength) < 0.05 ? nil : length
    }

    /// 「0:03.5」
    static func timeText(_ seconds: Double) -> String {
        let tenths = Int((max(seconds, 0) * 10).rounded())
        return String(format: "%d:%02d.%d", tenths / 600, (tenths / 10) % 60, tenths % 10)
    }

    // MARK: 読む

    private func load() async {
        guard let asset else { return }
        if asset.mediaType == .video {
            let range = edit.videoRange(duration: duration, length: clipSeconds)
            start = range.start
            length = range.length
            previewTime = start
            video = await withCheckedContinuation { continuation in
                let options = PHVideoRequestOptions()
                options.isNetworkAccessAllowed = true
                options.deliveryMode = .mediumQualityFormat
                PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
                    continuation.resume(returning: avAsset)
                }
            }
            await showFrame(at: previewTime)
            await loadFilmstrip()
        } else {
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            let image: UIImage? = await withCheckedContinuation { continuation in
                PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 1600, height: 1600),
                                                      contentMode: .aspectFit, options: options) { image, _ in
                    continuation.resume(returning: image)
                }
            }
            if let image { source = styled(image) }
        }
    }

    /// 帯の中の小さな絵を、動画の頭から終わりまで等しい間隔で読む
    private func loadFilmstrip() async {
        guard let video, duration > 0 else { return }
        let generator = AVAssetImageGenerator(asset: video)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 160, height: 160)
        let tolerance = CMTime(seconds: 0.25, preferredTimescale: 600)
        generator.requestedTimeToleranceBefore = tolerance
        generator.requestedTimeToleranceAfter = tolerance
        var images: [UIImage] = []
        for index in 0..<Self.filmstripCount {
            let seconds = duration * (Double(index) + 0.5) / Double(Self.filmstripCount)
            guard !Task.isCancelled,
                  let frame = try? await generator.image(at: CMTime(seconds: seconds, preferredTimescale: 600)).image
            else { continue }
            images.append(UIImage(cgImage: frame))
        }
        filmstrip = images
    }

    /// 動画の、その時点の絵を枠に出す（つまみを動かしている間も追いかける）
    private func showFrame(at seconds: Double) async {
        guard let video else { return }
        let generator = AVAssetImageGenerator(asset: video)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1200, height: 1200)
        let tolerance = CMTime(seconds: 0.1, preferredTimescale: 600)
        generator.requestedTimeToleranceBefore = tolerance
        generator.requestedTimeToleranceAfter = tolerance
        guard let frame = try? await generator.image(at: CMTime(seconds: seconds, preferredTimescale: 600)).image,
              !Task.isCancelled else { return }
        source = styled(UIImage(cgImage: frame))
    }

    /// 選んでいる色味をかけて見せる
    private func styled(_ image: UIImage) -> UIImage {
        guard look != .natural, let cg = image.cgImage else { return image }
        let input = CIImage(cgImage: cg)
        let output = look.apply(to: input)
        guard let result = CIContext().createCGImage(output, from: input.extent) else { return image }
        return UIImage(cgImage: result)
    }
}
