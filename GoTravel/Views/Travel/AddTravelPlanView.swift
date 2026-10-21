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
    @State private var destinationSearchTask: Task<Void, Never>?

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

    /// タイトルと行き先があれば、残り（日程の確認・表紙）を飛ばして保存できる
    private var canSaveNow: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
            && !destination.trimmingCharacters(in: .whitespaces).isEmpty
            && startDate <= endDate
    }

    /// 入力途中の内容があるか（誤操作による破棄を防ぐ）
    private var hasUnsavedInput: Bool {
        currentStep > 0 || !title.trimmingCharacters(in: .whitespaces).isEmpty
            || !destination.trimmingCharacters(in: .whitespaces).isEmpty || selectedImage != nil
    }

    // MARK: - Theme-Adaptive Colors
    //
    // 予定の追加の画面（`AddPlanView`）と同じ作りにそろえる：明るい地に旅行の色をふわりと流し、
    // 文字はテーマの文字の色、塗りのボタンは白い文字が読める濃さの旅行の色。
    // 以前は地が白から濃い色へ変わるグラデーションで、文字はダークモード用の明るい色に決め打ちしていたため、
    // 追加テーマ（藍と生成りなど）では上のほうの文字が読めなかった

    @Environment(\.colorScheme) private var colorScheme
    @State private var showDiscardConfirm = false
    @State private var expandedDate: DateField?
    @FocusState private var focusedField: Field?

    private enum Field { case title, destination }
    private enum DateField { case start, end }

    /// 旅行の色（予定の一覧・カレンダーの旅行と同じ）
    private var tripColor: Color { themeManager.currentTheme.travelColor }

    /// 白文字を載せる塗り。明るい色は白が読める濃さまで落とす
    private var filledTripColor: Color { ThemePreset.readableTint(tripColor, on: .white) }

    /// 文字の色
    private var uiAccentColor: Color { themeManager.currentTheme.adaptiveText(for: colorScheme) }

    private var cardSurface: Color { themeManager.currentTheme.listCardSurface(for: colorScheme) }

    private var backgroundGradient: some View {
        let base = colorScheme == .dark
            ? themeManager.currentTheme.backgroundDark
            : themeManager.currentTheme.backgroundLight
        return ZStack {
            base
            RadialGradient(colors: [tripColor.opacity(colorScheme == .dark ? 0.30 : 0.16), .clear],
                           center: UnitPoint(x: 0.06, y: 0), startRadius: 0, endRadius: 430)
            RadialGradient(colors: [tripColor.opacity(colorScheme == .dark ? 0.16 : 0.09), .clear],
                           center: UnitPoint(x: 1, y: 0.92), startRadius: 0, endRadius: 380)
        }
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
        .interactiveDismissDisabled(hasUnsavedInput)
        .confirmationDialog("入力内容を破棄しますか？", isPresented: $showDiscardConfirm, titleVisibility: .visible) {
            Button("破棄する", role: .destructive) { presentationMode.wrappedValue.dismiss() }
            Button("編集を続ける", role: .cancel) {}
        } message: {
            Text("作成途中の旅行計画は保存されません")
        }
        .onChange(of: startDate) { _, newValue in
            // 出発日を帰る日より後にしたら、帰る日を合わせる
            if endDate < newValue { endDate = newValue }
        }
        .onAppear { focusedField = .title }
    }

    // MARK: - Header（左：閉じる／戻る、右：保存）
    private var headerView: some View {
        HStack {
            Button(action: {
                if currentStep > 0 {
                    goBack()
                } else if hasUnsavedInput {
                    showDiscardConfirm = true
                } else {
                    presentationMode.wrappedValue.dismiss()
                }
            }) {
                Image(systemName: currentStep > 0 ? "chevron.left" : "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(uiAccentColor)
                    .frame(width: 38, height: 38)
                    .background(uiAccentColor.opacity(0.08), in: Circle())
            }
            .accessibilityLabel(currentStep > 0 ? "前の質問へ" : "閉じる")

            Spacer()

            if canSaveNow && !isLastStep {
                Button(action: saveTravelPlan) {
                    Text("保存")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(filledTripColor, in: Capsule())
                }
                .disabled(isUploading)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: canSaveNow)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Progress Indicator
    private var progressView: some View {
        HStack(spacing: 5) {
            ForEach(0..<totalSteps, id: \.self) { i in
                Capsule()
                    .fill(i <= currentStep ? tripColor : uiAccentColor.opacity(0.14))
                    .frame(height: 4)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentStep)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // MARK: - Step Heading（質問文そのものを見出しにする）
    private func stepHeading(_ stepName: String, question: String, sub: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ステップ \(currentStep + 1) · \(stepName)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(filledTripColor)
            Text(question)
                .font(.system(size: 27, weight: .heavy))
                .foregroundColor(uiAccentColor)
                .fixedSize(horizontal: false, vertical: true)
            if let sub {
                Text(sub)
                    .font(.system(size: 14))
                    .foregroundColor(uiAccentColor.opacity(0.55))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 4)
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

    // MARK: - Navigation Buttons（下は主ボタン1つ。戻るはヘッダーの ‹）
    private var navigationButtons: some View {
        VStack(spacing: 10) {
            Button(action: goForward) {
                HStack(spacing: 6) {
                    if isLastStep {
                        if isUploading {
                            ProgressView().tint(.white)
                            Text("保存中...")
                        } else {
                            Image(systemName: "airplane.departure")
                            Text("保存")
                        }
                    } else {
                        Text("次へ")
                        Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold))
                    }
                }
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(canProceed ? .white : uiAccentColor.opacity(0.35))
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(canProceed ? AnyShapeStyle(filledTripColor) : AnyShapeStyle(uiAccentColor.opacity(0.08)))
                )
                .shadow(color: canProceed ? tripColor.opacity(colorScheme == .dark ? 0 : 0.32) : .clear,
                        radius: 14, x: 0, y: 7)
                .animation(.easeInOut(duration: 0.2), value: canProceed)
            }
            .disabled(!canProceed || isUploading)

            // 表紙は入れなくても保存できる
            if currentStep == 3 && selectedImage == nil {
                Button(action: saveTravelPlan) {
                    Text("表紙なしで保存")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(uiAccentColor.opacity(0.5))
                }
                .disabled(isUploading)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 26)
    }

    private func goBack() {
        isGoingForward = false
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { currentStep -= 1 }
    }

    private func goForward() {
        guard !isLastStep else {
            saveTravelPlan()
            return
        }
        isGoingForward = true
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { currentStep += 1 }
        focusedField = currentStep == 1 ? .destination : nil
    }

    // MARK: - 入力欄（箱をやめて直接書く。下線の色で入れ終わったことが分かる）
    private func bigField(_ label: String, text: Binding<String>, placeholder: String, field: Field,
                          onChange: ((String) -> Void)? = nil) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(uiAccentColor.opacity(0.5))
            ZStack(alignment: .leading) {
                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(uiAccentColor.opacity(0.22))
                }
                TextField("", text: text)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(uiAccentColor)
                    .focused($focusedField, equals: field)
                    .submitLabel(.next)
                    .onSubmit { if canProceed { goForward() } }
                    .onChange(of: text.wrappedValue) { _, value in onChange?(value) }
            }
            Rectangle()
                .fill(text.wrappedValue.isEmpty ? uiAccentColor.opacity(0.15) : tripColor)
                .frame(height: 2)
                .animation(.easeInOut(duration: 0.2), value: text.wrappedValue.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }

    // MARK: - Step 0: Title
    private var step0Title: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                stepHeading("名前", question: "どんな旅行に\n行きますか？")
                bigField("名前", text: $title, placeholder: "夏の北海道旅行", field: .title)
                Spacer(minLength: 20)
            }
        }
    }

    // MARK: - Step 1: Destination
    private var step1Destination: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                stepHeading("行き先", question: "どこへ\n行きますか？", sub: "天気や地図に使います。")
                bigField("行き先", text: $destination, placeholder: "北海道、沖縄、ソウル…", field: .destination) { value in
                    searchLocationCoordinate(for: value)
                }
                if destinationCoordinate != nil && !destination.isEmpty {
                    Label("場所が見つかりました", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(filledTripColor)
                        .padding(.horizontal, 20)
                }
                Spacer(minLength: 20)
            }
        }
    }

    // MARK: - Step 2: Dates
    private var step2Dates: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                stepHeading("日程", question: "いつ\n行きますか？")
                VStack(spacing: 0) {
                    dateRow(.start, label: "出発", date: $startDate)
                    Rectangle().fill(uiAccentColor.opacity(0.08)).frame(height: 1).padding(.leading, 20)
                    dateRow(.end, label: "帰る日", date: $endDate, from: startDate)
                }
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(cardSurface))
                .padding(.horizontal, 20)

                if startDate <= endDate {
                    let nights = Calendar.current.dayDifference(from: startDate, to: endDate)
                    Text(nights == 0 ? "日帰り" : "\(nights)泊\(nights + 1)日")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(filledTripColor)
                        .padding(.horizontal, 20)
                }
                Spacer(minLength: 20)
            }
        }
    }

    /// 日付を大きく出し、押すとその場にカレンダーが開く（予定の追加の画面と同じ）
    private func dateRow(_ field: DateField, label: String, date: Binding<Date>, from lower: Date? = nil) -> some View {
        let isExpanded = expandedDate == field
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { expandedDate = isExpanded ? nil : field }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(label)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(uiAccentColor.opacity(0.5))
                        Text(TravelPlanTextExporter.dateString(date.wrappedValue))
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(uiAccentColor)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(uiAccentColor.opacity(0.4))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Group {
                    if let lower {
                        DatePicker("", selection: date, in: lower..., displayedComponents: .date)
                    } else {
                        DatePicker("", selection: date, displayedComponents: .date)
                    }
                }
                .datePickerStyle(.graphical)
                .labelsHidden()
                .tint(filledTripColor)
                .padding(.horizontal, 12)
                .transition(.opacity)
            }
        }
    }

    // MARK: - Step 3: Cover Image
    private var step3CoverImage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                stepHeading("表紙", question: "表紙の写真を\n選びますか？", sub: "あとからでも変えられます。")
                Group {
                    if let image = selectedImage {
                        selectedImageView(image: image)
                    } else {
                        imagePickerButton
                    }
                }
                .padding(.horizontal, 20)
                Spacer(minLength: 20)
            }
        }
    }

    private func selectedImageView(image: UIImage) -> some View {
        ZStack(alignment: .topTrailing) {
            Color.clear
                .frame(height: 220)
                .frame(maxWidth: .infinity)
                .overlay(Image(uiImage: image).resizable().scaledToFill())
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            Button(action: { selectedImage = nil }) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(.black.opacity(0.45), in: Circle())
            }
            .accessibilityLabel("表紙の写真を外す")
            .padding(12)
        }
    }

    private var imagePickerButton: some View {
        VStack(spacing: 10) {
            // 未購入のときだけ出る
            DeviceOnlyPhotoNote()
            imagePickerTapArea
        }
    }

    private var imagePickerTapArea: some View {
        Button(action: { showImagePicker = true }) {
            VStack(spacing: 12) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(filledTripColor)
                Text("写真を選ぶ")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(uiAccentColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(cardSurface))
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Actions
    private func saveTravelPlan() {
        isUploading = true
        Task { @MainActor in
            await settleDestinationCoordinate()
            if let image = selectedImage {
                saveWithImage(image)
            } else {
                saveWithoutImage()
            }
        }
    }

    private func saveWithImage(_ image: UIImage) {
        guard let imageData = image.storedPhotoData() else {
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
        // 打っている途中の検索は捨てる。残すと古い結果が後から上書きする
        destinationSearchTask?.cancel()

        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            destinationCoordinate = nil
            return
        }

        destinationSearchTask = Task { @MainActor in
            let coordinate = await DestinationGeocoder.coordinate(for: query)
            guard !Task.isCancelled else { return }
            destinationCoordinate = coordinate.map { ($0.latitude, $0.longitude) }
            // 終わったことを保存側に伝える（検索中なら保存が待つ）
            destinationSearchTask = nil
        }
    }

    /// 保存の前に、目的地の座標がそろうのを待つ。
    ///
    /// 検索は入力が止まって0.5秒後に始まり、通信を経て座標が入る。
    /// 以前は保存がこれを待たず、「沖縄」と打ってすぐ保存すると座標が空のまま残り、
    /// 天気が「設定された場所には天気の情報がありませんでした」になっていた。
    /// 検索中か、座標がまだ無いときは、ここで引き直してから保存する
    private func settleDestinationCoordinate() async {
        let query = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, destinationCoordinate == nil || destinationSearchTask != nil else { return }

        destinationSearchTask?.cancel()
        destinationSearchTask = nil
        let coordinate = await DestinationGeocoder.coordinate(for: query, debounce: 0)
        destinationCoordinate = coordinate.map { ($0.latitude, $0.longitude) }
    }

}

// MARK: - Preview
#Preview {
    AddTravelPlanView { _ in }
}
