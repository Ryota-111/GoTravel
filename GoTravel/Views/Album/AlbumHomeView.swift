import SwiftUI

// MARK: - Album Home View
struct AlbumHomeView: View {
    @ObservedObject private var albumManager = AlbumManager.shared
    @ObservedObject private var japanPhotoManager = JapanPhotoManager.shared
    // MainTabView から注入済みのインスタンスを使う（自前生成すると二重管理になる）
    @EnvironmentObject var travelPlanViewModel: TravelPlanViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme
    @State private var showCreateAlbum = false
    @State private var selectedAlbum: Album?
    @State private var animateCards = false
    @State private var editingAlbum: Album?

    // 写真一覧と同じ操作感で、まとめて削除できるようにする
    @State private var isSelectionMode = false
    @State private var selectedAlbumIds: Set<String> = []
    @State private var showDeleteConfirm = false

    /// 既定アルバム（日本全国フォトマップ）は削除できないので選択対象から外す
    private var deletableAlbums: [Album] {
        albumManager.albums.filter { !$0.isDefaultAlbum }
    }

    /// 日本全国フォトマップの写真は別管理なので、合計にはそちらの枚数を足す
    private var totalPhotoCount: Int {
        albumManager.albums.reduce(0) { total, album in
            total + (album.isJapanPhotoMap ? japanPhotoManager.photoCount : album.photoFileNames.count)
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient

                VStack(spacing: 0) {
                    headerBar

                    if albumManager.albums.isEmpty {
                        emptyState
                    } else {
                        albumGrid
                    }
                }

                if !isSelectionMode {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            fabButton
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 24)
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
                    animateCards = true
                }
            }
            .task {
                if let userId = authVM.userId {
                    albumManager.setup(userId: userId)
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $showCreateAlbum) {
            CreateAlbumView(travelPlans: travelPlanViewModel.travelPlans)
        }
        .sheet(item: $editingAlbum) { album in
            AlbumEditorView(album: album)
        }
        .fullScreenCover(item: $selectedAlbum) { album in
            // タイトル文字列ではなく種別で判定する
            if album.isJapanPhotoMap {
                JapanPhotoView()
            } else {
                AlbumDetailView(album: album)
            }
        }
        .confirmationDialog(deleteConfirmTitle, isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("削除", role: .destructive) { deleteSelectedAlbums() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("アルバム内の写真もすべて削除されます。この操作は取り消せません。")
        }
    }

    // MARK: - Album Grid
    private var albumGrid: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 14),
                GridItem(.flexible(), spacing: 14)
            ], spacing: 14) {
                ForEach(Array(albumManager.albums.enumerated()), id: \.element.id) { index, album in
                    AlbumCard(
                        album: album,
                        isSelectionMode: isSelectionMode,
                        isSelected: selectedAlbumIds.contains(album.id),
                        onTap: { handleTap(on: album) },
                        onEdit: { editingAlbum = album },
                        onDelete: { requestDelete(album) },
                        onStartSelection: { startSelection(with: album) }
                    )
                    .opacity(animateCards ? 1 : 0)
                    .offset(y: animateCards ? 0 : 20)
                    .animation(
                        // 枚数が多くても最後のカードが待たされ続けないよう上限を設ける
                        .spring(response: 0.6, dampingFraction: 0.8)
                            .delay(min(Double(index) * 0.06, 0.5)),
                        value: animateCards
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, isSelectionMode ? 20 : 100)
        }
    }

    // MARK: - Background
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: colorScheme == .dark ? [themeManager.currentTheme.gradientDark, themeManager.currentTheme.dark] : [themeManager.currentTheme.gradientLight, themeManager.currentTheme.light]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Colors
    private var accentColor: Color {
        colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1
    }

    private var mainColor: Color {
        themeManager.currentTheme.xprimary
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(isSelectionMode ? selectionTitle : "アルバム")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .foregroundColor(accentColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer(minLength: 0)

                if isSelectionMode {
                    Button("キャンセル") { exitSelectionMode() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(mainColor)
                } else if !deletableAlbums.isEmpty {
                    Button("選択") { enterSelectionMode() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(mainColor)
                }
            }

            if isSelectionMode {
                Button(action: toggleSelectAll) {
                    Text(selectedAlbumIds.count == deletableAlbums.count ? "すべて解除" : "すべて選択")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(mainColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(mainColor.opacity(0.12), in: Capsule())
                }
                .buttonStyle(PlainButtonStyle())
            } else if !albumManager.albums.isEmpty {
                HStack(spacing: 8) {
                    statChip(icon: "rectangle.stack.fill", text: "\(albumManager.albums.count)個のアルバム")
                    statChip(icon: "photo.on.rectangle.angled", text: "\(totalPhotoCount)枚")
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 14)
    }

    private func statChip(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption2.weight(.semibold))
            Text(text)
                .font(.caption.weight(.semibold))
        }
        .foregroundColor(mainColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(mainColor.opacity(0.12), in: Capsule())
    }

    // MARK: - Selection
    private var selectionTitle: String {
        selectedAlbumIds.isEmpty ? "アルバムを選択" : "\(selectedAlbumIds.count)個を選択中"
    }

    private var deleteConfirmTitle: String {
        selectedAlbumIds.count == 1
            ? "このアルバムを削除しますか？"
            : "\(selectedAlbumIds.count)個のアルバムを削除しますか？"
    }

    private var selectionToolbar: some View {
        Button(action: { showDeleteConfirm = true }) {
            HStack(spacing: 6) {
                Image(systemName: "trash.fill")
                Text("削除")
            }
            .font(.headline)
            .foregroundColor(selectedAlbumIds.isEmpty ? themeManager.currentTheme.secondaryText : .white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(selectedAlbumIds.isEmpty
                          ? themeManager.currentTheme.secondaryText.opacity(0.15)
                          : themeManager.currentTheme.error)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(selectedAlbumIds.isEmpty)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private func handleTap(on album: Album) {
        if isSelectionMode {
            // 既定アルバムは削除できないため選択させない
            guard !album.isDefaultAlbum else { return }
            if selectedAlbumIds.contains(album.id) {
                selectedAlbumIds.remove(album.id)
            } else {
                selectedAlbumIds.insert(album.id)
            }
        } else {
            selectedAlbum = album
        }
    }

    private func enterSelectionMode() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isSelectionMode = true
        }
    }

    private func startSelection(with album: Album) {
        guard !album.isDefaultAlbum else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isSelectionMode = true
            selectedAlbumIds = [album.id]
        }
    }

    private func exitSelectionMode() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isSelectionMode = false
            selectedAlbumIds.removeAll()
        }
    }

    private func toggleSelectAll() {
        if selectedAlbumIds.count == deletableAlbums.count {
            selectedAlbumIds.removeAll()
        } else {
            selectedAlbumIds = Set(deletableAlbums.map(\.id))
        }
    }

    private func requestDelete(_ album: Album) {
        guard !album.isDefaultAlbum else { return }
        selectedAlbumIds = [album.id]
        showDeleteConfirm = true
    }

    private func deleteSelectedAlbums() {
        let targets = albumManager.albums.filter { selectedAlbumIds.contains($0.id) }
        for album in targets {
            albumManager.deleteAlbum(album)
        }
        exitSelectionMode()
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(themeManager.currentTheme.xprimary.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 44))
                    .foregroundColor(themeManager.currentTheme.xprimary.opacity(0.5))
            }

            VStack(spacing: 8) {
                Text("アルバムがありません")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(accentColor)
                Text("「+」ボタンからアルバムを作成しましょう")
                    .font(.subheadline)
                    .foregroundColor(themeManager.currentTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }

            Button(action: { showCreateAlbum = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("アルバムを作成")
                }
                .font(.headline.weight(.bold))
                .foregroundColor(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(themeManager.currentTheme.xprimary)
                        .shadow(color: themeManager.currentTheme.xprimary.opacity(0.4), radius: 8, x: 0, y: 4)
                )
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 40)
    }

    // MARK: - FAB
    private var fabButton: some View {
        Button(action: { showCreateAlbum = true }) {
            ZStack {
                Circle()
                    .fill(themeManager.currentTheme.xprimary)
                    .frame(width: 58, height: 58)
                    .shadow(color: themeManager.currentTheme.xprimary.opacity(0.45), radius: 12, x: 0, y: 5)
                Image(systemName: "plus")
                    .font(.title2.bold())
                    .foregroundColor(.white)
            }
        }
        .accessibilityLabel("アルバムを作成")
    }
}

