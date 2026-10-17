import SwiftUI
import AVKit
import Photos

/// 旅のダイジェスト動画を作る画面（Travory Pro）
struct TripDigestView: View {
    let plan: TravelPlan

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private enum Phase: Equatable {
        case loading
        case noAccess
        case ready
    }

    @State private var phase: Phase = .loading
    @State private var sources: [TripDigest.Source] = []
    @State private var assets: [String: PHAsset] = [:]
    /// 外した写真・動画（旅行ごとに覚えておく）
    @State private var excluded: Set<String> = []
    @State private var reviewing: TripDigest.Scope?

    struct DigestResult: Identifiable, Hashable {
        let url: URL
        let title: String
        var id: URL { url }
    }

    private var usable: [TripDigest.Source] { sources.filter { !excluded.contains($0.id) } }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .loading:
                    ProgressView()
                case .noAccess:
                    noAccessView
                case .ready:
                    list
                }
            }
            .navigationTitle("旅のダイジェスト")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .navigationDestination(item: $reviewing) { scope in
                DigestReviewView(plan: plan, scope: scope, sources: sources, assets: assets, excluded: $excluded)
            }
            .task { await load() }
            .onChange(of: excluded) { _, value in
                TripDigestExclusions.save(value, planId: plan.id)
            }
        }
    }

    private var list: some View {
        List {
            Section {
                row(title: "旅行全体", scope: .trip)
                ForEach(1...max(plan.dayCount, 1), id: \.self) { day in
                    row(title: "Day \(day)　\(TravelPlanTextExporter.dateString(plan.date(forDay: day)))",
                        scope: .day(day))
                }
            } footer: {
                Text("旅行の期間に撮った写真と動画から、1時間に1つずつ選んで2秒ずつつなぎます。作る前に、選ばれた写真を確かめて外せます。動画は iPhone の中だけで作ります。")
            }
        }
    }

    private func row(title: String, scope: TripDigest.Scope) -> some View {
        let clips = TripDigest.clips(plan: plan, sources: usable, scope: scope)
        return Button {
            reviewing = scope
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .foregroundColor(.primary)
                    Text(clips.isEmpty ? "写真・動画がありません"
                         : "\(clips.count)コマ・約\(Int(TripDigest.duration(of: clips)))秒")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }
        }
        .disabled(clips.isEmpty)
    }

    private var noAccessView: some View {
        VStack(spacing: 14) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 44))
                .foregroundColor(.secondary)
            Text("旅行中に撮った写真と動画を使うため、写真へのアクセスを許可してください。")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Button("設定を開く") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
    }

    private func load() async {
        excluded = TripDigestExclusions.load(planId: plan.id)
        guard await TripDigestComposer.requestAccess() else {
            phase = .noAccess
            return
        }
        let found = TripDigestComposer.sources(for: plan)
        sources = found.sources
        assets = found.assets
        phase = .ready
    }
}

/// 外した写真・動画を、旅行ごとに覚えておく（端末の中だけ）
enum TripDigestExclusions {
    private static func key(_ planId: String?) -> String { "tripDigestExcluded.\(planId ?? "")" }

    static func load(planId: String?) -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: key(planId)) ?? [])
    }

    static func save(_ ids: Set<String>, planId: String?) {
        UserDefaults.standard.set(Array(ids), forKey: key(planId))
    }
}

extension TripDigest.Scope: Identifiable {
    var id: String {
        switch self {
        case .trip: return "trip"
        case .day(let n): return "day\(n)"
        }
    }
}

/// 作る前に、選ばれたコマを確かめる。押すと外れ、同じ時間の別の写真が代わりに入る
private struct DigestReviewView: View {
    let plan: TravelPlan
    let scope: TripDigest.Scope
    let sources: [TripDigest.Source]
    let assets: [String: PHAsset]
    @Binding var excluded: Set<String>

    @State private var progress: Double?
    @State private var result: TripDigestView.DigestResult?
    @State private var errorMessage: String?

