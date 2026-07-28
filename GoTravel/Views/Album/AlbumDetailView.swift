import SwiftUI

// MARK: - Album Detail View
struct AlbumDetailView: View {
    let album: Album
    @ObservedObject private var albumManager = AlbumManager.shared
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

    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient

                if photos.isEmpty {
                    emptyStateView
                } else {
                    photoGridView
                }
            }
            .navigationTitle(navigationTitleText)
            .navigationBarTitleDisplayMode(isSelectionMode ? .inline : .large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if isSelectionMode {
                        Button("キャンセル") { exitSelectionMode() }
                            .foregroundColor(albumColor)
                    } else {
                        Button("閉じる") { dismiss() }
                            .foregroundColor(albumColor)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSelectionMode {
                        Button(selectedPhotos.count == photos.count ? "すべて解除" : "すべて選択") {
                            toggleSelectAll()
                        }
                        .foregroundColor(albumColor)
                    } else {
                        HStack(spacing: 14) {
                            if !photos.isEmpty {
                                Button("選択") {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        isSelectionMode = true
                                    }
                                }
                                .foregroundColor(albumColor)
                            }

                            Button(action: { showAlbumEditor = true }) {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(albumColor)
                            }
                            .accessibilityLabel("アルバムを編集")

                            Button(action: {
                                showImagePicker = true
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(albumColor)
                            }
                            .accessibilityLabel("写真を追加")
                        }
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
        }
        .sheet(isPresented: $showImagePicker) {
            MultiPhotoPicker { images in
                guard !images.isEmpty else { return }
                albumManager.addPhotos(images, to: album.id)
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
            Text("削除した写真は元に戻せません")
        }
    }

    // MARK: - Selection

    private var navigationTitleText: String {
        if isSelectionMode { return selectionTitle }
        return currentAlbum?.title ?? album.title
    }

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

    // MARK: - Background
    private var backgroundGradient: some View {
        let base: Color = colorScheme == .dark
            ? themeManager.currentTheme.backgroundDark
            : themeManager.currentTheme.backgroundLight

        return LinearGradient(
            colors: [albumColor.opacity(colorScheme == .dark ? 0.35 : 0.20), base],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 15) {
            Image(systemName: currentAlbum?.icon ?? album.icon)
                .font(.system(size: 80))
                .foregroundColor(albumColor.opacity(0.5))

            Text("写真がありません")
                .font(.title2.bold())
                .foregroundColor(textColor)

            Text("＋ボタンから写真を追加しましょう")
                .font(.subheadline)
                .foregroundColor(themeManager.currentTheme.secondaryText)
                .multilineTextAlignment(.center)

            Button(action: {
                showImagePicker = true
            }) {
                Label("写真を追加", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 15)
                    .background(
                        LinearGradient(
                            colors: [albumColor, albumColor.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(15)
                    .shadow(color: albumColor.opacity(0.5), radius: 10, x: 0, y: 5)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.top, 10)
        }
    }

    // MARK: - Photo Grid View
    private var photoGridView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                albumStatsSection

                // 固定サイズだと画面幅によって隙間ができるため、正方形の可変セルにする
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ], spacing: 8) {
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
                        .scaleEffect(animatePhotos ? 1 : 0.8)
                        .animation(
                            .spring(response: 0.6, dampingFraction: 0.8)
                                .delay(min(Double(index) * 0.03, 0.4)),
                            value: animatePhotos
                        )
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }

    // MARK: - Album Stats Section
    private var albumStatsSection: some View {
        HStack(spacing: 30) {
            StatCard(
                icon: "photo.on.rectangle.angled",
                title: "写真",
                value: "\(photos.count)",
                color: albumColor
            )

            StatCard(
                icon: "calendar",
                title: "更新日",
                value: formatDate(currentAlbum?.updatedAt ?? Date()),
                color: albumColor
            )
        }
        .padding(.horizontal)
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
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? albumColor : albumColor.opacity(0.3), lineWidth: isSelected ? 3 : 1)
                )
                // 選択中は少し縮めて、選ばれていることが一目で分かるようにする
                .scaleEffect(isSelected ? 0.92 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
                .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
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

// MARK: - Stat Card
struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var themeManager = ThemeManager.shared

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)

                Text(title)
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.secondaryText)
            }

            Text(value)
                .font(.title3.bold())
                // 白固定だとライトモードで背景に溶けるためテーマの文字色を使う
                .foregroundColor(colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(colorScheme == .dark
                      ? themeManager.currentTheme.secondaryBackgroundDark
                      : themeManager.currentTheme.backgroundLight)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
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

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
