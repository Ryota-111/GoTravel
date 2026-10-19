import SwiftUI
import Charts

/// 旅の記録（3.1・無料）。「思い出」タブの上から開く。
///
/// 旅行の回数・のべ日数・行った都道府県と国・使った金額などを、年ごとか「これまで全部」で数える（`TripStats`）。
/// 費用の画面と同じく、色のグラデーションや影は使わず、数字を主役に細い線で区切る。
/// 最後に「今年の旅」を縦長のカードにして送れる
struct TripStatsView: View {
    @EnvironmentObject private var travelPlanViewModel: TravelPlanViewModel
    @EnvironmentObject private var plansViewModel: PlansViewModel
    @EnvironmentObject private var authVM: AuthViewModel
    @StateObject private var placesVM = PlacesViewModel()
    @ObservedObject private var resolver = TripRegionResolver.shared
    @ObservedObject private var albumManager = AlbumManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var period: TripStats.Period = .all
    @State private var metric: Metric = .trips
    @State private var shareCard: ShareCard?

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

    struct ShareCard: Identifiable {
        let image: UIImage
        let title: String
        var id: String { title }
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
        case .year(let year): return "\(year)年"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    let summary = summary
                    if summary.tripCount == 0 && summary.placeCount == 0 && summary.prefectures.isEmpty {
                        emptyState
                    } else {
                        totals(summary)
                        mapSection(summary)
                        if period == .all { yearsSection }
                        bestSection(summary)
                        shareButton(summary)
                    }
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("旅の記録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { periodMenu }
            }
            .sheet(item: $shareCard) { card in ShareCardSheet(card: card) }
            .task {
                if let userId = authVM.userId { placesVM.setupFetchedResultsController(userId: userId) }
            }
            // まだ調べていない場所の県を、少しずつ調べる（画面を閉じたら止まり、次に続きから）
            .task(id: placesVM.places.count + plans.count) {
                await resolver.resolve(TripStats.lookupCoordinates(plans: TripStats.finishedTrips(plans, now: now),
                                                                   places: placesVM.places))
            }
        }
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

    // MARK: - 数字

    private func totals(_ s: TripStats.Summary) -> some View {
        paper {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline, spacing: 18) {
                    bigNumber("\(s.tripCount)", unit: "回", label: "旅行")
                    bigNumber("\(s.dayCount)", unit: "日", label: "のべ")
                    Spacer(minLength: 0)
                }
                HStack(alignment: .firstTextBaseline, spacing: 18) {
                    bigNumber("\(s.prefectures.count)", unit: "都道府県", label: "行った")
                    bigNumber("\(s.countries.count)", unit: "か国", label: "国")
                    Spacer(minLength: 0)
                }
                Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 1)
                line("使った金額", value: TravelPlanTextExporter.currency(s.spend.rounded()))
                line("保存した場所", value: "\(s.placeCount)か所")
                line("おでかけ", value: "\(s.outingCount)回")
            }
        }
    }

    private func bigNumber(_ value: String, unit: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundColor(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value).font(.system(size: 34, weight: .semibold)).monospacedDigit()
                Text(unit).font(.subheadline).foregroundColor(.secondary)
            }
        }
    }

    private func line(_ title: String, value: String) -> some View {
        HStack {
            Text(title).font(.subheadline).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.subheadline.weight(.semibold)).monospacedDigit()
        }
    }

    // MARK: - 地図

    private func mapSection(_ s: TripStats.Summary) -> some View {
        paper {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    sectionTitle("行った都道府県")
                    Spacer()
                    Text("\(s.prefectures.count) / 47").font(.subheadline.weight(.semibold)).monospacedDigit()
                }
                VisitedPrefectureMap(visited: s.prefectures)
                    .frame(height: 300)
                if resolver.remaining > 0 {
                    Label("場所から県を調べています（あと\(resolver.remaining)か所）", systemImage: "hourglass")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - 年ごと

    private var yearsSection: some View {
        let rows = TripStats.yearRows(plans: plans, now: now)
        return Group {
            if rows.count >= 1 {
                paper {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            sectionTitle("年ごと")
                            Spacer()
                            Picker("", selection: $metric) {
                                ForEach(Metric.allCases) { Text($0.label).tag($0) }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 180)
                        }
                        Chart(rows) { row in
                            BarMark(x: .value("年", String(row.year)), y: .value(metric.label, value(of: row)))
                                .foregroundStyle(Color.accentColor.gradient)
                                .annotation(position: .top) {
                                    Text(valueText(of: row)).font(.caption2).foregroundColor(.secondary)
                                }
                        }
                        .chartYAxis(.hidden)
                        .frame(height: 160)
                    }
                }
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
            paper {
                VStack(alignment: .leading, spacing: 12) {
                    sectionTitle("いちばん")
                    if let longest = s.longest {
                        line("長い旅", value: "\(longest.title)  \(longest.days)日")
                    }
                    if let most = s.mostSpent {
                        line("使った旅", value: "\(most.title)  \(TravelPlanTextExporter.currency(most.amount.rounded()))")
                    }
                    if let top = s.topPrefecture {
                        line("よく行く県", value: "\(top.prefecture.name)  \(top.trips)回")
                    }
                    if !s.busyMonths.isEmpty {
                        line("よく出かける月", value: s.busyMonths.map { "\($0)月" }.joined(separator: "・"))
                    }
                }
            }
        }
    }

    // MARK: - カード

    private func shareButton(_ s: TripStats.Summary) -> some View {
        Button {
            let title = period == .all ? "これまでの旅" : "\(periodTitle)の旅"
            let renderer = ImageRenderer(content: TripStatsCard(title: title, summary: s))
            renderer.scale = 1
            if let image = renderer.uiImage { shareCard = ShareCard(image: image, title: title) }
        } label: {
            Label(period == .all ? "これまでの旅をカードにして送る" : "\(periodTitle)の旅をカードにして送る",
                  systemImage: "square.and.arrow.up")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.accentColor.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .foregroundColor(.accentColor)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "airplane.departure").font(.system(size: 40)).foregroundColor(.secondary)
            Text("終わった旅行がまだありません").font(.headline)
            Text("旅行計画の日付が過ぎると、ここに回数や行った都道府県が出ます。")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(.footnote.weight(.semibold)).foregroundColor(.secondary)
    }

    private func paper<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.primary.opacity(0.06), lineWidth: 1))
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

