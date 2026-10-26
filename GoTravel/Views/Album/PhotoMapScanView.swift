import SwiftUI
import Photos
import Combine

// MARK: - フォトマップの「カメラロールから自動追加」（3.1・Travory Pro）
//
// 場所の残っている写真から、行った県と年の候補を出す。県を押すとその県の写真が並び、選んでフォトマップに入れられる。
// 写真を入れた県は、撮った年で旅の記録の行った県にも足す。写真を入れずに行った県だけ記録するのは、
// 旅の記録の「行った県を足す」→「写真から探す」（`VisitedPrefectureScanList`）の役目
// 写真は端末の中だけで調べ、どこにも送らない。県は約10km 四方ごとにまとめて調べる（`TripRegionResolver`）

enum PhotoPrefectureScan {
    struct Photo: Equatable, Sendable {
        var id: String
        var date: Date
        var latitude: Double
        var longitude: Double
    }

    struct Candidate: Identifiable, Equatable {
        var prefecture: Prefecture
        /// 新しい順
        var photos: [Photo]
        /// 写真を撮った年（古い順）
        var years: [Int]
        var id: String { prefecture.rawValue }
    }

    /// 約10km 四方のまとまりの真ん中。県はこの点で調べる（調べる回数を減らすため）
    static func cell(_ latitude: Double, _ longitude: Double) -> (latitude: Double, longitude: Double) {
        ((latitude * 10).rounded() / 10, (longitude * 10).rounded() / 10)
    }

    /// 調べる点。写真の多いまとまりから先に調べる（候補が早く出るように）
    static func cells(of photos: [Photo]) -> [(latitude: Double, longitude: Double)] {
        var counts: [String: (point: (latitude: Double, longitude: Double), count: Int)] = [:]
        for photo in photos {
            let point = cell(photo.latitude, photo.longitude)
            let key = "\(point.latitude)_\(point.longitude)"
            counts[key, default: (point, 0)].count += 1
        }
        return counts.values.sorted { $0.count > $1.count }.map(\.point)
    }

    /// 県ごとの候補（写真の多い順）。県がまだ分からない写真は入れない
    static func candidates(of photos: [Photo], region: (Double, Double) -> TripRegion?,
                           calendar: Calendar = .current) -> [Candidate] {
        var byPrefecture: [Prefecture: [Photo]] = [:]
        for photo in photos {
            let point = cell(photo.latitude, photo.longitude)
            guard let prefecture = region(point.latitude, point.longitude)?.prefecture else { continue }
            byPrefecture[prefecture, default: []].append(photo)
        }
        return byPrefecture.map { prefecture, list in
            let sorted = list.sorted { $0.date > $1.date }
            let years = Set(sorted.map { calendar.component(.year, from: $0.date) }).sorted()
            return Candidate(prefecture: prefecture, photos: sorted, years: years)
        }
        .sorted { $0.photos.count != $1.photos.count ? $0.photos.count > $1.photos.count
                                                       : $0.prefecture.rawValue < $1.prefecture.rawValue }
    }

    /// 「2019年」「2019〜2023年」
    static func yearsText(_ years: [Int]) -> String {
        guard let first = years.first, let last = years.last else { return "" }
        return first == last ? "\(first)年" : "\(first)〜\(last)年"
    }
}

/// カメラロールの写真を読む（場所のある写真だけ）
@MainActor
final class PhotoPrefectureScanner: ObservableObject {
    enum Phase { case loading, noAccess, ready }

    @Published private(set) var phase: Phase = .loading
    @Published private(set) var photos: [PhotoPrefectureScan.Photo] = []

    func start() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else {
            phase = .noAccess
            return
        }
        photos = await Task.detached(priority: .userInitiated) { () -> [PhotoPrefectureScan.Photo] in
            let options = PHFetchOptions()
            options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            var result: [PhotoPrefectureScan.Photo] = []
            PHAsset.fetchAssets(with: options).enumerateObjects { asset, _, _ in
                guard let location = asset.location, let date = asset.creationDate,
                      !asset.mediaSubtypes.contains(.photoScreenshot) else { return }
                result.append(.init(id: asset.localIdentifier, date: date,
                                    latitude: location.coordinate.latitude, longitude: location.coordinate.longitude))
            }
            return result
        }.value
        phase = .ready
        // 県を少しずつ調べる（調べた分から候補に出る。閉じたら止まり、次に開いたとき続きから）
        await TripRegionResolver.shared.resolve(PhotoPrefectureScan.cells(of: photos))
    }
}

/// 候補の一覧
struct PhotoMapScanView: View {
    let albumId: String

