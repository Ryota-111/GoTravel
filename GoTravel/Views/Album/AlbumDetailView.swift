import SwiftUI

// MARK: - Album Detail View
/// アルバムの中。思い出タブ（`AlbumHomeView`）と同じ作りにそろえる（3.8）：
/// 大きな丸い見出し・小さな札・カプセルのボタン、テーマの背景
struct AlbumDetailView: View {
    let album: Album
    /// アルバムの旅行を同行者と共有しているとき、その旅行（3.8。写真を見せ合う）
    var sharedPlan: TravelPlan? = nil
    var userId: String? = nil
    @ObservedObject private var albumManager = AlbumManager.shared
    @ObservedObject private var sharing = SharedAlbumSync.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var showImagePicker = false
    @State private var animatePhotos = false
    @State private var viewerIndex: Int?
    @State private var showAlbumEditor = false

    // 選択モード（写真アプリと同じ操作感でまとめて削除できるようにする）
    @State private var isSelectionMode = false
    @State private var selectedPhotos: Set<String> = []
    @State private var showDeleteConfirmation = false

    // 同行者との写真の共有（3.8）
    @State private var confirmsStartSharing = false
    @State private var confirmsStopSharing = false

    private var currentAlbum: Album? {
        albumManager.albums.first(where: { $0.id == album.id })
    }

    private var photos: [String] {
        currentAlbum?.photoFileNames ?? []
    }

    private var albumColor: Color {
        currentAlbum?.coverColor ?? album.coverColor ?? themeManager.currentTheme.xprimary
    }

    /// 背景がテーマ背景色ベースなので、文字はテーマの文字色を使う
    private var textColor: Color {
        colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1
    }

    private var sharedPlanId: String? { sharedPlan?.id }
    private var isSharingPhotos: Bool {
        guard let sharedPlanId else { return false }
        _ = sharing.settingsVersion
        return sharing.isUploading(planId: sharedPlanId)
    }

