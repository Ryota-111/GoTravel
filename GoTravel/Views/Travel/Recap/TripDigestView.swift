import SwiftUI
import AVKit
import Photos
import PhotosUI

/// 旅のダイジェスト動画を作る画面（Travory Pro）。
///
/// 縦長の写真カードを横にめくって「旅行全体」か「Day ごと」を選ぶ。各カードはその日の1枚目の写真が表紙で、
/// 大きな日付を重ねる。下で文字の位置を選び、カードを押すと、コマを並べた一覧（使う写真を確かめて「作る」）へ
struct TripDigestView: View {
    /// 切り替えられるほかの旅行（アルバムから開いたとき）。空なら切り替えを出さない
    var otherPlans: [TravelPlan] = []

    @State private var plan: TravelPlan

    init(plan: TravelPlan, otherPlans: [TravelPlan] = []) {
        _plan = State(initialValue: plan)
        self.otherPlans = otherPlans
    }

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
    /// 自分で選び直した写真・動画（旅行ごとに覚えておく）
    @State private var pinned: Set<String> = []
    /// 自分で入れた文字（写真・動画ごと。Pro）
    @State private var captions: [String: String] = [:]
    /// 自分で足した写真・動画（旅行の期間の外の写真も。旅行ごとに覚えておく）
    @State private var added: [TripDigest.Added] = []
    /// 外した時間（その時間はまるごとコマにしない。旅行ごとに覚えておく）
    @State private var excludedHours: Set<String> = []
    /// コマごとのトリミングと、動画を何秒目から使うか（旅行ごとに覚えておく。3.2）
    @State private var edits: [String: DigestClipEdit] = [:]
    @ObservedObject private var proStore = ProStore.shared
    @State private var reviewing: TripDigest.Scope?
    @State private var selected: String? = TripDigest.Scope.trip.id
    @State private var result: DigestResult?
    /// 時刻・場所の文字の位置（左下・真ん中・右上）。次に作るときも同じにする
    @AppStorage("tripDigestTextPosition") private var textPosition = TripDigestComposer.TextPosition.bottomLeft.rawValue
    /// 残した動画が変わった合図（作り終わったら数を進め、下の札を読み直す）
    @State private var libraryVersion = 0

    struct DigestResult: Identifiable, Hashable {
        let url: URL
        let title: String
        var id: URL { url }
    }

    private var usable: [TripDigest.Source] { sources.filter { !excluded.contains($0.id) } }

    /// カードに並べる範囲（コマが1つも無い日は出さない）。
    /// 旅行の期間の写真が1枚も無いときは、全部の日を写真なしで出す（「＋ 足す」で写真を入れられるように）
    private var scopes: [TripDigest.Scope] {
        let all = [TripDigest.Scope.trip] + (1...max(plan.dayCount, 1)).map { TripDigest.Scope.day($0) }
        let withClips = all.filter { !clips(for: $0).isEmpty }
        return withClips.isEmpty ? all : withClips
    }

    private func clips(for scope: TripDigest.Scope) -> [TripDigest.Clip] {
        TripDigest.clips(plan: plan, sources: usable, scope: scope, pinned: pinned,
                         captions: proStore.isPurchased ? captions : [:], added: added, excludedHours: excludedHours)
    }

    private var selectedScope: TripDigest.Scope? {
        scopes.first { $0.id == selected } ?? scopes.first
    }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .loading:
                    ProgressView()
                case .noAccess:
                    noAccessView
                case .ready:
                    carousel
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .principal) { titleMenu }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $reviewing) { scope in
                DigestReviewView(plan: plan, scope: scope, sources: sources, assets: $assets,
                                 excluded: $excluded, pinned: $pinned, captions: $captions, added: $added,
                                 excludedHours: $excludedHours, edits: $edits)
            }
            .navigationDestination(item: $result) { result in
                TripDigestPlayerView(result: result)
            }
            .onChange(of: result) { _, _ in libraryVersion += 1 }
            .onChange(of: reviewing) { _, _ in libraryVersion += 1 }
            .task(id: plan.id) { await load() }
            .modifier(savesChoices)
        }
    }

    /// 外した・選び直した写真と、入れた文字を、旅行ごとに覚えておく
    private var savesChoices: some ViewModifier { SaveDigestChoices(planId: plan.id, excluded: excluded, pinned: pinned,
                                                                     captions: captions, added: added,
                                                                     excludedHours: excludedHours, edits: edits) }

    // MARK: 上：旅行の名前（押すとほかの旅行へ）

    @ViewBuilder
    private var titleMenu: some View {
        if otherPlans.count > 1 {
            Menu {
                ForEach(otherPlans) { other in
                    Button {
                        plan = other
                        selected = TripDigest.Scope.trip.id
                    } label: {
                        if other.id == plan.id { Label(other.title, systemImage: "checkmark") } else { Text(other.title) }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(plan.title).font(.headline).lineLimit(1)
                    Image(systemName: "chevron.down").font(.caption.weight(.semibold))
                }
                .foregroundColor(.primary)
            }
        } else {
            Text(plan.title).font(.headline).lineLimit(1)
        }
    }

    // MARK: 真ん中：縦長の写真カードを横にめくる

    private var carousel: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(Array(scopes.enumerated()), id: \.element.id) { index, scope in
                        DigestCoverCard(plan: plan, scope: scope, clips: clips(for: scope), assets: assets,
                                        position: index + 1, count: scopes.count)
                            .containerRelativeFrame(.horizontal) { width, _ in width * 0.72 }
                            .onTapGesture { reviewing = scope }
                            .id(scope.id)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, 28, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $selected)
            .frame(maxHeight: 520)
            // 作るのはカードを押した先（使う写真を確かめてから）。文字の位置はここでも選べる
            Text("カードを押すと、使う写真を確かめて動画を作れます")
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.top, 14)
            Spacer(minLength: 12)
            DigestTextPositionPicker(selection: $textPosition,
                                     sample: clips(for: selectedScope ?? .trip).first, assets: assets)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            bottomBar
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
        }
    }

    // MARK: 下：選んでいるカードの札（作った動画があれば、押すとすぐ見られる）

    private var bottomBar: some View {
        let scope = selectedScope ?? .trip
        let count = clips(for: scope)
        // 前に作った動画があれば、札を押すとそのまま見られる
        let saved = libraryVersion >= 0 ? TripDigestLibrary.entry(planId: plan.id, scopeId: scope.id) : nil
        return HStack(spacing: 12) {
            Button {
                if let saved { result = DigestResult(url: TripDigestLibrary.url(of: saved), title: saved.title) }
            } label: {
            HStack(spacing: 8) {
                Image(systemName: saved == nil ? "film.stack" : "play.circle.fill")
                    .font(.subheadline)
                VStack(alignment: .leading, spacing: 1) {
                    Text(scope.label(plan: plan).uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text(saved == nil ? "\(count.count)コマ・約\(Int(TripDigest.duration(of: count)))秒" : "作成済み・見る")
                        .font(.footnote.weight(.semibold))
                }
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color(.secondarySystemGroupedBackground)))
            .overlay(Capsule().stroke(Color.primary.opacity(0.08), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(saved == nil)
        }
        .frame(maxWidth: .infinity)
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
        phase = .loading
        // 1枚ずつ外す仕組みはやめた（外すのは時間ごと）。前に外した写真が見えないまま残らないように空にする
        excluded = []
        pinned = TripDigestExclusions.loadPinned(planId: plan.id)
        captions = TripDigestExclusions.loadCaptions(planId: plan.id)
        added = TripDigestExclusions.loadAdded(planId: plan.id)
        excludedHours = TripDigestExclusions.loadExcludedHours(planId: plan.id)
        edits = TripDigestExclusions.loadEdits(planId: plan.id)
        guard await TripDigestComposer.requestAccess() else {
            phase = .noAccess
            return
        }
        let found = TripDigestComposer.sources(for: plan)
        sources = found.sources
        var all = found.assets
        // 足した写真は旅行の期間の外にもあるので、別に読む（消された写真は足したものから外す）
        let missing = added.map(\.sourceId).filter { all[$0] == nil }
        if !missing.isEmpty {
            PHAsset.fetchAssets(withLocalIdentifiers: missing, options: nil).enumerateObjects { asset, _, _ in
                all[asset.localIdentifier] = asset
            }
            added.removeAll { all[$0.sourceId] == nil }
        }
        assets = all
        phase = .ready
    }
}

private struct SaveDigestChoices: ViewModifier {
    let planId: String?
    let excluded: Set<String>
    let pinned: Set<String>
    let captions: [String: String]
    let added: [TripDigest.Added]
    let excludedHours: Set<String>
    let edits: [String: DigestClipEdit]

    func body(content: Content) -> some View {
        content
            .onChange(of: edits) { _, value in TripDigestExclusions.saveEdits(value, planId: planId) }
            .onChange(of: excludedHours) { _, value in TripDigestExclusions.saveExcludedHours(value, planId: planId) }
            .onChange(of: added) { _, value in TripDigestExclusions.saveAdded(value, planId: planId) }
            .onChange(of: excluded) { _, value in TripDigestExclusions.save(value, planId: planId) }
            .onChange(of: pinned) { _, value in TripDigestExclusions.savePinned(value, planId: planId) }
            .onChange(of: captions) { _, value in TripDigestExclusions.saveCaptions(value, planId: planId) }
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

    /// 自分で選び直した写真・動画
    private static func pinKey(_ planId: String?) -> String { "tripDigestPinned.\(planId ?? "")" }

    static func loadPinned(planId: String?) -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: pinKey(planId)) ?? [])
    }

    static func savePinned(_ ids: Set<String>, planId: String?) {
        UserDefaults.standard.set(Array(ids), forKey: pinKey(planId))
    }

    /// 自分で入れた文字（写真・動画の id → 文字。空なら文字なし）
    private static func captionKey(_ planId: String?) -> String { "tripDigestCaptions.\(planId ?? "")" }

    static func loadCaptions(planId: String?) -> [String: String] {
        UserDefaults.standard.dictionary(forKey: captionKey(planId)) as? [String: String] ?? [:]
    }

    static func saveCaptions(_ captions: [String: String], planId: String?) {
        UserDefaults.standard.set(captions, forKey: captionKey(planId))
    }

    /// 外した時間（`TripDigest.hourKey`）
    private static func hourKey(_ planId: String?) -> String { "tripDigestExcludedHours.\(planId ?? "")" }

    static func loadExcludedHours(planId: String?) -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: hourKey(planId)) ?? [])
    }

    static func saveExcludedHours(_ keys: Set<String>, planId: String?) {
        UserDefaults.standard.set(Array(keys), forKey: hourKey(planId))
    }

    /// 自分で足した写真・動画（JSON）
    private static func addedKey(_ planId: String?) -> String { "tripDigestAdded.\(planId ?? "")" }

    static func loadAdded(planId: String?) -> [TripDigest.Added] {
        guard let data = UserDefaults.standard.data(forKey: addedKey(planId)) else { return [] }
        return (try? JSONDecoder().decode([TripDigest.Added].self, from: data)) ?? []
    }

    static func saveAdded(_ added: [TripDigest.Added], planId: String?) {
        UserDefaults.standard.set(try? JSONEncoder().encode(added), forKey: addedKey(planId))
    }

    /// コマごとのトリミングと、動画を何秒目から使うか（JSON。3.2）
    private static func editKey(_ planId: String?) -> String { "tripDigestEdits.\(planId ?? "")" }

    static func loadEdits(planId: String?) -> [String: DigestClipEdit] {
        guard let data = UserDefaults.standard.data(forKey: editKey(planId)) else { return [:] }
        return (try? JSONDecoder().decode([String: DigestClipEdit].self, from: data)) ?? [:]
    }

    static func saveEdits(_ edits: [String: DigestClipEdit], planId: String?) {
        UserDefaults.standard.set(try? JSONEncoder().encode(edits.filter { !$0.value.isDefault }), forKey: editKey(planId))
    }

    /// その写真・動画を、撮った時間のコマに選び直す（同じ時間の前の選び直しは外す。外していたら戻す）
    static func choose(_ source: TripDigest.Source, among sources: [TripDigest.Source],
                       pinned: inout Set<String>, excluded: inout Set<String>) {
        let sameHour = sources.filter { TripDigest.sameHour($0.date, source.date) }.map(\.id)
        pinned.subtract(sameHour)
        pinned.insert(source.id)
        excluded.remove(source.id)
    }
}

