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
                
                VStack {
                    planEventsTitleSection
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            headerSection
                            
                            albumGridSection
                        }
                        .padding()
                    }
                    
                    // Floating Action Button
                    ZStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: {
                                showCreateAlbum = true
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    themeManager.currentTheme.xprimary,
                                                    themeManager.currentTheme.xprimary.opacity(0.8)
                                                ]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 60, height: 60)
                                        .shadow(
                                            color: themeManager.currentTheme.xprimary.opacity(0.5),
                                            radius: 15,
                                            x: 0,
                                            y: 5
                                        )
                                    
                                    Image(systemName: "plus")
                                        .font(.title2.bold())
                                        .foregroundColor(DLtextColor)
                                }
                            }
                            .padding(.trailing, 20)
                            .padding(.bottom, 20)
                        }
                    }
                }
                .onAppear {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                        animateCards = true
                    }
                    // Setup Core Data FetchedResultsController
                    if let userId = authVM.userId {
                        travelPlanViewModel.setupFetchedResultsController(userId: userId)
                    }
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
        LinearGradient(
            gradient: Gradient(colors: colorScheme == .dark ? [themeManager.currentTheme.gradientDark, themeManager.currentTheme.dark] : [themeManager.currentTheme.gradientLight, themeManager.currentTheme.light]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Color
    private var textColor: Color {
        colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1
    }
    
    private var xtextColor: Color {
        colorScheme == .dark ? themeManager.currentTheme.accent1 : themeManager.currentTheme.accent2
    }
    
    private var DLtextColor: Color {
        colorScheme == .dark ? themeManager.currentTheme.light : themeManager.currentTheme.dark
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? themeManager.currentTheme.accent2.opacity(0.7) : themeManager.currentTheme.accent1.opacity(0.6)
    }
    
    // MARK: - Title Section
    private var planEventsTitleSection: some View {
        HStack {
            Text("アルバム")
                .font(.title.weight(.semibold))
                .foregroundColor(textColor)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("思い出をアルバムに")
                .font(.title2.bold())
                .foregroundColor(textColor)

            Text("\(albumManager.albums.count)個のアルバム")
                .font(.subheadline)
                .foregroundColor(secondaryTextColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 10)
    }

    // MARK: - Album Grid Section
    private var albumGridSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ], spacing: 16) {
            ForEach(Array(albumManager.albums.enumerated()), id: \.element.id) { index, album in
                AlbumCardWrapper(
                    album: album,
                    onTap: {
                        selectedAlbum = album
                    },
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
                    .spring(response: 0.6, dampingFraction: 0.8)
                        .delay(Double(index) * 0.05),
                    value: animateCards
                )
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
            .onTapGesture {
                onTap()
            }
            .onLongPressGesture(minimumDuration: 0.5, pressing: { pressing in
                if !album.isDefaultAlbum {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isPressed = pressing
                    }
                }
            }, perform: {
                onLongPress()
            })
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

    // coverColorが白に近い場合はアイコン色にフォールバック
    private var resolvedCoverColor: Color {
        let fallback = themeManager.currentTheme.xprimary
        guard let color = album.coverColor else { return fallback }
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else { return fallback }
        let brightness = 0.299 * r + 0.587 * g + 0.114 * b
        return brightness < 0.85 ? color : fallback
    }
    
    private var textColor: Color {
        colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? themeManager.currentTheme.accent2.opacity(0.7) : themeManager.currentTheme.accent1.opacity(0.6)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Photo Preview Grid
            photoPreviewSection

            // Album Info Section
            albumInfoSection
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    colorScheme == .dark ?
                    themeManager.currentTheme.light.opacity(0.15) :
                        themeManager.currentTheme.light.opacity(0.9)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            resolvedCoverColor.opacity(0.5),
                            resolvedCoverColor.opacity(0.2)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
        .shadow(
            color: resolvedCoverColor.opacity(0.5),
            radius: 10,
            x: 0,
            y: 5
        )
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .overlay(
            // Delete indicator overlay
            Group {
                if isPressed && !album.isDefaultAlbum {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(themeManager.currentTheme.error.opacity(0.3))

                        VStack(spacing: 8) {
                            Image(systemName: "trash.fill")
                                .font(.title)
                                .foregroundColor(.white)

                            Text("長押しで削除")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                        }
                    }
                    .transition(.opacity)
                }
            }
        )
    }

    // MARK: - Photo Preview Section
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
        .cornerRadius(radius: 20, corners: .allCorners)
        .frame(height: 140)
        .clipped()
    }

    private var emptyPhotoPreview: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    resolvedCoverColor.opacity(0.6),
                    resolvedCoverColor.opacity(0.3)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: album.icon)
                .font(.system(size: 50))
                .foregroundColor(.white.opacity(0.6))
        }
    }

    private var singlePhotoPreview: some View {
        Image(uiImage: recentPhotos[0])
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(height: 140)
    }

    private var multiPhotoPreview: some View {
        GeometryReader { geometry in
            let gridSize = geometry.size.width / 2

            LazyVGrid(columns: [
                GridItem(.fixed(gridSize), spacing: 2),
                GridItem(.fixed(gridSize), spacing: 2)
            ], spacing: 2) {
                ForEach(0..<4, id: \.self) { index in
                    if index < recentPhotos.count {
                        Image(uiImage: recentPhotos[index])
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: gridSize - 1, height: gridSize - 1)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        resolvedCoverColor.opacity(0.4),
                                        resolvedCoverColor.opacity(0.2)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: gridSize - 1, height: gridSize - 1)
                    }
                }
            }
        }
    }

    // MARK: - Album Info Section
    private var albumInfoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: album.icon)
                    .font(.subheadline)
                    .foregroundColor(resolvedCoverColor)

                Text(album.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(textColor)
                    .lineLimit(1)
            }

            HStack(spacing: 4) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.caption2)
                    .foregroundColor(secondaryTextColor)

                Text("\(album.photoFileNames.count)枚")
                    .font(.caption)
                    .foregroundColor(secondaryTextColor)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}



