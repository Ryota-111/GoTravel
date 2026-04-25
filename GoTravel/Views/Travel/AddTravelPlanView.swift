import SwiftUI
import PhotosUI
import MapKit

struct AddTravelPlanView: View {
    // MARK: - Properties
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var themeManager = ThemeManager.shared
    var onSave: (TravelPlan) -> Void

    // Wizard state
    @State private var currentStep: Int = 0
    @State private var isGoingForward: Bool = true

    // Form data
    @State private var title: String = ""
    @State private var destination: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var isUploading = false
    @State private var destinationCoordinate: (latitude: Double, longitude: Double)?

    private let totalSteps = 4
    private var isLastStep: Bool { currentStep == totalSteps - 1 }

    private var canProceed: Bool {
        switch currentStep {
        case 0: return !title.trimmingCharacters(in: .whitespaces).isEmpty
        case 1: return !destination.trimmingCharacters(in: .whitespaces).isEmpty
        case 2: return startDate <= endDate
        default: return true
        }
    }

    // MARK: - Theme-Adaptive Colors
    private var travelColor: Color { themeManager.currentTheme.travelColor }

    private var uiAccentColor: Color {
        switch themeManager.currentTheme.type {
        case .pastelPink:
            return Color(red: 0.15, green: 0.30, blue: 0.15)  // ダークグリーン（ピンク背景での視認性）
        default:
            return themeManager.currentTheme.accent2
        }
    }

