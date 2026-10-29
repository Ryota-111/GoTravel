import AVFoundation
import Photos
import SwiftUI

/// 1コマのトリミングと、動画を何秒目から使うかを決める画面（3.2）。
///
/// 枠は作る動画と同じ形。写真を指で動かして見せたいところを枠に入れ、2本指で広げると大きくできる。
/// 動画は下のつまみで、使いはじめを選ぶ（枠の中にはその時点の絵を出す）
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
    /// 動画の使いはじめ（つまみの値）
    @State private var start: Double = 0

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
    /// 使いはじめに選べるいちばん後ろ
    private var latestStart: Double { max(0, duration - clipSeconds) }

    var body: some View {
        VStack(spacing: 18) {
            Text(isVideo ? "指で動かして見せたいところを枠に入れ、2本指で広げると大きくできます。下のつまみで、動画のどこから使うかを選べます。"
                 : "指で動かして見せたいところを枠に入れ、2本指で広げると大きくできます。")
                .font(.footnote)
                .foregroundColor(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            cropFrame
                .padding(.horizontal, 28)
                .frame(maxHeight: .infinity)
            if isVideo && latestStart > 0 {
                startSlider
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
                        edit = DigestClipEdit()
                        start = DigestClipEdit().videoRange(duration: duration, length: clipSeconds).start
                    }
                }
                .disabled(edit.isUncropped && edit.videoStart == nil)
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
        .task(id: start) { await showFrame(at: start) }
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

    // MARK: 動画の使いはじめ

    private var startSlider: some View {
        VStack(spacing: 6) {
            HStack {
                Text("使いはじめ")
                    .font(.footnote.weight(.semibold))
                Spacer()
                Text("\(Self.timeText(start)) 〜 \(Self.timeText(min(start + clipSeconds, duration)))")
                    .font(.footnote.monospacedDigit())
            }
            .foregroundColor(.white)
            // 選べる範囲の中で、使う範囲を帯で見せる
            Slider(value: Binding(get: { start }, set: { value in
                start = value
                edit.videoStart = value
            }), in: 0...latestStart)
            .tint(.white)
            HStack {
                Text(Self.timeText(0))
                Spacer()
                Text("動画の長さ \(Self.timeText(duration))")
            }
            .font(.caption2.monospacedDigit())
            .foregroundColor(.white.opacity(0.55))
        }
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
            start = edit.videoRange(duration: duration, length: clipSeconds).start
            video = await withCheckedContinuation { continuation in
                let options = PHVideoRequestOptions()
                options.isNetworkAccessAllowed = true
                options.deliveryMode = .mediumQualityFormat
                PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
                    continuation.resume(returning: avAsset)
                }
            }
            await showFrame(at: start)
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
