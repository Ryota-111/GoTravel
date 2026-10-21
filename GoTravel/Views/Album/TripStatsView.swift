import SwiftUI
import Charts
import CoreLocation

/// 旅の記録（3.1・無料）。「思い出」タブの見出しの「記録」から開く。
///
/// 雑誌の特集ページのように組む：いちばん最近の旅の写真を大きく、数字は大きく細い書体で、
/// ラベルは小さな英字。枠や影は使わず、細い線と余白で区切る（`TripStats` で数える）。
/// 送るときは、ストーリーのように1ページずつの縦長のカード（`TripStatsStoryCard`）にする
struct TripStatsView: View {
    @EnvironmentObject private var travelPlanViewModel: TravelPlanViewModel
    @EnvironmentObject private var plansViewModel: PlansViewModel
    @EnvironmentObject private var authVM: AuthViewModel
    @StateObject private var placesVM = PlacesViewModel()
    @ObservedObject private var resolver = TripRegionResolver.shared
    @ObservedObject private var albumManager = AlbumManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var period: TripStats.Period = .all
    @State private var metric: Metric = .trips
    @State private var sharing = false

    enum Metric: String, CaseIterable, Identifiable {
        case trips, days, spend
        var id: String { rawValue }
        var label: String {
            switch self {
            case .trips: return "回数"
            case .days: return "日数"
            case .spend: return "金額"
            }
        }
    }

    private var now: Date { Date() }
    private var plans: [TravelPlan] { travelPlanViewModel.travelPlans }

    private var photoMapPrefectures: Set<Prefecture> {
        Set(albumManager.albums.filter(\.isJapanPhotoMap).flatMap(\.photoFileNames).compactMap(PhotoMapFiles.prefecture(of:)))
    }

    private var summary: TripStats.Summary {
        _ = resolver.version
        return TripStats.summary(plans: plans, places: placesVM.places, outings: plansViewModel.plans,
                                 photoMapPrefectures: photoMapPrefectures,
                                 region: { resolver.region($0, $1) }, period: period, now: now)
    }

    private var years: [Int] { TripStats.years(of: plans, now: now) }

    private var periodTitle: String {
        switch period {
        case .all: return "これまで全部"
        case .year(let year): return "\(String(year))年"
        }
    }

    /// 見出しに大きく出す英字（「2026」「ALL TIME」）
    private var periodMark: String {
        switch period {
        case .all: return "ALL TIME"
        case .year(let year): return String(year)
        }
    }

    // MARK: 色（テーマに合わせ、文字は読める濃さにする）

    private var ground: Color {
        colorScheme == .dark ? themeManager.currentTheme.backgroundDark : themeManager.currentTheme.backgroundLight
    }
    private var ink: Color { ThemePreset.readableText(on: ground) }
    private var faint: Color { ink.opacity(0.55) }
    private var rule: Color { ink.opacity(0.12) }
    private var accent: Color {
        ThemePreset.readableTintEitherWay(themeManager.currentTheme.primary, on: ground, minimum: 3.0)
    }

    private func plan(_ id: String?) -> TravelPlan? {
        guard let id else { return nil }
        return plans.first { $0.id == id }
    }

