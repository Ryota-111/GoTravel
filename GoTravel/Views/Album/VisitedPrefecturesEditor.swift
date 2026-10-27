import SwiftUI

/// 旅の記録の「＋ 行った県を足す」。アプリを使う前に行った県を、地方ごとの一覧から足す（3.1）。
///
/// 県を押して行った年を選ぶと、その県が行った県になる（何年でも）。旅行の回数や日数には数えない
struct VisitedPrefecturesEditor: View {
    @ObservedObject private var store = VisitedPrefectureStore.shared
    @ObservedObject private var albumManager = AlbumManager.shared
    @Environment(\.dismiss) private var dismiss

    /// 地方の区切り（`Prefecture` は北から順に並んでいる）
    static let regions: [(name: String, prefectures: [Prefecture])] = {
        let all = Prefecture.allCases
        return [("北海道・東北", Array(all[0..<7])), ("関東", Array(all[7..<14])), ("中部", Array(all[14..<23])),
                ("近畿", Array(all[23..<30])), ("中国・四国", Array(all[30..<39])), ("九州・沖縄", Array(all[39..<47]))]
    }()

    private var thisYear: Int { Calendar.current.component(.year, from: Date()) }
    private var yearChoices: [Int] { Array((1960...thisYear).reversed()) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Travory を使う前に行った県も足せます。県を押して行った年を選ぶと、都道府県の数と地図、その年の記録に入ります（旅行の回数や日数には入りません）。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    // 写真に残っている場所から、行った県と年をまとめて足す（写真はフォトマップに入れない）
                    NavigationLink {
                        VisitedPrefectureScanList()
                    } label: {
                        Label("写真から探す", systemImage: "sparkle.magnifyingglass")
                            .font(.body.weight(.semibold))
                    }
                }
                ForEach(Self.regions, id: \.name) { region in
                    Section(region.name) {
                        ForEach(region.prefectures) { prefecture in
                            row(prefecture)
                        }
                    }
                }
            }
            .navigationTitle("行った県を足す")
            // もうフォトマップに写真がある県を、年は分からない行った県として付けておく（初めの1回だけ）
            .onAppear {
                store.importPhotoMapOnce(Set(albumManager.albums.filter(\.isJapanPhotoMap)
                    .flatMap(\.photoFileNames).compactMap(PhotoMapFiles.prefecture(of:))))
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }

    /// 1県。押すと行った年を選ぶメニューが開き、年を選ぶとその県が行った県になる（チェックだけ付ける操作は無い）。
    /// 年を全部外すと行った県から外れる。以前に年なしで足した県は「年は分からない」と出し、外せるようにする
    private func row(_ prefecture: Prefecture) -> some View {
        let years = store.records[prefecture]
        return Menu {
            if let years {
                Section("外す") {
                    ForEach(years.sorted(by: >), id: \.self) { year in
                        Button("\(String(year))年を外す", systemImage: "minus.circle") {
                            store.undo(prefecture, years: [year])
                        }
                    }
                    if years.isEmpty {
                        Button("行った県から外す", systemImage: "minus.circle", role: .destructive) {
                            store.remove(prefecture)
                        }
                    }
                }
            }
            Section("行った年を足す") {
                ForEach(yearChoices.filter { !(years ?? []).contains($0) }, id: \.self) { year in
                    Button("\(String(year))年") { store.add(prefecture, years: [year]) }
                }
            }
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(prefecture.name).foregroundColor(.primary)
                    if let years {
                        Text(years.isEmpty ? "年は分からない" : years.sorted().map { "\($0)年" }.joined(separator: "・"))
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                }
                Spacer()
                Image(systemName: years == nil ? "plus.circle" : "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(years == nil ? .secondary : .accentColor)
            }
            .contentShape(Rectangle())
        }
        .accessibilityLabel(years == nil ? "\(prefecture.name)、行った年を足す"
                                         : "\(prefecture.name)、行った年を変える")
    }
}

/// 「行った県を足す」→「写真から探す」。写真に残っている場所から、行った県と年の候補を出し、
/// 押すと写真は入れずに、行った県と年として足す（もう一度押すと取り消す）。写真はこの iPhone の中だけで調べる
struct VisitedPrefectureScanList: View {
    @StateObject private var scanner = PhotoPrefectureScanner()
    @ObservedObject private var resolver = TripRegionResolver.shared
    @ObservedObject private var store = VisitedPrefectureStore.shared
    @Environment(\.openURL) private var openURL

    private var candidates: [PhotoPrefectureScan.Candidate] {
        _ = resolver.version
        return PhotoPrefectureScan.candidates(of: scanner.photos, region: { resolver.region($0, $1) })
    }

    private func isRecorded(_ candidate: PhotoPrefectureScan.Candidate) -> Bool {
        store.records[candidate.prefecture].map { Set(candidate.years).isSubset(of: $0) } ?? false
    }

    var body: some View {
        Group {
            switch scanner.phase {
            case .loading:
                ProgressView("写真を読んでいます")
            case .noAccess:
                VStack(spacing: 14) {
                    Text("写真の場所から県を探すため、写真へのアクセスを許可してください。")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    Button("設定を開く") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(32)
            case .ready:
                list
            }
        }
        .navigationTitle("写真から探す")
        .navigationBarTitleDisplayMode(.inline)
        .task { await scanner.start() }
    }

    private var list: some View {
        List {
            Section {
                Text("写真に残っている場所から、行った県と年を見つけます。押すと行った県として足します（写真はフォトマップに入れません）。写真はこの iPhone の中だけで調べます。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                if resolver.remaining > 0 {
                    Label("県を調べています（あと\(resolver.remaining)か所）", systemImage: "hourglass")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                let notYet = candidates.filter { !isRecorded($0) }
                if notYet.count > 1 {
                    Button("見つかった県をまとめて足す（\(notYet.count)県）") {
                        for candidate in notYet { store.add(candidate.prefecture, years: Set(candidate.years)) }
                    }
                    .font(.footnote.weight(.semibold))
                }
            }
            if candidates.isEmpty && resolver.remaining == 0 {
                Text("場所の残っている写真が見つかりませんでした。").foregroundColor(.secondary)
            }
            ForEach(candidates) { candidate in
                row(candidate)
            }
        }
    }

    private func row(_ candidate: PhotoPrefectureScan.Candidate) -> some View {
        let recorded = isRecorded(candidate)
        return HStack(spacing: 12) {
            AssetThumbnail(localIdentifier: candidate.photos.first?.id)
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(candidate.prefecture.name).font(.body.weight(.semibold))
                Text("\(candidate.photos.count)枚・\(PhotoPrefectureScan.yearsText(candidate.years))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer(minLength: 4)
            // もう一度押すと取り消せる
            Button {
                if recorded {
                    store.undo(candidate.prefecture, years: Set(candidate.years))
                } else {
                    store.add(candidate.prefecture, years: Set(candidate.years))
                }
            } label: {
                Label(recorded ? "行った" : "足す", systemImage: recorded ? "checkmark" : "plus")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(recorded ? .white : .accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(recorded ? Color.accentColor : Color.clear))
                    .overlay(Capsule().stroke(Color.accentColor.opacity(0.5), lineWidth: recorded ? 0 : 1))
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(recorded ? "\(candidate.prefecture.name)の「行った」を取り消す"
                                         : "\(candidate.prefecture.name)を行った県に足す")
        }
    }
}
