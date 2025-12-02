import SwiftUI

// MARK: - Album Home View
struct AlbumHomeView: View {
    @StateObject private var albumManager = AlbumManager.shared
    @StateObject private var travelPlanViewModel = TravelPlanViewModel()
    @EnvironmentObject var authVM: AuthViewModel
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

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        headerSection

                        albumGridSection
                    }
                    .padding()
                    .padding(.bottom, 80) // Add space for floating button
                }

                // Floating Action Button
                VStack {
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
                                                Color.orange,
                                                Color.orange.opacity(0.8)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 60, height: 60)
                                    .shadow(
                                        color: Color.orange.opacity(0.5),
                                        radius: 15,
                                        x: 0,
                                        y: 5
                                    )

                                Image(systemName: "plus")
                                    .font(.title2.bold())
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("アルバム")
            .navigationBarTitleDisplayMode(.large)
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
            gradient: Gradient(colors: colorScheme == .dark ?
                [.blue.opacity(0.7), .black] :
                [.blue.opacity(0.6), .white.opacity(0.3)]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("思い出をアルバムに")
                .font(.title2.bold())
                .foregroundColor(.white)

            Text("\(albumManager.albums.count)個のアルバム")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
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
    @Environment(\.colorScheme) var colorScheme

    private var recentPhotos: [UIImage] {
        albumManager.getRecentPhotos(from: album, limit: 4)
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
                        Color.white.opacity(0.15) :
                        Color.white.opacity(0.9)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            (album.coverColor ?? .blue).opacity(0.5),
                            (album.coverColor ?? .blue).opacity(0.2)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
        .shadow(
            color: (album.coverColor ?? .blue).opacity(0.3),
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
                            .fill(Color.red.opacity(0.3))

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
                    (album.coverColor ?? .blue).opacity(0.6),
                    (album.coverColor ?? .blue).opacity(0.3)
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
                                        (album.coverColor ?? .blue).opacity(0.4),
                                        (album.coverColor ?? .blue).opacity(0.2)
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
                    .foregroundColor(album.coverColor ?? .blue)

                Text(album.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }

            HStack(spacing: 4) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text("\(album.photoFileNames.count)枚")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Create Album View
struct CreateAlbumView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var albumManager = AlbumManager.shared
    @State private var creationMode: CreationMode = .manual
    @State private var albumTitle = ""
    @State private var selectedType: AlbumType = .custom
    @State private var selectedTravelPlan: TravelPlan?
    @Environment(\.colorScheme) var colorScheme

    let travelPlans: [TravelPlan]
    let albumTypes: [AlbumType] = [.travel, .family, .landscape, .food, .custom]

    enum CreationMode {
        case manual
        case fromTravelPlan
    }

    var body: some View {
        NavigationView {
            ZStack {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 30) {
                        // Mode Selection
                        modeSelectionSection

                        if creationMode == .manual {
                            manualCreationSection
                        } else {
                            travelPlanSelectionSection
                        }

                        Spacer()

                        createButton
                    }
                    .padding()
                }
            }
            .navigationTitle("新規アルバム")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Mode Selection
    private var modeSelectionSection: some View {
        VStack(spacing: 12) {
            Text("アルバムの作成方法")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                ModeButton(
                    title: "手動作成",
                    icon: "square.and.pencil",
                    isSelected: creationMode == .manual
                ) {
                    creationMode = .manual
                }

                ModeButton(
                    title: "旅行計画から",
                    icon: "airplane.departure",
                    isSelected: creationMode == .fromTravelPlan
                ) {
                    creationMode = .fromTravelPlan
                }
            }
        }
    }

    // MARK: - Manual Creation
    private var manualCreationSection: some View {
        VStack(spacing: 20) {
            TextField("アルバム名", text: $albumTitle)
                .font(.title3)
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(15)

            VStack(alignment: .leading, spacing: 12) {
                Text("アルバムの種類")
                    .font(.headline)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(albumTypes, id: \.self) { type in
                            AlbumTypeButton(
                                type: type,
                                isSelected: selectedType == type
                            ) {
                                selectedType = type
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Travel Plan Selection
    private var travelPlanSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("旅行計画を選択")
                .font(.headline)

            if travelPlans.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "airplane.departure")
                        .font(.system(size: 50))
                        .foregroundColor(.gray.opacity(0.7))

                    Text("旅行計画がありません")
                        .font(.subheadline)
                        .foregroundColor(.gray.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        ForEach(travelPlans) { plan in
                            TravelPlanSelectionCard(
                                plan: plan,
                                isSelected: selectedTravelPlan?.id == plan.id
                            ) {
                                selectedTravelPlan = plan
                            }
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
    }

    // MARK: - Create Button
    private var createButton: some View {
        Button(action: createAlbum) {
            Text("作成")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .foregroundColor(.white)
                .padding()
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            buttonColor,
                            buttonColor.opacity(0.7)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(15)
        }
        .disabled(!canCreate)
        .opacity(canCreate ? 1 : 0.5)
    }

    private var buttonColor: Color {
        if creationMode == .fromTravelPlan {
            return selectedTravelPlan?.cardColor ?? .blue
        } else {
            return selectedType.coverColor
        }
    }

    private var canCreate: Bool {
        if creationMode == .manual {
            return !albumTitle.isEmpty
        } else {
            return selectedTravelPlan != nil
        }
    }

    private func createAlbum() {
        if creationMode == .manual {
            albumManager.createAlbum(title: albumTitle, type: selectedType)
        } else if let travelPlan = selectedTravelPlan {
            albumManager.createTravelPlanAlbum(from: travelPlan)
        }
        dismiss()
    }
}

// MARK: - Mode Button
struct ModeButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.gray)

                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.orange.opacity(0.3) : Color.white.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.orange : Color.gray, lineWidth: 2)
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
                                    (plan.cardColor ?? .blue).opacity(0.8),
                                    (plan.cardColor ?? .white).opacity(0.5)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)

                    Image(systemName: "airplane.departure")
                        .font(.title3)
                        .foregroundColor(.black)
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.title)
                        .font(.headline)
                        .foregroundColor(.gray)

                    Text(plan.destination)
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                // Selection Indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.orange)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        colorScheme == .dark ?
                            Color.white.opacity(0.1) :
                            Color.white.opacity(0.2)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Color.blue : Color.gray,
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

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    type.coverColor,
                                    type.coverColor.opacity(0.7)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)

                    Image(systemName: type.icon)
                        .font(.title2)
                        .foregroundColor(.white)
                }
                .scaleEffect(isSelected ? 1.1 : 1.0)
                .shadow(
                    color: isSelected ? type.coverColor.opacity(0.6) : .clear,
                    radius: 10,
                    x: 0,
                    y: 5
                )

                Text(type.title)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            .frame(width: 80)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

extension AlbumType: Hashable {}

#Preview {
    AlbumHomeView()
}
