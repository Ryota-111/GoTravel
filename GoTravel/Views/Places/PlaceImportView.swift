import SwiftUI
import MapKit

/// 送られたリンク・文章・スクリーンショットから場所を探し、選んで「行きたい場所」に保存する画面（3.5）。
///
/// 中身の読み方は `PlaceImportReader`。見つかった場所を地図と一覧で見せ、押すだけで保存する。
/// カテゴリー・メモ・写真は、あとから場所の詳細で足せばよい（保存までの手順を減らすため）
struct PlaceImportView: View {
    enum Source: Equatable {
        case text(String)
        case image(UIImage)
    }

    let sources: [Source]
    /// 下のボタンの文字と、押したとき（受け取り箱の「次へ」など）。nil なら「閉じる」
    var nextTitle: String? = nil
    var onNext: (() -> Void)? = nil
    /// 送られたものを捨てる（受け取り箱から開いたときだけ）
    var onDiscard: (() -> Void)? = nil

    @EnvironmentObject private var authVM: AuthViewModel
    @StateObject private var places = PlacesViewModel()
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var categoryManager = PlaceCategoryManager.shared
    @ObservedObject private var proStore = ProStore.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var candidates: [PlaceImportCandidate] = []
    /// スクリーンショットから読めた、場所の名前らしい文字（押すと、その言葉で探し直す）
    @State private var queries: [String] = []
    @State private var isReading = true
    @State private var isSearching = false
    @State private var savedIDs: Set<String> = []
    @State private var searchText = ""
    @State private var selectedID: String?
    @State private var camera: MapCameraPosition = .automatic
    /// スクリーンショットを読めたか（Pro・お試し・使い切り）。スクリーンショットが無ければ nil
    @State private var screenshotAccess: ScreenshotAccess?
    @State private var didRead = false
    @State private var showsProSheet = false

    /// スクリーンショットから読むのは Pro の機能。Pro でない人も最初の数回は試せる（`PlaceScreenshotTrial`）
    private enum ScreenshotAccess: Equatable {
        case pro
        case trial(remaining: Int)
        case locked
    }

    private var hasImages: Bool {
        sources.contains { if case .image = $0 { return true } else { return false } }
    }

    private var accent: Color { themeManager.currentTheme.actionFill }
    private var textColor: Color {
        colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1
    }
    private var secondaryText: Color { themeManager.currentTheme.secondaryText }
    private var cardFill: Color { themeManager.currentTheme.listCardSurface(for: colorScheme) }

    /// 送られたものが、ログインしないと読めない投稿のリンクだけか
    private var isOnlySocialLink: Bool {
        sources.allSatisfy { source in
            guard case .text(let text) = source else { return false }
            let urls = PlaceLinkParser.urls(in: text)
            return !urls.isEmpty && urls.allSatisfy(PlaceLinkParser.isSocialPost)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    sourcePreview
                    if screenshotAccess == .locked { proNotice }
                    if !candidates.isEmpty { mapPreview }
                    results
                    if !queries.isEmpty { queryChips }
                    searchField
                    if case .trial(let remaining) = screenshotAccess { trialNote(remaining) }
                    if let onDiscard {
                        Button(role: .destructive) {
                            onDiscard()
                        } label: {
                            Label("送ったものを捨てる", systemImage: "trash")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(20)
                .readableWidth()
            }
            .background((colorScheme == .dark ? themeManager.currentTheme.backgroundDark
                                              : themeManager.currentTheme.backgroundLight).ignoresSafeArea())
            .navigationTitle("場所を保存")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(nextTitle ?? "閉じる") {
                        if let onNext { onNext() } else { dismiss() }
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(accent)
                }
            }
            .task(id: sources.count) {
                guard !didRead else { return }
                didRead = true
                await read()
            }
            // 使い切ったあと、ここから Pro を買ったら、そのまま読む
            .onChange(of: proStore.isPurchased) { _, purchased in
                if purchased && screenshotAccess == .locked { Task { await read() } }
            }
            .sheet(isPresented: $showsProSheet) {
                ProSheet(highlighted: nil, dismissesOnPurchase: true)
            }
            .task {
                if let userId = authVM.userId { places.setupFetchedResultsController(userId: userId) }
            }
        }
    }

    // MARK: - 送られたもの