extension TripDigest.Scope: Identifiable {
    var id: String {
        switch self {
        case .trip: return "trip"
        case .day(let n): return "day\(n)"
        }
    }

    /// 「旅行全体」「Day 2・9月22日(火)」
    func label(plan: TravelPlan) -> String {
        switch self {
        case .trip: return "旅行全体"
        case .day(let n): return "Day \(n)・\(TravelPlanTextExporter.dateString(plan.date(forDay: n)))"
        }
    }
}

extension TripDigest.Clip: Identifiable {
    var id: String { sourceId }
}

/// 動画を作る（最初の画面と確かめる画面の両方から使う）
@MainActor
enum DigestMaker {
    static func make(plan: TravelPlan, scope: TripDigest.Scope, clips: [TripDigest.Clip], assets: [String: PHAsset],
                     textPosition: TripDigestComposer.TextPosition, edits: [String: DigestClipEdit] = [:],
                     progress: @escaping @Sendable (Double) -> Void) async throws -> TripDigestView.DigestResult {
        // 無料でも作れる。Pro でなければ右下と最後に「Travory」の印を入れる（文字の位置は誰でも選べる）
        let isPro = ProStore.shared.isPurchased
        let items = await TripDigestComposer.loadItems(clips, assets: assets)
        try Task.checkCancellation()
        let subtitle = Self.subtitle(plan: plan, scope: scope)
        // 仕上げ（3.2）：最初の題名のカード・最後の行程の地図・下に敷く曲
        let finish = DigestFinish.current
        let opening = finish.opening ? DigestFinish.opening(plan: plan, scope: scope) : nil
        var mapCard: TripDigestComposer.MapCard?
        if finish.map {
            let label = DigestFinish.mapLabel(plan: plan, scope: scope)
            mapCard = await TripDigestComposer.mapCard(stops: TripDigest.mapStops(plan: plan, scope: scope),
                                                       caption: label.caption, headline: label.headline,
                                                       position: textPosition, watermark: !isPro)
        }
        try Task.checkCancellation()
        let temporary = try await TripDigestComposer.compose(items, title: plan.title, subtitle: subtitle,
                                                             fileName: TripDigest.fileName(plan: plan, scope: scope),
                                                             textPosition: textPosition,
                                                             watermark: !isPro, endCard: !isPro,
                                                             opening: opening, mapCard: mapCard,
                                                             music: finish.music?.url, keepsOriginalSound: finish.keepsSound,
                                                             edits: edits, look: DigestLook.current,
                                                             progress: progress)
        // 作った動画は残しておく（「思い出」タブのカードから、作り直さずに見られる）
        let url = (try? TripDigestLibrary.save(temporary, planId: plan.id, scopeId: scope.id, title: subtitle)) ?? temporary
        return TripDigestView.DigestResult(url: url, title: subtitle)
    }
}

extension DigestMaker {
    /// 最初のコマに題名と一緒に出す日付（「Day 2・9月22日(火)」「9月21日(月) 〜 9月23日(水)」）
    nonisolated static func subtitle(plan: TravelPlan, scope: TripDigest.Scope) -> String {
        switch scope {
        case .day(let n):
            return "Day \(n)・\(TravelPlanTextExporter.dateString(plan.date(forDay: n)))"
        case .trip:
            return "\(TravelPlanTextExporter.dateString(plan.startDate)) 〜 \(TravelPlanTextExporter.dateString(plan.endDate))"
        }
    }
}

/// 日付の見せ方（大きな数字・英字の月と曜日・日曜はピンク、土曜は青）
enum DigestDateStyle {
    private static let english: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func day(_ date: Date) -> String { "\(Calendar.current.component(.day, from: date))" }

    static func month(_ date: Date) -> String {
        english.dateFormat = "MMM"
        return english.string(from: date).uppercased()
    }

    static func weekday(_ date: Date) -> String {
        english.dateFormat = "EEE"
        return english.string(from: date).uppercased()
    }

    static func color(_ date: Date, default base: Color) -> Color {
        switch Calendar.current.component(.weekday, from: date) {
        case 1: return Color(red: 0.91, green: 0.3, blue: 0.5)
        case 7: return Color(red: 0.25, green: 0.45, blue: 0.85)
        default: return base
        }
    }
}

/// 写真を読み込む小さな部品（縮小した写真を1枚）
struct AssetImage: View {
    let asset: PHAsset?
    var target = CGSize(width: 600, height: 900)
    @State private var image: UIImage?

