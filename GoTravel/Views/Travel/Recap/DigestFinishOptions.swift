import AVFoundation
import Combine
import Photos
import SwiftUI

/// 旅のダイジェストの仕上げの設定（3.2）。端末に覚えておき、次に作るときも同じにする
struct DigestFinish {
    static let openingKey = "tripDigestOpening"
    static let mapKey = "tripDigestMap"
    static let musicKey = "tripDigestMusic"
    static let keepsSoundKey = "tripDigestKeepSound"
    /// 音楽を敷かないときの値
    static let noMusic = "none"

    var opening = true
    var map = true
    var music: TripDigestMusic.Track?
    var keepsSound = true

    /// 今の設定。決めていなければ、題名と地図のカードは入れ、曲は1曲目を敷く
    static var current: DigestFinish {
        let defaults = UserDefaults.standard
        func bool(_ key: String) -> Bool { defaults.object(forKey: key) as? Bool ?? true }
        let musicID = defaults.string(forKey: musicKey) ?? TripDigestMusic.tracks.first?.id
        return DigestFinish(opening: bool(openingKey), map: bool(mapKey),
                            music: TripDigestMusic.track(id: musicID), keepsSound: bool(keepsSoundKey))
    }

    /// 題名のカードに出す文字（旅行名・日付・行き先）
    static func opening(plan: TravelPlan, scope: TripDigest.Scope) -> TripDigestComposer.Opening {
        let destination = plan.destination.trimmingCharacters(in: .whitespacesAndNewlines)
        return TripDigestComposer.Opening(title: plan.title, subtitle: DigestMaker.subtitle(plan: plan, scope: scope),
                                          destination: destination.isEmpty ? nil : destination)
    }

    /// 地図のカードの文字。小さい1行（「Day 2」）と大きい文字（行き先。旅行全体は旅行名）
    static func mapLabel(plan: TravelPlan, scope: TripDigest.Scope) -> (caption: String, headline: String) {
        let destination = plan.destination.trimmingCharacters(in: .whitespacesAndNewlines)
        switch scope {
        case .day(let n):
            return ("Day \(n)", destination.isEmpty ? plan.title : destination)
        case .trip:
            let days = max(plan.dayCount, 1)
            return (days > 1 ? "Day 1〜\(days)" : "Day 1", plan.title)
        }
    }
}

/// 仕上げの設定を選ぶ欄（使う写真を確かめる画面に出す）。
/// すぐ上の「文字の位置」と同じく、動画と同じ部品で描いた見本を押して入れる・入れないを選ぶ
struct DigestFinishOptions: View {
    let plan: TravelPlan
    let scope: TripDigest.Scope
    /// 題名のカードの背景にする1コマ目
    let sample: TripDigest.Clip?
    let assets: [String: PHAsset]
    /// 地図のカードの文字も、選んでいる位置に出す
    let textPosition: TripDigestComposer.TextPosition

    @AppStorage(DigestFinish.openingKey) private var opening = true
    @AppStorage(DigestFinish.mapKey) private var map = true
    @AppStorage(DigestFinish.musicKey) private var music = TripDigestMusic.tracks.first?.id ?? DigestFinish.noMusic
    @AppStorage(DigestFinish.keepsSoundKey) private var keepsSound = true
    @AppStorage(DigestLook.storageKey) private var look = DigestLook.natural.rawValue
    @AppStorage(DigestShape.storageKey) private var shape = DigestShape.vertical.rawValue
    @AppStorage(DigestPace.storageKey) private var pace = DigestPace.standard

    @ObservedObject private var proStore = ProStore.shared
    @StateObject private var player = DigestMusicPreview()
    @State private var openingText: UIImage?
    @State private var mapPreview: UIImage?
    /// 地図を読めなかった（電波が無いなど）
    @State private var mapFailed = false
    /// 色味の見本（色味ごと。1枚目の写真に、動画と同じ部品でかけたもの）
    @State private var lookSamples: [DigestLook: UIImage] = [:]

