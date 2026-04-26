import SwiftUI

// MARK: - Album Home View
struct AlbumHomeView: View {
    @StateObject private var albumManager = AlbumManager.shared
    @StateObject private var travelPlanViewModel = TravelPlanViewModel()
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme
    @State private var showCreateAlbum = false
    @State private var selectedAlbum: Album?
    @State private var animateCards = false
    @State private var albumToDelete: Album?
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient

                VStack(spacing: 0) {
                    headerBar

                    if albumManager.albums.isEmpty {
                        emptyState
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 14),
                                GridItem(.flexible(), spacing: 14)
                            ], spacing: 14) {
                                ForEach(Array(albumManager.albums.enumerated()), id: \.element.id) { index, album in
                                    AlbumCardWrapper(
                                        album: album,
                                        onTap: { selectedAlbum = album },
                                        onLongPress: {
                                            if !album.isDefaultAlbum {
                                                albumToDelete = album
                                                showDeleteConfirm = true
                                            }
                                        }
                                    )
                                    .opacity(animateCards ? 1 : 0)
                                    .offset(y: animateCards ? 0 : 20)
                                    .animation(
                                        .spring(response: 0.6, dampingFraction: 0.8).delay(Double(index) * 0.06),
                                        value: animateCards
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 100)
                        }
                    }
                }

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
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                    animateCards = true
                }
                if let userId = authVM.userId {
                    travelPlanViewModel.setupFetchedResultsController(userId: userId)
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $showCreateAlbum) {
            CreateAlbumView(travelPlans: travelPlanViewModel.travelPlans)
        }
        .fullScreenCover(item: $selectedAlbum) { album in
            if album.title == "日本全国フォトマップ" {
                JapanPhotoView()
            } else {
                AlbumDetailView(album: album)
            }
        }
        .confirmationDialog("このアルバムを削除しますか？", isPresented: $showDeleteConfirm, presenting: albumToDelete) { album in
            Button("削除", role: .destructive) {
                albumManager.deleteAlbum(album)
            }
        } message: { album in
            Text("「\(album.title)」を削除すると、アルバム内の写真もすべて削除されます。")
        }
    }

    // MARK: - Background
    private var backgroundGradient: some View {
        let colors: [Color]
        switch themeManager.currentTheme.type {
        case .whiteBlack:
            colors = [Color(white: 0.97), Color(white: 0.91)]
        default:
            colors = colorScheme == .dark
                ? [themeManager.currentTheme.backgroundDark, themeManager.currentTheme.secondaryBackgroundDark]
                : [themeManager.currentTheme.backgroundLight, themeManager.currentTheme.secondaryBackgroundLight]
        }
        return LinearGradient(gradient: Gradient(colors: colors), startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
    }

    // MARK: - Colors
    private var accentColor: Color {
        colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("アルバム")
                    .font(.title.weight(.bold))
                    .foregroundColor(accentColor)
                Text("\(albumManager.albums.count)個")
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.secondaryText)
            }

            Spacer()

            if !albumManager.albums.isEmpty {
                let totalPhotos = albumManager.albums.reduce(0) { $0 + $1.photoFileNames.count }
                HStack(spacing: 4) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.caption.weight(.semibold))
                    Text("\(totalPhotos)枚")
                        .font(.caption.weight(.semibold))
                }
                .foregroundColor(themeManager.currentTheme.xprimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(themeManager.currentTheme.xprimary.opacity(0.1))
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 14)
        .background(themeManager.currentTheme.xprimary.opacity(0.08))
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
    }
}

// MARK: - Album Card Wrapper
struct AlbumCardWrapper: View {
    let album: Album
    let onTap: () -> Void
    let onLongPress: () -> Void
    @State private var isPressed = false

    var body: some View {
        AlbumCard(album: album, isPressed: $isPressed)
            .onTapGesture { onTap() }
            .onLongPressGesture(minimumDuration: 0.5, pressing: { pressing in
                if !album.isDefaultAlbum {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isPressed = pressing
                    }
                }
            }, perform: { onLongPress() })
    }
}

// MARK: - Album Card
struct AlbumCard: View {
    let album: Album
    @Binding var isPressed: Bool
    @StateObject private var albumManager = AlbumManager.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme

    private var recentPhotos: [UIImage] {
        albumManager.getRecentPhotos(from: album, limit: 4)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            photoPreviewSection
            albumInfoSection
        }
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(cardBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(resolvedCoverColor.opacity(0.35), lineWidth: 1.5)
        )
        .shadow(color: resolvedCoverColor.opacity(0.2), radius: 8, x: 0, y: 4)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .overlay(deleteOverlay)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Photo Preview
    private var photoPreviewSection: some View {
        Group {
            if recentPhotos.isEmpty {
                emptyPhotoPreview
            } else if recentPhotos.count == 1 {
                singlePhotoPreview
            } else {
                multiPhotoPreview
            }
        }
        .frame(height: 130)
        .clipped()
    }

    private var emptyPhotoPreview: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    resolvedCoverColor.opacity(0.7),
                    resolvedCoverColor.opacity(0.4)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: album.icon)
                .font(.system(size: 46))
                .foregroundColor(.white.opacity(0.7))
        }
    }

    private var singlePhotoPreview: some View {
        Image(uiImage: recentPhotos[0])
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(height: 130)
    }

    private var multiPhotoPreview: some View {
        GeometryReader { geometry in
            let half = geometry.size.width / 2
            LazyVGrid(columns: [
                GridItem(.fixed(half), spacing: 2),
                GridItem(.fixed(half), spacing: 2)
            ], spacing: 2) {
                ForEach(0..<4, id: \.self) { index in
                    if index < recentPhotos.count {
                        Image(uiImage: recentPhotos[index])
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: half - 1, height: half - 1)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(resolvedCoverColor.opacity(0.2))
                            .frame(width: half - 1, height: half - 1)
                    }
                }
            }
        }
    }

    // MARK: - Info Section
    private var albumInfoSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: album.icon)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(resolvedCoverColor)
                Text(album.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(accentColor)
                    .lineLimit(1)
            }

            HStack(spacing: 6) {
                HStack(spacing: 3) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 10))
                    Text("\(album.photoFileNames.count)枚")
                        .font(.system(size: 11))
                }
                .foregroundColor(themeManager.currentTheme.secondaryText)

                if album.travelPlanId != nil {
                    HStack(spacing: 3) {
                        Image(systemName: "airplane.departure")
                            .font(.system(size: 10))
                        Text("旅行")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(resolvedCoverColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(resolvedCoverColor.opacity(0.12))
                    .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Delete Overlay
    @ViewBuilder
    private var deleteOverlay: some View {
        if isPressed && !album.isDefaultAlbum {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(themeManager.currentTheme.error.opacity(0.75))
                VStack(spacing: 8) {
                    Image(systemName: "trash.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                    Text("長押しで削除")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
        }
    }
}

extension AlbumType: Hashable {}

#Preview {
    AlbumHomeView()
        .environmentObject(AuthViewModel())
}
