import SwiftUI
import AVKit
import Photos

/// 旅のダイジェスト動画を作る画面（Travory Pro）。
///
/// 縦長の写真カードを横にめくって「旅行全体」か「Day ごと」を選ぶ。各カードはその日の1枚目の写真が表紙で、
/// 大きな日付を重ねる。下の丸いボタンで「確かめる」（コマを並べた一覧へ）か「作る」
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
    @State private var reviewing: TripDigest.Scope?
    @State private var selected: String? = TripDigest.Scope.trip.id
    @State private var progress: Double?
    @State private var result: DigestResult?
    @State private var errorMessage: String?
    /// 時刻・場所の文字の位置（左下・真ん中・右上）。次に作るときも同じにする
    @AppStorage("tripDigestTextPosition") private var textPosition = TripDigestComposer.TextPosition.bottomLeft.rawValue
    @State private var showsPro = false
    /// 残した動画が変わった合図（作り終わったら数を進め、下の札を読み直す）
    @State private var libraryVersion = 0

    struct DigestResult: Identifiable, Hashable {
        let url: URL
        let title: String
        var id: URL { url }
    }

    private var usable: [TripDigest.Source] { sources.filter { !excluded.contains($0.id) } }

    /// カードに並べる範囲（コマが1つも無い日は出さない）
    private var scopes: [TripDigest.Scope] {
        let days = (1...max(plan.dayCount, 1)).map { TripDigest.Scope.day($0) }
        return ([.trip] + days).filter { !clips(for: $0).isEmpty }
    }

    private func clips(for scope: TripDigest.Scope) -> [TripDigest.Clip] {
        TripDigest.clips(plan: plan, sources: usable, scope: scope, pinned: pinned)
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
                    if scopes.isEmpty {
                        emptyView
                    } else {
                        carousel
                    }
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
                DigestReviewView(plan: plan, scope: scope, sources: sources, assets: assets,
                                 excluded: $excluded, pinned: $pinned)
            }
            .navigationDestination(item: $result) { result in
                TripDigestPlayerView(result: result)
            }
            .onChange(of: result) { _, _ in libraryVersion += 1 }
            .onChange(of: reviewing) { _, _ in libraryVersion += 1 }
            .overlay { if let progress { MakingOverlay(progress: progress) } }
            .alert(errorMessage ?? "", isPresented: Binding(get: { errorMessage != nil },
                                                            set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            }
            .task(id: plan.id) { await load() }
            .sheet(isPresented: $showsPro) { DigestProSheet(isPresented: $showsPro) }
            .onChange(of: excluded) { _, value in
                TripDigestExclusions.save(value, planId: plan.id)
            }
            .onChange(of: pinned) { _, value in
                TripDigestExclusions.savePinned(value, planId: plan.id)
            }
        }
    }

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
            Spacer(minLength: 12)
            DigestTextPositionPicker(selection: $textPosition,
                                     sample: clips(for: selectedScope ?? .trip).first, assets: assets,
                                     onLocked: { showsPro = true })
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            bottomBar
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
        }
    }

    // MARK: 下：選んでいるカードの札と、丸いボタン

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
            Spacer(minLength: 0)
            roundButton(systemImage: "square.grid.2x2", label: "確かめる") { reviewing = scope }
            roundButton(systemImage: "play.fill", label: "作る") {
                Task { await make(scope: scope) }
            }
        }
    }

    private func roundButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Color(.systemBackground))
                .frame(width: 52, height: 52)
                .background(Circle().fill(Color.primary.opacity(0.88)))
                .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
        }
        .accessibilityLabel(label)
        .disabled(progress != nil)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 44))
                .foregroundColor(.secondary)
            Text("この旅行の期間に撮った写真や動画が見つかりませんでした。")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding(32)
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
        excluded = TripDigestExclusions.load(planId: plan.id)
        pinned = TripDigestExclusions.loadPinned(planId: plan.id)
        guard await TripDigestComposer.requestAccess() else {
            phase = .noAccess
            return
        }
        let found = TripDigestComposer.sources(for: plan)
        sources = found.sources
        assets = found.assets
        phase = .ready
    }

    private func make(scope: TripDigest.Scope) async {
        progress = 0
        defer { progress = nil }
        do {
            result = try await DigestMaker.make(plan: plan, scope: scope, clips: clips(for: scope), assets: assets,
                                                textPosition: TripDigestComposer.TextPosition(rawValue: textPosition) ?? .bottomLeft) { value in
                // 作り終わったあとに遅れて届いた知らせで、作成中の表示を戻さない
                Task { @MainActor in if progress != nil { progress = value } }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
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
                     textPosition: TripDigestComposer.TextPosition,
                     progress: @escaping @Sendable (Double) -> Void) async throws -> TripDigestView.DigestResult {
        // 無料でも作れる。Pro でなければ最後に「Travory」の印を入れ、文字は左下にする
        let isPro = ProStore.shared.isPurchased
        let items = await TripDigestComposer.loadItems(clips, assets: assets)
        let subtitle: String
        switch scope {
        case .day(let n):
            subtitle = "Day \(n)・\(TravelPlanTextExporter.dateString(plan.date(forDay: n)))"
        case .trip:
            subtitle = "\(TravelPlanTextExporter.dateString(plan.startDate)) 〜 \(TravelPlanTextExporter.dateString(plan.endDate))"
        }
        let temporary = try await TripDigestComposer.compose(items, title: plan.title, subtitle: subtitle,
                                                             fileName: TripDigest.fileName(plan: plan, scope: scope),
                                                             textPosition: isPro ? textPosition : .bottomLeft,
                                                             endCard: !isPro, progress: progress)
        // 作った動画は残しておく（「思い出」タブのカードから、作り直さずに見られる）
        let url = (try? TripDigestLibrary.save(temporary, planId: plan.id, scopeId: scope.id, title: subtitle)) ?? temporary
        return TripDigestView.DigestResult(url: url, title: subtitle)
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
private struct AssetImage: View {
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
            .overlay { AssetImage(asset: clips.first.flatMap { assets[$0.sourceId] }) }
            .overlay {
                LinearGradient(colors: [.black.opacity(0.35), .clear, .clear, .black.opacity(0.55)],
                               startPoint: .top, endPoint: .bottom)
            }
            .overlay(alignment: .topLeading) { dateMark.padding(20) }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 8) {
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

    var body: some View {
        ZStack {
            Color.black.opacity(0.2).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView(value: progress).frame(maxWidth: 220)
                Text("動画を作っています…").font(.subheadline).foregroundColor(.secondary)
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
    let assets: [String: PHAsset]
    @Binding var excluded: Set<String>
    @Binding var pinned: Set<String>

    @State private var progress: Double?
    @State private var result: TripDigestView.DigestResult?
    @State private var errorMessage: String?
    @AppStorage("tripDigestTextPosition") private var textPosition = TripDigestComposer.TextPosition.bottomLeft.rawValue
    @State private var showsPro = false
    /// 押して大きく見ているコマ（外すかどうかはここで決める）
    @State private var previewing: TripDigest.Clip?

    private var clips: [TripDigest.Clip] {
        TripDigest.clips(plan: plan, sources: sources.filter { !excluded.contains($0.id) }, scope: scope, pinned: pinned)
    }

    /// この動画の範囲で外した写真・動画（押すと戻せる）
    private var excludedClips: [TripDigest.Clip] {
        let days: [Int]
        switch scope {
        case .day(let n): days = [n]
        case .trip: days = Array(1...max(plan.dayCount, 1))
        }
        let calendar = Calendar.current
        return sources.filter { excluded.contains($0.id) }.compactMap { source in
            guard let day = days.first(where: { calendar.isDate(source.date, inSameDayAs: plan.date(forDay: $0)) })
            else { return nil }
            return TripDigest.Clip(sourceId: source.id, dayNumber: day, date: source.date,
                                   timeText: TripDigest.timeText(source.date, calendar: calendar),
                                   placeName: TripDigest.placeName(near: source, plan: plan, dayNumber: day))
        }
        .sorted { $0.date < $1.date }
    }

    /// 日ごとのまとまり
    private var days: [(day: Int, clips: [TripDigest.Clip])] {
        Dictionary(grouping: clips, by: \.dayNumber).sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12, pinnedViews: [.sectionHeaders]) {
                Text("写真を押すと大きく見られ、外したり、その日の別の写真に選び直したりできます（長押しでも外せます）。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                DigestTextPositionPicker(selection: $textPosition, sample: clips.first, assets: assets,
                                         onLocked: { showsPro = true })
                ForEach(days, id: \.day) { group in
                    Section {
                        ForEach(group.clips) { clip in
                            row(clip)
                        }
                    } header: {
                        dayHeader(group.day, count: group.clips.count)
                    }
                }
                if !excludedClips.isEmpty {
                    excludedSection
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .overlay { if let progress { MakingOverlay(progress: progress) } }
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
            TripDigestPlayerView(result: result)
        }
        .sheet(item: $previewing) { clip in
            DigestPreviewSheet(asset: assets[clip.sourceId], clip: clip,
                               candidates: sources.filter { Calendar.current.isDate($0.date, inSameDayAs: clip.date) },
                               assets: assets,
                               onExclude: {
                                   withAnimation {
                                       _ = excluded.insert(clip.sourceId)
                                       _ = pinned.remove(clip.sourceId)
                                   }
                               },
                               onChoose: { source in
                                   withAnimation {
                                       TripDigestExclusions.choose(source, among: sources, pinned: &pinned, excluded: &excluded)
                                   }
                               })
        }
        .alert(errorMessage ?? "", isPresented: Binding(get: { errorMessage != nil },
                                                        set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        }
        .sheet(isPresented: $showsPro) { DigestProSheet(isPresented: $showsPro) }
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
                    withAnimation { _ = excluded.insert(clip.sourceId) }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(clip.timeText)\(clip.placeName.map { "・\($0)" } ?? "")")
        .accessibilityHint(excludedStyle ? "押すと戻します" : "押すと大きく表示します")
    }

    private var excludedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("外した写真（\(excludedClips.count)）")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button("すべて戻す") {
                    withAnimation { excluded.subtract(excludedClips.map(\.sourceId)) }
                }
                .font(.footnote)
            }
            Text("押すと戻せます。外した写真は、この旅行では次からも使いません。")
                .font(.caption)
                .foregroundColor(.secondary)
            ForEach(excludedClips) { clip in
                row(clip, excludedStyle: true)
            }
        }
        .padding(.top, 16)
    }

    private func make() async {
        progress = 0
        defer { progress = nil }
        do {
            result = try await DigestMaker.make(plan: plan, scope: scope, clips: clips, assets: assets,
                                                textPosition: TripDigestComposer.TextPosition(rawValue: textPosition) ?? .bottomLeft) { value in
                // 作り終わったあとに遅れて届いた知らせで、作成中の表示を戻さない
                Task { @MainActor in if progress != nil { progress = value } }
            }
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

/// コマを大きく見る。ここで外すかを決める
private struct DigestPreviewSheet: View {
    let asset: PHAsset?
    let clip: TripDigest.Clip
    /// 選び直せる写真・動画（その日に撮ったもの）
    let candidates: [TripDigest.Source]
    let assets: [String: PHAsset]
    let onExclude: () -> Void
    let onChoose: (TripDigest.Source) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if let image {
                    Image(uiImage: image).resizable().scaledToFit()
                } else {
                    ProgressView().tint(.white)
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 10) {
                    NavigationLink {
                        DigestSwapView(candidates: candidates, current: clip.sourceId, assets: assets) { source in
                            onChoose(source)
                            dismiss()
                        }
                    } label: {
                        Label("写真を選び直す", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    Button(role: .destructive) {
                        onExclude()
                        dismiss()
                    } label: {
                        Label("外す", systemImage: "eye.slash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .controlSize(.large)
                .padding(16)
            }
            .navigationTitle("Day \(clip.dayNumber) \(clip.timeText)\(clip.placeName.map { "・\($0)" } ?? "")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .task(id: asset?.localIdentifier) {
                guard let asset else { return }
                let options = PHImageRequestOptions()
                options.deliveryMode = .opportunistic
                options.isNetworkAccessAllowed = true
                PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 1200, height: 1200),
                                                      contentMode: .aspectFit, options: options) { result, _ in
                    if let result { image = result }
                }
            }
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
    /// 左下のほかを選ぼうとしたとき（Pro でない人）
    var onLocked: () -> Void = {}

    @ObservedObject private var proStore = ProStore.shared

    private func isLocked(_ position: TripDigestComposer.TextPosition) -> Bool {
        !proStore.isPurchased && position != .bottomLeft
    }

    /// 実際に使う位置（Pro でなければ左下）
    private var effective: String {
        proStore.isPurchased ? selection : TripDigestComposer.TextPosition.bottomLeft.rawValue
    }

    @State private var overlays: [String: UIImage] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("文字の位置")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            HStack(spacing: 14) {
                ForEach(TripDigestComposer.TextPosition.allCases) { position in
                    let isSelected = effective == position.rawValue
                    Button {
                        if isLocked(position) {
                            onLocked()
                        } else {
                            withAnimation(.easeInOut(duration: 0.15)) { selection = position.rawValue }
                        }
                    } label: {
                        VStack(spacing: 5) {
                            // 画面の幅いっぱいに3つ並ぶ大きさ（縦長 9:16）
                            Color.clear
                                .aspectRatio(9 / 16, contentMode: .fit)
                                .frame(maxWidth: 130)
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
                                .overlay(alignment: .topTrailing) {
                                    if isLocked(position) {
                                        Text("Pro")
                                            .font(.caption2.bold())
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Capsule().fill(.black.opacity(0.5)))
                                            .padding(5)
                                    }
                                }
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
                Text("動画の最後に1秒「Travory」の印が入ります。Pro なら印なしで、文字の位置も選べます。")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .task(id: sample?.sourceId) { renderOverlays() }
    }

    /// 3つの位置の文字を、動画と同じ部品で描く（縮めて持つ）
    private func renderOverlays() {
        let clip = sample ?? TripDigest.Clip(sourceId: "sample", dayNumber: 1, date: Date(), timeText: "14:05", placeName: "首里城")
        let context = CIContext()
        var result: [String: UIImage] = [:]
        for position in TripDigestComposer.TextPosition.allCases {
            guard let overlay = TripDigestComposer.overlayImage(for: clip, title: nil, subtitle: "", position: position),
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
    }
}

/// 文字の位置を変えようとしたとき（Pro でない人）
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