    @StateObject private var scanner = PhotoPrefectureScanner()
    @ObservedObject private var resolver = TripRegionResolver.shared
    @ObservedObject private var albumManager = AlbumManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private var mapFileNames: [String] {
        albumManager.albums.first { $0.id == albumId }?.photoFileNames ?? []
    }

    private var candidates: [PhotoPrefectureScan.Candidate] {
        _ = resolver.version
        let filled = Set(mapFileNames.compactMap(PhotoMapFiles.prefecture(of:)))
        // まだ写真の無い県を上に
        return PhotoPrefectureScan.candidates(of: scanner.photos, region: { resolver.region($0, $1) })
            .sorted { (filled.contains($0.prefecture) ? 1 : 0) < (filled.contains($1.prefecture) ? 1 : 0) }
    }

    var body: some View {
        NavigationStack {
            Group {
                switch scanner.phase {
                case .loading:
                    ProgressView("写真を読んでいます")
                case .noAccess:
                    noAccess
                case .ready:
                    list
                }
            }
            .navigationTitle("カメラロールから自動追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }.fontWeight(.semibold)
                }
            }
            .task { await scanner.start() }
        }
    }

    private var list: some View {
        let mapCounts = PhotoMapFiles.grouped(mapFileNames).mapValues(\.count)
        return List {
            Section {
                Text("写真に残っている場所から、行った県を探します。写真はこの iPhone の中だけで調べ、どこにも送りません。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                if resolver.remaining > 0 {
                    Label("県を調べています（あと\(resolver.remaining)か所）", systemImage: "hourglass")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            if candidates.isEmpty && resolver.remaining == 0 {
                Text("場所の残っている写真が見つかりませんでした。")
                    .foregroundColor(.secondary)
            }
            let notYet = candidates.filter { (mapCounts[$0.prefecture] ?? 0) == 0 }
            let already = candidates.filter { (mapCounts[$0.prefecture] ?? 0) > 0 }
            if !notYet.isEmpty {
                Section("まだフォトマップに写真が無い県（\(notYet.count)）") {
                    ForEach(notYet) { candidate in candidateLink(candidate, inMap: 0) }
                }
            }
            if !already.isEmpty {
                Section("もうフォトマップに写真がある県（\(already.count)）") {
                    ForEach(already) { candidate in
                        candidateLink(candidate, inMap: mapCounts[candidate.prefecture] ?? 0)
                    }
                }
            }
        }
    }

    private func candidateLink(_ candidate: PhotoPrefectureScan.Candidate, inMap: Int) -> some View {
        NavigationLink {
            PhotoMapScanPrefectureView(albumId: albumId, candidate: candidate)
        } label: {
            row(candidate, inMap: inMap)
        }
    }

    /// - Parameter inMap: その県で、もうフォトマップに入っている写真の枚数
    private func row(_ candidate: PhotoPrefectureScan.Candidate, inMap: Int) -> some View {
        HStack(spacing: 12) {
            AssetThumbnail(localIdentifier: candidate.photos.first?.id)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                // もうフォトマップに写真がある県は、見本の右下に印を付ける
                .overlay(alignment: .bottomTrailing) {
                    if inMap > 0 {
                        Image(systemName: "map.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(Color.accentColor))
                            .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                            .offset(x: 4, y: 4)
                    }
                }
            VStack(alignment: .leading, spacing: 3) {
                Text(candidate.prefecture.name).font(.body.weight(.semibold))
                Text("\(candidate.photos.count)枚・\(PhotoPrefectureScan.yearsText(candidate.years))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if inMap > 0 {
                    Label("フォトマップに\(inMap)枚あり", systemImage: "map.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.accentColor)
                }
            }
            Spacer(minLength: 4)
        }
    }

    private var noAccess: some View {
        VStack(spacing: 14) {
            Image(systemName: "photo.on.rectangle.angled").font(.system(size: 40)).foregroundColor(.secondary)
            Text("写真の場所から県を探すため、写真へのアクセスを許可してください。")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Button("設定を開く") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
    }
}

/// ある県の写真。選んでフォトマップに入れる
private struct PhotoMapScanPrefectureView: View {
    let albumId: String
    let candidate: PhotoPrefectureScan.Candidate

    @ObservedObject private var albumManager = AlbumManager.shared
    @ObservedObject private var visited = VisitedPrefectureStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selected: [String] = []
    @State private var isAdding = false

    private var remaining: Int {
        PhotoMapFiles.remainingSlots(for: candidate.prefecture,
                                     in: albumManager.albums.first { $0.id == albumId }?.photoFileNames ?? [])
    }

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 3)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                // 未購入のときだけ出る
                DeviceOnlyPhotoNote()
                Text("フォトマップに入れる写真を選んでください（あと\(remaining)枚まで）。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                // 年ごとに区切る。同じ県でも年が違えば別の旅行だと分かり、旅の記録でもその年ごとに入る
                LazyVGrid(columns: columns, spacing: 3, pinnedViews: [.sectionHeaders]) {
                    ForEach(photosByYear, id: \.year) { group in
                        Section {
                            ForEach(group.photos, id: \.id) { photo in
                                cell(photo)
                            }
                        } header: {
                            yearHeader(group.year, count: group.photos.count)
                        }
                    }
                }
            }
            .padding(12)
        }
        .navigationTitle("\(candidate.prefecture.name)・\(candidate.photos.count)枚")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if !selected.isEmpty {
                Button {
                    Task { await addSelected() }
                } label: {
                    HStack {
                        if isAdding { ProgressView().tint(.white) }
                        Text(isAdding ? "入れています…" : "\(selected.count)枚をフォトマップに入れる")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.accentColor))
                }
                .disabled(isAdding)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
    }

    /// 撮った年ごと（新しい年から）
    private var photosByYear: [(year: Int, photos: [PhotoPrefectureScan.Photo])] {
        let calendar = Calendar.current
        return Dictionary(grouping: candidate.photos) { calendar.component(.year, from: $0.date) }
            .sorted { $0.key > $1.key }
            .map { (year: $0.key, photos: $0.value) }
    }

    private func yearHeader(_ year: Int, count: Int) -> some View {
        let chosen = candidate.photos.filter { selected.contains($0.id)
            && Calendar.current.component(.year, from: $0.date) == year }.count
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(String(year))年").font(.headline)
            Text("\(count)枚").font(.caption).foregroundColor(.secondary)
            Spacer()
            if chosen > 0 {
                Text("\(chosen)枚選択").font(.caption.weight(.semibold)).foregroundColor(.accentColor)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
    }

    private func cell(_ photo: PhotoPrefectureScan.Photo) -> some View {
        let order = selected.firstIndex(of: photo.id)
        return Button {
            if let order { selected.remove(at: order) } else if selected.count < remaining { selected.append(photo.id) }
        } label: {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay { AssetThumbnail(localIdentifier: photo.id) }
                .clipped()
                .overlay(alignment: .topTrailing) {
                    ZStack {
                        Circle().fill(order == nil ? Color.black.opacity(0.25) : Color.accentColor)
                        Circle().stroke(Color.white, lineWidth: 1.5)
                        if let order { Text("\(order + 1)").font(.caption2.bold()).foregroundColor(.white) }
                    }
                    .frame(width: 22, height: 22)
                    .padding(6)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(order == nil ? "写真を選ぶ" : "\(order! + 1)番目に選んだ写真")
    }

    /// 選んだ写真を読み込み、選んだ順にフォトマップへ入れる（先頭が代表になる）
    private func addSelected() async {
        isAdding = true
        defer { isAdding = false }
        var images: [UIImage] = []
        for id in selected {
            if let image = await AssetThumbnail.loadFull(localIdentifier: id) { images.append(image) }
        }
        let wasEmpty = PhotoMapFiles.photos(of: candidate.prefecture,
                                            in: albumManager.albums.first { $0.id == albumId }?.photoFileNames ?? []).isEmpty
        let added = albumManager.addJapanPhotos(images, prefecture: candidate.prefecture, to: albumId)
        // 地図が1県埋まるのは達成感のある場面
        if wasEmpty && added > 0 { ReviewRequestManager.shared.record(.prefectureAdded) }
        // 写真を入れた県は、旅の記録にも撮った年で足す
        let years = Set(candidate.photos.filter { selected.contains($0.id) }
            .map { Calendar.current.component(.year, from: $0.date) })
        visited.add(candidate.prefecture, years: years)
        selected = []
        dismiss()
    }
}

/// カメラロールの写真の小さな見本（id から読む）
struct AssetThumbnail: View {
    let localIdentifier: String?
    @State private var image: UIImage?

    var body: some View {
        Color(.tertiarySystemFill)
            .overlay { if let image { Image(uiImage: image).resizable().scaledToFill() } }
            .clipped()
            .task(id: localIdentifier) {
                guard let localIdentifier,
                      let asset = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil).firstObject
                else { return }
                let options = PHImageRequestOptions()
                options.deliveryMode = .opportunistic
                options.isNetworkAccessAllowed = true
                PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 300, height: 300),
                                                      contentMode: .aspectFill, options: options) { result, _ in
                    if let result { image = result }
                }
            }
    }

    /// フォトマップに入れる大きさで読む（iCloud にあるものは取ってくる）
    static func loadFull(localIdentifier: String) async -> UIImage? {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil).firstObject
        else { return nil }
        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.resizeMode = .fast
            PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 2048, height: 2048),
                                                  contentMode: .aspectFit, options: options) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}