    private var backgroundGradient: some View {
        let colors: [Color]
        switch themeManager.currentTheme.type {
        case .whiteBlack:
            colors = [Color(white: 0.97), Color(white: 0.84)]
        default:
            colors = [themeManager.currentTheme.gradientDark, themeManager.currentTheme.dark]
        }
        return LinearGradient(
            gradient: Gradient(colors: colors),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: isGoingForward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: isGoingForward ? .leading : .trailing).combined(with: .opacity)
        )
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            backgroundGradient
            VStack(spacing: 0) {
                headerView
                progressView
                stepContentView
                navigationButtons
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImageCropPickerView(image: $selectedImage, aspectRatio: 1.0)
        }
        .navigationBarHidden(true)
    }

    // MARK: - Header
    private var headerView: some View {
        HStack {
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                Image(systemName: "xmark")
                    .foregroundColor(uiAccentColor)
                    .imageScale(.medium)
                    .padding(8)
                    .background(uiAccentColor.opacity(0.15))
                    .clipShape(Circle())
            }
            Spacer()
            Text("新しい旅行計画")
                .font(.headline)
                .foregroundColor(uiAccentColor)
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(travelColor.opacity(0.35))
    }

    // MARK: - Progress Indicator
    private var progressView: some View {
        VStack(spacing: 6) {
            HStack(spacing: 5) {
                ForEach(0..<totalSteps, id: \.self) { i in
                    Capsule()
                        .fill(i <= currentStep ? travelColor : uiAccentColor.opacity(0.2))
                        .frame(height: 4)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentStep)
            .padding(.horizontal, 20)
            Text("\(currentStep + 1) / \(totalSteps)")
                .font(.caption)
                .foregroundColor(uiAccentColor.opacity(0.6))
        }
        .padding(.vertical, 10)
    }

    // MARK: - Step Content
    private var stepContentView: some View {
        ZStack {
            switch currentStep {
            case 0: step0Title
            case 1: step1Destination
            case 2: step2Dates
            case 3: step3CoverImage
            default: EmptyView()
            }
        }
        .id(currentStep)
        .transition(stepTransition)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Navigation Buttons
    private var navigationButtons: some View {
        HStack(spacing: 12) {
            if currentStep > 0 {
                Button(action: goBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("戻る")
                    }
                    .font(.headline)
                    .foregroundColor(uiAccentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(uiAccentColor.opacity(0.15))
                    .cornerRadius(14)
                }
            }

            Button(action: goForward) {
                HStack(spacing: 4) {
                    if isLastStep {
                        if isUploading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: uiAccentColor))
                            Text("保存中...")
                        } else {
                            Image(systemName: "airplane.departure")
                            Text("保存")
                        }
                    } else {
                        Text("次へ")
                        Image(systemName: "chevron.right")
                    }
                }
                .font(.headline.weight(.bold))
                .foregroundColor(canProceed ? uiAccentColor : uiAccentColor.opacity(0.4))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(canProceed ? travelColor : uiAccentColor.opacity(0.1))
                .cornerRadius(14)
                .animation(.easeInOut(duration: 0.2), value: canProceed)
            }
            .disabled(!canProceed || isUploading)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 32)
        .background(.ultraThinMaterial)
    }

    private func goBack() {
        isGoingForward = false
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            currentStep -= 1
        }
    }

    private func goForward() {
        guard !isLastStep else {
            saveTravelPlan()
            return
        }
        isGoingForward = true
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            currentStep += 1
        }
    }

    // MARK: - Step 0: Title
    private var step0Title: some View {
        VStack(spacing: 28) {
            VStack(spacing: 8) {
                Text("旅行プランの名前は？")
                    .font(.title2.weight(.bold))
                    .foregroundColor(uiAccentColor)
                Text("例：夏の北海道旅行、沖縄3泊4日")
                    .font(.subheadline)
                    .foregroundColor(uiAccentColor.opacity(0.6))
            }
            .padding(.top, 40)

            HStack(spacing: 12) {
                Image(systemName: "pencil")
                    .foregroundColor(uiAccentColor.opacity(0.6))
                ZStack(alignment: .leading) {
                    if title.isEmpty {
                        Text("夏の北海道旅行")
                            .foregroundColor(uiAccentColor.opacity(0.3))
                            .font(.title3)
                    }
                    TextField("", text: $title)
                        .font(.title3)
                        .foregroundColor(uiAccentColor)
                }
            }
            .padding(20)
            .background(uiAccentColor.opacity(0.1))
            .cornerRadius(16)
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    // MARK: - Step 1: Destination
    private var step1Destination: some View {
        VStack(spacing: 28) {
            VStack(spacing: 8) {
                Text("どこへ行きますか？")
                    .font(.title2.weight(.bold))
                    .foregroundColor(uiAccentColor)
                Text("目的地を入力してください")
                    .font(.subheadline)
                    .foregroundColor(uiAccentColor.opacity(0.6))
            }
            .padding(.top, 40)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(travelColor)
                    ZStack(alignment: .leading) {
                        if destination.isEmpty {
                            Text("北海道、東京、大阪…")
                                .foregroundColor(uiAccentColor.opacity(0.3))
                                .font(.title3)
                        }
                        TextField("", text: $destination)
                            .font(.title3)
                            .foregroundColor(uiAccentColor)
                            .onChange(of: destination) { _, newValue in
                                searchLocationCoordinate(for: newValue)
                            }
                    }
                }
                .padding(20)
                .background(uiAccentColor.opacity(0.1))
                .cornerRadius(16)

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
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    // MARK: - Step 2: Dates
    private var step2Dates: some View {
        VStack(spacing: 28) {
            VStack(spacing: 8) {
                Text("いつ行きますか？")
                    .font(.title2.weight(.bold))
                    .foregroundColor(uiAccentColor)
                Text("出発日と帰宅日を設定してください")
                    .font(.subheadline)
                    .foregroundColor(uiAccentColor.opacity(0.6))
            }
            .padding(.top, 40)

            VStack(spacing: 12) {
                datePickerRow(label: "出発日", icon: "airplane.departure", date: $startDate)
                datePickerRow(label: "帰宅日", icon: "airplane.arrival", date: $endDate)

                if endDate < startDate {
                    Label("帰宅日は出発日以降にしてください", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.error)
                        .padding(.horizontal, 4)
                }

                if startDate <= endDate {
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
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    private func datePickerRow(label: String, icon: String, date: Binding<Date>) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(uiAccentColor.opacity(0.7))
                .frame(width: 28)
            Text(label)
                .font(.headline)
                .foregroundColor(uiAccentColor)
            Spacer()
            DatePicker("", selection: date, displayedComponents: .date)
                .colorMultiply(uiAccentColor)
                .datePickerStyle(CompactDatePickerStyle())
                .labelsHidden()
        }
        .padding(20)
        .background(uiAccentColor.opacity(0.1))
        .cornerRadius(16)
    }

    // MARK: - Step 3: Cover Image
    private var step3CoverImage: some View {
        VStack(spacing: 28) {
            VStack(spacing: 8) {
                Text("カードの表紙を設定しますか？")
                    .font(.title2.weight(.bold))
                    .foregroundColor(uiAccentColor)
                Text("任意 — スキップして保存できます")
                    .font(.subheadline)
                    .foregroundColor(uiAccentColor.opacity(0.6))
            }
            .padding(.top, 40)

            if let image = selectedImage {
                selectedImageView(image: image)
                    .padding(.horizontal, 20)
            } else {
                imagePickerButton
                    .padding(.horizontal, 20)
            }

            Spacer()
        }
    }

    private func selectedImageView(image: UIImage) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .cornerRadius(20)
                .clipped()

            Button(action: { selectedImage = nil }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(themeManager.currentTheme.error)
                    .background(Circle().fill(Color.white.opacity(0.8)))
            }
            .padding(12)
        }
    }

    private var imagePickerButton: some View {
        Button(action: { showImagePicker = true }) {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(travelColor.opacity(0.2))
                        .frame(width: 72, height: 72)
                    Image(systemName: "photo.fill")
                        .font(.system(size: 30))
                        .foregroundColor(travelColor)
                }
                Text("写真を選択")
                    .font(.headline)
                    .foregroundColor(uiAccentColor)
                Text("タップしてアルバムから選択")
                    .font(.caption)
                    .foregroundColor(uiAccentColor.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 36)
            .background(uiAccentColor.opacity(0.08))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(uiAccentColor.opacity(0.15), lineWidth: 1.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
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
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            createAndSavePlan(withImageFileName: nil)
            return
        }
        let fileName = "travel_plan_\(UUID().uuidString).jpg"
        do {
            try FileManager.saveImageDataToDocuments(data: imageData, named: fileName)
            createAndSavePlan(withImageFileName: fileName)
        } catch {
            createAndSavePlan(withImageFileName: nil)
        }
    }

    private func saveWithoutImage() {
        createAndSavePlan(withImageFileName: nil)
    }

    private func createAndSavePlan(withImageFileName fileName: String?) {
        let plan = TravelPlan(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: startDate,
            endDate: endDate < startDate ? startDate : endDate,
            destination: destination.trimmingCharacters(in: .whitespacesAndNewlines),
            latitude: destinationCoordinate?.latitude,
            longitude: destinationCoordinate?.longitude,
            localImageFileName: fileName,
            cardColor: themeManager.currentTheme.primary
        )
        onSave(plan)
        isUploading = false
        presentationMode.wrappedValue.dismiss()
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

// MARK: - Preview
#Preview {
    AddTravelPlanView { _ in }
}
