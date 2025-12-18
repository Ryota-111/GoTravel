import SwiftUI
import MapKit
import PhotosUI

struct PlaceDetailView: View {
    @State private var place: VisitedPlace

    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var placesVM = PlacesViewModel()
    @ObservedObject var themeManager = ThemeManager.shared
    @State private var showStreetView = false
    @State private var showMap = true
    @State private var lookAroundScene: MKLookAroundScene?
    @State private var isEditMode = false
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var displayImage: UIImage?
    @State private var isSaving = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    // 編集用の一時変数
    @State private var editedTitle: String = ""
    @State private var editedNotes: String = ""
    @State private var editedCategory: PlaceCategory = .other
    @State private var editedVisitedAt: Date = Date()

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    init(place: VisitedPlace) {
        _place = State(initialValue: place)
    }
    
    var textColor : Color {
        colorScheme == .dark ?  themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1
    }
    
    var xtextColor : Color {
        colorScheme == .dark ?  themeManager.currentTheme.dark : themeManager.currentTheme.light

    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                if isEditMode {
                    editModeView
                } else {
                    viewModeView
                }
            }
        }
        .background(
            (colorScheme == .dark ? themeManager.currentTheme.dark : themeManager.currentTheme.light)
                .ignoresSafeArea()
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isEditMode {
                    HStack(spacing: 12) {
                        Button("キャンセル") {
                            cancelEdit()
                        }
                        .foregroundColor(themeManager.currentTheme.secondaryText)

                        Button(action: saveChanges) {
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Text("保存")
                                    .fontWeight(.semibold)
                            }
                        }
                        .disabled(isSaving || editedTitle.isEmpty)
                        .foregroundColor(editedTitle.isEmpty ? themeManager.currentTheme.secondaryText : textColor)
                    }
                } else {
                    Button(action: {
                        enterEditMode()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                            Text("編集")
                        }
                        .foregroundColor(textColor)
                    }
                }
            }
        }
        .task {
            await loadLookAroundScene()
            loadLocalImage()
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedImage)
        }
        .alert("エラー", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .onChange(of: selectedImage) { oldValue, newValue in
            if newValue != nil {
                displayImage = newValue
            }
        }
    }

    // MARK: - View Mode
    private var viewModeView: some View {
        VStack(spacing: 0) {
            // Header Image with title overlay
            headerImageView

            // Content Card
            VStack(alignment: .leading, spacing: 0) {
                // Category Tag
                categoryTag
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                // Gradient Separator
                gradientSeparator

                // Notes Section
                notesSection
                    .padding(.horizontal, 24)

                // Gradient Separator
                gradientSeparator

                // Map Section (always visible)
                mapSection
                    .padding(.horizontal, 24)

                // Gradient Separator
                gradientSeparator

                // Street View Section
                streetViewSection
                    .padding(.horizontal, 24)

                // Gradient Separator
                gradientSeparator

                // Visit Date
                visitDateSection
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Edit Mode View
    private var editModeView: some View {
        VStack(spacing: 0) {
            // Header Image with Edit Button
            editHeaderImageView

            // Edit Form
            VStack(spacing: 20) {
                // Title Card
                VStack(alignment: .leading, spacing: 8) {
                    Text("場所の名前")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(textColor)

                    TextField("例：東京タワー", text: $editedTitle)
                        .font(.body)
                        .padding(12)
                        .foregroundColor(textColor)
                        .background(colorScheme == .dark ? themeManager.currentTheme.backgroundDark : themeManager.currentTheme.backgroundLight)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(colorScheme == .dark ? themeManager.currentTheme.backgroundDark.opacity(0.5) : themeManager.currentTheme.backgroundLight.opacity(0.5), lineWidth: 1)
                        )
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(colorScheme == .dark ? themeManager.currentTheme.secondaryBackgroundDark : themeManager.currentTheme.secondaryBackgroundLight)
                        .shadow(color: themeManager.currentTheme.dark.opacity(0.05), radius: 8, x: 0, y: 2)
                )

                // Category Card
                VStack(alignment: .leading, spacing: 8) {
                    Text("カテゴリ")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(textColor)

                    Menu {
                        ForEach(PlaceCategory.allCases) { category in
                            Button(action: {
                                editedCategory = category
                            }) {
                                HStack {
                                    Image(systemName: category.iconName)
                                    Text(category.displayName)
                                    if editedCategory == category {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: editedCategory.iconName)
                                .foregroundColor(textColor)
                            Text(editedCategory.displayName)
                                .foregroundColor(textColor)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(themeManager.currentTheme.secondaryText)
                        }
                        .font(.body)
                        .padding(12)
                        .background(colorScheme == .dark ? themeManager.currentTheme.backgroundDark : themeManager.currentTheme.backgroundLight)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(colorScheme == .dark ? themeManager.currentTheme.backgroundDark.opacity(0.5) : themeManager.currentTheme.backgroundLight.opacity(0.5), lineWidth: 1)
                        )
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(colorScheme == .dark ? themeManager.currentTheme.secondaryBackgroundDark : themeManager.currentTheme.secondaryBackgroundLight)
                        .shadow(color: themeManager.currentTheme.dark.opacity(0.05), radius: 8, x: 0, y: 2)
                )

                // Visit Date Card
                VStack(alignment: .leading, spacing: 8) {
                    Text("訪問日")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(textColor)

                    DatePicker("", selection: $editedVisitedAt, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(textColor)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(colorScheme == .dark ? themeManager.currentTheme.backgroundDark : themeManager.currentTheme.backgroundLight)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(colorScheme == .dark ? themeManager.currentTheme.backgroundDark.opacity(0.5) : themeManager.currentTheme.backgroundLight.opacity(0.5), lineWidth: 1)
                        )
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(colorScheme == .dark ? themeManager.currentTheme.secondaryBackgroundDark : themeManager.currentTheme.secondaryBackgroundLight)
                        .shadow(color: themeManager.currentTheme.dark.opacity(0.05), radius: 8, x: 0, y: 2)
                )

                // Notes Card
                VStack(alignment: .leading, spacing: 8) {
                    Text("メモ")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(textColor)

                    ZStack(alignment: .topLeading) {
                        if editedNotes.isEmpty {
                            Text("この場所についてのメモを記入...")
                                .foregroundColor(themeManager.currentTheme.secondaryText)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 20)
                        }

                        TextEditor(text: $editedNotes)
                            .font(.body)
                            .frame(minHeight: 120)
                            .padding(8)
                            .scrollContentBackground(.hidden)
                            .background(colorScheme == .dark ? themeManager.currentTheme.backgroundDark : themeManager.currentTheme.backgroundLight)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(colorScheme == .dark ? themeManager.currentTheme.backgroundDark.opacity(0.5) : themeManager.currentTheme.backgroundLight.opacity(0.5), lineWidth: 1)
                            )
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(colorScheme == .dark ? themeManager.currentTheme.secondaryBackgroundDark : themeManager.currentTheme.secondaryBackgroundLight)
                        .shadow(color: themeManager.currentTheme.dark.opacity(0.05), radius: 8, x: 0, y: 2)
                )

                // Action Buttons
                HStack(spacing: 12) {
                    Button(action: cancelEdit) {
                        Text("キャンセル")
                            .font(.headline)
                            .foregroundColor(textColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(colorScheme == .dark ? themeManager.currentTheme.secondaryBackgroundDark : themeManager.currentTheme.secondaryBackgroundLight)
                            )
                    }

                    Button(action: saveChanges) {
                        HStack(spacing: 8) {
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("保存")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                        }
                        .foregroundColor(textColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(editedTitle.isEmpty ? themeManager.currentTheme.secondaryText : themeManager.currentTheme.info)
                                .shadow(color: themeManager.currentTheme.info.opacity(0.3), radius: 8, x: 0, y: 4)
                        )
                    }
                    .disabled(isSaving || editedTitle.isEmpty)
                }
                .padding(.top, 10)
            }
            .padding(24)
        }
    }

    // MARK: - Header Image (View Mode)
    private var headerImageView: some View {
        ZStack(alignment: .bottomLeading) {
            // Background Image
            if let image = displayImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 250)
                    .clipped()
            } else {
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                themeManager.currentTheme.accent1.opacity(0.6),
                                themeManager.currentTheme.accent1.opacity(0.3)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 250)
                    .overlay(
                        Image(systemName: place.category.iconName)
                            .font(.system(size: 80))
                            .foregroundColor(themeManager.currentTheme.accent2.opacity(0.5))
                    )
            }

            // Gradient Overlay for better text readability
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0),
                    Color.black.opacity(0.7)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 150)
            .frame(maxHeight: .infinity, alignment: .bottom)

            // Title and Address Overlay
            VStack(alignment: .leading, spacing: 8) {
                Text(place.title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)

                if let address = place.address {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.subheadline)

                        Text(address)
                            .font(.subheadline)
                            .lineLimit(2)
                    }
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                }
            }
            .padding(24)
        }
        .frame(height: 250)
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: colorScheme == .dark ? [themeManager.currentTheme.accent2.opacity(0.5), themeManager.currentTheme.accent2.opacity(0.2)] : [themeManager.currentTheme.accent1.opacity(0.5), themeManager.currentTheme.accent1.opacity(0.2)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
            )
        )
    }

    // MARK: - Header Image (Edit Mode)
    private var editHeaderImageView: some View {
        ZStack {
            if let image = displayImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 200)
                    .clipped()
            } else {
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                themeManager.currentTheme.accent1.opacity(0.6),
                                themeManager.currentTheme.accent1.opacity(0.3)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 200)
                    .overlay(
                        Image(systemName: editedCategory.iconName)
                            .font(.system(size: 80))
                            .foregroundColor(.white.opacity(0.3))
                    )
            }

            // Change Photo Button
            Button(action: {
                showImagePicker = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "camera.fill")
                        .font(.body)
                    Text("写真を変更")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.6))
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                )
                .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
            }
        }
        .cornerRadius(15)
        .padding(.horizontal, 24)
        .padding(.vertical, 24)
    }

    // MARK: - Gradient Separator
    private var gradientSeparator: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.clear,
                        textColor.opacity(0.6),
                        Color.clear
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
            .padding(.vertical, 20)
    }

    // MARK: - Category Tag
    private var categoryTag: some View {
        HStack(spacing: 8) {
            Image(systemName: place.category.iconName)
                .font(.caption)
            Text(place.category.displayName)
                .font(.subheadline.weight(.semibold))
        }
        .foregroundColor(xtextColor)
        .padding(.horizontal, 13)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(textColor)
        )
        .shadow(color: textColor.opacity(0.3), radius: 4, x: 0, y: 2)
    }

    // MARK: - Notes Section
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "note.text")
                    .font(.headline)
                    .foregroundColor(textColor)
                Text("メモ")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(textColor)
            }

            if let notes = place.notes, !notes.isEmpty {
                Text(notes)
                    .font(.body)
                    .foregroundColor(themeManager.currentTheme.secondaryText)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("メモがありません")
                    .font(.body)
                    .foregroundColor(themeManager.currentTheme.secondaryText.opacity(0.5))
                    .italic()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }


    // MARK: - Street View Section
    private var streetViewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "eye.circle.fill")
                    .font(.headline)
                    .foregroundColor(textColor)
                Text("ストリートビュー")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(textColor)
            }

            if let scene = lookAroundScene {
                LookAroundPreview(
                    initialScene: scene,
                    allowsNavigation: true,
                    showsRoadLabels: true,
                    pointsOfInterest: .all,
                    badgePosition: .topLeading
                )
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(alignment: .bottomTrailing) {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption)
                        Text(place.title)
                            .font(.caption.weight(.medium))
                    }
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(12)
                }
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Street Viewを読み込み中...")
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.tertiarySystemBackground))
                )
            }
        }
    }

    // MARK: - Map Section
    private var mapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "map.circle.fill")
                    .font(.headline)
                    .foregroundColor(textColor)
                Text("マップ")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(textColor)
            }

            Map(position: .constant(.region(MKCoordinateRegion(
                center: place.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )))) {
                Marker(place.title, coordinate: place.coordinate)
                    .tint(themeManager.currentTheme.accent1)
            }
            .frame(height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(alignment: .bottomTrailing) {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.caption)
                    Text(place.title)
                        .font(.caption.weight(.medium))
                }
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .padding(12)
            }
        }
    }

    // MARK: - Visit Date Section
    private var visitDateSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar.circle.fill")
                .font(.headline)
                .foregroundColor(textColor)

            VStack(alignment: .leading, spacing: 4) {
                Text("訪問日")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(textColor)

                if let visitedAt = place.visitedAt {
                    Text(visitedAt.japaneseYearMonthDay())
                        .font(.subheadline)
                        .foregroundColor(textColor)
                } else {
                    Text("未設定")
                        .font(.subheadline)
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                }
            }

            Spacer()
        }
    }

    // MARK: - Edit Mode Functions
    private func enterEditMode() {
        editedTitle = place.title
        editedNotes = place.notes ?? ""
        editedCategory = place.category
        editedVisitedAt = place.visitedAt ?? Date()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isEditMode = true
        }
    }

    private func cancelEdit() {
        selectedImage = nil
        displayImage = loadImageFromLocal()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isEditMode = false
        }
    }

    private func saveChanges() {
        guard !editedTitle.isEmpty else { return }

        isSaving = true

        // 画像を保存（選択されている場合）
        if let image = selectedImage {
            // 即座にUIを更新
            displayImage = image

            saveImageLocally(image) { result in
                switch result {
                case .success(let fileName):
                    updatePlaceData(with: fileName)
                case .failure(let error):
                    handleSaveError(error)
                }
            }
        } else {
            updatePlaceData(with: place.localPhotoFileName)
        }
    }

    private func updatePlaceData(with localFileName: String?) {
        print("🔵 [PlaceDetail] updatePlaceData called with fileName: \(localFileName ?? "nil")")
        var updatedPlace = place
        updatedPlace.title = editedTitle
        updatedPlace.notes = editedNotes.isEmpty ? nil : editedNotes
        updatedPlace.category = editedCategory
        updatedPlace.visitedAt = editedVisitedAt
        updatedPlace.localPhotoFileName = localFileName

        print("🔵 [PlaceDetail] updatedPlace.localPhotoFileName: \(updatedPlace.localPhotoFileName ?? "nil")")
        print("🔵 [PlaceDetail] updatedPlace.visitedAt: \(editedVisitedAt)")

        // 即座にUIを更新
        place = updatedPlace
        selectedImage = nil
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isEditMode = false
        }

        // Core Dataに保存
        Task { @MainActor in
            guard let userId = authVM.userId else {
                isSaving = false
                return
            }

            print("🔵 [PlaceDetail] Saving to Core Data...")
            placesVM.update(updatedPlace, userId: userId, image: nil)
            print("✅ [PlaceDetail] Core Data save successful")
            isSaving = false
        }
    }

    private func handleSaveError(_ error: Error) {
        DispatchQueue.main.async {
            isSaving = false
            alertMessage = "保存に失敗しました: \(error.localizedDescription)"
            showAlert = true
        }
    }

    // MARK: - Image Storage Functions
    private func saveImageLocally(_ image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        print("🔵 [PlaceDetail] saveImageLocally called")
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            print("❌ [PlaceDetail] Failed to convert image to JPEG data")
            completion(.failure(NSError(domain: "PlaceDetailView", code: -1, userInfo: [NSLocalizedDescriptionKey: "画像データの変換に失敗しました"])))
            return
        }

        let fileName = "place_\(place.id ?? UUID().uuidString).jpg"
        print("🔵 [PlaceDetail] Saving image with fileName: \(fileName)")
        print("🔵 [PlaceDetail] place.id: \(place.id ?? "nil")")

        do {
            try FileManager.saveImageDataToDocuments(data: imageData, named: fileName)
            print("✅ [PlaceDetail] Image saved successfully: \(fileName)")
            completion(.success(fileName))
        } catch {
            print("❌ [PlaceDetail] Failed to save image: \(error)")
            completion(.failure(error))
        }
    }

    private func loadLocalImage() {
        displayImage = loadImageFromLocal()
    }

    private func loadImageFromLocal() -> UIImage? {
        print("🔵 [PlaceDetail] loadImageFromLocal called")
        print("🔵 [PlaceDetail] place.localPhotoFileName: \(place.localPhotoFileName ?? "nil")")

        guard let fileName = place.localPhotoFileName else {
            print("⚠️ [PlaceDetail] No localPhotoFileName set")
            return nil
        }

        if let image = FileManager.documentsImage(named: fileName) {
            print("✅ [PlaceDetail] Image loaded successfully: \(fileName)")
            return image
        } else {
            print("❌ [PlaceDetail] Image not found: \(fileName)")
            return nil
        }
    }

    // MARK: - Helper Functions
    private func loadLookAroundScene() async {
        guard place.latitude != 0 || place.longitude != 0 else { return }
        lookAroundScene = nil
        do {
            let request = MKLookAroundSceneRequest(coordinate: place.coordinate)
            lookAroundScene = try await request.scene
        } catch {
        }
    }
}

#Preview {
    NavigationStack {
        PlaceDetailView(
            place: VisitedPlace(
                title: "Munich",
                notes: "Beautiful city center with amazing architecture and history.", latitude: 48.1351, longitude: 11.5820, visitedAt: Date(), address: "Marienplatz 1, 80331 München", category: .hotel
            )
        )
    }
}