    var body: some View {
        Color(.tertiarySystemFill)
            .overlay {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                }
            }
            .clipped()
            .task(id: asset?.localIdentifier) {
                guard let asset else { return }
                let options = PHImageRequestOptions()
                options.deliveryMode = .opportunistic
                options.isNetworkAccessAllowed = true
                PHImageManager.default().requestImage(for: asset, targetSize: target, contentMode: .aspectFill,
                                                      options: options) { result, _ in
                    if let result { image = result }
                }
            }
    }
}

/// 縦長の表紙カード（旅行全体・Day ごと）
private struct DigestCoverCard: View {
    let plan: TravelPlan
    let scope: TripDigest.Scope
    let clips: [TripDigest.Clip]
    let assets: [String: PHAsset]
    let position: Int
    let count: Int

    private var date: Date {
        if case .day(let n) = scope { return plan.date(forDay: n) }
        return plan.startDate
    }

    /// 行った場所（重ならないように2つまで）
    private var places: String? {
        var seen: [String] = []
        for name in clips.compactMap(\.placeName) where !seen.contains(name) { seen.append(name) }
        guard !seen.isEmpty else { return nil }
        return seen.prefix(2).joined(separator: "・") + (seen.count > 2 ? " ほか" : "")
    }

    var body: some View {
        Color.clear
            .aspectRatio(3 / 4.6, contentMode: .fit)
            .overlay {
                if clips.isEmpty {
                    // 写真が無い日は、白い文字が読める色の地にする
                    LinearGradient(colors: [Color(red: 0.2, green: 0.38, blue: 0.62), Color(red: 0.12, green: 0.2, blue: 0.34)],
                                   startPoint: .top, endPoint: .bottom)
                } else {
                    AssetImage(asset: clips.first.flatMap { assets[$0.sourceId] })
                }
            }
            .overlay {
                LinearGradient(colors: [.black.opacity(0.35), .clear, .clear, .black.opacity(0.55)],
                               startPoint: .top, endPoint: .bottom)
            }
            .overlay(alignment: .topLeading) { dateMark.padding(20) }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 8) {
                    if clips.isEmpty {
                        Label("写真なし・押して足せます", systemImage: "plus.rectangle.on.rectangle")
                            .font(.footnote.weight(.semibold))
                    }
                    if let places {
                        Label(places, systemImage: "mappin.and.ellipse")
                            .font(.footnote.weight(.semibold))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    HStack(spacing: 10) {
                        Text("\(position)/\(count)")
                            .font(.caption2.monospacedDigit())
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(.white.opacity(0.35))
                                Capsule().fill(.white)
                                    .frame(width: geo.size.width * CGFloat(position) / CGFloat(max(count, 1)))
                            }
                        }
                        .frame(height: 2)
                    }
                }
                .foregroundColor(.white)
                .padding(20)
            }
            .overlay(alignment: .topTrailing) {
                if clips.contains(where: { assets[$0.sourceId]?.mediaType == .video }) {
                    Image(systemName: "video.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(18)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 14, y: 8)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(scope.label(plan: plan))、\(clips.count)コマ")
            .accessibilityHint("押すとコマを確かめられます")
    }

    @ViewBuilder
    private var dateMark: some View {
        switch scope {
        case .trip:
            VStack(alignment: .leading, spacing: 2) {
                Text("ALL")
                    .font(.system(size: 52, weight: .thin).width(.condensed))
                Text("\(plan.dayCount) DAYS")
                    .font(.system(size: 15, weight: .medium).width(.expanded))
            }
            .foregroundColor(.white)
        case .day(let n):
            VStack(alignment: .leading, spacing: 0) {
                Text(DigestDateStyle.day(date))
                    .font(.system(size: 64, weight: .thin).width(.condensed))
                Text(DigestDateStyle.month(date))
                    .font(.system(size: 17, weight: .medium).width(.expanded))
                Text("DAY \(n) · \(DigestDateStyle.weekday(date))")
                    .font(.system(size: 11, weight: .semibold))
                    .opacity(0.85)
                    .padding(.top, 4)
            }
            .foregroundColor(.white)
        }
    }
}

/// 作っている間に重ねる
private struct MakingOverlay: View {
    let progress: Double
    /// 「やめる」を押したとき
    let onCancel: () -> Void
    @State private var cancelling = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.2).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView(value: progress).frame(maxWidth: 220)
                Text(cancelling ? "やめています…" : "動画を作っています…")
                    .font(.subheadline).foregroundColor(.secondary)
                Button("やめる", role: .cancel) {
                    cancelling = true
                    onCancel()
                }
                .buttonStyle(.bordered)
                .disabled(cancelling)
            }
            .padding(28)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

/// 作る前に、選ばれたコマを確かめる。左に大きな時刻、右に写真の行で並べる。
/// 写真を押すと大きく見られ、そこで外せる（外すと同じ時間の別の写真が代わりに入る）
private struct DigestReviewView: View {
    let plan: TravelPlan
    let scope: TripDigest.Scope
    let sources: [TripDigest.Source]
    @Binding var assets: [String: PHAsset]
    @Binding var excluded: Set<String>
    @Binding var pinned: Set<String>
    @Binding var captions: [String: String]
    @Binding var added: [TripDigest.Added]
    @Binding var excludedHours: Set<String>
    @Binding var edits: [String: DigestClipEdit]
    /// 1コマの秒数が変わったら、上の「約◯秒」を出し直す（3.2）
    @AppStorage(DigestPace.storageKey) private var pace = DigestPace.standard
    /// 無料のまま Pro の仕上がり（色味・形・曲）を選んで「作る」を押した。選んだものの名前
    @State private var proNeeded: [String] = []
    @State private var showsPro = false

    @ObservedObject private var proStore = ProStore.shared
    @Environment(\.openURL) private var openURL
    /// 日ごとの「＋ 写真を足す」で選んでいる写真
    @State private var picking: [PhotosPickerItem] = []
    @State private var pickingDay: Int?
    /// 時刻が分からなかった足した写真（何時ごろかを選んでもらう）
    @State private var pendingAdd: PendingAdd?
    @State private var showsLimitedAccess = false
    @State private var progress: Double?
    @State private var making: Task<Void, Never>?
    @State private var result: TripDigestView.DigestResult?
    @State private var errorMessage: String?
    @AppStorage("tripDigestTextPosition") private var textPosition = TripDigestComposer.TextPosition.bottomLeft.rawValue
    /// 押して大きく見ているコマ（外すかどうかはここで決める）
    @State private var previewing: TripDigest.Clip?

    private var clips: [TripDigest.Clip] {
        TripDigest.clips(plan: plan, sources: sources.filter { !excluded.contains($0.id) }, scope: scope, pinned: pinned,
                         captions: proStore.isPurchased ? captions : [:], added: added, excludedHours: excludedHours)
    }

    /// 外した時間（この動画の範囲の日だけ）。押すと、その時間をまるごと戻せる
    private var excludedHourEntries: [(key: String, start: Date, day: Int, sources: [TripDigest.Source])] {
        let calendar = Calendar.current
        let days: [Int]
        switch scope {
        case .day(let n): days = [n]
        case .trip: days = Array(1...max(plan.dayCount, 1))
        }
        return excludedHours.compactMap { key in
            guard let start = TripDigest.hourStart(ofKey: key),
                  let day = days.first(where: { calendar.isDate(start, inSameDayAs: plan.date(forDay: $0)) })
            else { return nil }
            let inHour = sources.filter { TripDigest.hourKey($0.date, calendar: calendar) == key && !excluded.contains($0.id) }
            guard !inHour.isEmpty else { return nil }
            return (key, start, day, inHour.sorted { $0.date < $1.date })
        }
        .sorted { $0.start < $1.start }
    }

    /// 選び方の材料に、足した写真も入れたもの（文字の場所の名前・選び直しの候補に使う）
    private var allSources: [TripDigest.Source] {
        let addedIds = Set(added.map(\.sourceId))
        return sources.filter { !addedIds.contains($0.id) } + added.map(\.source)
    }

