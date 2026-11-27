import SwiftUI
import Combine

/// 日本全国フォトマップ。
///
/// 3.1 で作り直した：地図を主役に画面の幅いっぱいに出し、数字は「12 / 47」の1つと細い線1本だけにした。
/// 一覧は地方ごとに区切り、写真の無い県は県名だけの控えめな点線の枠にする（集めていく感じを出す）。
/// 以前は色違いの数字のカード3枚・カードの枠に入った小さな地図・均一に並ぶ47個の箱で、地図が主役になっていなかった
struct JapanPhotoView: View {
    /// 開いているフォトマップ（種類 `.japan` のアルバム）。複数作れるので、どれを開くかを受け取る
    let albumId: String
    @StateObject private var viewModel: JapanPhotoViewModel
    @ObservedObject var themeManager = ThemeManager.shared
    @State private var selectedPrefecture: Prefecture?
    /// 写真の無い県を押したとき、写真を選ぶ画面を直接開く
    @State private var addingPrefecture: Prefecture?
    /// カメラロールの写真の場所から、行った県の写真を探して入れる（Travory Pro）
    @State private var scanning = false
    @State private var showsPro = false
    @ObservedObject private var proStore = ProStore.shared
    /// 地図を全画面で開く（つまんで広げる・動かすのは全画面で。スクロールの中では取り合いになって操作しにくかった）
    @State private var showsFullMap = false
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    init(albumId: String) {
        self.albumId = albumId
        _viewModel = StateObject(wrappedValue: JapanPhotoViewModel(albumId: albumId))
    }

    // MARK: 色（テーマの地から、文字と差し色を決める）

    private var ground: Color {
        colorScheme == .dark ? themeManager.currentTheme.backgroundDark : themeManager.currentTheme.backgroundLight
    }
    private var ink: Color { ThemePreset.readableText(on: ground) }
    private var faint: Color { ink.opacity(0.55) }
    private var rule: Color { ink.opacity(0.12) }
    private var accent: Color {
        ThemePreset.readableTintEitherWay(themeManager.currentTheme.primary, on: ground, minimum: 3.0)
    }

    private var filledCount: Int { viewModel.covers.count }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    countSection
                    mapSection
                    ForEach(Self.regions, id: \.name) { region in
                        regionSection(region)
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .background(ground.ignoresSafeArea())
        // 県を押したら、まず写真をスライドで見返す（編集は右上から）。
        // 前は編集の一覧が開き、1枚ずつ開いて見直す必要があった。ご要望をいただいて変えた。
        // 写真がまだ無い県は、足せるように編集の一覧を開く
        .fullScreenCover(item: $selectedPrefecture) { prefecture in
            PrefectureSlideView(albumId: albumId, prefecture: prefecture)
        }
        // 写真の無い県は、スライドの画面と一覧の画面を重ねて開かず、写真を選ぶ画面だけを開く
        // （以前は黒いスライドの画面・写真の一覧・写真を選ぶ画面と、何枚も重なって開いていた）
        .sheet(isPresented: $scanning) { PhotoMapScanView(albumId: albumId) }
        .sheet(isPresented: $showsPro) { ProSheet(highlighted: nil) }
        .sheet(item: $addingPrefecture) { prefecture in
            MultiPhotoPicker(selectionLimit: PhotoMapFiles.maxPhotosPerPrefecture) { images in
                let added = AlbumManager.shared.addJapanPhotos(images, prefecture: prefecture, to: albumId)
                // 写真を入れた県は、年は分からない行った県として旅の記録にも足す（年はあとから足せる）
                if added > 0 { VisitedPrefectureStore.shared.add(prefecture) }
                // フォトマップの写真が3枚になったら、評価を頼む（3.8）
                if added > 0 { ReviewRequestManager.shared.photoMapPhotosAdded(albumId: albumId) }
            }
        }
    }

    /// 県を押したとき。写真があればスライドで見返し、無ければ写真を選ぶ画面を開く
    private func open(_ prefecture: Prefecture) {
        if viewModel.covers[prefecture] == nil {
            addingPrefecture = prefecture
        } else {
            selectedPrefecture = prefecture
        }
    }

