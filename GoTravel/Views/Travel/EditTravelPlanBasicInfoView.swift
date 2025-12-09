import SwiftUI
import MapKit

// TravelPlanの編集画面
struct EditTravelPlanBasicInfoView: View {
    // MARK: - Properties
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var viewModel: TravelPlanViewModel
    @EnvironmentObject var authVM: AuthViewModel
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

    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [themeManager.currentTheme.primary.opacity(0.9), Color.black]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var saveButtonGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [themeManager.currentTheme.primary, themeManager.currentTheme.secondary]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            backgroundGradient

            VStack {
                headerView
                scrollContent
                saveButton
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - View Components
    private var headerView: some View {
        HStack {
            backButton

            Spacer()

            Text("基本情報を編集")
                .font(.headline)
                .foregroundColor(.white)

            Spacer()
        }
        .padding()
        .background(Color.black.opacity(0.2))
    }

    private var backButton: some View {
        Button(action: { presentationMode.wrappedValue.dismiss() }) {
            HStack {
                Image(systemName: "chevron.left")
                    .foregroundColor(.white)
                    .imageScale(.large)
                Text("戻る")
                    .foregroundColor(.white)
            }
        }
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                basicInfoSection
                imagePickerSection
            }
            .padding()
        }
    }

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("旅行の詳細")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            customTextField(
                icon: "text.alignleft",
                placeholder: "タイトル",
                text: $title
            )

            customTextField(
                icon: "mappin.circle",
                placeholder: "目的地",
                text: $destination
            )
            .onChange(of: destination) { newValue in
                searchLocationCoordinate(for: newValue)
            }

            HStack(alignment: .center) {
                datePickerCard(title: "開始日", date: $startDate)
                datePickerCard(title: "終了日", date: $endDate)
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(15)
    }

    private var imagePickerSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("カード表紙の写真")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            if let image = selectedImage {
                selectedImageView(image: image)
            } else {
                imagePickerButton
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(15)
        .sheet(isPresented: $showImagePicker) {
            ImageCropPickerView(image: $selectedImage, aspectRatio: 1.0)
        }
        .onChange(of: selectedImage) { _, newImage in
            logImageChange(newImage)
        }
    }

    private func selectedImageView(image: UIImage) -> some View {
        VStack(spacing: 10) {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 200)
                    .cornerRadius(15)
                    .clipped()

                removeImageButton
            }

            changeImageButton
        }
    }

    private var removeImageButton: some View {
        Button(action: {
            selectedImage = nil
        }) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 30))
                .foregroundColor(.white)
                .background(Circle().fill(Color.black.opacity(0.5)))
        }
        .padding(8)
    }

    private var changeImageButton: some View {
        Button(action: {
            showImagePicker = true
        }) {
            HStack {
                Image(systemName: "photo")
                Text("写真を変更")
            }
            .foregroundColor(.white)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(themeManager.currentTheme.primary.opacity(0.5))
            .cornerRadius(10)
        }
    }

    private var imagePickerButton: some View {
        Button(action: {
            showImagePicker = true
        }) {
            VStack(spacing: 10) {
                Image(systemName: "photo.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white.opacity(0.7))

                Text("写真を選択")
                    .foregroundColor(.white)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .background(Color.white.opacity(0.2))
            .cornerRadius(15)
        }
    }

    private var saveButton: some View {
        Button(action: saveTravelPlan) {
            HStack {
                if isUploading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("保存中...")
                        .foregroundColor(.white)
                } else {
                    Text("保存")
                        .foregroundColor(.white)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(saveButtonGradient)
            .cornerRadius(10)
            .shadow(radius: 10)
        }
        .padding()
        .disabled(!isFormValid || isUploading)
    }

    // MARK: - Helper Views
    private func customTextField(icon: String, placeholder: String, text: Binding<String>) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.white.opacity(0.7))
            TextField(placeholder, text: text)
                .foregroundColor(.white)
        }
        .padding()
        .background(Color.white.opacity(0.2))
        .cornerRadius(10)
    }

    private func datePickerCard(title: String, date: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .foregroundColor(.white)
                .font(.headline)
            DatePicker("", selection: date, displayedComponents: .date)
                .datePickerStyle(CompactDatePickerStyle())
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color.white.opacity(0.2))
        .cornerRadius(10)
    }

    // MARK: - Helper Methods
    private func logImageChange(_ newImage: UIImage?) {
        if newImage != nil {
        } else {
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
            print("❌ Failed to save image: \(error)")
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
        #if DEBUG
        print("💾 [Edit] Updating travel plan:")
        print("   Title: \(title)")
        print("   Destination: \(destination)")
        if let coord = destinationCoordinate {
            print("   Coordinates: (\(coord.latitude), \(coord.longitude))")
        } else {
            print("   Coordinates: nil")
        }
        #endif

        var updatedPlan = plan
        updatedPlan.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedPlan.destination = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedPlan.latitude = destinationCoordinate?.latitude
        updatedPlan.longitude = destinationCoordinate?.longitude
        updatedPlan.startDate = startDate
        updatedPlan.endDate = normalizedEndDate
        updatedPlan.localImageFileName = fileName

        #if DEBUG
        if let lat = updatedPlan.latitude, let lon = updatedPlan.longitude {
            print("✅ [Edit] Updated plan with coordinates: (\(lat), \(lon))")
        } else {
            print("✅ [Edit] Updated plan without coordinates")
        }
        #endif

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
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        #if DEBUG
        print("🔍 [Edit] Searching location for: '\(trimmedQuery)'")
        #endif

        guard !trimmedQuery.isEmpty else {
            #if DEBUG
            print("⚠️ [Edit] Empty query, clearing coordinates")
            #endif
            destinationCoordinate = nil
            return
        }

        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = trimmedQuery

        let search = MKLocalSearch(request: searchRequest)
        search.start { response, error in
            if let error = error {
                #if DEBUG
                print("❌ [Edit] Location search error: \(error.localizedDescription)")
                #endif
                return
            }

            guard let response = response,
                  let firstItem = response.mapItems.first else {
                #if DEBUG
                print("❌ [Edit] No search results found for: '\(trimmedQuery)'")
                #endif
                return
            }

            let coordinate = firstItem.placemark.coordinate
            let foundLocation = (coordinate.latitude, coordinate.longitude)

            #if DEBUG
            print("✅ [Edit] Location found: \(firstItem.name ?? "Unknown")")
            print("   Coordinates: (\(coordinate.latitude), \(coordinate.longitude))")
            #endif

            DispatchQueue.main.async {
                destinationCoordinate = foundLocation
            }
        }
    }
}