    var body: some View {
        ZStack {
            backgroundGradient

            VStack(spacing: 0) {
                headerBar

                if photos.isEmpty {
                    VStack(spacing: 10) {
                        notes
                        Spacer(minLength: 0)
                        emptyStateView
                        Spacer(minLength: 0)
                    }
                } else {
                    photoGridView
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isSelectionMode {
                selectionToolbar
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                animatePhotos = true
            }
        }
        .task { await syncShared() }
        .sheet(isPresented: $showImagePicker) {
            MultiPhotoPicker { images in
                guard !images.isEmpty else { return }
                albumManager.addPhotos(images, to: album.id)
                ReviewRequestManager.shared.record(.photosAdded)
                Task { await syncShared() }
            }
        }
        .sheet(isPresented: $showAlbumEditor) {
            if let currentAlbum {
                AlbumEditorView(album: currentAlbum)
            }
        }
        .fullScreenCover(item: Binding(
            get: { viewerIndex.map { PhotoViewerTarget(index: $0) } },
            set: { viewerIndex = $0?.index }
        )) { target in
            PhotoViewerView(
                albumId: album.id,
                startIndex: target.index,
                albumColor: albumColor
            )
        }
        .confirmationDialog(
            selectedPhotos.count == 1 ? "この写真を削除しますか？" : "\(selectedPhotos.count)枚の写真を削除しますか？",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) {
                deleteSelectedPhotos()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text(sharedPlan == nil
                 ? "削除した写真は元に戻せません"
                 : "削除した写真は元に戻せません。自分が共有した写真は、同行者のアルバムからも消えます")
        }
        .confirmationDialog("自分の写真を同行者と共有しますか？", isPresented: $confirmsStartSharing,
                            titleVisibility: .visible) {
            Button("共有する") { setSharing(true) }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text(photos.isEmpty
                 ? "これから足す写真が、この旅行の同行者のアルバムにも入ります。共有コードで参加した人なら誰でも見られます。"
                 : "このアルバムの写真\(photos.count)枚と、これから足す写真が、この旅行の同行者のアルバムにも入ります。共有コードで参加した人なら誰でも見られます。")
        }
        .confirmationDialog("写真の共有をやめますか？", isPresented: $confirmsStopSharing, titleVisibility: .visible) {
            Button("共有をやめる", role: .destructive) { setSharing(false) }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("自分が共有した写真を、同行者のアルバムから消します。この端末のアルバムには残ります。")
        }
    }

    // MARK: - 見出し

    private var headerBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                if isSelectionMode {
                    Button(selectedPhotos.count == photos.count ? "すべて解除" : "すべて選択") {
                        toggleSelectAll()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(albumColor)
                } else {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.down")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(albumColor)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(albumColor.opacity(0.12)))
                    }
                    .accessibilityLabel("閉じる")
                }

                Spacer(minLength: 0)

                if isSelectionMode {
                    Button("キャンセル") { exitSelectionMode() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(albumColor)
                } else {
                    if !photos.isEmpty {
                        Button("選択") {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isSelectionMode = true
                            }
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(albumColor)
                    }
                    moreMenu
                    addButton
                }
            }
            .buttonStyle(.plain)

            Text(isSelectionMode ? selectionTitle : (currentAlbum?.title ?? album.title))
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundColor(textColor)
                .lineLimit(2)
                .minimumScaleFactor(0.7)

            if !isSelectionMode {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        chip(icon: "photo.on.rectangle.angled", text: "\(photos.count)枚")
                        chip(icon: "calendar", text: "\(formatDate(currentAlbum?.updatedAt ?? album.updatedAt)) 更新")
                        sharingChip
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
    }

    /// 写真を足す。思い出タブの「記録」と同じカプセル
    private var addButton: some View {
        Button { showImagePicker = true } label: {
            Label("追加", systemImage: "plus")
                .font(.subheadline.weight(.bold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(Capsule().fill(albumColor))
        }
        .accessibilityLabel("写真を追加")
    }

    /// アルバムの編集と、同行者との共有の切り替え
    private var moreMenu: some View {
        Menu {
            Button { showAlbumEditor = true } label: {
                Label("アルバムを編集", systemImage: "slider.horizontal.3")
            }
            if sharedPlan != nil {
                if isSharingPhotos {
                    Button(role: .destructive) { confirmsStopSharing = true } label: {
                        Label("写真の共有をやめる", systemImage: "person.2.slash")
                    }
                } else {
                    Button { confirmsStartSharing = true } label: {
                        Label("同行者と写真を共有", systemImage: "person.2")
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.subheadline.weight(.bold))
                .foregroundColor(albumColor)
                .frame(width: 36, height: 36)
                .background(Circle().fill(albumColor.opacity(0.12)))
        }
        .accessibilityLabel("その他")
    }

    /// 共有の様子。共有しているとき・やり取りしているとき・失敗したときだけ出す
    @ViewBuilder
    private var sharingChip: some View {
        if let sharedPlan, let sharedPlanId {
            if sharing.syncingPlanIds.contains(sharedPlanId) {
                HStack(spacing: 5) {
                    ProgressView().controlSize(.mini)
                    Text("同行者とやり取り中").font(.caption.weight(.semibold))
                }
                .foregroundColor(albumColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(albumColor.opacity(0.12), in: Capsule())
            } else if sharing.failedPlanIds.contains(sharedPlanId), let userId {
                Button {
                    Task { await sharing.sync(plan: sharedPlan, userId: userId) }
                } label: {
                    chip(icon: "arrow.clockwise", text: "やり取りできませんでした・もう一度",
                         color: themeManager.currentTheme.error)
                }
                .buttonStyle(.plain)
            } else if isSharingPhotos {
                chip(icon: "person.2.fill", text: "同行者と共有中")
            }
        }
    }

    private func chip(icon: String, text: String, color: Color? = nil) -> some View {
        let tint = color ?? albumColor
        return HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption2.weight(.semibold))
            Text(text)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundColor(tint)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(tint.opacity(0.12), in: Capsule())
    }

    /// 写真の上に出す案内（端末の中だけに保存される・同行者と見せ合える）
    @ViewBuilder
    private var notes: some View {
        VStack(spacing: 8) {
            // 未購入のときだけ出る。写真を入れる場所に置いておく
            DeviceOnlyPhotoNote()
            if let sharedPlanId, !sharing.isBannerDismissed(planId: sharedPlanId) {
                SharedAlbumBanner(tint: albumColor,
                                  onShare: { confirmsStartSharing = true },
                                  onDismiss: {
                                      withAnimation(.easeInOut(duration: 0.2)) {
                                          sharing.dismissBanner(planId: sharedPlanId)
                                      }
                                  })
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Selection

    private var selectionTitle: String {
        selectedPhotos.isEmpty ? "写真を選択" : "\(selectedPhotos.count)枚を選択中"
    }

    private var selectionToolbar: some View {
        HStack {
            Button(action: { showDeleteConfirmation = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "trash.fill")
                    Text("削除")
                }
                .font(.headline)
                .foregroundColor(selectedPhotos.isEmpty ? themeManager.currentTheme.secondaryText : .white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(selectedPhotos.isEmpty
                              ? themeManager.currentTheme.secondaryText.opacity(0.15)
                              : themeManager.currentTheme.error)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(selectedPhotos.isEmpty)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private func toggleSelection(_ fileName: String) {
        if selectedPhotos.contains(fileName) {
            selectedPhotos.remove(fileName)
        } else {
            selectedPhotos.insert(fileName)
        }
    }

    private func toggleSelectAll() {
        if selectedPhotos.count == photos.count {
            selectedPhotos.removeAll()
        } else {
            selectedPhotos = Set(photos)
        }
    }

    private func exitSelectionMode() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isSelectionMode = false
            selectedPhotos.removeAll()
        }
    }

    private func deleteSelectedPhotos() {
        let targets = Array(selectedPhotos)
        albumManager.removePhotos(fileNames: targets, from: album.id)
        exitSelectionMode()
    }

    private func deletePhoto(_ fileName: String) {
        albumManager.removePhotos(fileNames: [fileName], from: album.id)
    }

    // MARK: - 共有（3.8）

    /// 共有した旅行のアルバムなら、同行者と写真を突き合わせる
    private func syncShared() async {
        guard let sharedPlan, let userId else { return }
        await SharedAlbumSync.shared.sync(plan: sharedPlan, userId: userId)
    }

    private func setSharing(_ enabled: Bool) {
        guard let sharedPlan, let userId else { return }
        Task { await sharing.setUploading(enabled, plan: sharedPlan, userId: userId) }
    }

    // MARK: - Background

    /// 思い出タブと同じテーマの背景に、アルバムの色をうっすら重ねる
    private var backgroundGradient: some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark
                    ? [themeManager.currentTheme.gradientDark, themeManager.currentTheme.dark]
                    : [themeManager.currentTheme.gradientLight, themeManager.currentTheme.light],
                startPoint: .top,
                endPoint: .bottom
            )
            LinearGradient(
                colors: [albumColor.opacity(colorScheme == .dark ? 0.22 : 0.12), .clear],
                startPoint: .top,
                endPoint: .center
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 14) {
            Image(systemName: currentAlbum?.icon ?? album.icon)
                .font(.system(size: 34, weight: .semibold))
                .foregroundColor(albumColor)
                .frame(width: 84, height: 84)
                .background(Circle().fill(albumColor.opacity(0.12)))

            Text("写真がありません")
                .font(.title3.weight(.bold))
                .foregroundColor(textColor)

            Text(sharedPlan == nil
                 ? "右上の「追加」から写真を入れましょう"
                 : "右上の「追加」から写真を入れましょう。同行者が共有した写真もここに入ります")
                .font(.subheadline)
                .foregroundColor(themeManager.currentTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                showImagePicker = true
            } label: {
                Label("写真を追加", systemImage: "plus")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 13)
                    .background(Capsule().fill(albumColor))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(.bottom, 60)
    }

    // MARK: - Photo Grid View
    private var photoGridView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                notes

                // 写真アプリのように隙間を細くして、写真を大きく見せる
                IsWideLayoutReader { isWide in
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: isWide ? 5 : 3),
                              spacing: 4) {
                        ForEach(Array(photos.enumerated()), id: \.element) { index, fileName in
                            PhotoThumbnail(
                                fileName: fileName,
                                albumColor: albumColor,
                                isSelectionMode: isSelectionMode,
                                isSelected: selectedPhotos.contains(fileName),
                                onTap: {
                                    if isSelectionMode {
                                        toggleSelection(fileName)
                                    } else {
                                        viewerIndex = index
                                    }
                                },
                                onDelete: { deletePhoto(fileName) },
                                onStartSelection: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        isSelectionMode = true
                                        selectedPhotos = [fileName]
                                    }
                                }
                            )
                            .opacity(animatePhotos ? 1 : 0)
                            .scaleEffect(animatePhotos ? 1 : 0.94)
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.85)
                                    .delay(min(Double(index) * 0.02, 0.3)),
                                value: animatePhotos
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }
            .padding(.bottom, 24)
        }
        .refreshable { await syncShared() }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}

// MARK: - Photo Thumbnail
struct PhotoThumbnail: View {
    let fileName: String
    let albumColor: Color
    let isSelectionMode: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    let onStartSelection: () -> Void

    @ObservedObject private var albumManager = AlbumManager.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @State private var image: UIImage?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // セル幅に収まる正方形を土台にし、その上に画像を敷いて切り抜く。
            // 画像側に aspectRatio(_, contentMode: .fill) を付けるとセルより大きくなり隣と重なる
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Rectangle()
                            .fill(albumColor.opacity(0.15))
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(albumColor.opacity(0.4))
                            )
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                        .stroke(albumColor, lineWidth: isSelected ? 3 : 0)
                )
                // 選択中は少し縮めて、選ばれていることが一目で分かるようにする
                .scaleEffect(isSelected ? 0.92 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
                .contentShape(Rectangle())
                .onTapGesture { onTap() }
                .contextMenu {
                    // 長押しは標準のコンテキストメニューにする（独自ボタンより見つけやすい）
                    if !isSelectionMode {
                        Button {
                            onStartSelection()
                        } label: {
                            Label("選択", systemImage: "checkmark.circle")
                        }

                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                    }
                }

            if isSelectionMode {
                ZStack {
                    Circle()
                        .fill(isSelected ? albumColor : Color.black.opacity(0.35))
                        .frame(width: 24, height: 24)
                    Circle()
                        .stroke(Color.white, lineWidth: 1.5)
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .padding(6)
                .allowsHitTesting(false)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .task(id: fileName) {
            image = albumManager.thumbnail(fileName: fileName)
        }
    }
}

// MARK: - Photo Viewer Target
struct PhotoViewerTarget: Identifiable {
    let index: Int
    var id: Int { index }
}

// MARK: - Photo Viewer (スワイプで前後の写真へ移動できる)
struct PhotoViewerView: View {
    let albumId: String
    let startIndex: Int
    let albumColor: Color

    @Environment(\.dismiss) var dismiss
    @ObservedObject private var albumManager = AlbumManager.shared
    @State private var currentIndex: Int
    @State private var shareImage: UIImage?
    @State private var showDeleteConfirm = false

    /// 削除に追従させるため、アルバムから都度取得する
    private var fileNames: [String] {
        albumManager.albums.first(where: { $0.id == albumId })?.photoFileNames ?? []
    }

    init(albumId: String, startIndex: Int, albumColor: Color) {
        self.albumId = albumId
        self.startIndex = startIndex
        self.albumColor = albumColor
        _currentIndex = State(initialValue: startIndex)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(fileNames.enumerated()), id: \.element) { index, fileName in
                    ZoomablePhotoView(fileName: fileName)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(Color.black.opacity(0.45)))
                    }
                    .accessibilityLabel("閉じる")

                    Spacer()

                    if fileNames.count > 1 {
                        Text("\(currentIndex + 1) / \(fileNames.count)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(Color.black.opacity(0.45)))
                    }

                    Spacer()

                    HStack(spacing: 10) {
                        Button(action: prepareShare) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Circle().fill(Color.black.opacity(0.45)))
                        }
                        .accessibilityLabel("共有")

                        Button(action: { showDeleteConfirm = true }) {
                            Image(systemName: "trash")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Circle().fill(Color.black.opacity(0.45)))
                        }
                        .accessibilityLabel("この写真を削除")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()
            }
        }
        .sheet(item: Binding(
            get: { shareImage.map { ShareImageItem(image: $0) } },
            set: { shareImage = $0?.image }
        )) { item in
            ShareSheet(items: [item.image])
        }
        .confirmationDialog("この写真を削除しますか？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("削除", role: .destructive) { deleteCurrent() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("削除した写真は元に戻せません")
        }
        .onChange(of: fileNames.count) { _, newCount in
            // 削除で末尾が消えた場合に添字がはみ出さないようにする
            if newCount == 0 {
                dismiss()
            } else if currentIndex >= newCount {
                currentIndex = newCount - 1
            }
        }
    }

