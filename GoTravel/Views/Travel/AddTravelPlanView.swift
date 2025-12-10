import SwiftUI
import PhotosUI
import MapKit

// TravelPlanの追加画面
struct AddTravelPlanView: View {
    // MARK: - Properties
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var themeManager = ThemeManager.shared
    var onSave: (TravelPlan) -> Void

    @State private var title: String = ""
    @State private var destination: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var isUploading = false
    @State private var destinationCoordinate: (latitude: Double, longitude: Double)?

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
            gradient: Gradient(colors: [themeManager.currentTheme.gradientDark, themeManager.currentTheme.dark]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            backgroundGradient

            VStack {
                headerView
                contentView
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

            Text("新しい旅行計画")
                .font(.headline)
                .foregroundColor(themeManager.currentTheme.accent2)

            Spacer()
        }
        .padding()
        .background(themeManager.currentTheme.accent2.opacity(0.2))
    }

    private var backButton: some View {
        Button(action: { presentationMode.wrappedValue.dismiss() }) {
            HStack {
                Image(systemName: "chevron.left")
                    .foregroundColor(themeManager.currentTheme.accent2)
                    .imageScale(.large)
                Text("戻る")
                    .foregroundColor(themeManager.currentTheme.accent2)
            }
        }
    }

    private var contentView: some View {
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
                .foregroundColor(themeManager.currentTheme.accent2)

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
            .onChange(of: destination) { oldValue, newValue in
                searchLocationCoordinate(for: newValue)
            }

            HStack(alignment: .center) {
                datePickerCard(title: "開始日", date: $startDate)
                datePickerCard(title: "終了日", date: $endDate)
            }
        }
        .padding()
        .background(themeManager.currentTheme.accent2.opacity(0.1))
        .cornerRadius(15)
    }

    private var imagePickerSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("カード表紙の写真")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(themeManager.currentTheme.accent2)

            if let image = selectedImage {
                selectedImageView(image: image)
            } else {
                imagePickerButton
            }
        }
        .padding()
        .background(themeManager.currentTheme.accent2.opacity(0.1))
        .cornerRadius(15)
        .sheet(isPresented: $showImagePicker) {
            ImageCropPickerView(image: $selectedImage, aspectRatio: 1.0)
        }
    }

    private func selectedImageView(image: UIImage) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 200)
                .cornerRadius(15)
                .clipped()

            removeImageButton
        }
    }

    private var removeImageButton: some View {
        Button(action: {
            selectedImage = nil
        }) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 30))
                .foregroundColor(themeManager.currentTheme.error)
                .background(Circle().fill(themeManager.currentTheme.accent1.opacity(0.5)))
        }
        .padding(8)
    }

    private var imagePickerButton: some View {
        Button(action: {
            showImagePicker = true
        }) {
            VStack(spacing: 10) {
                Image(systemName: "photo.fill")
                    .font(.system(size: 50))
                    .foregroundColor(themeManager.currentTheme.accent2.opacity(0.7))

                Text("写真を選択")
                    .foregroundColor(themeManager.currentTheme.accent2)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .background(themeManager.currentTheme.accent2.opacity(0.2))
            .cornerRadius(15)
        }
    }

    private var saveButton: some View {
        Button(action: saveTravelPlan) {
            HStack {
                if isUploading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: themeManager.currentTheme.accent2))
                    Text("保存中...")
                        .foregroundColor(themeManager.currentTheme.accent2)
                } else {
                    Text("旅行計画を保存")
                        .foregroundColor(themeManager.currentTheme.accent2)
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

    private var saveButtonGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [themeManager.currentTheme.primary, themeManager.currentTheme.secondary]),
            startPoint: .leading,
            endPoint: .trailing
        )
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
        .background(themeManager.currentTheme.accent2.opacity(0.2))
        .cornerRadius(10)
    }

    private func datePickerCard(title: String, date: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .foregroundColor(themeManager.currentTheme.accent2)
                .font(.headline)
            DatePicker("", selection: date, displayedComponents: .date)
                .datePickerStyle(CompactDatePickerStyle())
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(themeManager.currentTheme.accent2.opacity(0.2))
        .cornerRadius(10)
    }

    // MARK: - Actions
    private func saveTravelPlan() {

        isUploading = true

        if let image = selectedImage {
            saveWithImage(image)
        } else {
            saveWithoutImage()
        }
    }

    private func saveWithImage(_ image: UIImage) {
        // 画像をローカルに保存
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            createAndSavePlan(withImageFileName: nil)
            return
        }

        let fileName = "travel_plan_\(UUID().uuidString).jpg"

        do {
            try FileManager.saveImageDataToDocuments(data: imageData, named: fileName)
            createAndSavePlan(withImageFileName: fileName)
        } catch {
            print("❌ Failed to save image: \(error)")
            createAndSavePlan(withImageFileName: nil)
        }
    }

    private func saveWithoutImage() {
        createAndSavePlan(withImageFileName: nil)
    }

    private func createAndSavePlan(withImageFileName fileName: String?) {
        #if DEBUG
        print("💾 Creating travel plan:")
        print("   Title: \(title)")
        print("   Destination: \(destination)")
        if let coord = destinationCoordinate {
            print("   Coordinates: (\(coord.latitude), \(coord.longitude))")
        } else {
            print("   Coordinates: nil")
        }
        print("   Start Date: \(startDate)")
        print("   End Date: \(normalizedEndDate)")
        #endif

        let plan = TravelPlan(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: startDate,
            endDate: normalizedEndDate,
            destination: destination.trimmingCharacters(in: .whitespacesAndNewlines),
            latitude: destinationCoordinate?.latitude,
            longitude: destinationCoordinate?.longitude,
            localImageFileName: fileName,
            cardColor: themeManager.currentTheme.primary
        )

        #if DEBUG
        if let lat = plan.latitude, let lon = plan.longitude {
            print("✅ Travel plan created with coordinates: (\(lat), \(lon))")
        } else {
            print("✅ Travel plan created without coordinates")
        }
        #endif

        onSave(plan)
        isUploading = false
        presentationMode.wrappedValue.dismiss()
    }

    // MARK: - Location Search
    private func searchLocationCoordinate(for query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        #if DEBUG
        print("🔍 Searching location for: '\(trimmedQuery)'")
        #endif

        guard !trimmedQuery.isEmpty else {
            #if DEBUG
            print("⚠️ Empty query, clearing coordinates")
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
                print("❌ Location search error: \(error.localizedDescription)")
                #endif
                return
            }

            guard let response = response,
                  let firstItem = response.mapItems.first else {
                #if DEBUG
                print("❌ No search results found for: '\(trimmedQuery)'")
                #endif
                return
            }

            let coordinate = firstItem.placemark.coordinate
            let foundLocation = (coordinate.latitude, coordinate.longitude)

            #if DEBUG
            print("✅ Location found: \(firstItem.name ?? "Unknown")")
            print("   Coordinates: (\(coordinate.latitude), \(coordinate.longitude))")
            #endif

            DispatchQueue.main.async {
                destinationCoordinate = foundLocation
            }
        }
    }
}

// MARK: - Preview
#Preview {
    AddTravelPlanView { _ in }
}
