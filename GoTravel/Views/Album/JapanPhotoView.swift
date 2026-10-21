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
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    /// 地図をつまんで広げられることは、最初の1回だけ知らせる
    @AppStorage("photoMapGestureHintShown") private var gestureHintShown = false
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
            Text("写真を入れた都道府県")
                .font(.system(size: 10, weight: .semibold).width(.expanded))
                .foregroundColor(accent)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    // MARK: - 地図（画面の幅いっぱい。つまんで広げ、指で動かせる）

    /// 47都道府県がちょうど入る四角（370 × 600 の中）
    private static let mapBounds: CGRect = Prefecture.allCases.reduce(CGRect.null) { rect, prefecture in
        let center = CGPoint(x: Prefecture.mapCanvas.width * prefecture.mapPosition.x,
                             y: Prefecture.mapCanvas.height * prefecture.mapPosition.y)
        let size = prefecture.mapSize
        return rect.union(CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2,
                                 width: size.width, height: size.height))
    }

    private var mapSection: some View {
        GeometryReader { geo in
            let box = Self.mapBounds
            let fit = min(geo.size.width / box.width, geo.size.height / box.height)
            let dx = (geo.size.width - box.width * fit) / 2
            let dy = (geo.size.height - box.height * fit) / 2
            ZStack(alignment: .topLeading) {
                ForEach(Prefecture.allCases) { prefecture in
                    mapCell(prefecture, scale: fit)
                        .position(x: dx + (Prefecture.mapCanvas.width * prefecture.mapPosition.x - box.minX) * fit,
                                  y: dy + (Prefecture.mapCanvas.height * prefecture.mapPosition.y - box.minY) * fit)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .scaleEffect(scale)
            .offset(offset)
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .contentShape(Rectangle())
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        scale = min(max(lastScale * value, 1), 3)
                        gestureHintShown = true
                    }
                    .onEnded { _ in
                        lastScale = scale
                        if scale <= 1.01 { withAnimation(.spring) { offset = .zero; lastOffset = .zero } }
                    }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        guard scale > 1.01 else { return }
                        let limitX = geo.size.width * (scale - 1) / 2
                        let limitY = geo.size.height * (scale - 1) / 2
                        offset = CGSize(width: min(max(lastOffset.width + value.translation.width, -limitX), limitX),
                                        height: min(max(lastOffset.height + value.translation.height, -limitY), limitY))
                    }
                    .onEnded { _ in lastOffset = offset }
            )
            // 広げたあと2回たたくと、元の大きさに戻る
            .onTapGesture(count: 2) {
                withAnimation(.spring) {
                    scale = 1; lastScale = 1; offset = .zero; lastOffset = .zero
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if !gestureHintShown {
                    Label("つまんで広げられます", systemImage: "hand.pinch")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(faint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(ink.opacity(0.06)))
                        .padding(12)
                        .allowsHitTesting(false)
                }
            }
        }
        .frame(height: 420)
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private func mapCell(_ prefecture: Prefecture, scale fit: CGFloat) -> some View {
        let size = CGSize(width: prefecture.mapSize.width * fit, height: prefecture.mapSize.height * fit)
        Group {
            if let photo = viewModel.covers[prefecture] {
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
        .onTapGesture { selectedPrefecture = prefecture }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(prefecture.name)\(viewModel.covers[prefecture] == nil ? "、写真なし" : "")")
        .accessibilityAddTraits(.isButton)
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
                        .onTapGesture { selectedPrefecture = prefecture }
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
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(ink.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .overlay(Image(systemName: "plus").font(.footnote.weight(.semibold))
                                .foregroundColor(ink.opacity(0.28)))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                let wasEmpty = fileNames.isEmpty
                let added = albumManager.addJapanPhotos(images, prefecture: prefecture, to: albumId)
                // 地図が1県埋まるのは達成感のある場面
                if wasEmpty && added > 0 {
                    ReviewRequestManager.shared.record(.prefectureAdded)
                }
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
                .clipShape(RoundedRectangle(cornerRadius: 10))
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
            RoundedRectangle(cornerRadius: 10)
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
                    RoundedRectangle(cornerRadius: 10)
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
                            .clipShape(RoundedRectangle(cornerRadius: 14))
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
                            .background(RoundedRectangle(cornerRadius: 14).fill(themeManager.currentTheme.xprimary))
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
                        .background(RoundedRectangle(cornerRadius: 14).fill(themeManager.currentTheme.error.opacity(0.1)))
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

    /// 手でそろえた位置（370 × 600 の中の割合）。**ここの数字は直さない。**
    /// 微調整は `PrefectureMapAdjustment` の表で持ち、`mapPosition` で足す
    var baseMapPosition: CGPoint {
        switch self {
        // 北海道
        case .hokkaido: return CGPoint(x: 1.45, y: 0.69)

        // 東北
        case .aomori: return CGPoint(x: 1.33, y: 0.82)
        case .iwate: return CGPoint(x: 1.368, y: 0.888)
        case .akita: return CGPoint(x: 1.301, y: 0.883)
        case .miyagi: return CGPoint(x: 1.341, y: 0.951)
        case .yamagata: return CGPoint(x: 1.284, y: 0.9493)
        case .fukushima: return CGPoint(x: 1.284, y: 1)

        // 関東
        case .ibaraki: return CGPoint(x: 1.294, y: 1.053)
        case .tochigi: return CGPoint(x: 1.265, y: 1.036)
        case .gunma: return CGPoint(x: 1.215, y: 1.045)
        case .saitama: return CGPoint(x: 1.231, y: 1.065)
        case .chiba: return CGPoint(x: 1.298, y: 1.093)
        case .tokyo: return CGPoint(x: 1.239, y: 1.081)
        case .kanagawa: return CGPoint(x: 1.236, y: 1.096)

        // 中部
        case .niigata: return CGPoint(x: 1.196, y: 0.9885)
        case .toyama: return CGPoint(x: 1.095, y: 1.04)
        case .ishikawa: return CGPoint(x: 1.064, y: 1.032)
        case .fukui: return CGPoint(x: 1.006, y: 1.081)
        case .yamanashi: return CGPoint(x: 1.189, y: 1.088)
        case .nagano: return CGPoint(x: 1.146, y: 1.066)
        case .gifu: return CGPoint(x: 1.07, y: 1.082)
        case .shizuoka: return CGPoint(x: 1.167, y: 1.111)
        case .aichi: return CGPoint(x: 1.089, y: 1.125)

        // 関西
        case .mie: return CGPoint(x: 1.025, y: 1.159)
        case .shiga: return CGPoint(x: 1.003, y: 1.114)
        case .kyoto: return CGPoint(x: 0.952, y: 1.115)
        case .osaka: return CGPoint(x: 0.947, y: 1.15)
        case .hyogo: return CGPoint(x: 0.9065, y: 1.132)
        case .nara: return CGPoint(x: 0.985, y: 1.169)
        case .wakayama: return CGPoint(x: 0.959, y: 1.194)

        // 中国
        case .tottori: return CGPoint(x: 0.827, y: 1.109)
        case .shimane: return CGPoint(x: 0.725, y: 1.132)
        case .okayama: return CGPoint(x: 0.829, y: 1.136)
        case .hiroshima: return CGPoint(x: 0.744, y: 1.152)
        case .yamaguchi: return CGPoint(x: 0.661, y: 1.174)

        // 四国
        case .tokushima: return CGPoint(x: 0.864, y: 1.189)
        case .kagawa: return CGPoint(x: 0.849, y: 1.171)
        case .ehime: return CGPoint(x: 0.774, y: 1.204)
        case .kochi: return CGPoint(x: 0.812, y: 1.218)

        // 九州
        case .fukuoka: return CGPoint(x: 0.589, y: 1.211)
        case .saga: return CGPoint(x: 0.553, y: 1.223)
        case .nagasaki: return CGPoint(x: 0.531, y: 1.237)
        case .kumamoto: return CGPoint(x: 0.592, y: 1.249)
        case .oita: return CGPoint(x: 0.642, y: 1.222)
        case .miyazaki: return CGPoint(x: 0.63, y: 1.273)
        case .kagoshima: return CGPoint(x: 0.592, y: 1.293)
        case .okinawa: return CGPoint(x: 0.35, y: 1.40)
        }
    }

    /// 手でそろえた大きさ。**ここの数字は直さない。** 微調整は `mapSize` で掛ける
    var baseMapSize: CGSize {
        switch self {
        case .hokkaido: return CGSize(width: 130, height: 130)
        case .aomori: return CGSize(width: 50, height: 42)
        case .iwate: return CGSize(width: 55, height: 55)
        case .akita: return CGSize(width: 53, height: 53)
        case .miyagi: return CGSize(width: 39, height: 39)
        case .yamagata: return CGSize(width: 45, height: 44)
        case .fukushima: return CGSize(width: 44, height: 44)
        case .ibaraki: return CGSize(width: 36, height: 36)
        case .tochigi: return CGSize(width: 29, height: 29)
        case .gunma: return CGSize(width: 36, height: 36)
        case .saitama: return CGSize(width: 29, height: 29)
        case .chiba: return CGSize(width: 35, height: 35)
        case .tokyo: return CGSize(width: 25, height: 25)
        case .kanagawa: return CGSize(width: 21, height: 21)
        case .niigata: return CGSize(width: 58, height: 60)
        case .toyama: return CGSize(width: 24, height: 30)
        case .ishikawa: return CGSize(width: 50, height: 45)
        case .fukui: return CGSize(width: 40, height: 40)
        case .yamanashi: return CGSize(width: 25, height: 25)
        case .nagano: return CGSize(width: 55, height: 57)
        case .gifu: return CGSize(width: 46, height: 46)
        case .shizuoka: return CGSize(width: 42, height: 42)
        case .aichi: return CGSize(width: 32, height: 32)
        case .mie: return CGSize(width: 55, height: 55)
        case .shiga: return CGSize(width:33, height: 33)
        case .kyoto: return CGSize(width:38, height: 38)
        case .osaka: return CGSize(width: 30, height: 30)
        case .hyogo: return CGSize(width:51, height: 51)
        case .nara: return CGSize(width:33, height: 33)
        case .wakayama: return CGSize(width:35, height: 33)
        case .tottori: return CGSize(width:40, height: 40)
        case .shimane: return CGSize(width:47, height: 47)
        case .okayama: return CGSize(width:36, height: 36)
        case .hiroshima: return CGSize(width:41, height: 41)
        case .yamaguchi: return CGSize(width:40, height: 40)
        case .tokushima: return CGSize(width:28, height: 28)
        case .kagawa: return CGSize(width:23, height: 23)
        case .ehime: return CGSize(width:41, height: 41)
        case .kochi: return CGSize(width:44, height: 44)
        case .fukuoka: return CGSize(width:32, height: 32)
        case .saga: return CGSize(width:24, height: 24)
        case .nagasaki: return CGSize(width:35, height: 35)
        case .kumamoto: return CGSize(width:30, height: 30)
        case .oita: return CGSize(width:29, height: 29)
        case .miyazaki: return CGSize(width:40, height: 40)
        case .kagoshima: return CGSize(width:36, height: 36)
        case .okinawa: return CGSize(width: 40, height: 40)
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