    @ViewBuilder
    private var sourcePreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("送られたもの")
                .font(.caption.weight(.semibold))
                .foregroundColor(secondaryText)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(sources.enumerated()), id: \.offset) { _, source in
                        switch source {
                        case .text(let text):
                            Text(text.trimmingCharacters(in: .whitespacesAndNewlines))
                                .font(.system(size: 12))
                                .foregroundColor(textColor.opacity(0.8))
                                .lineLimit(4)
                                .frame(width: sources.count == 1 ? nil : 220, alignment: .leading)
                                .padding(12)
                                .background(cardFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        case .image(let image):
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 72, height: 128)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                }
            }
        }
    }

    // MARK: - 見つかった場所

    private var mapPreview: some View {
        Map(position: $camera, selection: $selectedID) {
            ForEach(candidates) { candidate in
                Marker(candidate.name, systemImage: categoryManager.category(for: candidate.categoryId).icon,
                       coordinate: candidate.coordinate)
                    .tint(savedIDs.contains(candidate.id) ? .green : accent)
                    .tag(candidate.id)
            }
        }
        .frame(height: 190)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .allowsHitTesting(true)
    }

    @ViewBuilder
    private var results: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(isReading ? "場所を探しています…"
                 : (candidates.isEmpty ? (screenshotAccess == .locked ? "名前で探して保存できます" : "場所が見つかりませんでした")
                                       : "見つかった場所"))
                .font(.caption.weight(.semibold))
                .foregroundColor(secondaryText)

            if isReading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else if candidates.isEmpty && screenshotAccess != .locked {
                Text(isOnlySocialLink
                     ? "Instagram・TikTok の投稿のリンクからは、場所を読めません。投稿のスクリーンショットを送ってください。"
                     : "下の欄に場所の名前を入れて探せます。")
                    .font(.subheadline)
                    .foregroundColor(textColor.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(candidates) { candidate in
                    candidateRow(candidate)
                }
            }
        }
    }

    private func candidateRow(_ candidate: PlaceImportCandidate) -> some View {
        let category = categoryManager.category(for: candidate.categoryId)
        let saved = savedIDs.contains(candidate.id)
        let selected = selectedID == candidate.id
        return HStack(spacing: 12) {
            Image(systemName: category.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(category.color)
                .frame(width: 36, height: 36)
                .background(category.color.opacity(colorScheme == .dark ? 0.24 : 0.14), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(candidate.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(textColor)
                    .lineLimit(2)
                if let address = candidate.address {
                    Text(address)
                        .font(.caption)
                        .foregroundColor(secondaryText)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            Button {
                save(candidate)
            } label: {
                Label(saved ? "保存済み" : "保存", systemImage: saved ? "checkmark" : "plus")
                    .font(.subheadline.weight(.semibold))
                    .labelStyle(.titleAndIcon)
                    .foregroundColor(saved ? secondaryText : ThemePreset.readableText(on: accent))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(saved ? secondaryText.opacity(0.15) : accent, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(saved)
            .accessibilityLabel(saved ? "\(candidate.name)は保存済み" : "\(candidate.name)を行きたい場所に保存")
        }
        .padding(12)
        .background(cardFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(selected ? accent : .clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation {
                selectedID = candidate.id
                camera = .region(MKCoordinateRegion(center: candidate.coordinate, latitudinalMeters: 1500,
                                                    longitudinalMeters: 1500))
            }
        }
    }

    /// お試しを使い切った人へ。名前で探して保存するのは、これまでどおり無料
    private var proNotice: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("スクリーンショットから場所を読むのは、Travory Pro の機能です", systemImage: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(textColor)
                .fixedSize(horizontal: false, vertical: true)
            Text("お試しの\(PlaceScreenshotTrial.limit)回を使い終わりました。Pro なら、Instagram や TikTok のスクリーンショットから、何枚でも場所を読めます。"
                 + "下の「名前で探す」から保存するのは無料です。")
                .font(.system(size: 12))
                .foregroundColor(secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                showsProSheet = true
            } label: {
                Text("Travory Pro について")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ThemePreset.readableText(on: accent))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(accent))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(cardFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// お試しで読んだときの一言
    private func trialNote(_ remaining: Int) -> some View {
        Button {
            showsProSheet = true
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundColor(accent)
                Text(remaining > 0
                     ? "スクリーンショットからの読み取りは Pro の機能です。お試しで、あと\(remaining)回使えます。Pro なら何枚でも読めます。"
                     : "スクリーンショットからの読み取りは Pro の機能です。今回でお試しは終わりです。Pro なら何枚でも読めます。")
                    .font(.caption)
                    .foregroundColor(secondaryText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(secondaryText)
            }
            .padding(12)
            .background(cardFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    /// スクリーンショットから読めた文字。違う場所が出たときに、押して探し直す
    private var queryChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("読み取った文字（押すと、その言葉で探します）")
                .font(.caption.weight(.semibold))
                .foregroundColor(secondaryText)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(queries, id: \.self) { query in
                        Button {
                            Task { await searchAgain(query) }
                        } label: {
                            Text(query)
                                .font(.subheadline)
                                .foregroundColor(textColor)
                                .lineLimit(1)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(cardFill, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var searchField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("名前で探す")
                .font(.caption.weight(.semibold))
                .foregroundColor(secondaryText)
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(secondaryText)
                TextField("例：ブルーボトルコーヒー 清澄白河", text: $searchText)
                    .submitLabel(.search)
                    .onSubmit { Task { await searchAgain(searchText) } }
                if isSearching { ProgressView() }
            }
            .padding(12)
            .background(cardFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    // MARK: - 動き

    private func read() async {
        isReading = true
        let readsImages = decideScreenshotAccess()
        var found: [PlaceImportCandidate] = []
        var words: [String] = []
        for source in sources {
            switch source {
            case .text(let text):
                found += await PlaceImportReader.candidates(fromText: text)
            case .image(let image):
                guard readsImages, let cg = image.cgImage else { continue }
                let result = await PlaceImportReader.candidates(fromImage: cg)
                found += result.candidates
                words += result.queries
            }
        }
        var seen = Set<String>()
        candidates = found.filter { seen.insert($0.id).inserted }
        queries = Array(NSOrderedSet(array: words).array.compactMap { $0 as? String }.prefix(8))
        selectedID = candidates.first?.id
        isReading = false
    }

    /// スクリーンショットを読んでよいかを決める（お試しはここで1回使う）。
    /// Pro かどうかは、起動直後でも前回の結果から分かる（`ProStore.isPurchased`）
    private func decideScreenshotAccess() -> Bool {
        guard hasImages else {
            screenshotAccess = nil
            return false
        }
        if proStore.isPurchased {
            screenshotAccess = .pro
        } else if PlaceScreenshotTrial.consume() {
            screenshotAccess = .trial(remaining: PlaceScreenshotTrial.remaining())
        } else {
            screenshotAccess = .locked
        }
        return screenshotAccess != .locked
    }

    /// 言葉で探し直す。見つかったものを上に並べる
    private func searchAgain(_ query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSearching = true
        let found = await PlaceImportReader.search(trimmed, link: candidates.first?.linkURL)
        isSearching = false
        let newOnes = found.filter { candidate in !candidates.contains { $0.id == candidate.id } }
        withAnimation {
            candidates = newOnes + candidates
            selectedID = (found.first ?? newOnes.first)?.id ?? selectedID
            camera = .automatic
        }
    }

    /// 「行きたい場所」として保存する（訪問日なし）
    private func save(_ candidate: PlaceImportCandidate) {
        guard let userId = authVM.userId else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let link = candidate.linkURL.flatMap { URL(string: $0) }.map { PlaceLinkParser.isSocialPost($0) ? nil : $0.absoluteString } ?? nil
        places.add(VisitedPlace(title: candidate.name, latitude: candidate.latitude, longitude: candidate.longitude,
                                visitedAt: nil, address: candidate.address, linkURL: link,
                                categoryId: categoryManager.categories.contains { $0.id == candidate.categoryId }
                                    ? candidate.categoryId : (categoryManager.categories.first?.id ?? "other")),
                   userId: userId)
        withAnimation { _ = savedIDs.insert(candidate.id) }
    }
}

/// 共有メニューから「行きたい場所として送る」で届いたもの（3.5）。1件ずつ場所を探して保存してもらう。
/// 見終わった（「次へ」「完了」を押した・捨てた）ものは受け取り箱から消す。「あとで」は残す
struct SharedPlaceInboxView: View {
    @State var items: [SharedImportInbox.Item]
    @Environment(\.dismiss) private var dismiss

    private var current: SharedImportInbox.Item? { items.first }

    var body: some View {
        if let current {
            PlaceImportView(sources: [Self.source(of: current)].compactMap { $0 },
                            nextTitle: items.count > 1 ? "次へ（あと\(items.count - 1)件）" : "完了",
                            onNext: { finish(current) },
                            onDiscard: { finish(current) })
                .id(current.id)
        }
    }

    private func finish(_ item: SharedImportInbox.Item) {
        SharedImportInbox.remove(item)
        items.removeAll { $0.id == item.id }
        if items.isEmpty { dismiss() }
    }

    static func source(of item: SharedImportInbox.Item) -> PlaceImportView.Source? {
        switch item.content {
        case .text(let text): return .text(text)
        case .image(let url): return UIImage(contentsOfFile: url.path).map { .image($0) }
        }
    }
}
