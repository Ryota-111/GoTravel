import SwiftUI
import MapKit
import PhotosUI

struct PlaceDetailView: View {
    @State private var place: VisitedPlace

    @EnvironmentObject var authVM: AuthViewModel
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
            LinearGradient(
                gradient: Gradient(colors: colorScheme == .dark ? [.orange.opacity(0.8), .black] : [.orange.opacity(0.7), .white.opacity(0.1)]),
                startPoint: .top,
                endPoint: .bottom
            )
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
                        .foregroundColor(.secondary)

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
                        .foregroundColor(editedTitle.isEmpty ? .secondary : .orange)
                    }
                } else {
                    Button(action: {
                        enterEditMode()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                            Text("編集")
                        }
                        .foregroundColor(.orange)
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
            // Header Image
            headerImageView

            // Content Card
            VStack(alignment: .leading, spacing: 15) {
                // Category Tag
                categoryTag

                // Title
                titleSection

                // Notes Section
                notesSection

                // Action Buttons
                actionButtons

                // Map Section (expandable)
                if showMap {
                    mapSection
                }

                // Street View Section (expandable)
                if showStreetView {
                    streetViewSection
                }

                // Visit Date
                visitDateSection
            }
            .padding(24)
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
                        .foregroundColor(.secondary)

                    TextField("例：東京タワー", text: $editedTitle)
                        .font(.body)
                        .padding(12)
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(.separator).opacity(0.5), lineWidth: 1)
                        )
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemBackground))
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                )

                // Category Card
                VStack(alignment: .leading, spacing: 8) {
                    Text("カテゴリ")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

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
                                .foregroundColor(.orange)
                            Text(editedCategory.displayName)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .font(.body)
                        .padding(12)
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(.separator).opacity(0.5), lineWidth: 1)
                        )
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemBackground))
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                )

                // Visit Date Card
                VStack(alignment: .leading, spacing: 8) {
                    Text("訪問日")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    DatePicker("", selection: $editedVisitedAt, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(.separator).opacity(0.5), lineWidth: 1)
                        )
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemBackground))
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                )

                // Notes Card
                VStack(alignment: .leading, spacing: 8) {
                    Text("メモ")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    ZStack(alignment: .topLeading) {
                        if editedNotes.isEmpty {
                            Text("この場所についてのメモを記入...")
                                .foregroundColor(.secondary.opacity(0.5))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 20)
                        }

                        TextEditor(text: $editedNotes)
                            .font(.body)
                            .frame(minHeight: 120)
                            .padding(8)
                            .scrollContentBackground(.hidden)
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(.separator).opacity(0.5), lineWidth: 1)
                            )
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemBackground))
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                )

                // Action Buttons
                HStack(spacing: 12) {
                    Button(action: cancelEdit) {
                        Text("キャンセル")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.secondarySystemBackground))
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
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(editedTitle.isEmpty ? Color.gray : Color.blue)
                                .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
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
                                Color.orange.opacity(0.6),
                                Color.orange.opacity(0.3)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 200)
                    .overlay(
                        Image(systemName: place.category.iconName)
                            .font(.system(size: 80))
                            .foregroundColor(.white.opacity(0.3))
                    )
            }
        }
        .cornerRadius(15)
        .padding(.horizontal, 24)
        .padding(.vertical, 24)
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
                                Color.orange.opacity(0.6),
                                Color.orange.opacity(0.3)
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

    // MARK: - Title Section
    private var titleSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text(place.title)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)

                if let address = place.address {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text(address)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
            }

            Spacer()
        }
    }

    // MARK: - Category Tag
    private var categoryTag: some View {
        HStack(spacing: 8) {
            Image(systemName: place.category.iconName)
                .font(.caption)
            Text(place.category.displayName)
                .font(.subheadline.weight(.semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 13)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.orange)
        )
        .shadow(color: Color.orange.opacity(0.3), radius: 4, x: 0, y: 2)
    }

    // MARK: - Notes Section
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "note.text")
                    .font(.headline)
                    .foregroundColor(.orange)
                Text("メモ")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
            }

            if let notes = place.notes, !notes.isEmpty {
                Text(notes)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("メモがありません")
                    .font(.body)
                    .foregroundColor(.secondary.opacity(0.5))
                    .italic()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Action Buttons
    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Show on Map Button
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showMap.toggle()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: showMap ? "mappin.slash" : "mappin")
                        .font(.body)
                    Text(showMap ? "閉じる" : "マップを開く")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundColor(.orange)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.orange.opacity(0.6),
                                    Color.orange.opacity(0.1)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.orange, lineWidth: 2)
                        )
                )
            }

            // Street View Button
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showStreetView.toggle()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: showStreetView ? "eye.slash.fill" : "eye.fill")
                        .font(.body)
                    Text(showStreetView ? "閉じる" : "ストリートビュー")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundColor(.orange)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.orange.opacity(0.6),
                                    Color.orange.opacity(0.1)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.orange, lineWidth: 2)
                        )
                )
            }
        }
    }

    // MARK: - Street View Section
    private var streetViewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "eye.circle.fill")
                    .font(.headline)
                    .foregroundColor(.orange)
                Text("ストリートビュー")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
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
                    .foregroundColor(.white)
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
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.tertiarySystemBackground))
                )
            }
        }
        .transition(.asymmetric(
            insertion: .scale.combined(with: .opacity),
            removal: .scale.combined(with: .opacity)
        ))
    }

    // MARK: - Map Section
    private var mapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "map.circle.fill")
                    .font(.headline)
                    .foregroundColor(.orange)
                Text("マップ")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
            }

            Map(position: .constant(.region(MKCoordinateRegion(
                center: place.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )))) {
                Marker(place.title, coordinate: place.coordinate)
                    .tint(.orange)
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
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .padding(12)
            }
        }
        .transition(.asymmetric(
            insertion: .scale.combined(with: .opacity),
            removal: .scale.combined(with: .opacity)
        ))
    }

    // MARK: - Visit Date Section
    private var visitDateSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar.circle.fill")
                .font(.title3)
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 4) {
                Text("訪問日")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)

                if let visitedAt = place.visitedAt {
                    Text(visitedAt.japaneseYearMonthDay())
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                } else {
                    Text("未設定")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
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

        // 即座にUIを更新（CloudKit保存を待たない）
        place = updatedPlace
        selectedImage = nil
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isEditMode = false
        }

        // バックグラウンドでCloudKitに保存
        Task {
            guard let userId = authVM.userId else {
                await MainActor.run {
                    isSaving = false
                }
                return
            }

            do {
                print("🔵 [PlaceDetail] Saving to CloudKit (background)...")
                let savedPlace = try await CloudKitService.shared.saveVisitedPlace(updatedPlace, userId: userId, image: nil)
                print("✅ [PlaceDetail] CloudKit save successful")
                print("✅ [PlaceDetail] savedPlace.id: \(savedPlace.id ?? "nil")")
                print("✅ [PlaceDetail] savedPlace.localPhotoFileName: \(savedPlace.localPhotoFileName ?? "nil")")
                await MainActor.run {
                    isSaving = false
                    // CloudKitから返された最新のデータでplaceを更新
                    place = savedPlace
                }
            } catch {
                print("❌ [PlaceDetail] CloudKit save failed: \(error)")
                await MainActor.run {
                    isSaving = false
                    // エラーの場合はユーザーに通知するが、ローカルの変更は保持
                    handleSaveError(error)
                }
            }
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