/// SNS に載せやすい縦長のカード（1080 × 1350）
struct TripStatsCard: View {
    let title: String
    let summary: TripStats.Summary

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 64, weight: .bold))
            Text("Travory").font(.system(size: 30, weight: .semibold)).opacity(0.55).padding(.top, 6)
            Spacer(minLength: 40)
            HStack(alignment: .top, spacing: 60) {
                VStack(alignment: .leading, spacing: 40) {
                    stat("\(summary.tripCount)", "回", "旅行")
                    stat("\(summary.dayCount)", "日", "のべ")
                    stat("\(summary.prefectures.count)", "都道府県", "行った")
                    if summary.countries.count > 1 { stat("\(summary.countries.count)", "か国", "国") }
                }
                VisitedPrefectureMap(visited: summary.prefectures, visitedColor: .white,
                                     otherColor: .white.opacity(0.18))
                    .frame(width: 420, height: 640)
            }
            Spacer(minLength: 40)
            if let longest = summary.longest {
                Text("いちばん長い旅　\(longest.title) \(longest.days)日")
                    .font(.system(size: 34, weight: .medium))
                    .opacity(0.85)
            }
        }
        .foregroundColor(.white)
        .padding(80)
        .frame(width: 1080, height: 1350, alignment: .topLeading)
        .background(LinearGradient(colors: [Color(red: 0.12, green: 0.36, blue: 0.62), Color(red: 0.05, green: 0.16, blue: 0.32)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing))
    }

    private func stat(_ value: String, _ unit: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 30, weight: .medium)).opacity(0.7)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(value).font(.system(size: 96, weight: .bold)).monospacedDigit()
                Text(unit).font(.system(size: 34, weight: .semibold)).opacity(0.8)
            }
        }
    }
}

/// できたカードを見て、送る・保存する
private struct ShareCardSheet: View {
    let card: TripStatsView.ShareCard
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Image(uiImage: card.image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground).ignoresSafeArea())
                .navigationTitle(card.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        ShareLink(item: Image(uiImage: card.image),
                                  preview: SharePreview(card.title, image: Image(uiImage: card.image))) {
                            Label("送る・保存", systemImage: "square.and.arrow.up")
                        }
                    }
                }
        }
    }
}