    private var clips: [TripDigest.Clip] {
        TripDigest.clips(plan: plan, sources: sources.filter { !excluded.contains($0.id) }, scope: scope)
    }

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 6)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("見せたくない写真は押して外してください。外すと、同じ時間に撮った別の写真が代わりに入ります。外した写真は、この旅行では次からも使いません。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(clips, id: \.sourceId) { clip in
                        Button {
                            withAnimation { _ = excluded.insert(clip.sourceId) }
                        } label: {
                            DigestThumbnail(asset: assets[clip.sourceId], clip: clip)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(clip.timeText)\(clip.placeName.map { "・\($0)" } ?? "")を外す")
                    }
                }
                if !excluded.isEmpty {
                    Button("外した写真をすべて戻す（\(excluded.count)）") {
                        withAnimation { excluded.removeAll() }
                    }
                    .font(.footnote)
                }
            }
            .padding(16)
        }
        .overlay {
            if let progress {
                VStack(spacing: 12) {
                    ProgressView(value: progress).frame(maxWidth: 220)
                    Text("動画を作っています…").font(.subheadline).foregroundColor(.secondary)
                }
                .padding(28)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .navigationTitle("\(clips.count)コマ・約\(Int(TripDigest.duration(of: clips)))秒")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("作る") { Task { await make() } }
                    .fontWeight(.semibold)
                    .disabled(clips.isEmpty || progress != nil)
            }
        }
        .navigationDestination(item: $result) { result in
            DigestPlayerView(result: result)
        }
        .alert(errorMessage ?? "", isPresented: Binding(get: { errorMessage != nil },
                                                        set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }

    private func make() async {
        progress = 0
        defer { progress = nil }
        let items = await TripDigestComposer.loadItems(clips, assets: assets)
        let subtitle: String
        switch scope {
        case .day(let n):
            subtitle = "Day \(n)・\(TravelPlanTextExporter.dateString(plan.date(forDay: n)))"
        case .trip:
            subtitle = "\(TravelPlanTextExporter.dateString(plan.startDate)) 〜 \(TravelPlanTextExporter.dateString(plan.endDate))"
        }
        do {
            let url = try await TripDigestComposer.compose(items, title: plan.title, subtitle: subtitle,
                                                           fileName: TripDigest.fileName(plan: plan, scope: scope)) { value in
                Task { @MainActor in progress = value }
            }
            result = TripDigestView.DigestResult(url: url, title: subtitle)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// コマの見本（写真の縮小と、時刻・場所・動画の印）
private struct DigestThumbnail: View {
    let asset: PHAsset?
    let clip: TripDigest.Clip
    @State private var image: UIImage?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color(.secondarySystemBackground)
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            }
            LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 1) {
                if let place = clip.placeName {
                    Text(place).font(.caption2.weight(.semibold)).lineLimit(1)
                }
                Text("Day \(clip.dayNumber) \(clip.timeText)").font(.caption2)
            }
            .foregroundColor(.white)
            .padding(5)
            if asset?.mediaType == .video {
                Image(systemName: "video.fill")
                    .font(.caption2)
                    .foregroundColor(.white)
                    .padding(5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
            Image(systemName: "minus.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .black.opacity(0.5))
                .padding(5)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .aspectRatio(9 / 16, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .task(id: asset?.localIdentifier) {
            guard let asset else { return }
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.isNetworkAccessAllowed = true
            PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 240, height: 420),
                                                  contentMode: .aspectFill, options: options) { result, _ in
                if let result { image = result }
            }
        }
    }
}

/// できた動画を見て、送る・保存する
private struct DigestPlayerView: View {
    let result: TripDigestView.DigestResult
    @State private var player: AVPlayer?

    var body: some View {
        VideoPlayer(player: player)
            .aspectRatio(9 / 16, contentMode: .fit)
            .padding()
            .navigationTitle(result.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    ShareLink(item: result.url) {
                        Label("送る・保存", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .onAppear {
                let player = AVPlayer(url: result.url)
                self.player = player
                player.play()
            }
            .onDisappear { player?.pause() }
    }
}
