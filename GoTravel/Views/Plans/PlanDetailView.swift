import SwiftUI
import MapKit

struct PlanDetailView: View {
    @State var plan: Plan
    @State private var showMap = false
    @State private var showStreetView = false
    @State private var isEditMode = false
    @State private var displayImage: UIImage?
    @State private var showSidebar = false
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var isSaving = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showDeleteConfirmation = false
    @State private var showScheduleEditor = false
    @State private var isNotificationOn = false
    @State private var editingScheduleItem: PlanScheduleItem?

    // 編集用の一時変数
    @State private var editedTitle: String = ""
    @State private var editedDescription: String = ""
    @State private var editedLinkURL: String = ""
    @State private var editedPlanType: PlanType = .outing
    @State private var editedStartDate: Date = Date()
    @State private var editedEndDate: Date = Date()
    @State private var editedTime: Date?
    @State private var editedTags: [String] = []
    @State private var editedTagInput: String = ""
    @State private var editedRecurrence: PlanRecurrence = .none
    @State private var editedPlaces: [PlannedPlace] = []
    @State private var showAddPlaceInEdit = false
    @State private var mapPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 36.2048, longitude: 138.2529),
        span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
    ))
    @State private var selectedMapResult: MKMapItem?
    @State private var mapVisibleRegion: MKCoordinateRegion?
    @State private var searchText: String = ""
    @State private var searchResults: [MKMapItem] = []

    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: PlansViewModel
    @EnvironmentObject var authVM: AuthViewModel

    var onUpdate: ((Plan) -> Void)?

    var body: some View {
        ZStack(alignment: .leading) {
            // Main Content
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
            .offset(x: showSidebar ? 280 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showSidebar)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !isEditMode {
                            if value.translation.width > 0 && !showSidebar {
                                showSidebar = true
                            } else if value.translation.width < -50 && showSidebar {
                                showSidebar = false
                            }
                        }
                    }
            )

            // Overlay to close sidebar
            if showSidebar {
                Color.black.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showSidebar = false
                        }
                    }
                    .transition(.opacity)
            }

            // Sidebar (編集モード時は非表示)
            if !isEditMode {
                sidebarView
                    .offset(x: showSidebar ? 0 : -280)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showSidebar)
                    .zIndex(1)
            }
        }
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
                        .foregroundColor(editedTitle.isEmpty ? themeManager.currentTheme.secondaryText : planColor)
                    }
                } else {
                    Button(action: {
                        enterEditMode()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                            Text("編集")
                        }
                        .foregroundColor(planColor)
                    }
                }
            }
        }
        .task {
            loadLocalImage()
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedImage)
        }
        .fullScreenCover(isPresented: $showAddPlaceInEdit) {
            mapPickerView
        }
        .alert("エラー", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .alert("プランを削除", isPresented: $showDeleteConfirmation) {
            Button("キャンセル", role: .cancel) {}
            Button("削除", role: .destructive) {
                deletePlan()
            }
        } message: {
            Text("このプランを削除してもよろしいですか？この操作は取り消せません。")
        }
        .onChange(of: selectedImage) { oldValue, newValue in
            if newValue != nil {
                displayImage = newValue
            }
        }
    }

    // MARK: - Computed Properties
    /// 表示中の種別。編集中は編集後の種別で色と文言を出す
    private var effectivePlanType: PlanType {
        isEditMode ? editedPlanType : plan.planType
    }

    private var planColor: Color {
        effectivePlanType.color(themeManager.currentTheme)
    }

    private var planTypeText: String {
        effectivePlanType.displayName
    }

    private var planTypeIcon: String {
        effectivePlanType.icon
    }

    // MARK: - View Mode
    private var viewModeView: some View {
        VStack(spacing: 0) {
            // Top Border
            topBorderView

            // 写真の有無でヘッダーを出し分ける
            if displayImage == nil {
                noPhotoHeaderView
            } else {
                headerImageView
            }

            // Content Card
            VStack(alignment: .leading, spacing: 0) {
                // 写真なしヘッダーには種別バッジが入っているので重複させない
                if displayImage != nil {
                    HStack(spacing: 8) {
                        categoryTag
                        statusPill
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                } else {
                    Color.clear.frame(height: 8)
                }

                // 当日その場で開いたとき、一番上にあってほしいもの
                quickActionRow
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                // Description Section
                if let description = plan.description, !description.isEmpty {
                    gradientSeparator
                    descriptionSection(description)
                        .padding(.horizontal, 24)
                }

                // Link Section
                if let linkURL = plan.linkURL, !linkURL.isEmpty {
                    gradientSeparator
                    linkSection(linkURL)
                        .padding(.horizontal, 24)
                }

                if plan.planType == .anniversary {
                    gradientSeparator

                    anniversarySection
                        .padding(.horizontal, 24)
                } else {
                    gradientSeparator

                    // Schedule Section
                    scheduleSection
                        .padding(.horizontal, 24)
                }

                // 「歯医者 10:30」に地図は要らない。おでかけのときだけ出す
                if plan.planType == .outing {
                    gradientSeparator

                    mapSection
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                }

                // 場所の一覧は地図のピンと同じ内容で、タイムラインの各行も
                // 場所を持っている。三重になるのでここでは出さない

                if !plan.tags.isEmpty || plan.recurrence != .none {
                    gradientSeparator

                    tagAndRecurrenceRow
                        .padding(.horizontal, 24)
                }

                gradientSeparator

                completionSection
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Top Border
    private var topBorderView: some View {
        Rectangle()
            .fill(planColor)
            .frame(height: 6)
    }

    // MARK: - Gradient Separator
    private var gradientSeparator: some View {
        LinearGradient(
            gradient: Gradient(colors: separatorColors),
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 1)
        .padding(.vertical, 15)
    }

    private var separatorColors: [Color] {
        let color = plan.planType.color(themeManager.currentTheme)
        return [color, color]
    }

    // MARK: - Edit Mode Helpers

    private var editTextColor: Color {
        colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1
    }

    private var editFieldBg: Color {
        colorScheme == .dark ? themeManager.currentTheme.backgroundDark : themeManager.currentTheme.backgroundLight
    }

    private var editCardBg: Color {
        colorScheme == .dark ? themeManager.currentTheme.secondaryBackgroundDark : themeManager.currentTheme.secondaryBackgroundLight
    }

    @ViewBuilder
    private func editSectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(editCardBg)
                    .shadow(color: themeManager.currentTheme.shadow, radius: 6, x: 0, y: 2)
            )
    }

    private func editSectionLabel(_ text: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundColor(planColor)
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(editTextColor)
        }
    }

    private func editTypeButton(type: PlanType, icon: String, label: String) -> some View {
        let isSelected = editedPlanType == type
        let btnColor: Color = type.color(themeManager.currentTheme)
        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                editedPlanType = type
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                Text(label)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
            }
            .foregroundColor(isSelected ? .white : btnColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? btnColor : btnColor.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.clear : btnColor.opacity(0.35), lineWidth: 1.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func editDateRow(_ label: String, icon: String, date: Binding<Date>) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(planColor.opacity(0.8))
                .frame(width: 22)
            Text(label)
                .font(.subheadline)
                .foregroundColor(editTextColor)
            Spacer()
            DatePicker("", selection: date, displayedComponents: .date)
                .colorMultiply(planColor)
                .datePickerStyle(.compact)
                .labelsHidden()
        }
        .padding(14)
        .background(editFieldBg)
        .cornerRadius(12)
    }

    private func editTimeRow() -> some View {
        HStack {
            Image(systemName: "clock")
                .foregroundColor(planColor.opacity(0.8))
                .frame(width: 22)
            Text("時刻")
                .font(.subheadline)
                .foregroundColor(editTextColor)
            Spacer()
            DatePicker("", selection: Binding(
                get: { editedTime ?? Date() },
                set: { editedTime = $0 }
            ), displayedComponents: .hourAndMinute)
            .colorMultiply(planColor)
            .datePickerStyle(.compact)
            .labelsHidden()
            Button(action: { editedTime = nil }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(themeManager.currentTheme.secondaryText)
                    .padding(.leading, 6)
            }
        }
        .padding(14)
        .background(editFieldBg)
        .cornerRadius(12)
    }

    // MARK: - Edit Mode View
    private var editModeView: some View {
        VStack(spacing: 0) {
            editHeaderImageView

            VStack(spacing: 14) {

                // プランタイプ
                editSectionCard {
                    VStack(alignment: .leading, spacing: 12) {
                        editSectionLabel("プランタイプ", icon: "tag.fill")
                        HStack(spacing: 10) {
                            editTypeButton(type: .outing, icon: PlanType.outing.icon, label: PlanType.outing.displayName)
                            editTypeButton(type: .daily,  icon: PlanType.daily.icon,  label: PlanType.daily.displayName)
                            editTypeButton(type: .anniversary, icon: PlanType.anniversary.icon, label: PlanType.anniversary.displayName)
                        }
                    }
                }

                // タイトル
                editSectionCard {
                    VStack(alignment: .leading, spacing: 10) {
                        editSectionLabel("プラン名", icon: "pencil")
                        TextField("例：東京観光", text: $editedTitle)
                            .font(.body)
                            .foregroundColor(editTextColor)
                            .padding(14)
                            .background(editFieldBg)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        editedTitle.isEmpty
                                            ? themeManager.currentTheme.error.opacity(0.5)
                                            : planColor.opacity(0.3),
                                        lineWidth: 1.5
                                    )
                            )
                    }
                }

                // 日程
                editSectionCard {
                    VStack(alignment: .leading, spacing: 10) {
                        editSectionLabel(editDateSectionLabel, icon: "calendar")
                        VStack(spacing: 8) {
                            if editedPlanType == .anniversary {
                                // 記念日は日付だけ。時刻も期間も持たない
                                editDateRow("日付", icon: "calendar", date: $editedStartDate)
                            } else if editedPlanType == .outing {
                                editDateRow("開始日", icon: "airplane.departure", date: $editedStartDate)
                                editDateRow("終了日", icon: "calendar.badge.checkmark", date: $editedEndDate)
                                if editedEndDate < editedStartDate {
                                    Label("終了日は開始日以降にしてください", systemImage: "exclamationmark.triangle.fill")
                                        .font(.caption)
                                        .foregroundColor(themeManager.currentTheme.error)
                                        .padding(.top, 2)
                                }
                            } else {
                                editDateRow("日付", icon: "calendar", date: $editedStartDate)
                                if editedTime != nil {
                                    editTimeRow()
                                } else {
                                    Button(action: { editedTime = Date() }) {
                                        HStack {
                                            Image(systemName: "clock")
                                                .foregroundColor(planColor)
                                                .frame(width: 22)
                                            Text("時刻を設定")
                                                .font(.subheadline)
                                                .foregroundColor(editTextColor)
                                            Spacer()
                                            Image(systemName: "plus.circle.fill")
                                                .foregroundColor(planColor)
                                        }
                                        .padding(14)
                                        .background(editFieldBg)
                                        .cornerRadius(12)
                                    }
                                }
                            }
                        }
                    }
                }

                // 繰り返し（記念日は毎年で固定なので出さない）
                if editedPlanType == .daily {
                    editSectionCard {
                        VStack(alignment: .leading, spacing: 10) {
                            editSectionLabel("繰り返し", icon: "repeat")
                            HStack(spacing: 8) {
                                ForEach([PlanRecurrence.none, .weekly, .monthly], id: \.self) { rule in
                                    Button {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            editedRecurrence = rule
                                        }
                                    } label: {
                                        Text(rule.displayName)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(editedRecurrence == rule ? .white : editTextColor.opacity(0.7))
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 42)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .fill(editedRecurrence == rule
                                                          ? AnyShapeStyle(ThemePreset.readableTint(planColor, on: .white))
                                                          : AnyShapeStyle(editFieldBg))
                                            )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                    }
                }

                // タグ
                editSectionCard {
                    VStack(alignment: .leading, spacing: 10) {
                        editSectionLabel("タグ（任意）", icon: "number")

                        if !editedTags.isEmpty {
                            HStack(spacing: 6) {
                                ForEach(editedTags, id: \.self) { tag in
                                    Button {
                                        editedTags.removeAll { $0 == tag }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Text(tag)
                                                .font(.system(size: 12, weight: .semibold))
                                            Image(systemName: "xmark")
                                                .font(.system(size: 9, weight: .bold))
                                        }
                                        .foregroundColor(themeManager.currentTheme.secondaryText)
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 5)
                                        .background(themeManager.currentTheme.secondaryText.opacity(0.12), in: Capsule())
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }

                                Spacer(minLength: 0)
                            }
                        }

                        HStack(spacing: 8) {
                            TextField("仕事、家事、健康…", text: $editedTagInput)
                                .foregroundColor(editTextColor)
                                .submitLabel(.done)
                                .onSubmit { addEditedTag() }

                            Button("追加", action: addEditedTag)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(editedTagInput.trimmingCharacters(in: .whitespaces).isEmpty
                                                 ? themeManager.currentTheme.secondaryText
                                                 : planColor)
                                .disabled(editedTagInput.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        .padding(14)
                        .background(editFieldBg)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(planColor.opacity(0.2), lineWidth: 1))
                    }
                }

                // 予定内容
                editSectionCard {
                    VStack(alignment: .leading, spacing: 10) {
                        editSectionLabel("予定内容", icon: "text.alignleft")
                        ZStack(alignment: .topLeading) {
                            if editedDescription.isEmpty {
                                Text("この予定について...")
                                    .foregroundColor(themeManager.currentTheme.secondaryText.opacity(0.45))
                                    .font(.body)
                                    .padding(.top, 10)
                                    .padding(.leading, 5)
                            }
                            TextEditor(text: $editedDescription)
                                .font(.body)
                                .frame(minHeight: 100)
                                .foregroundColor(editTextColor)
                                .scrollContentBackground(.hidden)
                        }
                        .padding(14)
                        .background(editFieldBg)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(planColor.opacity(0.2), lineWidth: 1))
                    }
                }

                // 関連リンク（日常のみ）
                if editedPlanType == .daily {
                    editSectionCard {
                        VStack(alignment: .leading, spacing: 10) {
                            editSectionLabel("関連リンク（任意）", icon: "link")
                            HStack(spacing: 12) {
                                Image(systemName: "link")
                                    .foregroundColor(planColor.opacity(0.7))
                                TextField("https://example.com", text: $editedLinkURL)
                                    .foregroundColor(editTextColor)
                                    .keyboardType(.URL)
                                    .autocapitalization(.none)
                            }
                            .padding(14)
                            .background(editFieldBg)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(planColor.opacity(0.2), lineWidth: 1))
                        }
                    }
                }

                // 訪問場所。記念日は場所を持たない
                if editedPlanType != .anniversary {
                editSectionCard {
                    VStack(alignment: .leading, spacing: 10) {
                        editSectionLabel("訪問場所", icon: "mappin.circle.fill")

                        if editedPlaces.isEmpty {
                            HStack {
                                Image(systemName: "mappin.slash")
                                    .foregroundColor(themeManager.currentTheme.secondaryText.opacity(0.5))
                                Text("まだ場所が追加されていません")
                                    .font(.subheadline)
                                    .foregroundColor(themeManager.currentTheme.secondaryText.opacity(0.5))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(18)
                            .background(editFieldBg)
                            .cornerRadius(12)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(editedPlaces) { place in
                                    HStack(spacing: 12) {
                                        Image(systemName: "mappin.circle.fill")
                                            .foregroundColor(planColor)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(place.name)
                                                .font(.subheadline.weight(.medium))
                                                .foregroundColor(editTextColor)
                                            if let address = place.address {
                                                Text(address)
                                                    .font(.caption)
                                                    .foregroundColor(themeManager.currentTheme.secondaryText)
                                                    .lineLimit(1)
                                            }
                                        }
                                        Spacer()
                                        Button(action: {
                                            editedPlaces.removeAll { $0.id == place.id }
                                        }) {
                                            Image(systemName: "trash")
                                                .foregroundColor(themeManager.currentTheme.error)
                                                .padding(8)
                                        }
                                    }
                                    .padding(12)
                                    .background(editFieldBg)
                                    .cornerRadius(12)
                                }
                            }
                        }

                        Button(action: { showAddPlaceInEdit = true }) {
                            Label("場所を追加", systemImage: "plus.circle.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(ThemePreset.readableTint(planColor, on: .white))
                                .cornerRadius(12)
                        }
                    }
                }
                }

                // 削除ボタン
                Button(action: { showDeleteConfirmation = true }) {
                    Label("プランを削除", systemImage: "trash.fill")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(themeManager.currentTheme.error)
                                .shadow(color: themeManager.currentTheme.error.opacity(0.3), radius: 8, x: 0, y: 4)
                        )
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Header Image (View Mode)
    // MARK: - Header (写真なし)
    /// 写真がない場合は暗いスクリムをかけた擬似的な写真枠ではなく、
    /// テーマ色ベースの明るいヘッダーにして写真追加への導線を置く
    private var noPhotoHeaderView: some View {
        let mainColor = themeManager.currentTheme.xprimary
        let baseColor: Color = colorScheme == .dark
            ? themeManager.currentTheme.secondaryBackgroundDark
            : themeManager.currentTheme.backgroundLight
        let titleColor: Color = colorScheme == .dark
            ? themeManager.currentTheme.accent2
            : themeManager.currentTheme.accent1

        return ZStack(alignment: .bottomTrailing) {
            LinearGradient(
                colors: [mainColor.opacity(colorScheme == .dark ? 0.35 : 0.22), baseColor],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // 背景の飾りとして種別アイコンを大きく薄く置く
            Image(systemName: planTypeIcon)
                .font(.system(size: 150))
                .foregroundColor(mainColor.opacity(0.10))
                .offset(x: 40, y: 30)
                .clipped()

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [mainColor, mainColor.opacity(0.65)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)
                            .shadow(color: mainColor.opacity(0.35), radius: 5, x: 0, y: 3)
                        Image(systemName: planTypeIcon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    // 種別は色分けを残したいのでプランカラーのままにする
                    Text(planTypeText)
                        .font(.caption.weight(.bold))
                        .foregroundColor(planColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(planColor.opacity(0.16), in: Capsule())

                    statusPill
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(plan.title)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(titleColor)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.subheadline)

                        if plan.planType == .outing {
                            Text(dateRangeString(plan.startDate, plan.endDate))
                                .font(.subheadline)
                        } else {
                            Text(formatDate(plan.startDate))
                                .font(.subheadline)
                        }

                        if plan.planType == .daily, let time = plan.time {
                            HStack(spacing: 4) {
                                Image(systemName: "clock.fill")
                                    .font(.caption)
                                Text(formatTime(time))
                                    .font(.subheadline)
                                    .lineLimit(1)
                            }
                            .padding(.leading, 4)
                        }
                    }
                    .foregroundColor(themeManager.currentTheme.secondaryText)
                }

                Button(action: {
                    enterEditMode()
                    showImagePicker = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "camera.fill")
                            .font(.caption)
                        Text("写真を追加")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(mainColor, in: Capsule())
                    .shadow(color: mainColor.opacity(0.35), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .frame(maxWidth: .infinity)
        .clipped()
    }

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
                                planColor.opacity(0.6),
                                planColor.opacity(0.3)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 250)
                    .overlay(
                        Image(systemName: planTypeIcon)
                            .font(.system(size: 80))
                            .foregroundColor(themeManager.currentTheme.light.opacity(0.3))
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

            // Title and Date Overlay
            VStack(alignment: .leading, spacing: 8) {
                Text(plan.title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)

                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.subheadline)

                    if plan.planType == .outing {
                        Text(dateRangeString(plan.startDate, plan.endDate))
                            .font(.subheadline)
                    } else {
                        Text(formatDate(plan.startDate))
                            .font(.subheadline)
                    }

                    if plan.planType == .daily, let time = plan.time {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.caption)
                            Text(formatTime(time))
                                .font(.subheadline)
                                .lineLimit(1)
                        }
                        .padding(.leading, 4)
                    }
                }
                .foregroundColor(.white.opacity(0.9))
                .shadow(color: themeManager.currentTheme.accent1.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .padding(24)
        }
        .frame(height: 250)
    }

    // MARK: - Header Image (Edit Mode)
    private var editHeaderImageView: some View {
        ZStack(alignment: .bottom) {
            // 背景：写真 or プランカラーグラデーション
            if let image = displayImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 260)
                    .clipped()
            } else {
                LinearGradient(
                    gradient: Gradient(colors: [planColor.opacity(0.75), planColor.opacity(0.4)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 260)
                .overlay(
                    Image(systemName: editedPlanType.icon)
                        .font(.system(size: 80))
                        .foregroundColor(.white.opacity(0.2))
                )
            }

            // 下部グラデーションオーバーレイ（ボタン視認性確保）
            LinearGradient(
                gradient: Gradient(colors: [.clear, .black.opacity(0.45)]),
                startPoint: .center,
                endPoint: .bottom
            )
            .frame(height: 260)

            // 写真変更ボタン（右下）
            HStack {
                Spacer()
                Button(action: { showImagePicker = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "camera.fill")
                            .font(.subheadline)
                        Text("写真を変更")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
                }
                .padding(.trailing, 16)
                .padding(.bottom, 14)
            }
        }
        .frame(height: 260)
    }

    // MARK: - Category Tag
    private var categoryTag: some View {
        HStack(spacing: 8) {
            Image(systemName: planTypeIcon)
                .font(.caption)
            Text(planTypeText)
                .font(.subheadline.weight(.semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 13)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(planColor)
        )
        .shadow(color: planColor.opacity(0.3), radius: 4, x: 0, y: 2)
    }

    // MARK: - Date & Time Section
//    private var dateTimeSection: some View {
//        VStack(alignment: .leading, spacing: 12) {
//            HStack {
//                Image(systemName: "calendar.circle.fill")
//                    .font(.headline)
//                    .foregroundColor(planColor)
//                Text("日程")
//                    .font(.headline.weight(.semibold))
//                    .foregroundColor(.primary)
//            }
//
//            VStack(alignment: .leading, spacing: 8) {
//                if plan.planType == .outing {
//                    Text(dateRangeString(plan.startDate, plan.endDate))
//                        .font(.body)
//                        .foregroundColor(.secondary)
//                } else {
//                    Text(formatDate(plan.startDate))
//                        .font(.body)
//                        .foregroundColor(.secondary)
//                }
//
//                if plan.planType == .daily, let time = plan.time {
//                    HStack(spacing: 6) {
//                        Image(systemName: "clock.fill")
//                            .font(.caption)
//                            .foregroundColor(planColor)
//                        Text(formatTime(time))
//                            .font(.body)
//                            .foregroundColor(.secondary)
//                    }
//                }
//            }
//        }
//        .frame(maxWidth: .infinity, alignment: .leading)
//    }

    // MARK: - Description Section
    private func descriptionSection(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(description)
                .font(.body)
                .foregroundColor(themeManager.currentTheme.secondaryText)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Link Section
    private func linkSection(_ linkURL: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let url = URL(string: linkURL) {
                Link(destination: url) {
                    HStack {
                        Image(systemName: "safari")
                            .foregroundColor(planColor)
                        Text(linkURL)
                            .font(.subheadline)
                            .foregroundColor(colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.secondaryText)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(planColor.opacity(0.1))
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Action Buttons
//    private var actionButtons: some View {
//        HStack(spacing: 12) {
//            // Show on Map Button
//            Button(action: {
//                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
//                    showMap.toggle()
//                }
//            }) {
//                HStack(spacing: 8) {
//                    Image(systemName: showMap ? "map.slash.fill" : "map.fill")
//                        .font(.body)
//                    Text(showMap ? "閉じる" : "マップを開く")
//                        .font(.subheadline.weight(.semibold))
//                }
//                .foregroundColor(planColor)
//                .frame(maxWidth: .infinity)
//                .padding(.vertical, 16)
//                .background(
//                    RoundedRectangle(cornerRadius: 12)
//                        .fill(
//                            LinearGradient(
//                                gradient: Gradient(colors: [
//                                    planColor.opacity(0.6),
//                                    planColor.opacity(0.1)
//                                ]),
//                                startPoint: .topLeading,
//                                endPoint: .bottomTrailing
//                            )
//                        )
//                        .overlay(
//                            RoundedRectangle(cornerRadius: 12)
//                                .stroke(planColor, lineWidth: 2)
//                        )
//                )
//            }
//        }
//    }

    // MARK: - 状態
    //
    // 旅行計画のような大きな表紙ではなく、その日の1枚として小さく出す。
    // 開いた瞬間に「まだ先か、今日か、終わったか」が分かるようにする
    private var planStatusText: String? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.startOfDay(for: plan.startDate)
        let end = calendar.startOfDay(for: plan.endDate)

        if today < start {
            let days = calendar.dayDifference(from: today, to: start)
            return days == 1 ? "明日" : "あと\(days)日"
        }
        if today <= end {
            return plan.isMultiDay
                ? "\(calendar.dayDifference(from: start, to: today) + 1)日目"
                : "今日"
        }
        return "終了"
    }

    private var isPlanFinished: Bool {
        Calendar.current.startOfDay(for: Date()) > Calendar.current.startOfDay(for: plan.endDate)
    }

    @ViewBuilder
    private var statusPill: some View {
        if let planStatusText {
            Text(planStatusText)
                .font(.caption.weight(.bold))
                // 終わった予定は色を抜く
                .foregroundColor(isPlanFinished ? themeManager.currentTheme.secondaryText : planColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(isPlanFinished
                                   ? themeManager.currentTheme.secondaryText.opacity(0.12)
                                   : planColor.opacity(colorScheme == .dark ? 0.24 : 0.14))
                )
        }
    }

    // MARK: - 今すぐ使う操作
    //
    // 旅行計画には無い行。当日その場で開いて押すものを、見出しのすぐ下に並べる。
    // 経路案内は最初の場所へ、通知はその場で入切できる
    private var quickActionRow: some View {
        HStack(spacing: 10) {
            quickAction(
                icon: "arrow.triangle.turn.up.right.diamond.fill",
                title: "経路案内",
                subtitle: plan.places.first?.name,
                isEnabled: plan.places.first != nil,
                isOn: false
            ) {
                openRouteToFirstPlace()
            }

            quickAction(
                icon: "link",
                title: "リンク",
                subtitle: (plan.linkURL?.isEmpty == false) ? "1件" : "なし",
                isEnabled: plan.linkURL?.isEmpty == false,
                isOn: false
            ) {
                guard let raw = plan.linkURL, let url = URL(string: raw) else { return }
                UIApplication.shared.open(url)
            }

            quickAction(
                icon: isNotificationOn ? "bell.fill" : "bell.slash",
                title: "通知",
                subtitle: isNotificationOn ? "入" : "切",
                isEnabled: true,
                isOn: isNotificationOn
            ) {
                toggleNotification()
            }
        }
        .task {
            isNotificationOn = await NotificationService.shared.hasPendingPlanNotifications(for: plan.id)
        }
    }

    private func quickAction(
        icon: String,
        title: String,
        subtitle: String?,
        isEnabled: Bool,
        isOn: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(isEnabled ? planColor : themeManager.currentTheme.secondaryText.opacity(0.5))

                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(isEnabled
                                     ? (colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1)
                                     : themeManager.currentTheme.secondaryText.opacity(0.5))

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 76)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isOn
                          ? AnyShapeStyle(planColor.opacity(colorScheme == .dark ? 0.22 : 0.12))
                          : AnyShapeStyle(colorScheme == .dark
                                          ? themeManager.currentTheme.secondaryBackgroundDark
                                          : themeManager.currentTheme.backgroundLight))
            )
            .shadow(
                color: colorScheme == .dark || isOn ? .clear : Color.black.opacity(0.06),
                radius: 10,
                x: 0,
                y: 4
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled)
    }

    /// 最初の場所へ地図アプリで案内させる。
    /// 座標を持っているので、URLを組み立てる必要はない
    private func openRouteToFirstPlace() {
        guard let place = plan.places.first else { return }

        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: place.coordinate))
        mapItem.name = place.name
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }

    private func toggleNotification() {
        if isNotificationOn {
            NotificationService.shared.cancelPlanNotifications(for: plan.id)
            isNotificationOn = false
        } else {
            NotificationService.shared.schedulePlanNotifications(for: plan)
            // 予定日が過ぎていると何も予約されないため、結果を見てから戻す
            Task {
                isNotificationOn = await NotificationService.shared.hasPendingPlanNotifications(for: plan.id)
            }
        }
    }

    // MARK: - 記念日
    //
    // 時刻も場所も持たない。日数だけで成立するので、
    // 日常の画面（時刻が主役）でもおでかけの画面（地図とタイムライン）でも表せない
    private var anniversarySection: some View {
        VStack(spacing: 14) {
            Text(anniversaryCountdownText)
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .foregroundColor(planColor)
                .monospacedDigit()

            Text("\(anniversaryOccurrence)回目 · \(DateFormatter.japaneseDate.string(from: plan.startDate))から")
                .font(.system(size: 13))
                .foregroundColor(themeManager.currentTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(planColor.opacity(colorScheme == .dark ? 0.18 : 0.10))
        )
    }

    /// 今年の記念日までの日数。過ぎていれば来年の分を数える
    private var anniversaryCountdownText: String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard let next = nextAnniversaryDate else { return "今日" }
        let days = calendar.dayDifference(from: today, to: next)

        if days == 0 { return "今日" }
        if days == 1 { return "明日" }
        return "あと\(days)日"
    }

    private var nextAnniversaryDate: Date? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var components = calendar.dateComponents([.month, .day], from: plan.startDate)
        components.year = calendar.component(.year, from: today)

        guard let thisYear = calendar.date(from: components) else { return nil }
        if calendar.startOfDay(for: thisYear) >= today { return thisYear }

        components.year = (components.year ?? 0) + 1
        return calendar.date(from: components)
    }

    /// 「10回目」。最初の年から数える
    private var anniversaryOccurrence: Int {
        let calendar = Calendar.current
        guard let next = nextAnniversaryDate else { return 1 }
        let years = calendar.component(.year, from: next) - calendar.component(.year, from: plan.startDate)
        return max(years + 1, 1)
    }

    // MARK: - タグと繰り返し
    private var tagAndRecurrenceRow: some View {
        HStack(spacing: 6) {
            if plan.recurrence != .none {
                HStack(spacing: 5) {
                    Image(systemName: "repeat")
                        .font(.system(size: 11, weight: .bold))
                    Text(plan.recurrence.displayName)
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(planColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(planColor.opacity(colorScheme == .dark ? 0.22 : 0.12), in: Capsule())
            }

            // タグは中立の灰色。種別の色と役割を混ぜない
            ForEach(plan.tags, id: \.self) { tag in
                Text(tag)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(themeManager.currentTheme.secondaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(themeManager.currentTheme.secondaryText.opacity(0.12), in: Capsule())
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    // MARK: - 完了
    //
    // 用事は「終わったか」が意味を持つ。旅行計画には無い概念
    private var completionSection: some View {
        VStack(spacing: 10) {
            Button(action: toggleCompletion) {
                HStack(spacing: 8) {
                    Image(systemName: plan.isCompleted ? "arrow.uturn.backward" : "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text(plan.isCompleted ? "完了を取り消す" : "完了にする")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(plan.isCompleted
                                 ? themeManager.currentTheme.secondaryText
                                 : ThemePreset.readableText(on: planColor))
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(plan.isCompleted
                              ? AnyShapeStyle(themeManager.currentTheme.secondaryText.opacity(0.12))
                              : AnyShapeStyle(planColor))
                )
            }
            .buttonStyle(PlainButtonStyle())

            if !plan.isCompleted, plan.recurrence != .none, let next = plan.recurrence.nextDate(after: plan.startDate) {
                Text("完了にすると、\(DateFormatter.japaneseDate.string(from: next))の予定が自動で作られます。")
                    .font(.system(size: 12))
                    .foregroundColor(themeManager.currentTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
    }

    /// 完了にしたとき、繰り返しの設定があれば次回分を作る。
    ///
    /// 未来の分をあらかじめ並べておくと、1件だけ直したいときに
    /// どれを直せばいいのか分からなくなる。済んだ時点で1件だけ作る
    private func toggleCompletion() {
        var updated = plan
        updated.isCompleted.toggle()
        plan = updated

        guard let userId = authVM.userId else { return }
        viewModel.update(updated, userId: userId)

        guard updated.isCompleted,
              updated.recurrence != .none,
              let nextStart = updated.recurrence.nextDate(after: updated.startDate) else { return }

        let span = Calendar.current.dayDifference(from: updated.startDate, to: updated.endDate)
        var next = updated
        next.id = UUID().uuidString
        next.isCompleted = false
        next.createdAt = Date()
        next.startDate = nextStart
        next.endDate = Calendar.current.date(byAdding: .day, value: span, to: nextStart) ?? nextStart
        // 済んだ回の記録は引き継がない
        next.scheduleItems = updated.scheduleItems.map { item in
            var copy = item
            copy.id = UUID().uuidString
            return copy
        }

        viewModel.add(next, userId: userId)
    }

    // MARK: - Map Section
    private var mapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "map.circle.fill")
                    .font(.headline)
                    .foregroundColor(planColor)
                Text("マップ")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1)

                Spacer()

                Button(action: {
                    showAddPlaceInEdit = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.body)
                        Text("追加")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundColor(planColor)
                }
            }

            if plan.places.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "map")
                        .font(.system(size: 40))
                        .foregroundColor(colorScheme == .dark ? themeManager.currentTheme.separatorDark : themeManager.currentTheme.separatorLight)
                    Text("場所がまだありません")
                        .font(.subheadline)
                        .foregroundColor(colorScheme == .dark ? themeManager.currentTheme.separatorDark : themeManager.currentTheme.separatorLight)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                Map(position: .constant(.region(calculateMapRegion()))) {
                    ForEach(plan.places) { place in
                        Marker(place.name, coordinate: place.coordinate)
                            .tint(planColor)
                    }
                }
                // 300ptは旅行計画の地図と同じ大きさで、当日の確認には過剰だった
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(alignment: .bottomTrailing) {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption)
                        Text("\(plan.places.count)件")
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
        }
    }

    // MARK: - Schedule Section
    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("タイムスケジュール")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1)

                Spacer()

                Button(action: {
                    editingScheduleItem = nil
                    showScheduleEditor = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.body)
                        Text("追加")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundColor(planColor)
                }
            }

            if plan.scheduleItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 40))
                        .foregroundColor(colorScheme == .dark ? themeManager.currentTheme.separatorDark : themeManager.currentTheme.separatorLight)
                    Text("スケジュールがまだありません")
                        .font(.subheadline)
                        .foregroundColor(colorScheme == .dark ? themeManager.currentTheme.separatorDark : themeManager.currentTheme.separatorLight)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(scheduleItemsByDay, id: \.day) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            // 1日だけの予定では見出しが冗長になるので出さない
                            if plan.isMultiDay {
                                dayHeader(for: group.day)
                            }

                            let nowIndex = nextItemIndex(in: group.items, day: group.day)

                            VStack(spacing: 0) {
                                ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                                    let isLast = index == group.items.count - 1
                                    let state = scheduleRowState(index: index, nowIndex: nowIndex)

                                    scheduleItemRow(item: item, isLast: isLast, state: state)

                                    if !isLast, needsMoveMarker(from: item, to: group.items[index + 1]) {
                                        moveMarkerRow(state: state)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $showScheduleEditor) {
            ScheduleItemEditorView(
                plan: $plan,
                scheduleItem: editingScheduleItem,
                onSave: { updatedPlan in
                    plan = updatedPlan
                    if let userId = authVM.userId {
                        viewModel.update(updatedPlan, userId: userId)
                    }
                }
            )
        }
    }

    /// 「1日目 8/1(土)」の見出し
    private func dayHeader(for day: Int) -> some View {
        HStack(spacing: 8) {
            Text("\(day)日目")
                .font(.caption.weight(.bold))
                .foregroundColor(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(planColor, in: Capsule())

            Text(formatDayHeaderDate(plan.date(forDay: day)))
                .font(.subheadline.weight(.semibold))
                .foregroundColor(colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1)

            Spacer()
        }
    }

    private func formatDayHeaderDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日(E)"
        return formatter.string(from: date)
    }

    /// タイムラインの1行の状態。
    /// 過ぎた・次の1件・これからは、その日が今日のときだけ意味を持つ
    private enum ScheduleRowState {
        case past, now, future, flat
    }

    private func scheduleItemRow(item: PlanScheduleItem, isLast: Bool, state: ScheduleRowState) -> some View {
        HStack(alignment: .top, spacing: 0) {
            // 時刻は塗らず等幅で右に揃える。レールを読ませるため
            Text(formatTime(item.time))
                .font(.system(size: 13, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundColor(state == .past
                                 ? themeManager.currentTheme.secondaryText.opacity(0.6)
                                 : themeManager.currentTheme.secondaryText)
                .frame(width: 46, alignment: .trailing)
                .padding(.top, 1)

            // レール
            VStack(spacing: 0) {
                scheduleDot(state: state)

                if !isLast {
                    Rectangle()
                        .fill(railColor(state: state))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 12)
            .padding(.leading, 10)
            .padding(.trailing, 16)
            .padding(.top, 3)

            // Content
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.body.weight(.semibold))
                    .foregroundColor(colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1)

                if let placeId = item.placeId,
                   let place = plan.places.first(where: { $0.id == placeId }) {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption)
                            .foregroundColor(planColor.opacity(0.7))
                        Text(place.name)
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.secondaryText)
                    }
                }

                if let note = item.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                        .lineLimit(2)
                }
            }

            Spacer()

            // Edit/Delete Buttons
            Menu {
                Button(action: {
                    editingScheduleItem = item
                    showScheduleEditor = true
                }) {
                    Label("編集", systemImage: "pencil")
                }

                Button(role: .destructive, action: {
                    deleteScheduleItem(item)
                }) {
                    Label("削除", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.body)
                    .foregroundColor(colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1)
            }
        }
        .padding(.vertical, 8)
    }

    /// レールの点。過ぎた分は塗り、次の1件は光らせ、これからは中を抜く
    @ViewBuilder
    private func scheduleDot(state: ScheduleRowState) -> some View {
        switch state {
        case .now:
            Circle()
                .fill(planColor)
                .frame(width: 12, height: 12)
                .overlay(Circle().stroke(planColor.opacity(0.16), lineWidth: 5))
        case .past:
            Circle()
                .fill(planColor.opacity(0.55))
                .frame(width: 12, height: 12)
        case .future, .flat:
            Circle()
                .fill(colorScheme == .dark
                      ? themeManager.currentTheme.secondaryBackgroundDark
                      : themeManager.currentTheme.backgroundLight)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle().strokeBorder(
                        state == .flat ? planColor.opacity(0.55) : themeManager.currentTheme.secondaryText.opacity(0.65),
                        lineWidth: 2.5
                    )
                )
        }
    }

    private func railColor(state: ScheduleRowState) -> Color {
        state == .past
            ? planColor.opacity(0.4)
            : themeManager.currentTheme.secondaryText.opacity(0.18)
    }

    /// 予定と予定のあいだに挟む移動の目印。
    ///
    /// 所要時間は出さない。バス・電車・徒歩を分けて出すには
    /// 経路計算（`MKDirections`）が要るうえ、電車はそもそも計算できない。
    /// 「ここで移動する」ことだけ分かれば足りる
    private func moveMarkerRow(state: ScheduleRowState) -> some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: 46)

            Rectangle()
                .fill(railColor(state: state))
                .frame(width: 2)
                .frame(maxHeight: .infinity)
                .frame(width: 12)
                .padding(.leading, 10)
                .padding(.trailing, 16)

            HStack(spacing: 5) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 10, weight: .bold))
                Text("移動")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(themeManager.currentTheme.secondaryText.opacity(0.75))

            Spacer(minLength: 0)
        }
        .frame(height: 26)
    }

    /// 移動を挟むのは、続けて別の場所へ行くときだけ。
    /// 場所が入っていない項目や、同じ場所での続きには出さない
    private func needsMoveMarker(from: PlanScheduleItem, to: PlanScheduleItem) -> Bool {
        guard let fromPlace = from.placeId, let toPlace = to.placeId else { return false }
        return fromPlace != toPlace
    }

    /// 次に控えている1件の位置。その日が今日でなければ nil
    private func nextItemIndex(in items: [PlanScheduleItem], day: Int) -> Int? {
        let dayDate = Calendar.current.date(byAdding: .day, value: day - 1, to: plan.startDate) ?? plan.startDate
        guard Calendar.current.isDateInToday(dayDate) else { return nil }

        let nowMinutes = minutesOfDay(Date())
        return items.firstIndex { minutesOfDay($0.time) >= nowMinutes }
    }

    private func scheduleRowState(index: Int, nowIndex: Int?) -> ScheduleRowState {
        guard let nowIndex else { return .flat }
        if index < nowIndex { return .past }
        if index == nowIndex { return .now }
        return .future
    }

    /// 何日目かでまとめ、日ごとに時刻順で並べる。
    /// 複数日のおでかけで1日目と2日目の予定が混ざらないようにするため
    private var scheduleItemsByDay: [(day: Int, items: [PlanScheduleItem])] {
        let grouped = Dictionary(grouping: plan.scheduleItems) { plan.dayNumber(for: $0) }

        return grouped.keys.sorted().map { day in
            let items = (grouped[day] ?? []).sorted { minutesOfDay($0.time) < minutesOfDay($1.time) }
            return (day, items)
        }
    }

    /// 日付部分を無視して時刻だけで比較するための分換算
    private func minutesOfDay(_ date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private func deleteScheduleItem(_ item: PlanScheduleItem) {
        var updatedPlan = plan
        updatedPlan.scheduleItems.removeAll { $0.id == item.id }
        plan = updatedPlan
        if let userId = authVM.userId {
            viewModel.update(updatedPlan, userId: userId)
        }
    }

    // MARK: - Sidebar View
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("スケジュール")
                        .font(.title2.bold())
                        .foregroundColor(themeManager.currentTheme.light)

                    Spacer()
                }

                Text("\(sortedPlans.count)件のプラン")
                    .font(.subheadline)
                    .foregroundColor(themeManager.currentTheme.light)
            }
            .padding(20)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        planColor,
                        planColor.opacity(0.8)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            // Schedule List
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(sortedPlans) { schedulePlan in
                        sidebarPlanItem(plan: schedulePlan)
                    }
                }
                .padding(12)
            }
            .background(colorScheme == .dark ? themeManager.currentTheme.secondaryBackgroundDark : themeManager.currentTheme.secondaryBackgroundLight)
        }
        .frame(width: 280)
        .background(colorScheme == .dark ? themeManager.currentTheme.secondaryBackgroundDark : themeManager.currentTheme.secondaryBackgroundLight)
        .shadow(color: .black.opacity(0.2), radius: 15, x: 5, y: 0)
    }

    private func sidebarPlanItem(plan schedulePlan: Plan) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                plan = schedulePlan
                showSidebar = false
                loadLocalImage()
            }
        }) {
            HStack(alignment: .top, spacing: 12) {
                // Plan type icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    schedulePlan.planType.color(themeManager.currentTheme),
                                    schedulePlan.planType.color(themeManager.currentTheme).opacity(0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)

                    Image(systemName: schedulePlan.planType.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }
                .shadow(color: schedulePlan.planType.color(themeManager.currentTheme).opacity(0.4), radius: 6, x: 0, y: 3)

                VStack(alignment: .leading, spacing: 6) {
                    Text(schedulePlan.title)
                        .font(.system(size: 15, weight: .semibold))
                        // light は全テーマで白のため、明るいカード背景では読めなかった
                        .foregroundColor(themeManager.currentTheme.adaptiveText(for: colorScheme))
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                            .foregroundColor(themeManager.currentTheme.secondaryText)
                        if schedulePlan.planType == .outing {
                            Text(dateRangeString(schedulePlan.startDate, schedulePlan.endDate))
                                .font(.caption)
                                .foregroundColor(themeManager.currentTheme.secondaryText)
                        } else {
                            Text(formatDate(schedulePlan.startDate))
                                .font(.caption)
                                .foregroundColor(themeManager.currentTheme.secondaryText)
                        }
                    }

                    if !schedulePlan.places.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.caption2)
                                .foregroundColor(schedulePlan.planType.color(themeManager.currentTheme))
                            Text("\(schedulePlan.places.count)件")
                                .font(.caption)
                                .foregroundColor(themeManager.currentTheme.secondaryText)
                        }
                    }
                }

                Spacer()

                if schedulePlan.id == plan.id {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(schedulePlan.planType.color(themeManager.currentTheme))
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(schedulePlan.id == plan.id ?
                          schedulePlan.planType.color(themeManager.currentTheme).opacity(0.1) :
                          Color(.tertiarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(schedulePlan.id == plan.id ?
                            schedulePlan.planType.color(themeManager.currentTheme).opacity(0.4) :
                            Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Computed Properties for Sidebar
    private var sortedPlans: [Plan] {
        let today = Calendar.current.startOfDay(for: Date())
        return viewModel.plans
            .filter { plan in
                let endDate: Date
                if plan.planType == .outing {
                    // おでかけプランの場合は終了日をチェック
                    endDate = Calendar.current.startOfDay(for: plan.endDate)
                } else {
                    // 日常プランの場合は開始日をチェック
                    endDate = Calendar.current.startOfDay(for: plan.startDate)
                }
                // 今日以降のプランのみを表示
                return endDate >= today
            }
            .sorted { $0.startDate < $1.startDate }
    }

    private var editDateSectionLabel: String {
        switch editedPlanType {
        case .outing:      return "日程"
        case .daily:       return "日付・時刻"
        case .anniversary: return "日付"
        }
    }

    private func addEditedTag() {
        let trimmed = editedTagInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !editedTags.contains(trimmed) else { return }
        editedTags.append(trimmed)
        editedTagInput = ""
    }

    // MARK: - Edit Mode Functions
    private func enterEditMode() {
        editedTitle = plan.title
        editedDescription = plan.description ?? ""
        editedLinkURL = plan.linkURL ?? ""
        editedPlanType = plan.planType
        editedStartDate = plan.startDate
        editedEndDate = plan.endDate
        editedTime = plan.time
        editedPlaces = plan.places
        editedTags = plan.tags
        editedTagInput = ""
        editedRecurrence = plan.recurrence
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
            saveImageLocally(image) { result in
                switch result {
                case .success(let fileName):
                    updatePlanData(with: fileName)
                case .failure(let error):
                    handleSaveError(error)
                }
            }
        } else {
            updatePlanData(with: plan.localImageFileName)
        }
    }

    private func updatePlanData(with localFileName: String?) {
        var updatedPlan = plan
        updatedPlan.title = editedTitle
        updatedPlan.description = editedDescription.isEmpty ? nil : editedDescription
        updatedPlan.linkURL = editedLinkURL.isEmpty ? nil : editedLinkURL
        updatedPlan.planType = editedPlanType
        updatedPlan.startDate = editedStartDate
        updatedPlan.endDate = editedEndDate
        updatedPlan.time = editedTime
        updatedPlan.places = editedPlaces
        updatedPlan.localImageFileName = localFileName
        updatedPlan.tags = editedTags
        // 記念日は毎年で固定。種別を変えたときに古い設定が残らないようにする
        updatedPlan.recurrence = editedPlanType == .anniversary ? .yearly : editedRecurrence

        // 記念日は時刻も場所も持たない
        if editedPlanType == .anniversary {
            updatedPlan.time = nil
            updatedPlan.places = []
            updatedPlan.endDate = editedStartDate
        }

        if let userId = authVM.userId {
            viewModel.update(updatedPlan, userId: userId)
        }

        DispatchQueue.main.async {
            isSaving = false
            plan = updatedPlan
            selectedImage = nil
            displayImage = loadImageFromLocal()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isEditMode = false
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
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            completion(.failure(NSError(domain: "PlanDetailView", code: -1, userInfo: [NSLocalizedDescriptionKey: "画像データの変換に失敗しました"])))
            return
        }

        let fileName = "plan_\(plan.id).jpg"

        do {
            try FileManager.saveImageDataToDocuments(data: imageData, named: fileName)
            completion(.success(fileName))
        } catch {
            completion(.failure(error))
        }
    }

    private func loadLocalImage() {
        displayImage = loadImageFromLocal()
    }

    private func loadImageFromLocal() -> UIImage? {
        guard let fileName = plan.localImageFileName else { return nil }

        if let image = FileManager.documentsImage(named: fileName) {
            return image
        } else {
            return nil
        }
    }

    // MARK: - Helper Functions
    private func calculateMapRegion() -> MKCoordinateRegion {
        guard let firstPlace = plan.places.first,
              firstPlace.coordinate.latitude.isFinite,
              firstPlace.coordinate.longitude.isFinite else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 36.2048, longitude: 138.2529),
                span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
            )
        }

        return MKCoordinateRegion(
            center: firstPlace.coordinate,
            latitudinalMeters: CLLocationDistance(max(plan.places.count * 1000, 2000)),
            longitudinalMeters: CLLocationDistance(max(plan.places.count * 1000, 2000))
        )
    }

    private func dateRangeString(_ start: Date, _ end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        formatter.locale = Locale(identifier: "ja_JP")
        return "\(formatter.string(from: start))〜\(formatter.string(from: end))"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日(E)"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }

    private func formatTime(_ time: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: time)
    }

    // MARK: - Delete Function
    private func deletePlan() {
        Task { @MainActor in
            // ViewModelからプランを削除（CloudKitの削除完了まで待つ）
            await viewModel.deletePlan(plan, userId: authVM.userId)

            // ローカル画像ファイルを削除
            if let fileName = plan.localImageFileName {
                try? FileManager.removeDocumentFile(named: fileName)
            }

            // CloudKit削除完了後に画面を閉じる
            dismiss()
        }
    }

    // MARK: - Map Picker View
    private var mapPickerView: some View {
        NavigationView {
            ZStack {
                Map(position: $mapPosition, selection: $selectedMapResult) {
                    ForEach(searchResults, id: \.self) { result in
                        Marker(item: result)
                            .tint(themeManager.currentTheme.error)
                    }
                }
                .safeAreaInset(edge: .top) {
                    mapSearchBarView
                }
                .safeAreaInset(edge: .bottom) {
                    if let selectedResult = selectedMapResult {
                        mapSelectedResultDetailView(selectedResult)
                    }
                }
                .onMapCameraChange { context in
                    mapVisibleRegion = context.region
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        showAddPlaceInEdit = false
                    }
                }
            }
        }
    }

    // MARK: - Map Search Bar
    private var mapSearchBarView: some View {
        TextField("場所を検索", text: $searchText)
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .onSubmit {
                Task {
                    await performMapSearch()
                }
            }
    }

    private func performMapSearch() async {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        // 施設だけに絞ると住所で検索できないため住所も対象にする
        request.resultTypes = [.pointOfInterest, .address]

        // 表示中の狭い範囲に限定すると遠方の場所が一切ヒットしない。
        // 近くを優先しつつ遠方も拾えるよう、中心だけ引き継いで範囲は広く取る
        request.region = MKCoordinateRegion(
            center: mapVisibleRegion?.center
                ?? CLLocationCoordinate2D(latitude: 36.2048, longitude: 138.2529),
            span: MKCoordinateSpan(latitudeDelta: 60, longitudeDelta: 60)
        )

        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            searchResults = response.mapItems
            if let firstResult = searchResults.first {
                withAnimation {
                    mapPosition = .region(MKCoordinateRegion(
                        center: firstResult.placemark.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    ))
                }
            }
            searchText = ""
        } catch {
        }
    }

    // MARK: - Map Selected Result Detail View
    private func mapSelectedResultDetailView(_ result: MKMapItem) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(result.name ?? "名称なし")
                        .font(.title2)
                        .fontWeight(.bold)

                    if let category = result.pointOfInterestCategory?.rawValue {
                        Text(category)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }

            if let address = result.placemark.title {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundStyle(themeManager.currentTheme.error)
                        .font(.title3)
                    Text(address)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let phoneNumber = result.phoneNumber {
                HStack(spacing: 8) {
                    Image(systemName: "phone.circle.fill")
                        .foregroundStyle(themeManager.currentTheme.success)
                        .font(.title3)
                    Text(phoneNumber)
                        .font(.subheadline)
                    Spacer()
                    Button {
                        if let url = URL(string: "tel:\(phoneNumber.replacingOccurrences(of: " ", with: ""))") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text("電話")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(themeManager.currentTheme.success)
                            .foregroundStyle(.white)
                            .cornerRadius(8)
                    }
                }
            }

            if let url = result.url {
                HStack(spacing: 8) {
                    Image(systemName: "safari.fill")
                        .foregroundStyle(themeManager.currentTheme.actionFill)
                        .font(.title3)
                    Text(url.host ?? "Website")
                        .font(.subheadline)
                        .lineLimit(1)
                    Spacer()
                    Button {
                        UIApplication.shared.open(url)
                    } label: {
                        Text("開く")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(themeManager.currentTheme.actionFill)
                            .foregroundStyle(.white)
                            .cornerRadius(8)
                    }
                }
            }

            Divider()

            HStack(spacing: 12) {
                Button {
                    result.openInMaps()
                } label: {
                    Label("経路", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(themeManager.currentTheme.actionFill.opacity(0.12))
                        .foregroundStyle(themeManager.currentTheme.actionFill)
                        .cornerRadius(10)
                }

                Button {
                    addPlaceFromMapResult(result)
                } label: {
                    Label("追加", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(themeManager.currentTheme.adaptiveText(for: colorScheme).opacity(0.12))
                        .foregroundStyle(themeManager.currentTheme.adaptiveText(for: colorScheme))
                        .cornerRadius(10)
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: -4)
        .padding(.horizontal)
        .padding(.bottom, 12)
    }

    private func addPlaceFromMapResult(_ result: MKMapItem) {
        let place = PlannedPlace(
            name: result.name ?? "名称不明",
            latitude: result.placemark.coordinate.latitude,
            longitude: result.placemark.coordinate.longitude,
            address: result.placemark.title
        )

        if isEditMode {
            // Edit mode: Add to temporary edited places
            editedPlaces.append(place)
        } else {
            // View mode: Add to plan directly and save
            var updatedPlan = plan
            updatedPlan.places.append(place)
            plan = updatedPlan

            if let userId = authVM.userId {
                viewModel.update(updatedPlan, userId: userId)
            }
        }

        selectedMapResult = nil
        showAddPlaceInEdit = false
    }
}