    /// 日ごとのまとまり
    /// コマが無い日も出す（見出しの「＋ 足す」から写真を入れられるように）
    private var days: [(day: Int, clips: [TripDigest.Clip])] {
        let grouped = Dictionary(grouping: clips, by: \.dayNumber)
        let numbers: [Int]
        switch scope {
        case .day(let n): numbers = [n]
        case .trip: numbers = Array(1...max(plan.dayCount, 1))
        }
        return numbers.map { ($0, grouped[$0] ?? []) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12, pinnedViews: [.sectionHeaders]) {
                Text("写真を押すと大きく見られ、外したり、その日の別の写真に選び直したり、出す文字や時刻を変えたりできます。「＋ 足す」で、あとからもらった写真も入れられます。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                DigestTextPositionPicker(selection: $textPosition, sample: clips.first, assets: assets)
                // 題名・地図のカードと音楽（3.2）
                DigestFinishOptions(plan: plan, scope: scope, sample: clips.first, assets: assets,
                                    textPosition: TripDigestComposer.TextPosition(rawValue: textPosition) ?? .bottomLeft)
                ForEach(days, id: \.day) { group in
                    Section {
                        ForEach(group.clips) { clip in
                            row(clip)
                        }
                        if group.clips.isEmpty {
                            Text("この日の写真や動画はまだありません。「＋ 足す」で入れられます。")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(.secondarySystemGroupedBackground)))
                        }
                    } header: {
                        dayHeader(group.day, count: group.clips.count)
                    }
                }
                if !excludedHourEntries.isEmpty {
                    excludedHoursSection
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .overlay {
            if let progress { MakingOverlay(progress: progress, onCancel: { making?.cancel() }) }
        }
        .navigationTitle("\(clips.count)コマ・約\(Int(TripDigest.duration(of: clips)))秒")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("作る", action: startMaking)
                    .fontWeight(.semibold)
                    .disabled(clips.isEmpty || progress != nil)
            }
        }
        .navigationDestination(item: $result) { result in
            TripDigestPlayerView(result: result)
        }
        // Pro の仕上がりは選んで見本で試せる。作るときに、Pro にするか外して作るかを選んでもらう
        .alert("Pro の仕上がりを選んでいます", isPresented: Binding(get: { !proNeeded.isEmpty },
                                                              set: { if !$0 { proNeeded = [] } })) {
            Button("Pro を見る") { showsPro = true }
            Button("外して作る") {
                DigestFinish.dropPro()
                making = Task { await make() }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("\(proNeeded.joined(separator: "・"))は Pro の機能です。「外して作る」なら、そのままの色・縦長で作ります。")
        }
        .sheet(isPresented: $showsPro) { DigestProSheet(isPresented: $showsPro) }
        .sheet(item: $previewing) { shown in
            // 外す・選び直す・文字を変えると、ここで作り直したコマの並びがそのまま開いた画面に届く
            DigestPreviewSheet(plan: plan, scope: scope, clips: clips, startId: shown.id, sources: allSources,
                               assets: assets, edits: edits,
                               onEdit: { clip, edit in edits[clip.sourceId] = edit.isDefault ? nil : edit },
                               onExclude: { clip in withAnimation { exclude(clip) } },
                               onChoose: { clip, source in withAnimation { choose(source, for: clip) } },
                               onCaption: { clip, text in captions[clip.sourceId] = text },
                               onSetHour: { clip, hour in setHour(hour, of: clip) },
                               onAddAfter: { clip, ids in add(ids, day: clip.dayNumber, after: clip) },
                               onReplace: { clip, id in replace(clip, with: id) })
        }
        .sheet(item: $pendingAdd) { pending in
            DigestAddedTimeSheet(count: pending.ids.count, day: pending.day, plan: plan) { hour in
                let base = TripDigest.date(day: pending.day, hour: hour, plan: plan)
                for (offset, id) in pending.ids.enumerated() {
                    insertAdded(id, date: base.addingTimeInterval(Double(offset)))
                }
            }
            .presentationDetents([.medium])
        }
        .alert("この写真は使えません", isPresented: $showsLimitedAccess) {
            Button("設定を開く") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            Button("閉じる", role: .cancel) {}
        } message: {
            Text("写真へのアクセスが「選択した写真」になっています。設定アプリの「Travory」→「写真」で「フルアクセス」にすると、あとからもらった写真も足せます。")
        }
        .onChange(of: picking) { _, items in
            guard !items.isEmpty, let day = pickingDay else { return }
            if !add(items.compactMap(\.itemIdentifier), day: day, after: nil) { showsLimitedAccess = true }
            picking = []
        }
        .alert(errorMessage ?? "", isPresented: Binding(get: { errorMessage != nil },
                                                        set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }

    private func dayHeader(_ day: Int, count: Int) -> some View {
        let date = plan.date(forDay: day)
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("DAY \(day)")
                .font(.system(size: 13, weight: .bold).width(.expanded))
            Text(TravelPlanTextExporter.dateString(date))
                .font(.footnote)
                .foregroundColor(DigestDateStyle.color(date, default: .secondary))
            Spacer()
            Text("\(count)コマ").font(.caption).foregroundColor(.secondary)
            PhotosPicker(selection: Binding(get: { picking },
                                            set: { pickingDay = day; picking = $0 }),
                         matching: .any(of: [.images, .videos]), photoLibrary: .shared()) {
                Label("足す", systemImage: "plus")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().stroke(Color.accentColor.opacity(0.5), lineWidth: 1))
            }
            .accessibilityLabel("Day \(day)に写真を足す")
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(Color(.systemGroupedBackground))
    }

    /// 1コマ：左に大きな時刻、右に写真
    private func row(_ clip: TripDigest.Clip, excludedStyle: Bool = false) -> some View {
        let parts = clip.timeText.split(separator: ":")
        let tint = DigestDateStyle.color(clip.date, default: .primary)
        return HStack(spacing: 0) {
            VStack(spacing: 2) {
                Text(parts.first.map(String.init) ?? "")
                    .font(.system(size: 34, weight: .bold).width(.condensed))
                    .foregroundColor(tint)
                Text(":\(parts.dropFirst().first.map(String.init) ?? "00")")
                    .font(.system(size: 12, weight: .semibold).width(.expanded))
                    .foregroundColor(tint.opacity(0.8))
                Image(systemName: assets[clip.sourceId]?.mediaType == .video ? "video" : "camera")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .padding(.top, 6)
            }
            .frame(width: 78)
            AssetImage(asset: assets[clip.sourceId], target: CGSize(width: 700, height: 420))
                .frame(height: 128)
                .overlay(alignment: .topTrailing) {
                    if clip.isAdded {
                        Text("足した")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(.black.opacity(0.45)))
                            .padding(8)
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    if let place = clip.placeName {
                        Label(place, systemImage: "mappin")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(.black.opacity(0.45)))
                            .padding(8)
                    }
                }
                .overlay {
                    if excludedStyle {
                        ZStack {
                            Color.black.opacity(0.5)
                            Label("戻す", systemImage: "arrow.uturn.backward")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white)
                        }
                    }
                }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture {
            if excludedStyle {
                withAnimation { _ = excluded.remove(clip.sourceId) }
            } else {
                previewing = clip
            }
        }
        .contextMenu {
            if !excludedStyle {
                Button("このコマを外す", systemImage: "eye.slash") {
                    withAnimation { exclude(clip) }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(clip.timeText)\(clip.placeName.map { "・\($0)" } ?? "")")
        .accessibilityHint(excludedStyle ? "押すと戻します" : "押すと大きく表示します")
    }

    // MARK: 足す・外す・時刻

    struct PendingAdd: Identifiable {
        let day: Int
        let ids: [String]
        var id: String { "\(day)|" + ids.joined(separator: ",") }
    }

    /// 外す。撮った時間のコマは、その時間をまるごと外す（同じ時間の別の写真が代わりに入らない）。
    /// 足したコマは、足したものから消す
    private func exclude(_ clip: TripDigest.Clip) {
        if clip.isAdded {
            added.removeAll { $0.sourceId == clip.sourceId }
        } else {
            excludedHours.insert(TripDigest.hourKey(clip.date))
            pinned.remove(clip.sourceId)
        }
    }

    /// 外した時間：代表の写真と時刻。押すと、その時間をまるごと戻す
    private var excludedHoursSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("外した時間（\(excludedHourEntries.count)）")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button("すべて戻す") {
                    withAnimation { excludedHours.subtract(excludedHourEntries.map(\.key)) }
                }
                .font(.footnote)
            }
            Text("押すと、その時間のコマを戻せます。")
                .font(.caption)
                .foregroundColor(.secondary)
            ForEach(excludedHourEntries, id: \.key) { entry in
                HStack(spacing: 12) {
                    AssetImage(asset: entry.sources.first.flatMap { assets[$0.id] }, target: CGSize(width: 200, height: 200))
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    Text("Day \(entry.day)  \(TripDigest.timeText(entry.start, calendar: .current))")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Label("戻す", systemImage: "arrow.uturn.backward")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.accentColor)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
                .contentShape(Rectangle())
                .onTapGesture { withAnimation { _ = excludedHours.remove(entry.key) } }
                .accessibilityElement(children: .combine)
                .accessibilityHint("押すと、この時間のコマを戻します")
            }
        }
        .padding(.top, 16)
    }