// MARK: - Album Card
struct AlbumCard: View {
    let album: Album
    let isSelectionMode: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onStartSelection: () -> Void

    @ObservedObject private var albumManager = AlbumManager.shared
    @ObservedObject private var japanPhotoManager = JapanPhotoManager.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme

    /// 計算プロパティのままだと参照のたびにディスクから読み直すため、一度だけ読んで保持する
    @State private var recentPhotos: [UIImage] = []

    /// 日本全国フォトマップの写真は JapanPhotoManager が別に持っているため、枚数もそちらを見る
    private var photoCount: Int {
        album.isJapanPhotoMap ? japanPhotoManager.photoCount : album.photoFileNames.count
    }

    private func loadRecentPhotos() {
        recentPhotos = album.isJapanPhotoMap
            ? japanPhotoManager.recentThumbnails(limit: 4)
            : albumManager.recentThumbnails(from: album, limit: 4)
    }

    private var resolvedCoverColor: Color {
        let fallback = themeManager.currentTheme.xprimary
        guard let color = album.coverColor else { return fallback }
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else { return fallback }
        let brightness = 0.299 * r + 0.587 * g + 0.114 * b
        return brightness < 0.85 ? color : fallback
    }

    private var cardBg: Color {
        colorScheme == .dark
            ? themeManager.currentTheme.secondaryBackgroundDark
            : themeManager.currentTheme.backgroundLight
    }