    private var stops: [TripDigest.MapStop] { TripDigest.mapStops(plan: plan, scope: scope) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("仕上がり")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            HStack(alignment: .top, spacing: 14) {
                tile(name: "題名", isOn: $opening) {
                    ZStack {
                        AssetImage(asset: sample.flatMap { assets[$0.sourceId] }, target: CGSize(width: 300, height: 540))
                            .blur(radius: 6)
                        Color.black.opacity(0.42)
                        if let openingText {
                            Image(uiImage: openingText).resizable()
                        }
                    }
                }
                if !stops.isEmpty {
                    tile(name: "行程の地図", isOn: $map) {
                        ZStack {
                            Color(white: 0.12)
                            if let mapPreview {
                                Image(uiImage: mapPreview).resizable()
                            } else if mapFailed {
                                VStack(spacing: 4) {
                                    Image(systemName: "wifi.slash")
                                    Text("地図を読めません")
                                }
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))
                            } else {
                                ProgressView().tint(.white)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            lookRow
                .padding(.top, 6)
            choiceRow("形") {
                ForEach(DigestShape.allCases) { candidate in
                    chip(selected: shape == candidate.rawValue, accessibility: "画面の形：\(candidate.name)") {
                        shape = candidate.rawValue
                    } label: {
                        HStack(spacing: 5) {
                            // 形そのものを小さな枠で見せる
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .stroke(lineWidth: 1.5)
                                .frame(width: 14 * min(1, candidate.size.width / candidate.size.height),
                                       height: 14 * min(1, candidate.size.height / candidate.size.width))
                            Text(candidate.name)
                        }
                    }
                }
            }
            choiceRow("1コマ") {
                ForEach(DigestPace.choices, id: \.self) { seconds in
                    chip(selected: pace == seconds, accessibility: "1コマの長さ：\(DigestPace.text(seconds))") {
                        pace = seconds
                    } label: {
                        Text(DigestPace.text(seconds))
                    }
                }
            }
            soundRow
                .padding(.top, 2)
        }
        .task(id: "\(plan.title)|\(plan.destination)|\(scope.id)|\(shape)") { renderOpeningText() }
        .task(id: "\(scope.id)|\(textPosition.rawValue)|\(proStore.isPurchased)|\(stops.count)|\(shape)") { await renderMap() }
        .task(id: "\(sample?.sourceId ?? "")|\(shape)") { await renderLooks() }
        .onDisappear { player.stop() }
    }

    /// 見本の絵を押して、入れる・入れないを切り替える（「文字の位置」と同じ大きさと選び方）
    private func tile<Content: View>(name: String, isOn: Binding<Bool>, @ViewBuilder content: () -> Content) -> some View {
        let selected = isOn.wrappedValue
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { isOn.wrappedValue.toggle() }
        } label: {
            VStack(spacing: 5) {
                Color.clear
                    .aspectRatio(TripDigestComposer.aspectRatio, contentMode: .fit)
                    .frame(maxWidth: 130, maxHeight: 231)
                    .overlay { content() }
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .opacity(selected ? 1 : 0.35)
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(selected ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: selected ? 3 : 1)
                    )
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20, weight: .semibold))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, selected ? Color.accentColor : Color.black.opacity(0.25))
                            .padding(6)
                    }
                    .shadow(color: .black.opacity(selected ? 0.15 : 0.05), radius: 4, y: 2)
                Text(selected ? name : "\(name)なし")
                    .font(.caption2.weight(selected ? .bold : .regular))
                    .foregroundColor(selected ? .accentColor : .secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(name)のカード")
        .accessibilityValue(selected ? "入れる" : "入れない")
    }

    /// 曲を選ぶ丸いボタン（押すと少し流れる）と、動画の音を残すかのスピーカー
    private var soundRow: some View {
        HStack(spacing: 10) {
            if TripDigestMusic.tracks.isEmpty {
                Text("動画の音")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            } else {
                Image(systemName: "music.note")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        musicChip(id: DigestFinish.noMusic, name: "なし")
                        ForEach(TripDigestMusic.tracks) { track in
                            musicChip(id: track.id, name: track.name, track: track)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { keepsSound.toggle() }
            } label: {
                Image(systemName: keepsSound ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(keepsSound ? .accentColor : .secondary)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(keepsSound ? Color.accentColor.opacity(0.15) : Color(.tertiarySystemFill)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("動画の音")
            .accessibilityValue(keepsSound ? "残す" : "消す")
        }
    }

    /// 色味：1枚目の写真に色味をかけた見本を横に並べ、押して選ぶ
    private var lookRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(DigestLook.allCases) { candidate in
                    let selected = look == candidate.rawValue
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { look = candidate.rawValue }
                    } label: {
                        VStack(spacing: 4) {
                            Color(.tertiarySystemFill)
                                .frame(width: 58, height: 58)
                                .overlay {
                                    if let image = lookSamples[candidate] {
                                        Image(uiImage: image).resizable().scaledToFill()
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(selected ? Color.accentColor : Color.primary.opacity(0.1),
                                                lineWidth: selected ? 3 : 1)
                                )
                            Text(candidate.name)
                                .font(.caption2.weight(selected ? .bold : .regular))
                                .foregroundColor(selected ? .accentColor : .secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("色味：\(candidate.name)")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .padding(.vertical, 2)
        }
    }

    /// 左に小さな見出し、右に丸いボタンを並べる行（形・1コマの秒数）
    private func choiceRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
                .frame(width: 34, alignment: .leading)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) { content() }
                    .padding(.vertical, 2)
            }
        }
    }

    private func chip<Label: View>(selected: Bool, accessibility: String, action: @escaping () -> Void,
                                   @ViewBuilder label: () -> Label) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { action() }
        } label: {
            label()
                .font(.footnote.weight(selected ? .semibold : .regular))
                .foregroundColor(selected ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(selected ? Color.accentColor : Color(.tertiarySystemFill)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibility)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func musicChip(id: String, name: String, track: TripDigestMusic.Track? = nil) -> some View {
        let selected = music == id
        let playing = player.playingID == id
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { music = id }
            if let track, !playing { player.play(track) } else { player.stop() }
        } label: {
            HStack(spacing: 4) {
                if track != nil && selected {
                    Image(systemName: playing ? "stop.fill" : "play.fill")
                        .font(.system(size: 9, weight: .bold))
                }
                Text(name)
            }
            .font(.footnote.weight(selected ? .semibold : .regular))
            .foregroundColor(selected ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(selected ? Color.accentColor : Color(.tertiarySystemFill)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("音楽：\(name)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// 題名のカードの文字を、動画と同じ部品で描く（背景はその場でぼかす）
    private func renderOpeningText() {
        guard let text = TripDigestComposer.openingTextImage(DigestFinish.opening(plan: plan, scope: scope)),
              let cg = CIContext().createCGImage(text, from: CGRect(origin: .zero, size: TripDigestComposer.renderSize))
        else { return }
        openingText = UIImage(cgImage: cg).downscaled(maxPixel: 720)
    }

    /// 色味の見本を描く。1枚目の写真を小さく読み、動画と同じ部品で色味をかける
    private func renderLooks() async {
        guard let asset = sample.flatMap({ assets[$0.sourceId] }) else { return }
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.resizeMode = .fast
        let image: UIImage? = await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 180, height: 180),
                                                  contentMode: .aspectFill, options: options) { image, _ in
                continuation.resume(returning: image)
            }
        }
        guard let cg = image?.cgImage else { return }
        let input = CIImage(cgImage: cg)
        let context = CIContext()
        var result: [DigestLook: UIImage] = [:]
        for candidate in DigestLook.allCases {
            if let output = context.createCGImage(candidate.apply(to: input), from: input.extent) {
                result[candidate] = UIImage(cgImage: output)
            }
        }
        lookSamples = result
    }

    /// 地図のカードの最後のコマ（経路を引き終えたところ）を、動画と同じ部品で描く
    private func renderMap() async {
        guard !stops.isEmpty else { return }
        mapFailed = false
        let label = DigestFinish.mapLabel(plan: plan, scope: scope)
        guard let card = await TripDigestComposer.mapCard(stops: stops, caption: label.caption, headline: label.headline,
                                                          position: textPosition, watermark: !proStore.isPurchased),
              let frame = card.frame(at: TripDigestComposer.MapCard.seconds),
              let cg = CIContext().createCGImage(frame, from: CGRect(origin: .zero, size: TripDigestComposer.renderSize))
        else {
            mapFailed = true
            return
        }
        mapPreview = UIImage(cgImage: cg).downscaled(maxPixel: 720)
    }
}

/// 曲を選んだときに、はじめの10秒ほどを試しに流す
@MainActor
final class DigestMusicPreview: ObservableObject {
    @Published private(set) var playingID: String?
    private var player: AVAudioPlayer?
    private var stopping: Task<Void, Never>?

    func play(_ track: TripDigestMusic.Track) {
        stop()
        guard let player = try? AVAudioPlayer(contentsOf: track.url) else { return }
        self.player = player
        player.volume = 0.8
        player.play()
        playingID = track.id
        stopping = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 9_000_000_000)
            player.setVolume(0, fadeDuration: 1)
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            self?.stop()
        }
    }

    func stop() {
        stopping?.cancel()
        stopping = nil
        player?.stop()
        player = nil
        playingID = nil
    }
}