    private func prepareShare() {
        guard fileNames.indices.contains(currentIndex) else { return }
        shareImage = albumManager.loadPhoto(fileName: fileNames[currentIndex])
    }

    private func deleteCurrent() {
        guard fileNames.indices.contains(currentIndex) else { return }
        albumManager.removePhotos(fileNames: [fileNames[currentIndex]], from: albumId)
    }
}

// MARK: - Zoomable Photo
struct ZoomablePhotoView: View {
    let fileName: String

    @ObservedObject private var albumManager = AlbumManager.shared
    @State private var image: UIImage?
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black

                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            SimultaneousGesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        scale = min(max(lastScale * value, 0.8), 5.0)
                                    }
                                    .onEnded { _ in
                                        lastScale = scale
                                        if scale <= 1.0 {
                                            resetZoom()
                                        }
                                    },
                                DragGesture()
                                    .onChanged { value in
                                        // 等倍のときはページ送りを優先するのでドラッグは受け付けない
                                        guard scale > 1.0 else { return }
                                        offset = clampedOffset(
                                            CGSize(
                                                width: lastOffset.width + value.translation.width,
                                                height: lastOffset.height + value.translation.height
                                            ),
                                            in: geometry.size
                                        )
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                    }
                            )
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                if scale > 1.0 {
                                    resetZoom()
                                } else {
                                    scale = 2.5
                                    lastScale = 2.5
                                }
                            }
                        }
                } else {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
            }
        }
        .task(id: fileName) {
            image = albumManager.loadPhoto(fileName: fileName)
        }
    }

    private func resetZoom() {
        scale = 1.0
        lastScale = 1.0
        offset = .zero
        lastOffset = .zero
    }

    /// 拡大した分だけしか動かせないようにして、画像を画面外へ逃がさない
    private func clampedOffset(_ proposed: CGSize, in size: CGSize) -> CGSize {
        let maxX = max((size.width * scale - size.width) / 2, 0)
        let maxY = max((size.height * scale - size.height) / 2, 0)
        return CGSize(
            width: min(max(proposed.width, -maxX), maxX),
            height: min(max(proposed.height, -maxY), maxY)
        )
    }
}

// MARK: - Share
struct ShareImageItem: Identifiable {
    let image: UIImage
    var id: String { String(describing: ObjectIdentifier(image)) }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    /// 何をして終わったかを呼び出し側に伝える。
    /// 写真に保存したときは共有シートが黙って閉じるだけで、
    /// 保存できたのか分からないため
    var onComplete: ((UIActivity.ActivityType?, Bool) -> Void)? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { activityType, completed, _, _ in
            onComplete?(activityType, completed)
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
