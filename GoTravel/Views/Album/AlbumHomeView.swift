import SwiftUI

// MARK: - Album Home View
struct AlbumHomeView: View {
    @StateObject private var albumManager = AlbumManager.shared
    @Environment(\.colorScheme) var colorScheme
    @State private var showCreateAlbum = false
    @State private var selectedAlbum: Album?
    @State private var animateCards = false

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
                }
            }
            .navigationTitle("アルバム")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showCreateAlbum = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                }
            }
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                    animateCards = true
                }
            }
        }
        .sheet(isPresented: $showCreateAlbum) {
            CreateAlbumView()
        }
        .fullScreenCover(item: $selectedAlbum) { album in
            if album.title == "日本全国フォトマップ" {
                JapanPhotoView()
            } else {
                AlbumDetailView(album: album)
            }
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
                AlbumCard(album: album)
                    .onTapGesture {
                        selectedAlbum = album
                    }
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

// MARK: - Album Card
struct AlbumCard: View {
    let album: Album
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
    @State private var albumTitle = ""
    @State private var selectedType: AlbumType = .custom
    @Environment(\.colorScheme) var colorScheme

    let albumTypes: [AlbumType] = [.travel, .family, .landscape, .food, .custom]

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.opacity(0.9).ignoresSafeArea()

                VStack(spacing: 30) {
                    Spacer()

                    VStack(spacing: 20) {
                        TextField("アルバム名", text: $albumTitle)
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(15)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("アルバムの種類")
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.8))

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

                    Spacer()

                    Button(action: createAlbum) {
                        Text("作成")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        selectedType.coverColor,
                                        selectedType.coverColor.opacity(0.7)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(15)
                    }
                    .disabled(albumTitle.isEmpty)
                    .opacity(albumTitle.isEmpty ? 0.5 : 1)
                }
                .padding()
            }
            .navigationTitle("新規アルバム")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("キャンセル") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }

    private func createAlbum() {
        albumManager.createAlbum(title: albumTitle, type: selectedType)
        dismiss()
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
                    .foregroundColor(.white)
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
