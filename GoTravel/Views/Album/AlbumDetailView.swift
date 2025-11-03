import SwiftUI

// MARK: - Album Detail View
struct AlbumDetailView: View {
    let album: Album
    @StateObject private var albumManager = AlbumManager.shared
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var showImagePicker = false
    @State private var selectedPhotoFileName: String?
    @State private var showDeleteConfirmation = false
    @State private var animatePhotos = false

    private var currentAlbum: Album? {
        albumManager.albums.first(where: { $0.id == album.id })
    }

    private var photos: [String] {
        currentAlbum?.photoFileNames ?? []
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
            .navigationTitle(album.title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                    .foregroundColor(album.coverColor)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showImagePicker = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(album.coverColor)
                    }
                }
            }
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                    animatePhotos = true
                }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            PhotoPicker { image in
                if let currentAlbum = currentAlbum {
                    albumManager.addPhoto(image, to: currentAlbum)
                }
            }
        }
        .confirmationDialog(
            "この写真を削除しますか？",
            isPresented: $showDeleteConfirmation,
            presenting: selectedPhotoFileName
        ) { fileName in
            Button("削除", role: .destructive) {
                if let currentAlbum = currentAlbum {
                    albumManager.removePhoto(fileName: fileName, from: currentAlbum)
                }
            }
        }
    }

    // MARK: - Background
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: colorScheme == .dark ?
                [(album.coverColor ?? .blue).opacity(0.7), .black] :
                [(album.coverColor ?? .blue).opacity(0.6), .white.opacity(0.3)]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 15) {
            Image(systemName: album.icon)
                .font(.system(size: 80))
                .foregroundColor(.white.opacity(0.8))

            Text("写真がありません")
                .font(.title2.bold())

            Text("＋ボタンから写真を追加しましょう")
                .font(.subheadline)
                .foregroundColor(.gray)
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
                            gradient: Gradient(colors: [
                                (album.coverColor ?? .blue),
                                (album.coverColor ?? .blue).opacity(0.7)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(15)
                    .shadow(
                        color: (album.coverColor ?? .blue).opacity(0.5),
                        radius: 10,
                        x: 0,
                        y: 5
                    )
            }
            .padding(.top, 10)
        }
    }

    // MARK: - Photo Grid View
    private var photoGridView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Album Stats
                albumStatsSection

                // Photo Grid
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ], spacing: 8) {
                    ForEach(Array(photos.enumerated()), id: \.element) { index, fileName in
                        if let image = albumManager.loadPhoto(fileName: fileName) {
                            PhotoThumbnail(
                                image: image,
                                albumColor: album.coverColor ?? .blue
                            )
                            .onTapGesture {
                                selectedPhotoFileName = fileName
                            }
                            .onLongPressGesture {
                                selectedPhotoFileName = fileName
                                showDeleteConfirmation = true
                            }
                            .opacity(animatePhotos ? 1 : 0)
                            .scaleEffect(animatePhotos ? 1 : 0.8)
                            .animation(
                                .spring(response: 0.6, dampingFraction: 0.8)
                                    .delay(Double(index) * 0.03),
                                value: animatePhotos
                            )
                        }
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
                color: album.coverColor ?? .blue
            )

            StatCard(
                icon: "calendar",
                title: "更新日",
                value: formatDate(currentAlbum?.updatedAt ?? Date()),
                color: album.coverColor ?? .blue
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
    let image: UIImage
    let albumColor: Color
    @State private var showFullScreen = false

    var body: some View {
        Button(action: {
            showFullScreen = true
        }) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 110, height: 110)
                .clipped()
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(albumColor.opacity(0.3), lineWidth: 1)
                )
                .shadow(
                    color: .black.opacity(0.2),
                    radius: 5,
                    x: 0,
                    y: 2
                )
        }
        .fullScreenCover(isPresented: $showFullScreen) {
            PhotoFullScreenView(image: image, albumColor: albumColor)
        }
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)

                Text(title)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }

            Text(value)
                .font(.title3.bold())
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(
                    colorScheme == .dark ?
                        Color.white.opacity(0.1) :
                        Color.white.opacity(0.2)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Photo Full Screen View
struct PhotoFullScreenView: View {
    let image: UIImage
    let albumColor: Color
    @Environment(\.dismiss) var dismiss

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    SimultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = lastScale * value
                            }
                            .onEnded { value in
                                lastScale = scale
                                if scale < 1.0 {
                                    withAnimation(.spring()) {
                                        scale = 1.0
                                        lastScale = 1.0
                                        offset = .zero
                                        lastOffset = .zero
                                    }
                                } else if scale > 5.0 {
                                    scale = 5.0
                                    lastScale = 5.0
                                }
                            },
                        DragGesture()
                            .onChanged { value in
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                            .onEnded { value in
                                lastOffset = offset
                            }
                    )
                )

            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding()
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                    .padding()
                }
                Spacer()
            }
        }
    }
}

#Preview {
    AlbumDetailView(album: Album(
        title: "旅行",
        coverColor: .orange,
        icon: "airplane"
    ))
}
