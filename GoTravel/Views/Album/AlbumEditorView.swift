import SwiftUI

// MARK: - Album Editor
/// アルバムの名前・色・アイコンを後から変更する画面
struct AlbumEditorView: View {
    let album: Album

    @ObservedObject private var albumManager = AlbumManager.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var title: String
    @State private var selectedColor: Color
    @State private var selectedIcon: String

    private static let iconChoices = [
        "photo.on.rectangle.angled", "airplane", "airplane.departure", "map.fill",
        "person.3.fill", "mountain.2.fill", "fork.knife", "cup.and.saucer.fill",
        "heart.fill", "star.fill", "camera.fill", "leaf.fill"
    ]

    private static let colorChoices: [Color] = [
        .blue, .teal, .green, .yellow, .orange, .red, .pink, .purple, .indigo, .brown
    ]

    init(album: Album) {
        self.album = album
        _title = State(initialValue: album.title)
        _selectedColor = State(initialValue: album.coverColor ?? .blue)
        _selectedIcon = State(initialValue: album.icon)
    }

    private var accentColor: Color {
        colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1
    }

    private var fieldBackground: Color {
        colorScheme == .dark
            ? themeManager.currentTheme.secondaryBackgroundDark
            : themeManager.currentTheme.backgroundLight
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        previewCard
                        titleSection
                        colorSection
                        iconSection
                    }
                    .padding(20)
                }
            }
            .navigationTitle("アルバムを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") { save() }
                        .fontWeight(.semibold)
                        .foregroundColor(canSave ? selectedColor : themeManager.currentTheme.secondaryText)
                        .disabled(!canSave)
                }
            }
        }
    }

    private var backgroundGradient: some View {
        let base: Color = colorScheme == .dark
            ? themeManager.currentTheme.backgroundDark
            : themeManager.currentTheme.backgroundLight

        return LinearGradient(
            colors: [selectedColor.opacity(colorScheme == .dark ? 0.28 : 0.16), base],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var previewCard: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: [selectedColor, selectedColor.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 84, height: 84)
                    .shadow(color: selectedColor.opacity(0.4), radius: 10, x: 0, y: 5)

                Image(systemName: selectedIcon)
                    .font(.system(size: 36))
                    .foregroundColor(.white)
            }

            Text(title.isEmpty ? "アルバム名" : title)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundColor(accentColor)
                .lineLimit(1)

            Text("\(album.photoFileNames.count)枚")
                .font(.caption)
                .foregroundColor(themeManager.currentTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(fieldBackground, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(selectedColor.opacity(0.3), lineWidth: 1)
        )
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("名前", icon: "textformat")

            TextField("アルバム名", text: $title)
                .font(.body)
                .foregroundColor(accentColor)
                .padding(16)
                .background(fieldBackground, in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(selectedColor.opacity(0.25), lineWidth: 1)
                )
        }
    }

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("色", icon: "paintpalette.fill")

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                ForEach(Array(Self.colorChoices.enumerated()), id: \.offset) { _, color in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedColor = color
                        }
                    } label: {
                        Circle()
                            .fill(color)
                            .frame(height: 44)
                            .overlay(
                                Circle()
                                    .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                            )
                            .overlay {
                                if color == selectedColor {
                                    Image(systemName: "checkmark")
                                        .font(.headline.weight(.bold))
                                        .foregroundColor(.white)
                                }
                            }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(16)
            .background(fieldBackground, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private var iconSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("アイコン", icon: "square.grid.2x2.fill")

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                ForEach(Self.iconChoices, id: \.self) { icon in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedIcon = icon
                        }
                    } label: {
                        Image(systemName: icon)
                            .font(.system(size: 20))
                            .foregroundColor(icon == selectedIcon ? .white : selectedColor)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(icon == selectedIcon ? selectedColor : selectedColor.opacity(0.12))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(16)
            .background(fieldBackground, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private func sectionLabel(_ text: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundColor(selectedColor)
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(accentColor)
        }
    }

    private func save() {
        albumManager.updateAlbumDetails(
            id: album.id,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            coverColor: selectedColor,
            icon: selectedIcon
        )
        dismiss()
    }
}