    var body: some View {
        let summary = summary
        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    hero(summary)
                    if summary.tripCount == 0 && summary.placeCount == 0 && summary.prefectures.isEmpty {
                        emptyState
                    } else {
                        Group {
                            numbers(summary)
                            hairline
                            mapSection(summary)
                            if period == .all { yearsSection }
                            bestSection(summary)
                            filmStrip(summary)
                            shareButton
                        }
                        .padding(.horizontal, 24)
                    }
                }
                .padding(.bottom, 40)
            }
            .ignoresSafeArea(edges: .top)
            .background(ground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.subheadline.weight(.semibold))
                    }
                    .accessibilityLabel("閉じる")
                }
                ToolbarItem(placement: .topBarTrailing) { periodMenu }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $sharing) {
                TripStatsShareSheet(summary: summary, periodMark: periodMark, periodTitle: periodTitle,
                                    heroPlan: plan(summary.tripIds.first), longestPlan: plan(summary.longestPlanId))
            }
            .task {
                if let userId = authVM.userId { placesVM.setupFetchedResultsController(userId: userId) }
            }
            // まだ調べていない場所の県を、少しずつ調べる（画面を閉じたら止まり、次に続きから）
            // 旅行の場所が増えたとき（目的地を引き直したときなど）にも、やり直す
            .task(id: lookupKey) {
                let filled = await fillMissingDestinations()
                // 引き直した場所は、旅行のデータの更新が届くのを待たずに、そのまま県を調べる
                await resolver.resolve(TripStats.lookupCoordinates(plans: TripStats.finishedTrips(plans, now: now)) + filled)
            }
        }
    }

    /// 県を調べ直すきっかけ。旅行・保存した場所の数と、場所の入った旅行の数
    private var lookupKey: String {
        let located = plans.filter { $0.latitude != nil && $0.longitude != nil }.count
        return "\(plans.count)|\(placesVM.places.count)|\(located)"
    }

    /// 目的地の場所が空のまま保存された旅行を、目的地の文字から補う（詳細を開いたときと同じ）。
    /// 詳細を開くまで場所が無く、その旅行の県が数えられていなかった。引き直した場所を返す
    private func fillMissingDestinations() async -> [(latitude: Double, longitude: Double)] {
        guard let userId = authVM.userId else { return [] }
        var filled: [(latitude: Double, longitude: Double)] = []
        for trip in TripStats.tripsMissingDestination(plans, now: now) {
            if Task.isCancelled { break }
            guard let coordinate = await DestinationGeocoder.coordinate(for: trip.destination, debounce: 0),
                  var latest = plans.first(where: { $0.id == trip.id }),
                  latest.latitude == nil || latest.longitude == nil else { continue }
            latest.latitude = coordinate.latitude
            latest.longitude = coordinate.longitude
            travelPlanViewModel.update(latest, userId: userId)
            filled.append((latitude: coordinate.latitude, longitude: coordinate.longitude))
        }
        return filled
    }

    private var periodMenu: some View {
        Menu {
            Picker("期間", selection: $period) {
                Text("これまで全部").tag(TripStats.Period.all)
                ForEach(years, id: \.self) { year in Text("\(String(year))年").tag(TripStats.Period.year(year)) }
            }
        } label: {
            HStack(spacing: 3) {
                Text(periodTitle)
                Image(systemName: "chevron.down").font(.caption2.weight(.bold))
            }
            .font(.subheadline.weight(.semibold))
        }
    }

    // MARK: - 表紙：いちばん最近の旅の写真

    private func hero(_ s: TripStats.Summary) -> some View {
        let cover = plan(s.tripIds.first).flatMap(TravelBookletRenderer.coverImage(for:))
        return ZStack(alignment: .bottomLeading) {
            Group {
                if let cover {
                    Image(uiImage: cover).resizable().scaledToFill()
                } else {
                    LinearGradient(colors: [accent.opacity(0.85), accent.opacity(0.45)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
            .frame(height: 360)
            .frame(maxWidth: .infinity)
            .clipped()
            LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 4) {
                Text(periodMark)
                    .font(.system(size: 54, weight: .thin).width(.condensed))
                Text("YOUR TRAVELS  ·  旅の記録")
                    .font(.system(size: 12, weight: .semibold).width(.expanded))
                    .opacity(0.85)
            }
            .foregroundColor(.white)
            .padding(24)
        }
        .frame(height: 360)
    }

    // MARK: - 数字

    private func numbers(_ s: TripStats.Summary) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top, spacing: 0) {
                figure("\(s.tripCount)", "TRIPS", "旅行")
                figure("\(s.dayCount)", "DAYS", "のべ日数")
                figure("\(s.prefectures.count)", "PREFECTURES", "都道府県")
            }
            VStack(spacing: 10) {
                if s.countries.count > 1 { detail("国と地域", "\(s.countries.count)") }
                detail("使った金額", TravelPlanTextExporter.currency(s.spend.rounded()))
                detail("保存した場所", "\(s.placeCount)か所")
                detail("おでかけ", "\(s.outingCount)回")
            }
        }
        .padding(.top, 28)
        .padding(.bottom, 24)
    }

    private func figure(_ value: String, _ label: String, _ japanese: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 52, weight: .thin).width(.condensed))
                .monospacedDigit()
                .foregroundColor(ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 10, weight: .semibold).width(.expanded))
                .foregroundColor(accent)
            Text(japanese).font(.caption2).foregroundColor(faint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func detail(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.footnote).foregroundColor(faint)
            Rectangle().fill(rule).frame(height: 1).padding(.horizontal, 8).offset(y: -3)
            Text(value).font(.subheadline.weight(.medium)).monospacedDigit().foregroundColor(ink)
        }
    }

    private var hairline: some View { Rectangle().fill(rule).frame(height: 1) }

    private func sectionMark(_ english: String, _ japanese: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(english).font(.system(size: 11, weight: .semibold).width(.expanded)).foregroundColor(accent)
            Text(japanese).font(.caption).foregroundColor(faint)
        }
    }

    // MARK: - 地図

    private func mapSection(_ s: TripStats.Summary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                sectionMark("JAPAN", "行った都道府県")
                Spacer()
                Text("\(s.prefectures.count)")
                    .font(.system(size: 28, weight: .thin).width(.condensed))
                    .foregroundColor(ink)
                Text("/ 47").font(.caption).foregroundColor(faint)
            }
            VisitedPrefectureMap(visited: s.prefectures, visitedColor: accent, otherColor: ink.opacity(0.08))
                .frame(height: 320)
            if resolver.remaining > 0 {
                Text("場所から県を調べています（あと\(resolver.remaining)か所）")
                    .font(.caption2)
                    .foregroundColor(faint)
            }
        }
        .padding(.vertical, 24)
    }

    // MARK: - 年ごと

    @ViewBuilder
    private var yearsSection: some View {
        let rows = TripStats.yearRows(plans: plans, now: now)
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                hairline
                HStack {
                    sectionMark("BY YEAR", "年ごと")
                    Spacer()
                    Picker("", selection: $metric) {
                        ForEach(Metric.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 168)
                }
                .padding(.top, 24)
                Chart(rows) { row in
                    BarMark(x: .value("年", String(row.year)), y: .value(metric.label, value(of: row)), width: 18)
                        .foregroundStyle(accent)
                        .clipShape(Capsule())
                        .annotation(position: .top) {
                            Text(valueText(of: row)).font(.caption2).foregroundColor(faint)
                        }
                }
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks { _ in AxisValueLabel().foregroundStyle(faint) }
                }
                .frame(height: 150)
                .padding(.bottom, 24)
            }
        }
    }

    private func value(of row: TripStats.YearRow) -> Double {
        switch metric {
        case .trips: return Double(row.trips)
        case .days: return Double(row.days)
        case .spend: return row.spend
        }
    }

    private func valueText(of row: TripStats.YearRow) -> String {
        switch metric {
        case .trips: return "\(row.trips)回"
        case .days: return "\(row.days)日"
        case .spend: return row.spend >= 10_000 ? "\(Int((row.spend / 10_000).rounded()))万" : "¥\(Int(row.spend))"
        }
    }

    // MARK: - いちばん

    @ViewBuilder
    private func bestSection(_ s: TripStats.Summary) -> some View {
        if s.longest != nil || s.mostSpent != nil || s.topPrefecture != nil || !s.busyMonths.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                hairline
                sectionMark("HIGHLIGHTS", "いちばん").padding(.top, 24)
                if let longest = s.longest {
                    best("いちばん長い旅", longest.title, "\(longest.days) DAYS", photo: plan(s.longestPlanId))
                }
                if let most = s.mostSpent {
                    best("いちばん使った旅", most.title, TravelPlanTextExporter.currency(most.amount.rounded()),
                         photo: plan(s.mostSpentPlanId))
                }
                if let top = s.topPrefecture {
                    best("よく行く県", top.prefecture.name, "\(top.trips) TRIPS", photo: nil)
                }
                if !s.busyMonths.isEmpty {
                    best("よく出かける月", s.busyMonths.map { "\($0)月" }.joined(separator: "・"), nil, photo: nil)
                }
            }
            .padding(.bottom, 24)
        }
    }

    private func best(_ caption: String, _ title: String, _ value: String?, photo: TravelPlan?) -> some View {
        HStack(spacing: 14) {
            Group {
                if let image = photo.flatMap(TravelBookletRenderer.coverImage(for:)) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    accent.opacity(0.15)
                        .overlay(Image(systemName: "sparkle").font(.footnote).foregroundColor(accent))
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(caption).font(.caption2).foregroundColor(faint)
                Text(title).font(.subheadline.weight(.semibold)).foregroundColor(ink).lineLimit(1)
            }
            Spacer(minLength: 8)
            if let value {
                Text(value)
                    .font(.system(size: 13, weight: .semibold).width(.expanded))
                    .monospacedDigit()
                    .foregroundColor(ink)
            }
        }
    }

    // MARK: - 写真の帯

    @ViewBuilder
    private func filmStrip(_ s: TripStats.Summary) -> some View {
        let trips = s.tripIds.compactMap(plan)
        let withPhotos = trips.compactMap { trip in TravelBookletRenderer.coverImage(for: trip).map { (trip, $0) } }
        if !withPhotos.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                hairline
                sectionMark("JOURNAL", "旅の写真").padding(.top, 24)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(withPhotos.prefix(20), id: \.0.id) { trip, image in
                            VStack(alignment: .leading, spacing: 6) {
                                Image(uiImage: image).resizable().scaledToFill()
                                    .frame(width: 120, height: 160)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                Text(trip.title).font(.caption.weight(.semibold)).foregroundColor(ink).lineLimit(1)
                                Text(DigestDateStyle.month(trip.startDate) + " " + String(Calendar.current.component(.year, from: trip.startDate)))
                                    .font(.system(size: 9, weight: .semibold).width(.expanded))
                                    .foregroundColor(faint)
                            }
                            .frame(width: 120)
                        }
                    }
                }
                .scrollClipDisabled()
            }
            .padding(.bottom, 28)
        }
    }

    // MARK: - 送る

    private var shareButton: some View {
        Button { sharing = true } label: {
            HStack {
                Text(period == .all ? "これまでの旅をカードにして送る" : "\(periodTitle)の旅をカードにして送る")
                Spacer()
                Image(systemName: "arrow.up.right")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(ThemePreset.readableText(on: ink))
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Capsule().fill(ink))
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("終わった旅行がまだありません").font(.headline).foregroundColor(ink)
            Text("旅行計画の日付が過ぎると、ここに回数や行った都道府県が出ます。")
                .font(.footnote)
                .foregroundColor(faint)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 24)
    }
}