    private var accentColor: Color {
        colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1
    }

    /// 選択モード中、既定アルバムは削除できないので選べないことを見た目でも示す
    private var isDimmed: Bool {
        isSelectionMode && album.isDefaultAlbum
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            photoPreviewSection
            albumInfoSection
        }
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    isSelected ? resolvedCoverColor : resolvedCoverColor.opacity(0.3),
                    lineWidth: isSelected ? 3 : 1
                )
        )
        .overlay(alignment: .topTrailing) { selectionBadge }
        .shadow(color: resolvedCoverColor.opacity(0.18), radius: 8, x: 0, y: 4)
        .opacity(isDimmed ? 0.45 : 1)
        .scaleEffect(isSelected ? 0.95 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelectionMode)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .contextMenu {
            // 長押しは標準のメニューにする（独自の編集モードより見つけやすい）
            if !isSelectionMode {
                Button {
                    onEdit()
                } label: {
                    Label("アルバムを編集", systemImage: "slider.horizontal.3")
                }

                if !album.isDefaultAlbum {
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
        }
        .task(id: album.photoFileNames) {
            loadRecentPhotos()
        }
        // 日本全国フォトマップは別管理なので、そちらの更新にも追従させる
        .task(id: japanPhotoManager.savedPrefectures) {
            if album.isJapanPhotoMap {
                loadRecentPhotos()
            }
        }
    }

    // MARK: - Selection Badge
    @ViewBuilder
    private var selectionBadge: some View {
        if isSelectionMode && !album.isDefaultAlbum {
            ZStack {
                Circle()
                    .fill(isSelected ? resolvedCoverColor : Color.black.opacity(0.35))
                    .frame(width: 26, height: 26)
                Circle()
                    .stroke(Color.white, lineWidth: 1.5)
                    .frame(width: 26, height: 26)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .padding(8)
            .allowsHitTesting(false)
            .transition(.scale.combined(with: .opacity))
        }
    }

    // MARK: - Photo Preview
    private var photoPreviewSection: some View {
        // 4:3 の可変サイズにして、端末幅が変わっても崩れないようにする
        Color.clear
            .aspectRatio(4.0 / 3.0, contentMode: .fit)
            .overlay {
                if recentPhotos.isEmpty {
                    emptyPhotoPreview
                } else if recentPhotos.count == 1 {
                    photoFill(recentPhotos[0])
                } else {
                    mosaicPreview
                }
            }
            .overlay(alignment: .bottomLeading) { photoCountBadge }
            .clipped()
    }

    private func photoFill(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
    }

    private var emptyPhotoPreview: some View {
        ZStack {
            LinearGradient(
                colors: [resolvedCoverColor.opacity(0.75), resolvedCoverColor.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: album.icon)
                .font(.system(size: 44))
                .foregroundColor(.white.opacity(0.85))
        }
    }

    /// 2x2 のモザイク。GeometryReader で幅を測らず、比率だけで組む
    private var mosaicPreview: some View {
        VStack(spacing: 2) {
            ForEach(0..<2, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(0..<2, id: \.self) { column in
                        let index = row * 2 + column
                        Group {
                            if index < recentPhotos.count {
                                photoFill(recentPhotos[index])
                            } else {
                                resolvedCoverColor.opacity(0.25)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var photoCountBadge: some View {
        if !recentPhotos.isEmpty {
            HStack(spacing: 4) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 10, weight: .semibold))
                Text("\(photoCount)")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial, in: Capsule())
            .environment(\.colorScheme, .dark)
            .padding(8)
        }
    }

    // MARK: - Info Section
    private var albumInfoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: album.icon)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(resolvedCoverColor)
                Text(album.title)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundColor(accentColor)
                    .lineLimit(1)
            }

            HStack(spacing: 6) {
                Text(photoCount == 0 ? "写真なし" : "\(photoCount)枚")
                    .font(.caption2)
                    .foregroundColor(themeManager.currentTheme.secondaryText)

                if album.travelPlanId != nil {
                    badge(icon: "airplane.departure", text: "旅行")
                }

                if album.isDefaultAlbum {
                    badge(icon: "lock.fill", text: "既定")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func badge(icon: String, text: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(text)
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundColor(resolvedCoverColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(resolvedCoverColor.opacity(0.14), in: Capsule())
    }
}

#Preview {
    AlbumHomeView()
        .environmentObject(AuthViewModel())
        .environmentObject(TravelPlanViewModel())
}
