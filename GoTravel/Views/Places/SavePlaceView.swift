import SwiftUI
import MapKit

struct SavePlaceView: View {

    // MARK: - Properties
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject var vm: SavePlaceViewModel
    @ObservedObject var themeManager = ThemeManager.shared
    @ObservedObject var categoryManager = PlaceCategoryManager.shared
    @Environment(\.colorScheme) var colorScheme

    @State private var selectedImage: UIImage?

    // MARK: - Theme
    private var accentColor: Color {
        colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1
    }

    private var fieldBg: Color {
        colorScheme == .dark ? themeManager.currentTheme.backgroundDark : themeManager.currentTheme.backgroundLight
    }

    private var cardBg: Color {
        colorScheme == .dark ? themeManager.currentTheme.secondaryBackgroundDark : themeManager.currentTheme.secondaryBackgroundLight
    }

    private var bgGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: colorScheme == .dark
                ? [themeManager.currentTheme.backgroundDark, themeManager.currentTheme.secondaryBackgroundDark]
                : [themeManager.currentTheme.backgroundLight, themeManager.currentTheme.secondaryBackgroundLight]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var isSaveDisabled: Bool {
        vm.title.trimmingCharacters(in: .whitespaces).isEmpty || vm.isSaving || vm.coordinate == nil
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            bgGradient

            VStack(spacing: 0) {
                headerView

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        // ミニマップ
                        if let coord = vm.coordinate {
                            miniMapView(coord: coord)
                        }

                        titleSection
                        categorySection
                        dateSection
                        notesSection

                        if let error = vm.error {
                            errorView(error)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }

                saveButton
            }
        }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack {
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                Image(systemName: "xmark")
                    .foregroundColor(accentColor)
                    .imageScale(.medium)
                    .padding(8)
                    .background(accentColor.opacity(0.1))
                    .clipShape(Circle())
            }

            Spacer()

            Text("場所を保存")
                .font(.headline)
                .foregroundColor(accentColor)

            Spacer()

            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(themeManager.currentTheme.xprimary.opacity(0.12))
    }

    // MARK: - Mini Map
    private func miniMapView(coord: CLLocationCoordinate2D) -> some View {
        Map(initialPosition: .region(MKCoordinateRegion(
            center: coord,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        ))) {
            Marker("", coordinate: coord)
                .tint(themeManager.currentTheme.error)
        }
        .frame(height: 160)
        .cornerRadius(16)
        .allowsHitTesting(false)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(themeManager.currentTheme.xprimary.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: themeManager.currentTheme.shadow, radius: 6, x: 0, y: 2)
    }

    // MARK: - Title Section
    private var titleSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("場所の名前", icon: "mappin.circle.fill")
                TextField("例：東京タワー", text: $vm.title)
                    .font(.body)
                    .foregroundColor(accentColor)
                    .padding(14)
                    .background(fieldBg)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                vm.title.isEmpty
                                    ? themeManager.currentTheme.error.opacity(0.4)
                                    : themeManager.currentTheme.xprimary.opacity(0.3),
                                lineWidth: 1.5
                            )
                    )
            }
        }
    }

    // MARK: - Category Section
    private var categorySection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("カテゴリー", icon: "tag.fill")

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                    ForEach(categoryManager.categories) { cat in
                        let isSelected = vm.categoryId == cat.id
                        Button(action: { vm.categoryId = cat.id }) {
                            VStack(spacing: 6) {
                                ZStack {
                                    Circle()
                                        .fill(isSelected ? themeManager.currentTheme.xprimary : themeManager.currentTheme.xprimary.opacity(0.08))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: cat.icon)
                                        .font(.system(size: 18))
                                        .foregroundColor(isSelected ? .white : accentColor.opacity(0.6))
                                }
                                Text(cat.name)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(isSelected ? themeManager.currentTheme.xprimary : themeManager.currentTheme.secondaryText)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }

    // MARK: - Date Section
    private var dateSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("訪問日（任意）", icon: "calendar")

                // 訪問日を設定するかどうかのトグル
                HStack {
                    Image(systemName: "calendar.circle")
                        .foregroundColor(themeManager.currentTheme.xprimary.opacity(0.8))
                        .frame(width: 24)
                    Text("訪問日を設定")
                        .font(.subheadline)
                        .foregroundColor(accentColor)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { vm.visitedAt != nil },
                        set: { vm.visitedAt = $0 ? Date() : nil }
                    ))
                    .labelsHidden()
                    .tint(themeManager.currentTheme.xprimary)
                }
                .padding(14)
                .background(fieldBg)
                .cornerRadius(12)

                // トグルON時のみDatePickerを表示
                if let date = vm.visitedAt {
                    HStack {
                        Image(systemName: "calendar.badge.checkmark")
                            .foregroundColor(themeManager.currentTheme.xprimary.opacity(0.8))
                            .frame(width: 24)
                        Text("日付")
                            .font(.subheadline)
                            .foregroundColor(accentColor)
                        Spacer()
                        DatePicker("", selection: Binding(
                            get: { date },
                            set: { vm.visitedAt = $0 }
                        ), displayedComponents: .date)
                        .colorMultiply(themeManager.currentTheme.xprimary)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                    }
                    .padding(14)
                    .background(fieldBg)
                    .cornerRadius(12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: vm.visitedAt != nil)
        }
    }

    // MARK: - Notes Section
    private var notesSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("メモ（任意）", icon: "note.text")
                ZStack(alignment: .topLeading) {
                    if vm.notes.isEmpty {
                        Text("感想・特徴など…")
                            .foregroundColor(themeManager.currentTheme.secondaryText.opacity(0.5))
                            .font(.body)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                    }
                    TextEditor(text: $vm.notes)
                        .font(.body)
                        .frame(minHeight: 90)
                        .foregroundColor(accentColor)
                        .scrollContentBackground(.hidden)
                }
                .padding(14)
                .background(fieldBg)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(themeManager.currentTheme.xprimary.opacity(0.15), lineWidth: 1))
            }
        }
    }

    // MARK: - Error
    private func errorView(_ error: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(themeManager.currentTheme.error)
            Text(error)
                .font(.caption)
                .foregroundColor(themeManager.currentTheme.error)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(themeManager.currentTheme.error.opacity(0.08))
        .cornerRadius(12)
    }

    // MARK: - Save Button
    private var saveButton: some View {
        Button(action: performSave) {
            HStack(spacing: 6) {
                if vm.isSaving {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("保存中...")
                } else {
                    Image(systemName: "bookmark.fill")
                    Text("この場所を保存")
                }
            }
            .font(.headline.weight(.bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSaveDisabled ? themeManager.currentTheme.secondaryText : themeManager.currentTheme.xprimary)
                    .shadow(color: themeManager.currentTheme.xprimary.opacity(isSaveDisabled ? 0 : 0.4), radius: 8, x: 0, y: 4)
            )
            .animation(.easeInOut(duration: 0.2), value: isSaveDisabled)
        }
        .disabled(isSaveDisabled)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 32)
        .background(.ultraThinMaterial)
    }

    // MARK: - Helpers
    @ViewBuilder
    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardBg)
                    .shadow(color: themeManager.currentTheme.shadow, radius: 6, x: 0, y: 2)
            )
    }

    private func sectionLabel(_ text: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundColor(themeManager.currentTheme.xprimary)
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(accentColor)
        }
    }

    private func performSave() {
        guard let userId = authVM.userId else { return }
        vm.save(userId: userId) { result in
            switch result {
            case .success:
                presentationMode.wrappedValue.dismiss()
            case .failure:
                break
            }
        }
    }
}