    // MARK: - 見出し（閉じるボタンと名前だけ）

    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ink)
                    .frame(width: 38, height: 38)
                    .background(ink.opacity(0.07), in: Circle())
            }
            .accessibilityLabel("閉じる")
            Spacer()
            Text(viewModel.title)
                .font(.headline)
                .foregroundColor(ink)
                .lineLimit(1)
            Spacer()
            Color.clear.frame(width: 38, height: 38)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - 数字（12 / 47 と細い線1本）

    private var countSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(filledCount)")
                    .font(.system(size: 56, weight: .thin).width(.condensed))
                    .monospacedDigit()
                    .foregroundColor(ink)
                Text("/ 47")
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(faint)
                Spacer()
                Text(filledCount == 47 ? "全国制覇" : "あと\(47 - filledCount)県")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(filledCount == 47 ? accent : faint)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(rule)
                    Capsule().fill(accent)
                        .frame(width: max(geo.size.width * CGFloat(filledCount) / 47, filledCount > 0 ? 3 : 0))
                }
            }
            .frame(height: 3)
            HStack {
                Text("写真を入れた都道府県")
                    .font(.system(size: 10, weight: .semibold).width(.expanded))
                    .foregroundColor(accent)
                Spacer()
                // 写真に残っている場所から、行った県の写真を探して入れる（Travory Pro）
                Button {
                    if proStore.isPurchased { scanning = true } else { showsPro = true }
                } label: {
                    HStack(spacing: 5) {
                        Label("カメラロールから自動追加", systemImage: "sparkle.magnifyingglass")
                        if !proStore.isPurchased {
                            Text("Pro")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(accent))
                        }
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .overlay(Capsule().stroke(accent.opacity(0.5), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(proStore.isPurchased ? "カメラロールから自動追加" : "カメラロールから自動追加（Pro）")
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    // MARK: - 地図（画面の幅いっぱい。押すと県を開き、「広げて見る」で全画面）

    private var mapSection: some View {
        PhotoMapCanvas(covers: viewModel.covers, ink: ink, onTap: open)
            .frame(height: 420)
            .overlay(alignment: .bottomTrailing) {
                // ふだんの地図は固定。つまんで広げる・動かすのは全画面で
                Button { showsFullMap = true } label: {
                    Label("全画面で見る", systemImage: "arrow.up.left.and.arrow.down.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(ink)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(ink.opacity(0.12), lineWidth: 1))
                }
                .padding(12)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
            .fullScreenCover(isPresented: $showsFullMap) {
                PhotoMapFullScreen(albumId: albumId, viewModel: viewModel, title: viewModel.title)
            }
    }

    // MARK: - 地方ごとの一覧

    /// 地方の区切り（`Prefecture` は北から順に並んでいる）
    private static let regions: [(name: String, prefectures: [Prefecture])] = {
        let all = Prefecture.allCases
        return [("北海道・東北", Array(all[0..<7])), ("関東", Array(all[7..<14])), ("中部", Array(all[14..<23])),
                ("近畿", Array(all[23..<30])), ("中国・四国", Array(all[30..<39])), ("九州・沖縄", Array(all[39..<47]))]
    }()

    private func regionSection(_ region: (name: String, prefectures: [Prefecture])) -> some View {
        let filled = region.prefectures.filter { viewModel.covers[$0] != nil }.count
        return VStack(alignment: .leading, spacing: 12) {
            Rectangle().fill(rule).frame(height: 1)
            HStack(alignment: .firstTextBaseline) {
                Text(region.name).font(.subheadline.weight(.semibold)).foregroundColor(ink)
                Spacer()
                Text("\(filled) / \(region.prefectures.count)")
                    .font(.footnote.monospacedDigit())
                    .foregroundColor(faint)
            }
            .padding(.top, 16)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 12) {
                ForEach(region.prefectures) { prefecture in
                    PrefectureTile(prefecture: prefecture, photo: viewModel.covers[prefecture],
                                   photoCount: viewModel.photoCount(of: prefecture), ink: ink, accent: accent)
                        .onTapGesture { open(prefecture) }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
}

/// 一覧の1県。写真があれば写真を大きく、無ければ県名だけの控えめな点線の枠
struct PrefectureTile: View {
    let prefecture: Prefecture
    let photo: UIImage?
    var photoCount: Int = 0
    let ink: Color
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if let photo {
                        // 枠の大きさを先に決めて、その中で切り抜く（横長の写真が隣へはみ出さないように）
                        Image(uiImage: photo).resizable().scaledToFill()
                    } else {
                        RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                            .strokeBorder(ink.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .overlay(Image(systemName: "plus").font(.footnote.weight(.semibold))
                                .foregroundColor(ink.opacity(0.28)))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    if photoCount > 1 {
                        Text("\(photoCount)枚")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.black.opacity(0.5)))
                            .padding(5)
                    }
                }
            Text(prefecture.name)
                .font(.system(size: 11, weight: photo == nil ? .regular : .semibold))
                .foregroundColor(photo == nil ? ink.opacity(0.5) : ink)
                .lineLimit(1)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(prefecture.name)\(photo == nil ? "、写真なし" : "、写真\(max(photoCount, 1))枚")")
        .accessibilityAddTraits(.isButton)
    }
}

/// 日本地図（写真のある県は写真を県の形に切り抜き、無い県はごく薄い色）。押した県を `onTap` で返す
struct PhotoMapCanvas: View {
    let covers: [Prefecture: UIImage]
    let ink: Color
    let onTap: (Prefecture) -> Void

    /// 47都道府県がちょうど入る四角（370 × 600 の中）
    static let mapBounds: CGRect = Prefecture.allCases.reduce(CGRect.null) { rect, prefecture in
        let center = CGPoint(x: Prefecture.mapCanvas.width * prefecture.mapPosition.x,
                             y: Prefecture.mapCanvas.height * prefecture.mapPosition.y)
        let size = prefecture.mapSize
        return rect.union(CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2,
                                 width: size.width, height: size.height))
    }.union(Prefecture.okinawaInsetFrame)

    var body: some View {
        GeometryReader { geo in
            let box = Self.mapBounds
            let fit = min(geo.size.width / box.width, geo.size.height / box.height)
            let dx = (geo.size.width - box.width * fit) / 2
            let dy = (geo.size.height - box.height * fit) / 2
            ZStack(alignment: .topLeading) {
                OkinawaInsetFrame(box: box, scale: fit, dx: dx, dy: dy, color: ink.opacity(0.22))
                ForEach(Prefecture.allCases) { prefecture in
                    cell(prefecture, scale: fit)
                        .position(x: dx + (Prefecture.mapCanvas.width * prefecture.mapPosition.x - box.minX) * fit,
                                  y: dy + (Prefecture.mapCanvas.height * prefecture.mapPosition.y - box.minY) * fit)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    @ViewBuilder
    private func cell(_ prefecture: Prefecture, scale fit: CGFloat) -> some View {
        let size = CGSize(width: prefecture.mapSize.width * fit, height: prefecture.mapSize.height * fit)
        Group {
            if let photo = covers[prefecture] {
                MaskedPrefectureImage(prefecture: prefecture, photo: photo, size: size)
            } else if let mask = prefecture.maskImage {
                Image(uiImage: mask).renderingMode(.template).resizable().aspectRatio(contentMode: .fit)
                    .foregroundColor(ink.opacity(0.1))
            } else {
                prefecture.shape.fill(ink.opacity(0.1))
            }
        }
        .frame(width: size.width, height: size.height)
        .contentShape(Rectangle())
        .onTapGesture { onTap(prefecture) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(prefecture.name)\(covers[prefecture] == nil ? "、写真なし" : "")")
        .accessibilityAddTraits(.isButton)
    }
}

/// 沖縄を囲む角丸の枠（沖縄は九州の左下に大きくして置いているので、別の場所だと分かるように）
struct OkinawaInsetFrame: View {
    /// 地図の四角（370 × 600 の中）と、そこから画面への倍率・ずらし
    let box: CGRect
    let scale: CGFloat
    let dx: CGFloat
    let dy: CGFloat
    let color: Color

    var body: some View {
        let frame = Prefecture.okinawaInsetFrame
        RoundedRectangle(cornerRadius: 6 * scale, style: .continuous)
            .strokeBorder(color, lineWidth: max(0.5, 0.8 * scale))
            .frame(width: frame.width * scale, height: frame.height * scale)
            .position(x: dx + (frame.midX - box.minX) * scale, y: dy + (frame.midY - box.minY) * scale)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// 地図を全画面で見る。写真アプリと同じように、指を置いた場所に向かって広げ、はじいて動かせ、
/// 2回たたくとその場所を広げる（もう一度で戻す）。県を押せば、写真を見たり入れたりできる
private struct PhotoMapFullScreen: View {
    let albumId: String
    @ObservedObject var viewModel: JapanPhotoViewModel
    let title: String

    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPrefecture: Prefecture?
    @State private var addingPrefecture: Prefecture?

    private var ground: Color {
        colorScheme == .dark ? themeManager.currentTheme.backgroundDark : themeManager.currentTheme.backgroundLight
    }
    private var ink: Color { ThemePreset.readableText(on: ground) }

    var body: some View {
        ZStack(alignment: .top) {
            ground.ignoresSafeArea()
            ZoomableScrollView {
                PhotoMapCanvas(covers: viewModel.covers, ink: ink) { prefecture in
                    if viewModel.covers[prefecture] == nil { addingPrefecture = prefecture } else { selectedPrefecture = prefecture }
                }
                .padding(12)
                .background(ground)
            }
            .ignoresSafeArea(edges: .bottom)
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(ink)
                        .frame(width: 38, height: 38)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("閉じる")
                Spacer()
                Text(title).font(.headline).foregroundColor(ink)
                Spacer()
                Color.clear.frame(width: 38, height: 38)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .fullScreenCover(item: $selectedPrefecture) { prefecture in
            PrefectureSlideView(albumId: albumId, prefecture: prefecture)
        }
        .sheet(item: $addingPrefecture) { prefecture in
            MultiPhotoPicker(selectionLimit: PhotoMapFiles.maxPhotosPerPrefecture) { images in
                let added = AlbumManager.shared.addJapanPhotos(images, prefecture: prefecture, to: albumId)
                // 写真を入れた県は、年は分からない行った県として旅の記録にも足す（年はあとから足せる）
                if added > 0 {
                    VisitedPrefectureStore.shared.add(prefecture)
                    ReviewRequestManager.shared.photoMapPhotosAdded(albumId: albumId)
                }
            }
        }
    }
}

/// 写真アプリと同じ拡大・移動（UIScrollView）。中身は SwiftUI のまま
private struct ZoomableScrollView<Content: View>: UIViewRepresentable {
    @ViewBuilder var content: () -> Content

    func makeCoordinator() -> Coordinator { Coordinator(hosting: UIHostingController(rootView: content())) }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 5
        scrollView.bouncesZoom = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.backgroundColor = .clear
        let hosted = context.coordinator.hosting.view!
        hosted.backgroundColor = .clear
        hosted.translatesAutoresizingMaskIntoConstraints = true
        hosted.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrollView.addSubview(hosted)
        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.doubleTapped(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)
        context.coordinator.scrollView = scrollView
        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.hosting.rootView = content()
        let hosted = context.coordinator.hosting.view!
        if scrollView.zoomScale == 1, hosted.frame.size != scrollView.bounds.size {
            hosted.frame = CGRect(origin: .zero, size: scrollView.bounds.size)
            scrollView.contentSize = scrollView.bounds.size
        }
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        let hosting: UIHostingController<Content>
        weak var scrollView: UIScrollView?

        init(hosting: UIHostingController<Content>) { self.hosting = hosting }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { hosting.view }

        @objc func doubleTapped(_ recognizer: UITapGestureRecognizer) {
            guard let scrollView else { return }
            if scrollView.zoomScale > 1.01 {
                scrollView.setZoomScale(1, animated: true)
            } else {
                let point = recognizer.location(in: hosting.view)
                let size = CGSize(width: scrollView.bounds.width / 3, height: scrollView.bounds.height / 3)
                scrollView.zoom(to: CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2,
                                           width: size.width, height: size.height), animated: true)
            }
        }
    }
}

// MARK: - Prefecture Gallery View
/// ある県の写真の一覧。先頭が代表で、地図の県の形に切り抜いて出すのはこれ。
///
/// 2.7 までは県ごとに1枚で、この画面は1枚を差し替えるだけだった。
/// 「一つの県に何枚も写真を保存したい」という要望から、一覧にした
struct PrefectureGalleryView: View {
    let albumId: String
    let prefecture: Prefecture

    @ObservedObject private var albumManager = AlbumManager.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var showPicker = false
    @State private var previewing: PreviewTarget?
    // 選択モード（アルバムの写真と同じ操作感で、まとめて削除できるようにする）
    @State private var isSelecting = false
    @State private var selected: Set<String> = []
    @State private var showDeleteConfirm = false

    private struct PreviewTarget: Identifiable {
        let fileName: String
        var id: String { fileName }
    }

    private var allFileNames: [String] {
        albumManager.albums.first { $0.id == albumId }?.photoFileNames ?? []
    }

    private var fileNames: [String] {
        PhotoMapFiles.photos(of: prefecture, in: allFileNames)
    }

    private var remaining: Int {
        PhotoMapFiles.remainingSlots(for: prefecture, in: allFileNames)
    }

    private var accentColor: Color {
        colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("\(fileNames.count) / \(PhotoMapFiles.maxPhotosPerPrefecture)枚。先頭の写真が地図に出ます")
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.secondaryText)

                    // 未購入のときだけ出る
                    DeviceOnlyPhotoNote()

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(Array(fileNames.enumerated()), id: \.element) { index, fileName in
                            photoCell(fileName, isCover: index == 0)
                        }
                        if !isSelecting {
                            addCell
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle(navigationTitleText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if isSelecting {
                        Button("キャンセル") { exitSelection() }
                            .foregroundColor(accentColor)
                    } else {
                        Button("閉じる") { dismiss() }
                            .foregroundColor(accentColor)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSelecting {
                        Button(selected.count == fileNames.count ? "すべて解除" : "すべて選択") {
                            selected = selected.count == fileNames.count ? [] : Set(fileNames)
                        }
                        .foregroundColor(accentColor)
                    } else if !fileNames.isEmpty {
                        Button("選択") {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isSelecting = true }
                        }
                        .foregroundColor(accentColor)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if isSelecting {
                    deleteBar
                }
            }
            .confirmationDialog(
                selected.count == 1 ? "この写真を削除しますか？" : "\(selected.count)枚の写真を削除しますか？",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("削除", role: .destructive) { deleteSelected() }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text(deleteMessage)
            }
        }
        .sheet(isPresented: $showPicker) {
            MultiPhotoPicker(selectionLimit: remaining) { images in
                let added = albumManager.addJapanPhotos(images, prefecture: prefecture, to: albumId)
                // 写真を入れた県は、年は分からない行った県として旅の記録にも足す（年はあとから足せる）
                if added > 0 { VisitedPrefectureStore.shared.add(prefecture) }
                // フォトマップの写真が3枚になったら、評価を頼む（3.8）
                if added > 0 { ReviewRequestManager.shared.photoMapPhotosAdded(albumId: albumId) }
            }
        }
        .sheet(item: $previewing) { target in
            PhotoMapPhotoPreview(
                prefecture: prefecture,
                fileName: target.fileName,
                isCover: fileNames.first == target.fileName,
                onMakeCover: { albumManager.makeJapanCover(target.fileName, in: albumId) },
                onDelete: { albumManager.removeJapanPhoto(target.fileName, from: albumId) }
            )
        }
    }

    // MARK: - 選択

    private var navigationTitleText: String {
        guard isSelecting else { return prefecture.name }
        return selected.isEmpty ? "写真を選択" : "\(selected.count)枚を選択中"
    }

    /// 代表の写真を消すと、残った写真の先頭が地図に出る。何が起きるかを先に伝える
    private var deleteMessage: String {
        let removesCover = fileNames.first.map(selected.contains) ?? false
        let removesAll = selected.count == fileNames.count
        if removesAll { return "\(prefecture.name)の写真がなくなり、地図から消えます。元に戻せません。" }
        if removesCover { return "代表の写真も含まれます。残った写真の先頭が地図に出ます。元に戻せません。" }
        return "削除した写真は元に戻せません"
    }

    private var deleteBar: some View {
        Button {
            showDeleteConfirm = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "trash.fill")
                Text("削除")
            }
            .font(.headline)
            .foregroundColor(selected.isEmpty ? themeManager.currentTheme.secondaryText : .white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                Capsule().fill(selected.isEmpty
                               ? themeManager.currentTheme.secondaryText.opacity(0.15)
                               : themeManager.currentTheme.error)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(selected.isEmpty)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private func toggle(_ fileName: String) {
        if selected.contains(fileName) {
            selected.remove(fileName)
        } else {
            selected.insert(fileName)
        }
    }

    private func exitSelection() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isSelecting = false
            selected = []
        }
    }

    private func deleteSelected() {
        albumManager.removeJapanPhotos(Array(selected), from: albumId)
        exitSelection()
    }

    private func photoCell(_ fileName: String, isCover: Bool) -> some View {
        let isSelected = selected.contains(fileName)
        return Button {
            if isSelecting {
                toggle(fileName)
            } else {
                previewing = PreviewTarget(fileName: fileName)
            }
        } label: {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if let image = JapanPhotoManager.shared.thumbnail(fileName) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        themeManager.currentTheme.xprimary.opacity(0.08)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
                .opacity(isSelecting && !isSelected ? 0.75 : 1)
                .overlay(alignment: .bottomTrailing) {
                    if isSelecting {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20))
                            .foregroundStyle(.white, isSelected ? themeManager.currentTheme.error : Color.black.opacity(0.3))
                            .padding(5)
                    }
                }
                .overlay(alignment: .topLeading) {
                    if isCover {
                        Text("代表")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(themeManager.currentTheme.xprimary))
                            .padding(5)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isCover ? "代表の写真" : "写真")
        .accessibilityAddTraits(isSelecting && isSelected ? .isSelected : [])
    }

    private var addCell: some View {
        Button {
            showPicker = true
        } label: {
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .fill(themeManager.currentTheme.xprimary.opacity(0.08))
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    VStack(spacing: 4) {
                        Image(systemName: "photo.badge.plus")
                            .font(.title3)
                        Text(remaining > 0 ? "写真を追加" : "上限です")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(themeManager.currentTheme.xprimary.opacity(remaining > 0 ? 0.8 : 0.35))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .stroke(themeManager.currentTheme.xprimary.opacity(0.25),
                                style: StrokeStyle(lineWidth: 1.2, dash: [6, 4]))
                )
        }
        .buttonStyle(.plain)
        .disabled(remaining == 0)
    }
}

/// 県の写真を、横にスライドして見返す。右上の「編集」で、追加・代表・削除の一覧を開く
struct PrefectureSlideView: View {
    let albumId: String
    let prefecture: Prefecture

    @ObservedObject private var albumManager = AlbumManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var page = 0
    @State private var showsEditor = false

    private var fileNames: [String] {
        PhotoMapFiles.photos(of: prefecture,
                             in: albumManager.albums.first { $0.id == albumId }?.photoFileNames ?? [])
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if fileNames.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.7))
                        Text("\(prefecture.name)の写真はまだありません")
                            .foregroundColor(.white.opacity(0.8))
                        Button("写真を追加") { showsEditor = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    TabView(selection: $page) {
                        ForEach(Array(fileNames.enumerated()), id: \.element) { index, fileName in
                            SlidePhoto(fileName: fileName)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: fileNames.count > 1 ? .always : .never))
                    .ignoresSafeArea(edges: .bottom)
                }
            }
            .navigationTitle(fileNames.isEmpty ? prefecture.name
                             : "\(prefecture.name)  \(min(page, fileNames.count - 1) + 1) / \(fileNames.count)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black.opacity(0.6), for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("編集") { showsEditor = true }
                }
            }
        }
        .sheet(isPresented: $showsEditor) {
            PrefectureGalleryView(albumId: albumId, prefecture: prefecture)
        }
        .onAppear {
            // 写真が無い県は、足すための一覧をすぐ開く
            if fileNames.isEmpty { showsEditor = true }
        }
        .onChange(of: fileNames.count) { _, count in
            if page >= count { page = max(count - 1, 0) }
        }
    }

    /// 1枚。押し広げて拡大できる
    private struct SlidePhoto: View {
        let fileName: String
        @State private var image: UIImage?
        @State private var scale: CGFloat = 1

        var body: some View {
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .gesture(
                            MagnifyGesture()
                                .onChanged { scale = max(1, min($0.magnification, 4)) }
                                .onEnded { _ in withAnimation(.spring) { scale = 1 } }
                        )
                } else {
                    ProgressView().tint(.white)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task(id: fileName) {
                image = JapanPhotoManager.shared.thumbnail(fileName)
                if let full = JapanPhotoManager.shared.loadImage(fileName) { image = full }
            }
        }
    }
}

/// フォトマップの写真を大きく見る。代表にする・削除する
struct PhotoMapPhotoPreview: View {
    let prefecture: Prefecture
    let fileName: String
    let isCover: Bool
    let onMakeCover: () -> Void
    let onDelete: () -> Void

    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Group {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.large))
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxHeight: .infinity)

                if isCover {
                    Label("地図に出ている写真です", systemImage: "map.fill")
                        .font(.subheadline)
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                } else {
                    Button {
                        onMakeCover()
                        dismiss()
                    } label: {
                        Label("代表にする（地図に出す）", systemImage: "star.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: AppRadius.large).fill(themeManager.currentTheme.xprimary))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                }

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("写真を削除", systemImage: "trash")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundColor(themeManager.currentTheme.error)
                        .background(RoundedRectangle(cornerRadius: AppRadius.large).fill(themeManager.currentTheme.error.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .navigationTitle(prefecture.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
            .confirmationDialog("この写真を削除しますか？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("削除", role: .destructive) {
                    onDelete()
                    dismiss()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text(isCover ? "代表の写真です。削除すると、次の写真が地図に出ます。元に戻せません。" : "削除した写真は元に戻せません")
            }
            .task {
                image = JapanPhotoManager.shared.loadImage(fileName)
            }
        }
    }
}

// MARK: - Prefecture Enum (No changes - kept as is)
enum Prefecture: String, CaseIterable, Identifiable {
    case hokkaido, aomori, iwate, miyagi, akita, yamagata, fukushima
    case ibaraki, tochigi, gunma, saitama, chiba, tokyo, kanagawa
    case niigata, toyama, ishikawa, fukui, yamanashi, nagano, gifu, shizuoka, aichi
    case mie, shiga, kyoto, osaka, hyogo, nara, wakayama
    case tottori, shimane, okayama, hiroshima, yamaguchi
    case tokushima, kagawa, ehime, kochi
    case fukuoka, saga, nagasaki, kumamoto, oita, miyazaki, kagoshima
    case okinawa

    var id: String { rawValue }

    var name: String {
        switch self {
        case .hokkaido: return "北海道"
        case .aomori: return "青森県"
        case .iwate: return "岩手県"
        case .miyagi: return "宮城県"
        case .akita: return "秋田県"
        case .yamagata: return "山形県"
        case .fukushima: return "福島県"
        case .ibaraki: return "茨城県"
        case .tochigi: return "栃木県"
        case .gunma: return "群馬県"
        case .saitama: return "埼玉県"
        case .chiba: return "千葉県"
        case .tokyo: return "東京都"
        case .kanagawa: return "神奈川県"
        case .niigata: return "新潟県"
        case .toyama: return "富山県"
        case .ishikawa: return "石川県"
        case .fukui: return "福井県"
        case .yamanashi: return "山梨県"
        case .nagano: return "長野県"
        case .gifu: return "岐阜県"
        case .shizuoka: return "静岡県"
        case .aichi: return "愛知県"
        case .mie: return "三重県"
        case .shiga: return "滋賀県"
        case .kyoto: return "京都府"
        case .osaka: return "大阪府"
        case .hyogo: return "兵庫県"
        case .nara: return "奈良県"
        case .wakayama: return "和歌山県"
        case .tottori: return "鳥取県"
        case .shimane: return "島根県"
        case .okayama: return "岡山県"
        case .hiroshima: return "広島県"
        case .yamaguchi: return "山口県"
        case .tokushima: return "徳島県"
        case .kagawa: return "香川県"
        case .ehime: return "愛媛県"
        case .kochi: return "高知県"
        case .fukuoka: return "福岡県"
        case .saga: return "佐賀県"
        case .nagasaki: return "長崎県"
        case .kumamoto: return "熊本県"
        case .oita: return "大分県"
        case .miyazaki: return "宮崎県"
        case .kagoshima: return "鹿児島県"
        case .okinawa: return "沖縄県"
        }
    }

    var shortName: String {
        String(name.prefix(3))
    }

    /// 地図の中の位置（370 × 600 の中の割合。県の形の四角の真ん中）。
    /// 国土の形（Natural Earth・パブリックドメイン）の実際の県境から作った（3.9）。
    /// 県の形の画像 `prefecture_<名前>` と組で、作り直すときは両方をいっしょに書き出す
    var baseMapPosition: CGPoint {
        switch self {
        case .hokkaido: return CGPoint(x: 0.84658, y: 0.08259)
        case .aomori: return CGPoint(x: 0.75469, y: 0.17295)
        case .iwate: return CGPoint(x: 0.78167, y: 0.21763)
        case .miyagi: return CGPoint(x: 0.76387, y: 0.26041)
        case .akita: return CGPoint(x: 0.73483, y: 0.21472)
        case .yamagata: return CGPoint(x: 0.72362, y: 0.25905)
        case .fukushima: return CGPoint(x: 0.72431, y: 0.29548)
        case .ibaraki: return CGPoint(x: 0.73146, y: 0.33218)
        case .tochigi: return CGPoint(x: 0.71015, y: 0.32019)
        case .gunma: return CGPoint(x: 0.67566, y: 0.32606)
        case .saitama: return CGPoint(x: 0.68752, y: 0.34332)
        case .chiba: return CGPoint(x: 0.73415, y: 0.36156)
        case .tokyo: return CGPoint(x: 0.69284, y: 0.35478)
        case .kanagawa: return CGPoint(x: 0.69007, y: 0.36521)
        case .niigata: return CGPoint(x: 0.66285, y: 0.28639)
        case .toyama: return CGPoint(x: 0.59499, y: 0.32187)
        case .ishikawa: return CGPoint(x: 0.57446, y: 0.31580)
        case .fukui: return CGPoint(x: 0.54401, y: 0.35044)
        case .yamanashi: return CGPoint(x: 0.65842, y: 0.35921)
        case .nagano: return CGPoint(x: 0.63006, y: 0.34015)
        case .gifu: return CGPoint(x: 0.58117, y: 0.35087)
        case .shizuoka: return CGPoint(x: 0.64304, y: 0.37482)
        case .aichi: return CGPoint(x: 0.59471, y: 0.37936)
        case .mie: return CGPoint(x: 0.55603, y: 0.39765)
        case .shiga: return CGPoint(x: 0.54274, y: 0.37086)
        case .kyoto: return CGPoint(x: 0.51359, y: 0.37052)
        case .osaka: return CGPoint(x: 0.51133, y: 0.39146)
        case .hyogo: return CGPoint(x: 0.48651, y: 0.38111)
        case .nara: return CGPoint(x: 0.53295, y: 0.40326)
        case .wakayama: return CGPoint(x: 0.51702, y: 0.41713)
        case .tottori: return CGPoint(x: 0.43968, y: 0.36733)
        case .shimane: return CGPoint(x: 0.38098, y: 0.36748)
        case .okayama: return CGPoint(x: 0.44019, y: 0.38307)
        case .hiroshima: return CGPoint(x: 0.39099, y: 0.39356)
        case .yamaguchi: return CGPoint(x: 0.34205, y: 0.40587)
        case .tokushima: return CGPoint(x: 0.45691, y: 0.41754)
        case .kagawa: return CGPoint(x: 0.44788, y: 0.40405)
        case .ehime: return CGPoint(x: 0.39527, y: 0.42798)
        case .kochi: return CGPoint(x: 0.42315, y: 0.43879)
        case .fukuoka: return CGPoint(x: 0.29459, y: 0.43215)
        case .saga: return CGPoint(x: 0.27324, y: 0.44003)
        case .nagasaki: return CGPoint(x: 0.24335, y: 0.42650)
        case .kumamoto: return CGPoint(x: 0.29561, y: 0.46145)
        case .oita: return CGPoint(x: 0.33251, y: 0.44146)
        case .miyazaki: return CGPoint(x: 0.32486, y: 0.48038)
        case .kagoshima: return CGPoint(x: 0.28575, y: 0.51190)
        case .okinawa: return CGPoint(x: 0.10464, y: 0.51893)
        }
    }

    /// 地図の中の大きさ（ポイント。県の形の画像の縦横の比と同じ）
    var baseMapSize: CGSize {
        switch self {
        case .hokkaido: return CGSize(width: 101.590, height: 86.505)
        case .aomori: return CGSize(width: 30.594, height: 28.046)
        case .iwate: return CGSize(width: 23.685, height: 35.642)
        case .miyagi: return CGSize(width: 23.548, height: 25.619)
        case .akita: return CGSize(width: 21.237, height: 34.188)
        case .yamagata: return CGSize(width: 17.937, height: 29.242)
        case .fukushima: return CGSize(width: 31.635, height: 24.612)
        case .ibaraki: return CGSize(width: 20.222, height: 25.080)
        case .tochigi: return CGSize(width: 16.114, height: 19.796)
        case .gunma: return CGSize(width: 21.756, height: 22.464)
        case .saitama: return CGSize(width: 19.711, height: 10.905)
        case .chiba: return CGSize(width: 18.901, height: 24.781)
        case .tokyo: return CGSize(width: 16.153, height: 8.189)
        case .kanagawa: return CGSize(width: 14.864, height: 11.267)
        case .niigata: return CGSize(width: 37.847, height: 38.101)
        case .toyama: return CGSize(width: 16.377, height: 14.738)
        case .ishikawa: return CGSize(width: 18.990, height: 30.829)
        case .fukui: return CGSize(width: 22.872, height: 20.060)
        case .yamanashi: return CGSize(width: 15.987, height: 16.817)
        case .nagano: return CGSize(width: 23.354, height: 38.372)
        case .gifu: return CGSize(width: 22.930, height: 27.582)
        case .shizuoka: return CGSize(width: 28.260, height: 21.699)
        case .aichi: return CGSize(width: 18.987, height: 16.913)
        case .mie: return CGSize(width: 18.101, height: 32.459)
        case .shiga: return CGSize(width: 11.745, height: 18.928)
        case .kyoto: return CGSize(width: 19.677, height: 22.604)
        case .osaka: return CGSize(width: 10.558, height: 15.186)
        case .hyogo: return CGSize(width: 19.987, height: 31.107)
        case .nara: return CGSize(width: 11.206, height: 19.349)
        case .wakayama: return CGSize(width: 15.704, height: 19.707)
        case .tottori: return CGSize(width: 23.191, height: 11.536)
        case .shimane: return CGSize(width: 28.758, height: 42.900)
        case .okayama: return CGSize(width: 18.999, height: 18.969)
        case .hiroshima: return CGSize(width: 23.612, height: 21.193)
        case .yamaguchi: return CGSize(width: 26.967, height: 18.813)
        case .tokushima: return CGSize(width: 18.504, height: 15.131)
        case .kagawa: return CGSize(width: 14.827, height: 11.687)
        case .ehime: return CGSize(width: 27.813, height: 29.526)
        case .kochi: return CGSize(width: 28.206, height: 24.024)
        case .fukuoka: return CGSize(width: 19.532, height: 20.696)
        case .saga: return CGSize(width: 13.056, height: 12.788)
        case .nagasaki: return CGSize(width: 29.775, height: 44.784)
        case .kumamoto: return CGSize(width: 22.908, height: 22.897)
        case .oita: return CGSize(width: 21.096, height: 19.979)
        case .miyazaki: return CGSize(width: 19.660, height: 30.563)
        case .kagoshima: return CGSize(width: 25.768, height: 40.691)
        case .okinawa: return CGSize(width: 64.831, height: 46.540)
        }
    }

    var shapePath: Path {
        var path = Path()

        switch self {
        case .hokkaido:
            path.move(to: CGPoint(x: 0.5, y: 0))
            path.addLine(to: CGPoint(x: 1, y: 0.3))
            path.addLine(to: CGPoint(x: 0.9, y: 0.7))
            path.addLine(to: CGPoint(x: 0.6, y: 1))
            path.addLine(to: CGPoint(x: 0.2, y: 0.9))
            path.addLine(to: CGPoint(x: 0, y: 0.5))
            path.addLine(to: CGPoint(x: 0.1, y: 0.2))
            path.closeSubpath()

        case .tokyo:
            path.addEllipse(in: CGRect(x: 0, y: 0, width: 1, height: 1))

        case .osaka:
            path.move(to: CGPoint(x: 0.3, y: 0))
            path.addLine(to: CGPoint(x: 1, y: 0.2))
            path.addLine(to: CGPoint(x: 0.9, y: 0.8))
            path.addLine(to: CGPoint(x: 0.4, y: 1))
            path.addLine(to: CGPoint(x: 0, y: 0.6))
            path.closeSubpath()

        default:
            path.move(to: CGPoint(x: 0.2, y: 0))
            path.addLine(to: CGPoint(x: 1, y: 0.1))
            path.addLine(to: CGPoint(x: 0.9, y: 0.9))
            path.addLine(to: CGPoint(x: 0.1, y: 1))
            path.addLine(to: CGPoint(x: 0, y: 0.3))
            path.closeSubpath()
        }

        return path
    }

    var shape: some Shape {
        PrefectureShape(prefecture: self)
    }

    var maskImage: UIImage? {
        UIImage(named: "prefecture_\(rawValue)")
    }

    func generateMaskImage() -> UIImage? {
        let size = mapSize
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            let path = shapePath
            let scaledPath = path.applying(CGAffineTransform(scaleX: size.width, y: size.height))

            UIColor.white.setFill()
            context.cgContext.addPath(scaledPath.cgPath)
            context.cgContext.fillPath()
        }
    }
}

// MARK: - Prefecture Shape (No changes - kept as is)
struct PrefectureShape: Shape {
    let prefecture: Prefecture

    func path(in rect: CGRect) -> Path {
        let path = prefecture.shapePath
        let scaleX = rect.width
        let scaleY = rect.height

        return path.applying(CGAffineTransform(scaleX: scaleX, y: scaleY))
    }
}

// MARK: - Masked Prefecture Image (No changes - kept as is)
struct MaskedPrefectureImage: View {
    let prefecture: Prefecture
    let photo: UIImage
    let size: CGSize

    var body: some View {
        if let maskImage = prefecture.maskImage {
            Image(uiImage: photo)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size.width, height: size.height)
                .clipped()
                .mask(
                    Image(uiImage: maskImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: size.width, height: size.height)
                )
        } else {
            Image(uiImage: photo)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size.width, height: size.height)
                .clipShape(prefecture.shape)
        }
    }
}

// MARK: - ViewModel
/// 開いているフォトマップの、県ごとの代表写真を持つ。
/// アルバムの並びが変わったら（写真を足した・代表を変えた・別の端末から同期された）読み直す
final class JapanPhotoViewModel: ObservableObject {
    @Published private(set) var covers: [Prefecture: UIImage] = [:]
    @Published private(set) var title: String = AlbumType.japan.title
    private(set) var fileNames: [String] = []

    private let albumId: String
    private var cancellable: AnyCancellable?

    init(albumId: String) {
        self.albumId = albumId
        cancellable = AlbumManager.shared.$albums
            .receive(on: DispatchQueue.main)
            .sink { [weak self] albums in
                guard let self else { return }
                self.apply(albums.first { $0.id == self.albumId })
            }
    }

    func photoCount(of prefecture: Prefecture) -> Int {
        PhotoMapFiles.photos(of: prefecture, in: fileNames).count
    }

    private func apply(_ album: Album?) {
        guard let album else { return }
        title = album.title
        guard album.photoFileNames != fileNames || covers.isEmpty else { return }
        fileNames = album.photoFileNames

        var result: [Prefecture: UIImage] = [:]
        for (prefecture, files) in PhotoMapFiles.grouped(fileNames) {
            if let cover = files.first, let image = JapanPhotoManager.shared.thumbnail(cover) {
                result[prefecture] = image
            }
        }
        covers = result
    }
}

#Preview {
    JapanPhotoView(albumId: "preview")
}
