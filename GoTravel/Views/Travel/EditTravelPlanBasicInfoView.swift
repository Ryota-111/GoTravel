import SwiftUI
import MapKit

struct EditTravelPlanBasicInfoView: View {
    // MARK: - Properties
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var viewModel: TravelPlanViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var themeManager = ThemeManager.shared

    let plan: TravelPlan
    @State private var title: String
    @State private var destination: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var isUploading = false
    @State private var destinationCoordinate: (latitude: Double, longitude: Double)?

    // MARK: - Initialization
    init(plan: TravelPlan) {
        self.plan = plan
        _title = State(initialValue: plan.title)
        _destination = State(initialValue: plan.destination)
        _startDate = State(initialValue: plan.startDate)
        _endDate = State(initialValue: plan.endDate)

        if let latitude = plan.latitude, let longitude = plan.longitude {
            _destinationCoordinate = State(initialValue: (latitude, longitude))
        }

        if let localImageFileName = plan.localImageFileName,
           let image = FileManager.documentsImage(named: localImageFileName) {
            _selectedImage = State(initialValue: image)
        }
    }

    // MARK: - Computed Properties
    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !destination.trimmingCharacters(in: .whitespaces).isEmpty &&
        startDate <= endDate
    }

    private var normalizedEndDate: Date {
        endDate < startDate ? startDate : endDate
    }

    private var travelColor: Color {
        switch themeManager.currentTheme.type {
        case .whiteBlack: return Color.black
        default: return themeManager.currentTheme.primary
        }
    }

    private var textColor: Color {
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

    // MARK: - Body
    var body: some View {
        ZStack {
            bgGradient

            VStack(spacing: 0) {
                headerView

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        coverImageSection
                        titleSection
                        destinationSection
                        dateSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }

                saveButton
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showImagePicker) {
            ImageCropPickerView(image: $selectedImage, aspectRatio: 1.0)
        }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack {
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                Image(systemName: "xmark")
                    .foregroundColor(textColor)
                    .imageScale(.medium)
                    .padding(8)
                    .background(textColor.opacity(0.1))
                    .clipShape(Circle())
            }

            Spacer()

            Text("基本情報を編集")
                .font(.headline)
                .foregroundColor(textColor)

            Spacer()

            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(travelColor.opacity(0.15))
    }

    // MARK: - Cover Image Section
    private var coverImageSection: some View {
        ZStack(alignment: .bottom) {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipped()
            } else {
                LinearGradient(
                    gradient: Gradient(colors: [travelColor.opacity(0.7), travelColor.opacity(0.4)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 200)
                .overlay(
                    Image(systemName: "airplane")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.25))
                )
            }

            LinearGradient(
                gradient: Gradient(colors: [.clear, .black.opacity(0.4)]),
                startPoint: .center,
                endPoint: .bottom
            )
            .frame(height: 200)

            HStack {
                if selectedImage != nil {
                    Button(action: { selectedImage = nil }) {
                        Label("削除", systemImage: "trash")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }
                }
                Spacer()
                Button(action: { showImagePicker = true }) {
                    Label(selectedImage == nil ? "写真を追加" : "写真を変更", systemImage: "camera.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
        .cornerRadius(20)
        .shadow(color: travelColor.opacity(0.2), radius: 10, x: 0, y: 5)
    }

    // MARK: - Title Section
    private var titleSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("タイトル", icon: "pencil")
                TextField("例：夏の北海道旅行", text: $title)
                    .font(.body)
                    .foregroundColor(textColor)
                    .padding(14)
                    .background(fieldBg)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(title.isEmpty ? themeManager.currentTheme.error.opacity(0.5) : travelColor.opacity(0.3), lineWidth: 1.5)
                    )
            }
        }
    }

    // MARK: - Destination Section
    private var destinationSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("目的地", icon: "mappin.circle.fill")
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(travelColor)
                        TextField("北海道、東京、大阪…", text: $destination)
                            .font(.body)
                            .foregroundColor(textColor)
                            .onChange(of: destination) { _, newValue in
                                searchLocationCoordinate(for: newValue)
                            }
                    }
                    .padding(14)
                    .background(fieldBg)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(destination.isEmpty ? themeManager.currentTheme.error.opacity(0.5) : travelColor.opacity(0.3), lineWidth: 1.5)
                    )

                    if destinationCoordinate != nil && !destination.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(travelColor)
                            Text("位置情報を取得しました")
                                .font(.caption)
                                .foregroundColor(travelColor)
                        }
                        .padding(.horizontal, 4)
                    }
                }
            }
        }
    }

    // MARK: - Date Section
    private var dateSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("日程", icon: "calendar")
                VStack(spacing: 8) {
                    dateRow("出発日", icon: "airplane.departure", date: $startDate)
                    dateRow("帰宅日", icon: "airplane.arrival", date: $endDate)

                    if endDate < startDate {
                        Label("帰宅日は出発日以降にしてください", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.error)
                            .padding(.top, 2)
                    } else {
                        let nights = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
                        if nights > 0 {
                            HStack(spacing: 6) {
                                Image(systemName: "moon.stars.fill")
                                    .foregroundColor(travelColor)
                                Text("\(nights)泊\(nights + 1)日")
                                    .font(.caption)
                                    .foregroundColor(travelColor)
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                }
            }
        }
    }

    private func dateRow(_ label: String, icon: String, date: Binding<Date>) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(travelColor.opacity(0.8))
                .frame(width: 24)
            Text(label)
                .font(.subheadline)
                .foregroundColor(textColor)
            Spacer()
            DatePicker("", selection: date, displayedComponents: .date)
                .colorMultiply(travelColor)
                .datePickerStyle(.compact)
                .labelsHidden()
        }
        .padding(14)
        .background(fieldBg)
        .cornerRadius(12)
    }

    // MARK: - Save Button
    private var saveButton: some View {
        Button(action: saveTravelPlan) {
            HStack(spacing: 6) {
                if isUploading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("保存中...")
                } else {
                    Image(systemName: "checkmark.circle.fill")
                    Text("保存")
                }
            }
            .font(.headline.weight(.bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isFormValid ? travelColor : themeManager.currentTheme.secondaryText)
                    .shadow(color: travelColor.opacity(0.4), radius: 8, x: 0, y: 4)
            )
            .animation(.easeInOut(duration: 0.2), value: isFormValid)
        }
        .disabled(!isFormValid || isUploading)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 32)
        .background(.ultraThinMaterial)
    }

    // MARK: - Helper Views
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
                .foregroundColor(travelColor)
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(textColor)
        }
    }

    // MARK: - Actions
    private func saveTravelPlan() {
        isUploading = true

        if let image = selectedImage {
            handleImageSave(image)
        } else {
            handleNoImageSave()
        }
    }

    private func handleImageSave(_ image: UIImage) {
        if let existingFileName = plan.localImageFileName,
           FileManager.documentsImage(named: existingFileName) == image {
            saveUpdatedPlan(with: existingFileName)
        } else {
            saveNewImage(image)
        }
    }

    private func saveNewImage(_ image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            saveUpdatedPlan(with: plan.localImageFileName)
            return
        }

        let fileName = "travel_plan_\(UUID().uuidString).jpg"

        do {
            try FileManager.saveImageDataToDocuments(data: imageData, named: fileName)
            deleteOldImageIfExists()
            saveUpdatedPlan(with: fileName)
        } catch {
            saveUpdatedPlan(with: plan.localImageFileName)
        }
    }

    private func handleNoImageSave() {
        deleteOldImageIfExists()
        saveUpdatedPlan(with: nil)
    }

    private func deleteOldImageIfExists() {
        if let oldFileName = plan.localImageFileName {
            try? FileManager.removeDocumentFile(named: oldFileName)
        }
    }

    private func saveUpdatedPlan(with fileName: String?) {
        var updatedPlan = plan
        updatedPlan.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedPlan.destination = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedPlan.latitude = destinationCoordinate?.latitude
        updatedPlan.longitude = destinationCoordinate?.longitude
        updatedPlan.startDate = startDate
        updatedPlan.endDate = normalizedEndDate
        updatedPlan.localImageFileName = fileName

        if let userId = authVM.userId {
            viewModel.update(updatedPlan, userId: userId, image: selectedImage)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isUploading = false
            presentationMode.wrappedValue.dismiss()
        }
    }

    // MARK: - Location Search
    private func searchLocationCoordinate(for query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            destinationCoordinate = nil
            return
        }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        MKLocalSearch(request: request).start { response, _ in
            guard let item = response?.mapItems.first else { return }
            let coord = item.placemark.coordinate
            DispatchQueue.main.async {
                destinationCoordinate = (coord.latitude, coord.longitude)
            }
        }
    }
}