// MARK: - Mode Button
struct ModeButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme

    private var textColor: Color {
        themeManager.currentTheme.accent2
    }

    private var buttonTextColor: Color {
        isSelected ? textColor : themeManager.currentTheme.secondaryText
    }

    private var backgroundColor: Color {
        if isSelected {
            return themeManager.currentTheme.primary.opacity(0.3)
        } else {
            return themeManager.currentTheme.dark.opacity(0.1)
        }
    }

    private var borderColor: Color {
        isSelected ? textColor : themeManager.currentTheme.secondaryText.opacity(0.5)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(buttonTextColor)

                Text(title)
                    .font(.caption)
                    .foregroundColor(buttonTextColor)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: 2)
            )
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Travel Plan Selection Card
struct TravelPlanSelectionCard: View {
    let plan: TravelPlan
    let isSelected: Bool
    let action: () -> Void
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    (plan.cardColor ?? themeManager.currentTheme.primary).opacity(0.8),
                                    (plan.cardColor ?? themeManager.currentTheme.primary).opacity(0.5)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)

                    Image(systemName: "airplane.departure")
                        .font(.title3)
                        .foregroundColor(themeManager.currentTheme.accent2)
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.title)
                        .font(.headline)
                        .foregroundColor(themeManager.currentTheme.accent2)

                    Text(plan.destination)
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.accent2)
                }

                Spacer()

                // Selection Indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(themeManager.currentTheme.success)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(themeManager.currentTheme.light)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? themeManager.currentTheme.success : themeManager.currentTheme.accent2.opacity(0.5),
                        lineWidth: 2
                    )
            )
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Album Type Button
struct AlbumTypeButton: View {
    let type: AlbumType
    let isSelected: Bool
    let action: () -> Void
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme

    private var textColor: Color {
        colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    type.coverColor,
                                    type.coverColor
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                        .overlay(
                            RoundedRectangle(cornerRadius: 100)
                                .stroke(type.defaultCoverColor, lineWidth: 2
                                )
                        )

                    Image(systemName: type.icon)
                        .font(.title2)
                        .foregroundColor(themeManager.currentTheme.light)
                }
                .scaleEffect(isSelected ? 1.1 : 1.0)
                .shadow(
                    color: isSelected ? type.defaultCoverColor.opacity(0.6) : .clear,
                    radius: 10,
                    x: 0,
                    y: 5
                )

                Text(type.title)
                    .font(.caption)
                    .foregroundColor(type.defaultCoverColor)
                    .lineLimit(1)
            }
            .frame(width: 45)
            .padding()
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

extension AlbumType: Hashable {}

#Preview {
    AlbumHomeView()
        .environmentObject(AuthViewModel())
}