/// 行った県を塗った日本地図（フォトマップと同じ県の形を使う）
struct VisitedPrefectureMap: View {
    let visited: Set<Prefecture>
    var visitedColor: Color = .accentColor
    var otherColor: Color = Color.primary.opacity(0.12)

    /// フォトマップの県の位置は 370 × 600 の中で決めてある
    private static let canvas = CGSize(width: 370, height: 600)

    /// 47都道府県がちょうど入る四角（370 × 600 の中）
    private static let bounds: CGRect = Prefecture.allCases.reduce(CGRect.null) { rect, prefecture in
        let center = CGPoint(x: canvas.width * prefecture.mapPosition.x, y: canvas.height * prefecture.mapPosition.y)
        let size = prefecture.mapSize
        return rect.union(CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2,
                                 width: size.width, height: size.height))
    }

    var body: some View {
        GeometryReader { geo in
            let box = Self.bounds
            let scale = min(geo.size.width / box.width, geo.size.height / box.height)
            // 真ん中に寄せる
            let dx = (geo.size.width - box.width * scale) / 2
            let dy = (geo.size.height - box.height * scale) / 2
            ZStack(alignment: .topLeading) {
                ForEach(Prefecture.allCases) { prefecture in
                    cell(prefecture, scale: scale)
                        .position(x: dx + (Self.canvas.width * prefecture.mapPosition.x - box.minX) * scale,
                                  y: dy + (Self.canvas.height * prefecture.mapPosition.y - box.minY) * scale)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("行った都道府県：\(visited.map(\.name).sorted().joined(separator: "、"))")
    }

    @ViewBuilder
    private func cell(_ prefecture: Prefecture, scale: CGFloat) -> some View {
        let color = visited.contains(prefecture) ? visitedColor : otherColor
        let size = prefecture.mapSize
        Group {
            if let mask = prefecture.maskImage {
                Image(uiImage: mask).renderingMode(.template).resizable().aspectRatio(contentMode: .fit)
                    .foregroundColor(color)
            } else {
                prefecture.shape.fill(color)
            }
        }
        .frame(width: size.width * scale, height: size.height * scale)
    }
}

// MARK: - 送るカード（ストーリーのように1ページずつ）

/// 縦長（1080 × 1920）のカード。3ページ：数字・地図・いちばん長い旅
struct TripStatsStoryCard: View {
    enum Page: Int, CaseIterable, Identifiable {
        case numbers, map, longest
        var id: Int { rawValue }
    }

    let page: Page
    let summary: TripStats.Summary
    let periodMark: String
    let heroImage: UIImage?
    let longestImage: UIImage?

    var body: some View {
        ZStack {
            background
            VStack(alignment: .leading, spacing: 0) {
                Text(periodMark)
                    .font(.system(size: 120, weight: .thin).width(.condensed))
                Text("YOUR TRAVELS")
                    .font(.system(size: 30, weight: .semibold).width(.expanded))
                    .opacity(0.8)
                Spacer()
                content
                Spacer()
                Text("Travory")
                    .font(.system(size: 34, weight: .semibold))
                    .opacity(0.6)
            }
            .foregroundColor(.white)
            .padding(90)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 1080, height: 1920)
    }

    @ViewBuilder
    private var background: some View {
        let image = page == .longest ? (longestImage ?? heroImage) : heroImage
        if let image, page != .map {
            Image(uiImage: image).resizable().scaledToFill().frame(width: 1080, height: 1920).clipped()
            // 白い文字が写真に負けないよう、全体を暗くし、上下はさらに暗くする
            Color.black.opacity(0.35)
            LinearGradient(colors: [.black.opacity(0.4), .clear, .black.opacity(0.6)],
                           startPoint: .top, endPoint: .bottom)
        } else {
            Color(red: 0.11, green: 0.10, blue: 0.09)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch page {
        case .numbers:
            VStack(alignment: .leading, spacing: 64) {
                figure("\(summary.tripCount)", "TRIPS")
                figure("\(summary.dayCount)", "DAYS")
                figure("\(summary.prefectures.count)", "PREFECTURES")
            }
        case .map:
            VStack(alignment: .leading, spacing: 30) {
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    Text("\(summary.prefectures.count)").font(.system(size: 160, weight: .thin).width(.condensed))
                    Text("/ 47").font(.system(size: 50, weight: .light)).opacity(0.7)
                }
                VisitedPrefectureMap(visited: summary.prefectures, visitedColor: Color(red: 0.84, green: 0.68, blue: 0.52),
                                     otherColor: .white.opacity(0.14))
                    .frame(width: 900, height: 900)
            }
        case .longest:
            VStack(alignment: .leading, spacing: 20) {
                Text("いちばん長い旅").font(.system(size: 44, weight: .medium)).opacity(0.85)
                Text(summary.longest?.title ?? "").font(.system(size: 100, weight: .bold)).lineLimit(2)
                    .minimumScaleFactor(0.5)
                Text("\(summary.longest?.days ?? 0) DAYS")
                    .font(.system(size: 60, weight: .semibold).width(.expanded))
            }
        }
    }

    private func figure(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(value).font(.system(size: 190, weight: .thin).width(.condensed)).monospacedDigit()
                .fixedSize()
            Text(label).font(.system(size: 34, weight: .semibold).width(.expanded)).opacity(0.85)
        }
    }
}

/// カードを1ページずつめくって見て、そのページを送る・保存する
private struct TripStatsShareSheet: View {
    let summary: TripStats.Summary
    let periodMark: String
    let periodTitle: String
    let heroPlan: TravelPlan?
    let longestPlan: TravelPlan?

    @Environment(\.dismiss) private var dismiss
    @State private var page: TripStatsStoryCard.Page = .numbers
    @State private var images: [TripStatsStoryCard.Page: UIImage] = [:]

    private var pages: [TripStatsStoryCard.Page] {
        TripStatsStoryCard.Page.allCases.filter { $0 != .longest || summary.longest != nil }
    }

    var body: some View {
        NavigationStack {
            TabView(selection: $page) {
                ForEach(pages) { page in
                    Group {
                        if let image = images[page] {
                            Image(uiImage: image).resizable().scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        } else {
                            ProgressView()
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
                    .tag(page)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("\(periodTitle)の旅")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if let image = images[page] {
                        ShareLink(item: Image(uiImage: image),
                                  preview: SharePreview("\(periodTitle)の旅", image: Image(uiImage: image))) {
                            Label("送る・保存", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
            .task { render() }
        }
    }

    private func render() {
        let hero = heroPlan.flatMap(TravelBookletRenderer.coverImage(for:))?.downscaled(maxPixel: 1920)
        let longest = longestPlan.flatMap(TravelBookletRenderer.coverImage(for:))?.downscaled(maxPixel: 1920)
        for page in pages {
            let renderer = ImageRenderer(content: TripStatsStoryCard(page: page, summary: summary, periodMark: periodMark,
                                                                     heroImage: hero, longestImage: longest))
            renderer.scale = 1
            images[page] = renderer.uiImage
        }
    }
}