    /// 選び直す。足したコマは、同じ時刻のまま写真だけを入れ替える
    private func choose(_ source: TripDigest.Source, for clip: TripDigest.Clip) {
        if clip.isAdded, let index = added.firstIndex(where: { $0.sourceId == clip.sourceId }) {
            added[index].sourceId = source.id
            added[index].isVideo = source.isVideo
            added[index].latitude = source.latitude
            added[index].longitude = source.longitude
            excluded.remove(source.id)
        } else {
            TripDigestExclusions.choose(source, among: sources, pinned: &pinned, excluded: &excluded)
        }
    }

    /// コマの時刻を変える。撮った時間のコマは、足したコマとして決めた時刻に置き直す
    private func setHour(_ hour: Int, of clip: TripDigest.Clip) {
        let date = TripDigest.date(day: clip.dayNumber, hour: hour, plan: plan)
        if let index = added.firstIndex(where: { $0.sourceId == clip.sourceId }) {
            added[index].date = date
        } else if let source = sources.first(where: { $0.id == clip.sourceId }) {
            pinned.remove(source.id)
            added.append(TripDigest.Added(sourceId: source.id, date: date, isVideo: source.isVideo,
                                          latitude: source.latitude, longitude: source.longitude))
        }
    }

    /// 選んだ写真を足す。時刻は、撮った日時 → 近くの予定 → 差し込んだコマ の順に決め、
    /// どれでも分からなければ何時ごろかを選んでもらう
    /// - Returns: 写真を読めなければ false（写真へのアクセスが「選択した写真」のとき）
    @discardableResult
    private func add(_ ids: [String], day: Int, after clip: TripDigest.Clip?) -> Bool {
        guard !ids.isEmpty else { return true }
        var fetched: [String: PHAsset] = [:]
        PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil).enumerateObjects { asset, _, _ in
            fetched[asset.localIdentifier] = asset
        }
        guard !fetched.isEmpty else { return false }
        var unknown: [String] = []
        var cursor = clip?.date
        for id in ids {
            guard let asset = fetched[id] else { continue }
            assets[id] = asset
            let source = TripDigest.Source(id: id, date: asset.creationDate ?? .distantPast,
                                           isVideo: asset.mediaType == .video, duration: asset.duration,
                                           latitude: asset.location?.coordinate.latitude,
                                           longitude: asset.location?.coordinate.longitude)
            if let date = TripDigest.addedDate(for: source, plan: plan, dayNumber: day) {
                insertAdded(id, date: date)
            } else if let base = cursor {
                // 差し込んだコマのすぐあと（何枚か選んだら、選んだ順に）
                let next = base.addingTimeInterval(1)
                insertAdded(id, date: next)
                cursor = next
            } else {
                unknown.append(id)
            }
        }
        if !unknown.isEmpty { pendingAdd = PendingAdd(day: day, ids: unknown) }
        return true
    }

    /// コマの写真を、カメラロールの写真に入れ替える（時刻はそのまま）。
    /// 撮った時間のコマは、その時間を外し、選んだ写真を同じ時刻に足す
    private func replace(_ clip: TripDigest.Clip, with id: String) -> Bool {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else { return false }
        assets[id] = asset
        withAnimation {
            if clip.isAdded, let index = added.firstIndex(where: { $0.sourceId == clip.sourceId }) {
                let date = added[index].date
                added.remove(at: index)
                insertAdded(id, date: date)
            } else {
                // その時間を外し、選んだ写真を同じ時刻に足す（「外した時間」から戻せば、もとのコマも戻る）
                excludedHours.insert(TripDigest.hourKey(clip.date))
                pinned.remove(clip.sourceId)
                insertAdded(id, date: clip.date)
            }
        }
        return true
    }

    private func insertAdded(_ id: String, date: Date) {
        guard let asset = assets[id] else { return }
        added.removeAll { $0.sourceId == id }
        excluded.remove(id)
        withAnimation {
            added.append(TripDigest.Added(sourceId: id, date: date, isVideo: asset.mediaType == .video,
                                          latitude: asset.location?.coordinate.latitude,
                                          longitude: asset.location?.coordinate.longitude))
        }
    }

    /// 「作る」。無料のまま Pro の仕上がりを選んでいたら、先に案内を出す
    private func startMaking() {
        let pro = proStore.isPurchased ? [] : DigestFinish.proFeatures
        if pro.isEmpty {
            making = Task { await make() }
        } else {
            proNeeded = pro
        }
    }

    private func make() async {
        progress = 0
        defer {
            progress = nil
            making = nil
        }
        do {
            result = try await DigestMaker.make(plan: plan, scope: scope, clips: clips, assets: assets,
                                                textPosition: TripDigestComposer.TextPosition(rawValue: textPosition) ?? .bottomLeft,
                                                edits: edits) { value in
                // 作り終わったあとに遅れて届いた知らせで、作成中の表示を戻さない
                Task { @MainActor in if progress != nil { progress = value } }
            }
        } catch is CancellationError {
            // 「やめる」を押した
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// できた動画を見て、送る・保存する
struct TripDigestPlayerView: View {
    let result: TripDigestView.DigestResult
    @State private var player: AVPlayer?

    var body: some View {
        VideoPlayer(player: player)
            .aspectRatio(9 / 16, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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

/// コマを大きく見る。動画と同じ 9:16 の切り取りに、時刻・場所の文字（無料なら右下の Travory も）を
/// 実際の見た目で重ねる。左右にめくって前後のコマへ移り、そのまま外す・選び直す・文字を変えるができる
private struct DigestPreviewSheet: View {
    let plan: TravelPlan
    let scope: TripDigest.Scope
    /// 今のコマの並び（外す・選び直すと、作り直したものが届く）
    let clips: [TripDigest.Clip]
    /// 開いたときに出すコマ
    let startId: String
    let sources: [TripDigest.Source]
    let assets: [String: PHAsset]
    /// コマごとのトリミングと、動画の使いはじめ（3.2）
    let edits: [String: DigestClipEdit]
    let onEdit: (TripDigest.Clip, DigestClipEdit) -> Void
    let onExclude: (TripDigest.Clip) -> Void
    let onChoose: (TripDigest.Clip, TripDigest.Source) -> Void
    /// 出す文字を決めた（nil なら場所の名前に戻す）
    let onCaption: (TripDigest.Clip, String?) -> Void
    /// コマの時刻（0〜23時）を変えた
    let onSetHour: (TripDigest.Clip, Int) -> Void
    /// このコマのあとに写真を足す（写真の id）。読めなければ false
    let onAddAfter: (TripDigest.Clip, [String]) -> Bool
    /// このコマの写真を、カメラロールの写真に入れ替える（時刻はそのまま）。読めなければ false
    let onReplace: (TripDigest.Clip, String) -> Bool
    @State private var showsLimitedAccess = false

    @Environment(\.dismiss) private var dismiss
    @State private var adding: [PhotosPickerItem] = []
    @ObservedObject private var proStore = ProStore.shared
    @AppStorage("tripDigestTextPosition") private var textPosition = TripDigestComposer.TextPosition.bottomLeft.rawValue
    @State private var index = 0
    @State private var didStart = false
    @State private var editsCaption = false
    @State private var draft = ""
    @State private var showsPro = false
    @State private var swapping = false
    @State private var trimming = false
    /// 色味・画面の形・1コマの秒数が変わったら描き直す
    @AppStorage(DigestLook.storageKey) private var lookValue = DigestLook.natural.rawValue
    @AppStorage(DigestShape.storageKey) private var shapeValue = DigestShape.vertical.rawValue
    @AppStorage(DigestPace.storageKey) private var paceValue = DigestPace.standard

    private var look: DigestLook { DigestLook(rawValue: lookValue) ?? .natural }

    private var current: TripDigest.Clip? {
        clips.indices.contains(index) ? clips[index] : clips.last
    }

    private var position: TripDigestComposer.TextPosition {
        TripDigestComposer.TextPosition(rawValue: textPosition) ?? .bottomLeft
    }

    /// 日程から見つけた場所の名前（自分で文字を入れていなければ、これが出る）
    private func originalPlace(of clip: TripDigest.Clip) -> String? {
        sources.first { $0.id == clip.sourceId }
            .flatMap { TripDigest.placeName(near: $0, plan: plan, dayNumber: clip.dayNumber) }
    }

    var body: some View {
        NavigationStack {
            pager
                .safeAreaInset(edge: .bottom) { actionBar }
                // キーボードが出ても、写真の大きさや並びは変えない（文字が隠れるときだけ、写真のほうで少し上げる）
                .ignoresSafeArea(.keyboard, edges: .bottom)
                .navigationBarTitleDisplayMode(.inline)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .toolbar { topBar }
                .toolbar { keyboardBar }
                .navigationDestination(isPresented: $swapping) { swapView }
                .navigationDestination(isPresented: $trimming) { trimView }
                .sheet(isPresented: $showsPro) { DigestProSheet(isPresented: $showsPro) }
                .modifier(PreviewEvents(sheet: self))
                .alert("この写真は使えません", isPresented: $showsLimitedAccess) {
                    Button("設定を開く") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                    Button("閉じる", role: .cancel) {}
                } message: {
                    Text("写真へのアクセスが「選択した写真」になっています。設定アプリの「Travory」→「写真」で「フルアクセス」にすると、あとからもらった写真も使えます。")
                }
        }
    }

    private var pager: some View {
        ZStack {
            // 書いている間に写真のまわりを押すと決まる
            Color.black.ignoresSafeArea()
                .onTapGesture { commitCaption() }
            TabView(selection: $index) {
                ForEach(Array(clips.enumerated()), id: \.element.id) { offset, clip in
                    page(clip, offset: offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
    }

    private func page(_ clip: TripDigest.Clip, offset: Int) -> some View {
        DigestFramePreview(clip: clip, asset: assets[clip.sourceId],
                           edit: edits[clip.sourceId] ?? DigestClipEdit(), look: look,
                           // 題名のカードを入れるときは、動画と同じく1コマ目に題名を重ねない（3.2）
                           title: offset == 0 && !DigestFinish.current.opening ? plan.title : nil,
                           subtitle: DigestMaker.subtitle(plan: plan, scope: scope),
                           position: position, watermark: !proStore.isPurchased,
                           isActive: offset == index,
                           editing: offset == index && editsCaption ? $draft : nil,
                           onCommit: commitCaption)
            .padding(.horizontal, 28)
            .padding(.vertical, 8)
            // 写真を押すと、重ねた文字をその場で書き換えられる。
            // 書いている間は写真を押しても何もしない（文字の中を押してカーソルを動かせるように）
            .onTapGesture { if !editsCaption { editCaption() } }
            .tag(offset)
    }

    @ToolbarContentBuilder
    private var topBar: some ToolbarContent {
        ToolbarItem(placement: .principal) { timeMenu }
        // 外す・選び直す・文字はその場で保存しているので、閉じるのではなく「完了」にする
        // （書いている途中なら、そこまでを決めてから閉じる）
        ToolbarItem(placement: .confirmationAction) {
            Button("完了") {
                commitCaption()
                dismiss()
            }
            .fontWeight(.semibold)
        }
    }

    /// 時刻を押すと、このコマの時刻を変えられる（あとからもらった写真など）
    private var timeMenu: some View {
        Menu {
            if let current {
                Picker("時刻", selection: Binding(
                    get: { Calendar.current.component(.hour, from: current.date) },
                    set: { onSetHour(current, $0) })) {
                    ForEach(0..<24, id: \.self) { hour in Text("\(hour):00").tag(hour) }
                }
            }
        } label: {
            VStack(spacing: 1) {
                HStack(spacing: 4) {
                    Text(current.map { "Day \($0.dayNumber)  \($0.timeText)" } ?? "")
                        .font(.headline)
                    Image(systemName: "chevron.down").font(.caption2.weight(.bold))
                }
                Text("\(min(index + 1, clips.count)) / \(clips.count)")
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(.white.opacity(0.65))
            }
            .foregroundColor(.white)
        }
        .accessibilityLabel("このコマの時刻を変える")
    }

    @ToolbarContentBuilder
    private var keyboardBar: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            if let current, originalPlace(of: current) != nil {
                Button("場所の名前に戻す") {
                    onCaption(current, nil)
                    editsCaption = false
                }
            }
            Spacer()
            Button("完了", action: commitCaption).fontWeight(.semibold)
        }
    }

    @ViewBuilder
    private var trimView: some View {
        if let current {
            DigestTrimView(clip: current, asset: assets[current.sourceId],
                           edit: edits[current.sourceId] ?? DigestClipEdit(), look: look) { edit in
                onEdit(current, edit)
            }
        }
    }

    @ViewBuilder
    private var swapView: some View {
        if let current {
            DigestSwapView(candidates: sources.filter { Calendar.current.isDate($0.date, inSameDayAs: current.date) },
                           current: current.sourceId, assets: assets,
                           onChoose: { source in
                               onChoose(current, source)
                               swapping = false
                           },
                           onPickFromLibrary: { id in
                               if onReplace(current, id) { swapping = false } else { showsLimitedAccess = true }
                           })
        }
    }

    /// めくった・足した・数が変わったときの動き（body を短くするため分けた）
    private struct PreviewEvents: ViewModifier {
        let sheet: DigestPreviewSheet

        func body(content: Content) -> some View {
            content
                // 書いている途中でめくったら、そこまでを決める
                .onChange(of: sheet.index) { _, _ in if sheet.editsCaption { sheet.commitCaption() } }
                .onChange(of: sheet.adding) { _, items in
                    guard !items.isEmpty, let current = sheet.current else { return }
                    if !sheet.onAddAfter(current, items.compactMap(\.itemIdentifier)) { sheet.showsLimitedAccess = true }
                    sheet.adding = []
                }
                .onAppear {
                    guard !sheet.didStart else { return }
                    sheet.didStart = true
                    sheet.index = sheet.clips.firstIndex { $0.id == sheet.startId } ?? 0
                }
                // 外して数が減ったら、同じ位置（最後なら1つ前）のコマを出す。全部外したら閉じる
                .onChange(of: sheet.clips.count) { _, count in
                    if count == 0 { sheet.dismiss() } else { sheet.index = min(sheet.index, count - 1) }
                }
        }
    }

    /// 3つの操作は同じ大きさ・同じ色にする（外しても戻せるので、外すだけを目立たせない）
    private var actionBar: some View {
        VStack(spacing: 10) {
            Text("左右にめくると、前後のコマを見られます")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.5))
            HStack(spacing: 8) {
                actionButton("文字", systemImage: "textformat", badge: proStore.isPurchased ? nil : "Pro") {
                    editCaption()
                }
                PhotosPicker(selection: $adding, matching: .any(of: [.images, .videos]), photoLibrary: .shared()) {
                    actionLabel("足す", systemImage: "plus.rectangle.on.rectangle")
                }
                .buttonStyle(.plain)
                .disabled(current == nil)
                .accessibilityLabel("このコマのあとに写真を足す")
                actionButton("選び直す", systemImage: "photo.on.rectangle") { swapping = true }
                actionButton("トリミング", systemImage: "crop") { trimming = true }
                actionButton("外す", systemImage: "eye.slash") {
                    if let current { onExclude(current) }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private func actionButton(_ title: String, systemImage: String, badge: String? = nil,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            actionLabel(title, systemImage: systemImage, badge: badge)
        }
        .buttonStyle(.plain)
        .disabled(current == nil)
        .accessibilityLabel(badge == nil ? title : "\(title)（\(badge!)）")
    }

    private func actionLabel(_ title: String, systemImage: String, badge: String? = nil) -> some View {
            VStack(spacing: 6) {
                Image(systemName: systemImage).font(.system(size: 20, weight: .medium))
                Text(title).font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.12)))
            .overlay(alignment: .topTrailing) {
                if let badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.white.opacity(0.25)))
                        .padding(6)
                }
            }
    }

    /// 書いた文字を決める。変えていなければ何もしない（場所の名前を、自分で入れた文字にしてしまわない）
    private func commitCaption() {
        guard editsCaption else { return }
        editsCaption = false
        guard let current else { return }
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed != (current.placeName ?? "") { onCaption(current, trimmed) }
    }

    /// 出す文字を変える（Pro）。無料のときは、日程の場所の名前だけ
    private func editCaption() {
        guard let current else { return }
        if proStore.isPurchased {
            draft = current.placeName ?? ""
            editsCaption = true
        } else {
            showsPro = true
        }
    }
}

/// 足した写真の時刻が分からなかったとき、何時ごろの写真かを選んでもらう
private struct DigestAddedTimeSheet: View {
    let count: Int
    let day: Int
    let plan: TravelPlan
    let onDone: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var hour = 12

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                Text("写真から時刻が分からなかったので、何時ごろの写真かを選んでください。あとから、写真を押した画面で直せます。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Picker("時刻", selection: $hour) {
                    ForEach(0..<24, id: \.self) { hour in Text("\(hour):00").tag(hour) }
                }
                .pickerStyle(.wheel)
            }
            .navigationTitle("Day \(day) の\(count)枚")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("足す") {
                        onDone(hour)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

/// 動画の1コマの見本。動画と同じ部品（`TripDigestComposer.overlayImage`）で文字を描いて重ねる。
/// 動画のコマは、動画で使う真ん中の2秒をくり返し流す（めくって見ているときだけ）
private struct DigestFramePreview: View {
    let clip: TripDigest.Clip
    let asset: PHAsset?
    /// トリミングと動画の使いはじめ（3.2）
    var edit = DigestClipEdit()
    var look: DigestLook = .natural
    /// 最初のコマに大きく出す題名
    let title: String?
    let subtitle: String
    let position: TripDigestComposer.TextPosition
    let watermark: Bool
    let isActive: Bool
    /// 書き換えている文字。nil なら書き換えていない
    var editing: Binding<String>? = nil
    var onCommit: () -> Void = {}

    /// 読んだ写真（トリミングと色味をかける前）
    @State private var source: UIImage?
    /// トリミングと色味をかけた写真（動画と同じ部品で描く）
    @State private var image: UIImage?
    @State private var overlay: UIImage?
    /// 書きはじめる前の、画面の中の位置（キーボードで隠れるかを決める）
    @State private var restingFrame: CGRect = .zero
    @State private var keyboardTop: CGFloat?
    @FocusState private var focused: Bool

    private static let context = CIContext()

    private var isEditing: Bool { editing != nil }

    // MARK: 書き換える文字の位置（動画の 1080 × 1920 の座標。`TripDigestComposer.overlayImage` と合わせる）

    private static let placeFontSize: CGFloat = 64
    /// 場所の名前の1行の高さ（太字 64 の行の高さ）
    private static let placeLineHeight: CGFloat = 76

    /// 場所の名前の行の、上下の真ん中
    private var placeCenterY: CGFloat {
        let H = TripDigestComposer.renderSize.height
        let timeLine: CGFloat = 53 + 8
        switch position {
        case .bottomLeft: return H - 150 - Self.placeLineHeight / 2
        case .topRight: return 170 + timeLine + Self.placeLineHeight / 2
        case .center: return (title == nil ? H * 0.44 : H * 0.56) + timeLine + Self.placeLineHeight / 2
        }
    }

    private var placeAlignment: TextAlignment {
        switch position {
        case .bottomLeft: return .leading
        case .center: return .center
        case .topRight: return .trailing
        }
    }

    /// キーボードで文字が隠れるときだけ、隠れない分だけ写真を上げる（大きさは変えない）
    private var lift: CGFloat {
        guard isEditing, let keyboardTop, restingFrame.width > 0 else { return 0 }
        let k = restingFrame.width / TripDigestComposer.renderSize.width
        let lineBottom = restingFrame.minY + (placeCenterY + Self.placeLineHeight / 2) * k
        return max(0, lineBottom - (keyboardTop - 12))
    }

    var body: some View {
        Color(white: 0.12)
            .aspectRatio(TripDigestComposer.aspectRatio, contentMode: .fit)
            .overlay {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    ProgressView().tint(.white)
                }
            }
            .overlay {
                if isActive, let asset, asset.mediaType == .video {
                    DigestLoopingVideo(asset: asset, edit: edit, look: look, seconds: TripDigest.clipSeconds,
                                       canvas: TripDigestComposer.renderSize)
                        .id("\(edit.hashValue)|\(look.rawValue)|\(TripDigest.clipSeconds)|\(TripDigestComposer.aspectRatio)")
                }
            }
            .overlay {
                if let overlay { Image(uiImage: overlay).resizable() }
            }
            .overlay {
                if let editing {
                    GeometryReader { geo in placeField(editing, in: geo.size) }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                if !isEditing { restingFrame = frame }
            }
            .offset(y: -lift)
            .animation(.easeOut(duration: 0.25), value: lift)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task(id: clip.sourceId) { loadImage() }
            .task(id: "\(source.map { ObjectIdentifier($0) }.debugDescription)|\(edit.hashValue)|\(look.rawValue)|\(TripDigestComposer.aspectRatio)") {
                renderImage()
            }
            .task(id: "\(clip.sourceId)|\(clip.placeName ?? "")|\(position.rawValue)|\(watermark)|\(title ?? "")|\(isEditing)|\(TripDigestComposer.aspectRatio)") {
                renderOverlay()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { note in
                keyboardTop = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.minY
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                keyboardTop = nil
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Day \(clip.dayNumber) \(clip.timeText)\(clip.placeName.map { "、\($0)" } ?? "")")
            .accessibilityHint("押すと、出す文字を変えられます")
    }

    private func loadImage() {
        guard let asset else { return }
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 900, height: 1600),
                                              contentMode: .aspectFill, options: options) { result, _ in
            if let result { source = result }
        }
    }

    /// 動画と同じ部品で、トリミングと色味をかける（半分の大きさで描く）
    private func renderImage() {
        guard let cg = source?.cgImage else { return }
        let half = CGAffineTransform(scaleX: 0.5, y: 0.5)
        let frame = TripDigestComposer.frameImage(CIImage(cgImage: cg), edit: edit, look: look).transformed(by: half)
        let rect = CGRect(origin: .zero, size: TripDigestComposer.renderSize).applying(half)
        guard let rendered = Self.context.createCGImage(frame, from: rect) else { return }
        image = UIImage(cgImage: rendered)
    }

    /// 場所の名前があったところに、同じ大きさ・同じ見た目の入力欄を置く
    private func placeField(_ text: Binding<String>, in size: CGSize) -> some View {
        let k = size.width / TripDigestComposer.renderSize.width
        let margin: CGFloat = 72
        return TextField("", text: text, prompt: Text("文字を入れる").foregroundColor(.white.opacity(0.5)))
            .font(.system(size: Self.placeFontSize * k, weight: .bold))
            .foregroundColor(.white)
            .tint(.white)
            .multilineTextAlignment(placeAlignment)
            .shadow(color: .black.opacity(0.5), radius: 5 * k)
            .focused($focused)
            .submitLabel(.done)
            .onSubmit(onCommit)
            .frame(width: size.width - margin * 2 * k, height: Self.placeLineHeight * k)
            .position(x: size.width / 2, y: placeCenterY * k)
            .onAppear { focused = true }
    }

    private func renderOverlay() {
        // 書き換えている間は、場所の名前を描かない（入力欄が代わりに出る）。
        // 空白を1つ入れておき、時刻の行の位置は変えない
        var clip = clip
        if isEditing { clip.placeName = " " }
        guard let ci = TripDigestComposer.overlayImage(for: clip, title: title, subtitle: subtitle,
                                                       position: position, watermark: watermark),
              let cg = Self.context.createCGImage(ci, from: ci.extent) else { return }
        overlay = UIImage(cgImage: cg).downscaled(maxPixel: 1200)
    }
}

/// 動画のコマの見本：真ん中の2秒を、音を消してくり返し流す（動画で使うのと同じ範囲）
private struct DigestLoopingVideo: UIViewRepresentable {
    let asset: PHAsset
    var edit = DigestClipEdit()
    var look: DigestLook = .natural
    var seconds: Double = TripDigest.clipSeconds
    /// 作る動画の大きさ（トリミングをこの形で見せる）
    var canvas: CGSize = TripDigestComposer.renderSize

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.load(asset, edit: edit, look: look, seconds: seconds, canvas: canvas)
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {}

    static func dismantleUIView(_ uiView: PlayerView, coordinator: ()) {
        uiView.stop()
    }

    final class PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
        private var looper: AVPlayerLooper?
        private var requestID: PHImageRequestID?
        private var stopped = false

        func load(_ asset: PHAsset, edit: DigestClipEdit, look: DigestLook, seconds: Double, canvas: CGSize) {
            playerLayer.videoGravity = .resizeAspectFill
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .mediumQualityFormat
            let duration = asset.duration
            requestID = PHImageManager.default().requestPlayerItem(forVideo: asset, options: options) { [weak self] item, _ in
                guard let item else { return }
                DispatchQueue.main.async { self?.start(item, duration: duration, edit: edit, look: look,
                                                       seconds: seconds, canvas: canvas) }
            }
        }

        private func start(_ item: AVPlayerItem, duration: TimeInterval, edit: DigestClipEdit, look: DigestLook,
                           seconds: Double, canvas: CGSize) {
            guard !stopped else { return }
            let player = AVQueuePlayer()
            player.isMuted = true
            let used = edit.videoRange(duration: duration, length: max(min(seconds, duration), 0.1))
            let range = CMTimeRange(start: CMTime(seconds: used.start, preferredTimescale: 600),
                                    duration: CMTime(seconds: max(used.length, 0.1), preferredTimescale: 600))
            // トリミングと色味は、動画と同じ部品でかける（半分の大きさで）
            if !edit.isUncropped || look != .natural {
                let half = CGSize(width: canvas.width / 2, height: canvas.height / 2)
                let composition = AVMutableVideoComposition(asset: item.asset) { request in
                    let frame = TripDigestComposer.frameImage(request.sourceImage, edit: edit, look: look,
                                                              motion: 1, canvas: half)
                    request.finish(with: frame, context: nil)
                }
                composition.renderSize = half
                item.videoComposition = composition
            }
            looper = AVPlayerLooper(player: player, templateItem: item, timeRange: range)
            playerLayer.player = player
            player.play()
        }

        func stop() {
            stopped = true
            playerLayer.player?.pause()
            looper?.disableLooping()
            if let requestID { PHImageManager.default().cancelImageRequest(requestID) }
        }
    }
}

/// 時刻・場所の文字の位置を選ぶ（左下・真ん中・右上）。
/// 選ぶボタンそのものを見本にする：1枚目の写真に、そのコマの時刻と場所を、動画と同じ部品
/// （`TripDigestComposer.overlayImage`）で重ねて描くので、見本と動画の見た目が食い違わない
private struct DigestTextPositionPicker: View {
    @Binding var selection: String
    /// 見本にするコマ（選んでいる範囲の1枚目）
    let sample: TripDigest.Clip?
    let assets: [String: PHAsset]

    @ObservedObject private var proStore = ProStore.shared

    @State private var overlays: [String: UIImage] = [:]
    /// 画面の形が変わったら描き直す（3.2）
    @AppStorage(DigestShape.storageKey) private var shape = DigestShape.vertical.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("文字の位置")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            HStack(spacing: 14) {
                ForEach(TripDigestComposer.TextPosition.allCases) { position in
                    let isSelected = selection == position.rawValue
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { selection = position.rawValue }
                    } label: {
                        VStack(spacing: 5) {
                            // 画面の幅いっぱいに3つ並ぶ大きさ（縦長 9:16）
                            Color.clear
                                .aspectRatio(TripDigestComposer.aspectRatio, contentMode: .fit)
                                .frame(maxWidth: 130, maxHeight: 231)
                                .overlay {
                                    AssetImage(asset: sample.flatMap { assets[$0.sourceId] },
                                               target: CGSize(width: 300, height: 540))
                                }
                                .overlay {
                                    if let overlay = overlays[position.rawValue] {
                                        Image(uiImage: overlay).resizable()
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.12),
                                                lineWidth: isSelected ? 3 : 1)
                                )
                                .shadow(color: .black.opacity(isSelected ? 0.15 : 0.05), radius: 4, y: 2)
                            HStack(spacing: 3) {
                                if isSelected {
                                    Image(systemName: "checkmark").font(.system(size: 9, weight: .bold))
                                }
                                Text(position.name)
                            }
                            .font(.caption2.weight(isSelected ? .bold : .regular))
                            .foregroundColor(isSelected ? .accentColor : .secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("文字の位置：\(position.name)")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .frame(maxWidth: .infinity)
            if !proStore.isPurchased {
                Text("右下に小さく「Travory」の文字が、最後に1秒「Travory」の印が入ります。Pro なら印なしになり、色味・正方形と横長、場所の名前の代わりに好きな文字も使えます。")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .task(id: "\(sample?.sourceId ?? "")|\(sample?.placeName ?? "")|\(proStore.isPurchased)|\(shape)") { renderOverlays() }
    }

    /// 3つの位置の文字を、動画と同じ部品で描く（縮めて持つ）
    private func renderOverlays() {
        let clip = sample ?? TripDigest.Clip(sourceId: "sample", dayNumber: 1, date: Date(), timeText: "14:05", placeName: "首里城")
        let context = CIContext()
        var result: [String: UIImage] = [:]
        for position in TripDigestComposer.TextPosition.allCases {
            guard let overlay = TripDigestComposer.overlayImage(for: clip, title: nil, subtitle: "", position: position,
                                                                watermark: !proStore.isPurchased),
                  let cg = context.createCGImage(overlay, from: overlay.extent) else { continue }
            result[position.rawValue] = UIImage(cgImage: cg).downscaled(maxPixel: 720)
        }
        overlays = result
    }
}

/// その日に撮った写真・動画を時間ごとに並べ、コマに使うものを選び直す
private struct DigestSwapView: View {
    let candidates: [TripDigest.Source]
    let current: String
    let assets: [String: PHAsset]
    let onChoose: (TripDigest.Source) -> Void
    /// カメラロールのすべての写真から選んだ（写真の id）。その日に撮った写真に無いとき（あとからもらった写真など）
    var onPickFromLibrary: ((String) -> Void)? = nil

    @State private var libraryItem: PhotosPickerItem?

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 4)]

    private var hours: [(hour: Int, sources: [TripDigest.Source])] {
        let calendar = Calendar.current
        return Dictionary(grouping: candidates) { calendar.component(.hour, from: $0.date) }
            .sorted { $0.key < $1.key }
            .map { ($0.key, $0.value.sorted { $0.date < $1.date }) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14, pinnedViews: [.sectionHeaders]) {
                if onPickFromLibrary != nil {
                    PhotosPicker(selection: $libraryItem, matching: .any(of: [.images, .videos]),
                                 photoLibrary: .shared()) {
                        VStack(alignment: .leading, spacing: 3) {
                            Label("カメラロールのすべての写真から選ぶ", systemImage: "photo.on.rectangle.angled")
                                .font(.subheadline.weight(.semibold))
                            Text("あとからもらった写真なども選べます。このコマの時刻のまま入れ替えます。")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.secondarySystemBackground)))
                    }
                    .buttonStyle(.plain)
                    Text("この日に撮った写真")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                ForEach(hours, id: \.hour) { group in
                    Section {
                        LazyVGrid(columns: columns, spacing: 4) {
                            ForEach(group.sources, id: \.id) { source in
                                Button { onChoose(source) } label: {
                                    Color.clear
                                        .aspectRatio(1, contentMode: .fit)
                                        .overlay { AssetImage(asset: assets[source.id], target: CGSize(width: 300, height: 300)) }
                                        .overlay(alignment: .topTrailing) {
                                            if source.isVideo {
                                                Image(systemName: "video.fill")
                                                    .font(.caption2).foregroundColor(.white).padding(5)
                                            }
                                        }
                                        .overlay {
                                            if source.id == current {
                                                RoundedRectangle(cornerRadius: 6).stroke(Color.accentColor, lineWidth: 3)
                                            }
                                        }
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(source.id == current ? "今のコマ" : "この写真にする")
                            }
                        }
                    } header: {
                        Text("\(group.hour):00")
                            .font(.system(size: 15, weight: .bold).width(.condensed))
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemBackground))
                    }
                }
            }
            .padding(12)
        }
        .background(Color(.systemBackground))
        .navigationTitle("写真を選び直す")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(nil, for: .navigationBar)
        .onChange(of: libraryItem) { _, item in
            guard let id = item?.itemIdentifier else { return }
            libraryItem = nil
            onPickFromLibrary?(id)
        }
    }
}

/// Pro の案内（好きな文字を入れようとしたとき。Pro でない人）
private struct DigestProSheet: View {
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            ProView()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") { isPresented = false }
                    }
                }
        }
    }
}
