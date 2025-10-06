import SwiftUI
import PhotosUI

struct AddTravelPlanView: View {

    // MARK: - Properties
    @Environment(\.presentationMode) var presentationMode
    var onSave: (TravelPlan) -> Void

    @State private var title: String = ""
    @State private var destination: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var isUploading = false

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
            gradient: Gradient(colors: [Color.blue.opacity(0.9), Color.black]),
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
                .foregroundColor(.white)
                .background(Circle().fill(Color.black.opacity(0.5)))
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
                    Text("旅行計画を保存")
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

    private var saveButtonGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [Color.blue, Color.purple]),
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

    // MARK: - Actions
    private func saveTravelPlan() {
        print("🎯 AddTravelPlanView: 保存処理開始")
        print("   タイトル: \(title)")
        print("   目的地: \(destination)")
        print("   画像: \(selectedImage != nil ? "あり" : "なし")")

        isUploading = true

        if let image = selectedImage {
            saveWithImage(image)
        } else {
            saveWithoutImage()
        }
    }

    private func saveWithImage(_ image: UIImage) {
        print("📸 AddTravelPlanView: 画像ローカル保存開始")
        FirestoreService.shared.saveTravelPlanImageLocally(image) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let fileName):
                    print("✅ AddTravelPlanView: 画像保存成功 - \(fileName)")
                    createAndSavePlan(withImageFileName: fileName)

                case .failure(let error):
                    print("❌ AddTravelPlanView: 画像保存エラー - \(error.localizedDescription)")
                    // エラーでも画像なしで保存
                    createAndSavePlan(withImageFileName: nil)
                }
            }
        }
    }

    private func saveWithoutImage() {
        print("⚪️ AddTravelPlanView: 画像なしで保存")
        createAndSavePlan(withImageFileName: nil)
    }

    private func createAndSavePlan(withImageFileName fileName: String?) {
        let plan = TravelPlan(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: startDate,
            endDate: normalizedEndDate,
            destination: destination.trimmingCharacters(in: .whitespacesAndNewlines),
            localImageFileName: fileName,
            cardColor: Color.blue
        )

        print("📤 AddTravelPlanView: onSave呼び出し")
        onSave(plan)
        isUploading = false
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Preview
#Preview {
    AddTravelPlanView { _ in }
}
