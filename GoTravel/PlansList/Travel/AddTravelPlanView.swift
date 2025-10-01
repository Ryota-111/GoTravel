import SwiftUI
import PhotosUI

struct AddTravelPlanView: View {
    @Environment(\.presentationMode) var presentationMode

    var onSave: (TravelPlan) -> Void

    @State private var title: String = ""
    @State private var destination: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()
    @State private var selectedImage: UIImage? = nil
    @State private var showImagePicker = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var showDetailSheet = false
    @State private var isUploading = false

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.9), Color.black]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack {
                headerView

                ScrollView {
                    VStack(spacing: 20) {
                        basicInfoSection
                        imagePickerSection
                        detailSection
                    }
                    .padding()
                }

                saveButton
            }
        }
        .navigationBarHidden(true)
    }

    private var headerView: some View {
        HStack {
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.white)
                    .imageScale(.large)
                Text("戻る")
                    .foregroundColor(.white)
            }

            Spacer()

            Text("新しい旅行計画")
                .font(.headline)
                .foregroundColor(.white)

            Spacer()
        }
        .padding()
        .background(Color.black.opacity(0.2))
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

            VStack(spacing: 15) {
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
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 200)
                        .cornerRadius(15)
                        .clipped()

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
            } else {
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
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(15)
        .sheet(isPresented: $showImagePicker) {
            ImagePickerView(sourceType: imageSourceType, image: $selectedImage)
        }
    }

    private var detailSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("詳細")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Button(action: {
                showDetailSheet = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("詳細を追加")
                }
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue.opacity(0.5))
                .cornerRadius(10)
            }

            Text("※詳細は後ほど追加できます")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(15)
        .sheet(isPresented: $showDetailSheet) {
            Text("詳細追加画面（後ほど実装）")
                .font(.title)
                .padding()
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
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue, Color.purple]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(10)
            .shadow(radius: 10)
        }
        .padding()
        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty ||
                  destination.trimmingCharacters(in: .whitespaces).isEmpty ||
                  startDate > endDate || isUploading)
    }

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

    private func saveTravelPlan() {
        print("🎯 AddTravelPlanView: 保存処理開始")
        print("   タイトル: \(title)")
        print("   目的地: \(destination)")
        print("   画像: \(selectedImage != nil ? "あり" : "なし")")

        isUploading = true
        let normalizedEnd = endDate < startDate ? startDate : endDate

        if let image = selectedImage {
            print("📸 AddTravelPlanView: 画像ローカル保存開始")
            FirestoreService.shared.saveTravelPlanImageLocally(image) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let fileName):
                        print("✅ AddTravelPlanView: 画像保存成功 - \(fileName)")
                        let plan = TravelPlan(
                            title: self.title.trimmingCharacters(in: .whitespacesAndNewlines),
                            startDate: self.startDate,
                            endDate: normalizedEnd,
                            destination: self.destination.trimmingCharacters(in: .whitespacesAndNewlines),
                            localImageFileName: fileName,
                            cardColor: Color.blue
                        )
                        print("📤 AddTravelPlanView: onSave呼び出し")
                        self.onSave(plan)
                        self.isUploading = false
                        self.presentationMode.wrappedValue.dismiss()

                    case .failure(let error):
                        print("❌ AddTravelPlanView: 画像保存エラー - \(error.localizedDescription)")
                        self.isUploading = false
                        // エラーでも画像なしで保存
                        let plan = TravelPlan(
                            title: self.title.trimmingCharacters(in: .whitespacesAndNewlines),
                            startDate: self.startDate,
                            endDate: normalizedEnd,
                            destination: self.destination.trimmingCharacters(in: .whitespacesAndNewlines),
                            localImageFileName: nil,
                            cardColor: Color.blue
                        )
                        self.onSave(plan)
                        self.presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        } else {
            print("⚪️ AddTravelPlanView: 画像なしで保存")
            let plan = TravelPlan(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                startDate: startDate,
                endDate: normalizedEnd,
                destination: destination.trimmingCharacters(in: .whitespacesAndNewlines),
                localImageFileName: nil,
                cardColor: Color.blue
            )
            print("📤 AddTravelPlanView: onSave呼び出し（画像なし）")
            onSave(plan)
            isUploading = false
            presentationMode.wrappedValue.dismiss()
        }
    }
}

#Preview {
    AddTravelPlanView { _ in }
}
