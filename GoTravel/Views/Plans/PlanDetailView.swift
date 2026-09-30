import SwiftUI
import MapKit

struct PlanDetailView: View {
    /// 経路案内の行き先。開くアプリはプロフィールの設定に従う（`mapNavigation`）
    @State private var navigationTarget: MapDestination?
    /// 地図から場所を選ぶ画面（全画面）の中の経路案内。上の画面の選択肢は全画面の上に出せないため分ける
    @State private var searchResultNavigationTarget: MapDestination?
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
    @State private var showNotificationSettings = false
    @State private var showRoutePicker = false
    /// 編集中に写真を外したか。保存を押すまで実体は消さない（編集の取り消しで戻せるように）
    @State private var isRemovingPhoto = false
    @State private var editingScheduleItem: PlanScheduleItem?

    // 編集用の一時変数
    @State private var editedTitle: String = ""
    @State private var editedDescription: String = ""
    @State private var editedLinkURL: String = ""
    @State private var editedPlanType: PlanType = .outing
    @State private var editedStartDate: Date = Date()
    @State private var editedEndDate: Date = Date()
    @State private var editedTime: Date?
    @State private var editedEndTime: Date?
    @State private var editedTagIDs: [String] = []
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
    @ObservedObject var tagManager = PlanTagManager.shared
    @Environment(\.colorScheme) var colorScheme

    /// この予定に付いているタグ。消されたタグを指すIDは落ちる
    private var planTags: [PlanTag] {
        tagManager.tags(for: plan.tagIDs)
    }
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
            .background(backgroundGradient)
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
        .confirmationDialog("どこへ案内しますか？", isPresented: $showRoutePicker, titleVisibility: .visible) {
            ForEach(routeDestinations) { place in
                Button(place.name) {
                    // 閉じきる前に次の選択肢（どのアプリで開くか）を出すと表示されないことがあるので、
                    // この行き先選びが消えてから渡す
                    Task {
                        try? await Task.sleep(for: .milliseconds(350))
                        openRoute(to: place)
                    }
                }
            }
            Button("キャンセル", role: .cancel) {}
        }
        .mapNavigation($navigationTarget)
        .sheet(isPresented: $showNotificationSettings) {
            PlanNotificationSettingsView(plan: plan) { reminders in
                saveReminders(reminders)
            }
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
    //
    // 種別ごとに別の画面を出す。
    // おでかけは色の帯＋操作＋タイムライン、日常は時刻を主役にした1枚、
    // 記念日は日数だけ。同じ画面に押し込めると、どれも中途半端になる
    private var viewModeView: some View {
        VStack(spacing: 0) {
            topBorderView

            // 写真は入れていれば出す。無いときは種別ごとの見出しが表紙になる
            if displayImage != nil {
                headerImageView
            }

            VStack(alignment: .leading, spacing: 16) {
                planHeaderArea

                if let description = plan.description, !description.isEmpty {
                    descriptionCard(description)
                }

                switch plan.planType {
                case .outing:
                    quickActionRow
                    scheduleSection
                    if !plan.places.isEmpty {
                        mapSection
                    }

                case .daily:
                    dailyPlaceCard
                    dailySettingsList
                    // 以前に入れたスケジュールがある予定だけ、今までどおり出す。
                    // 日常の主役は時刻なので、新しく作った予定には出さない
                    if !plan.scheduleItems.isEmpty {
                        scheduleSection
                    }

                case .anniversary:
                    anniversarySection
                    dailySettingsList
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
    }

    // MARK: - 見出し

    @ViewBuilder
    private var planHeaderArea: some View {
        switch plan.planType {
        case .outing:      outingHeader
        case .daily:       dailyHeader
        case .anniversary: dailyHeader
        }
    }

    /// おでかけの見出し。
    ///
    /// 以前は種別色を敷いた表紙カードだったが、面を塗るのをやめて
    /// 日常・記念日と同じ組みに揃えた。
    /// 色を持つのは種別のピルと状態のチップ、それとタグだけ
    private var outingHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                typePill()

                if !planTags.isEmpty {
                    tagRow()
                }

                Spacer(minLength: 0)

                if let planStatusText {
                    Text(planStatusText)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(planColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(planColor.opacity(colorScheme == .dark ? 0.22 : 0.12), in: Capsule())
                }
            }

            Text(plan.title)
                .font(.system(size: 26, weight: .heavy))
                .foregroundColor(titleColor)
                .lineLimit(2)

            Text(outingHeaderDateText)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(themeManager.currentTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var outingHeaderDateText: String {
        var text = DateFormatter.japaneseDate.string(from: plan.startDate)
        if !Calendar.current.isDate(plan.startDate, inSameDayAs: plan.endDate) {
            text += " 〜 " + DateFormatter.japaneseDate.string(from: plan.endDate)
        }
        if let first = plan.scheduleItems.min(by: { $0.time < $1.time }) {
            text += " · " + DateFormatter.japaneseTime.string(from: first.time) + " から"
        }
        return text
    }

    /// 日常と記念日は、時刻（または日数）そのものを主役にする
    private var dailyHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                typePill()
                tagRow()
                Spacer(minLength: 0)
            }

            Text(plan.title)
                .font(.system(size: 26, weight: .heavy))
                .foregroundColor(titleColor)
                .lineLimit(2)

            if plan.planType == .daily {
                HStack(alignment: .lastTextBaseline, spacing: 14) {
                    // 終わりは主役ではないので、開始時刻の右に小さく添える
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Text(plan.time.map { DateFormatter.japaneseTime.string(from: $0) } ?? "終日")
                            .font(.system(size: 44, weight: .heavy, design: .rounded))
                            .foregroundColor(planColor)
                            .monospacedDigit()

                        if let endTime = plan.endTime {
                            Text("〜 " + DateFormatter.japaneseTime.string(from: endTime))
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundColor(planColor.opacity(0.75))
                                .monospacedDigit()
                        }
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text(DateFormatter.japaneseDate.string(from: plan.startDate))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(titleColor)

                        if let countdown = dailyCountdownText {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 10, weight: .bold))
                                Text(countdown)
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .foregroundColor(planColor)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(planColor.opacity(colorScheme == .dark ? 0.22 : 0.12), in: Capsule())
                        }
                    }

                    Spacer(minLength: 0)
                }
            }
        }
    }

    /// 背景。ここだけ `dark`（＝純黒）を直に敷いていたため、
    /// テーマ側の `backgroundDark` を持ち上げてもこの画面には効いていなかった
    private var backgroundGradient: some View {
        themeManager.currentTheme.backgroundGradient(for: colorScheme)
            .ignoresSafeArea()
    }

    private var titleColor: Color {
        colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1
    }

    private func typePill() -> some View {
        HStack(spacing: 5) {
            Image(systemName: planTypeIcon)
                .font(.system(size: 10, weight: .bold))
            Text(planTypeText)
                .font(.system(size: 12, weight: .bold))
        }
        .foregroundColor(planColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(planColor.opacity(colorScheme == .dark ? 0.22 : 0.12), in: Capsule())
    }

    /// タグはそれぞれの色で出す。見出しの面を塗るのをやめたので、
    /// 白抜きで載せる必要がなくなった
    @ViewBuilder
    private func tagRow() -> some View {
        HStack(spacing: 6) {
            ForEach(planTags) { tag in
                Text(tag.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(tag.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        tag.color.opacity(colorScheme == .dark ? 0.24 : 0.14),
                        in: Capsule()
                    )
            }

            // タグが1つも無いときは、足せることが分かる口を出す
            if planTags.isEmpty {
                Button(action: enterEditMode) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .bold))
                        Text("タグ")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(themeManager.currentTheme.secondaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().strokeBorder(
                            themeManager.currentTheme.secondaryText.opacity(0.35),
                            style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                        )
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    /// 「あと2時間10分」。今日の予定のときだけ出す
    private var dailyCountdownText: String? {
        let calendar = Calendar.current
        guard calendar.isDateInToday(plan.startDate), let time = plan.time else { return nil }

        let parts = calendar.dateComponents([.hour, .minute], from: time)
        guard let target = calendar.date(bySettingHour: parts.hour ?? 0, minute: parts.minute ?? 0, second: 0, of: Date()) else { return nil }

        let minutes = Int(target.timeIntervalSince(Date()) / 60)
        guard minutes > 0 else { return nil }

        if minutes < 60 { return "あと\(minutes)分" }
        return "あと\(minutes / 60)時間\(minutes % 60)分"
    }

    // MARK: - 内容
    private func descriptionCard(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15))
            .foregroundColor(titleColor.opacity(0.85))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(cardSurface)
            )
            .shadow(color: colorScheme == .dark ? .clear : Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    private var cardSurface: Color {
        colorScheme == .dark
            ? themeManager.currentTheme.secondaryBackgroundDark
            : themeManager.currentTheme.backgroundLight
    }

    /// 日常の場所は1行だけ。無いときは、入れると何ができるのかを添える
    @ViewBuilder
    private var dailyPlaceCard: some View {
        if let place = plan.places.first {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(planColor.opacity(colorScheme == .dark ? 0.24 : 0.14))
                        .frame(width: 44, height: 44)
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(planColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(place.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(titleColor)
                        .lineLimit(1)

                    if let address = place.address, !address.isEmpty {
                        Text(address)
                            .font(.system(size: 12))
                            .foregroundColor(themeManager.currentTheme.secondaryText)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                Button { openRoute(to: place) } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("経路")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(planColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(planColor.opacity(colorScheme == .dark ? 0.24 : 0.14), in: Capsule())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(cardSurface)
            )
            .shadow(color: colorScheme == .dark ? .clear : Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
        } else {
            Button(action: enterEditMode) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(planColor.opacity(colorScheme == .dark ? 0.22 : 0.12))
                            .frame(width: 44, height: 44)
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(planColor)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("場所を追加")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(titleColor)
                        Text("入れておくと、この画面から経路案内を開けます。")
                            .font(.system(size: 12))
                            .foregroundColor(themeManager.currentTheme.secondaryText)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(themeManager.currentTheme.secondaryText.opacity(0.5))
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            themeManager.currentTheme.secondaryText.opacity(0.3),
                            style: StrokeStyle(lineWidth: 1.5, dash: [7, 5])
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private var quickActionRow: some View {
        HStack(spacing: 10) {
            quickAction(
                icon: "arrow.triangle.turn.up.right.diamond.fill",
                title: "経路案内",
                subtitle: routeSubtitle,
                isEnabled: !routeDestinations.isEmpty,
                isOn: false
            ) {
                startRouteGuidance()
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
                icon: plan.hasReminders ? "bell.fill" : "bell.slash",
                title: "通知",
                subtitle: reminderSummary,
                isEnabled: true,
                isOn: plan.hasReminders
            ) {
                showNotificationSettings = true
            }
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

    /// 通知・繰り返し・リンクの3行。値が右に出るので、設定済みかどうかが一目で分かる
    private var dailySettingsList: some View {
        VStack(spacing: 0) {
            settingsRow(
                icon: "bell",
                title: "通知",
                value: reminderSummary,
                isSet: plan.hasReminders,
                action: { showNotificationSettings = true }
            )

            settingsDivider

            settingsRow(
                icon: "repeat",
                title: "繰り返し",
                value: plan.recurrence.displayName,
                isSet: plan.recurrence != .none,
                action: enterEditMode
            )

            settingsDivider

            settingsRow(
                icon: "link",
                title: "リンク",
                value: (plan.linkURL?.isEmpty == false) ? "設定済み" : "未設定",
                isSet: plan.linkURL?.isEmpty == false,
                action: {
                    if let raw = plan.linkURL, let url = URL(string: raw) {
                        UIApplication.shared.open(url)
                    } else {
                        enterEditMode()
                    }
                }
            )
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(cardSurface)
        )
        .shadow(color: colorScheme == .dark ? .clear : Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    /// 通知の設定内容を1行で。件数だけだと何が鳴るのか分からないので、
    /// 1つなら名前をそのまま出す
    private var reminderSummary: String {
        let reminders = plan.effectiveReminders

        switch reminders.count {
        case 0:  return "なし"
        case 1:  return reminders[0].displayName
        default: return "\(reminders.count)件"
        }
    }

    /// 選んだ通知を予定に保存して、予約を入れ直す
    private func saveReminders(_ reminders: [PlanReminder]) {
        var updated = plan
        updated.reminders = reminders
        plan = updated

        guard let userId = authVM.userId else { return }
        viewModel.update(updated, userId: userId)
    }

    private var settingsDivider: some View {
        Rectangle()
            .fill(themeManager.currentTheme.secondaryText.opacity(0.12))
            .frame(height: 1)
            .padding(.leading, 52)
    }

    private func settingsRow(icon: String, title: String, value: String, isSet: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isSet ? planColor : themeManager.currentTheme.secondaryText)
                    .frame(width: 24)

                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(titleColor)

                Spacer(minLength: 0)

                Text(value)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isSet ? planColor : themeManager.currentTheme.secondaryText)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(themeManager.currentTheme.secondaryText.opacity(0.4))
            }
            .padding(.horizontal, 16)
            .frame(height: 54)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
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

    /// 編集画面の1区切り。
    ///
    /// 以前はセクションごとに影付きのカードを敷いていたが、中の入力欄も箱を持っているため
    /// 箱が二重になり、8つ並ぶと画面が箱だらけだった。
    /// 面を塗るのはやめて薄い区切り線だけにする。詳細画面をフラットにしたのとも揃う
    private func editSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 16)

            Rectangle()
                .fill(themeManager.currentTheme.secondaryText.opacity(0.15))
                .frame(height: 1)
        }
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

    /// 始まりと終わりで同じ行を使う
    private func editTimeRow(_ label: String, time: Binding<Date?>) -> some View {
        HStack {
            Image(systemName: "clock")
                .foregroundColor(planColor.opacity(0.8))
                .frame(width: 22)
            Text(label)
                .font(.subheadline)
                .foregroundColor(editTextColor)
            Spacer()
            DatePicker("", selection: Binding(
                get: { time.wrappedValue ?? Date() },
                set: { time.wrappedValue = $0 }
            ), displayedComponents: .hourAndMinute)
            .colorMultiply(planColor)
            .datePickerStyle(.compact)
            .labelsHidden()
            Button(action: { time.wrappedValue = nil }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(themeManager.currentTheme.secondaryText)
                    .padding(.leading, 6)
            }
        }
        .padding(14)
        .background(editFieldBg)
        .cornerRadius(12)
    }

    /// まだ設定していない時刻を足す口
    private func editAddTimeRow(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(planColor)
                    .frame(width: 22)
                Text(label)
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

    // MARK: - Edit Mode View
    private var editModeView: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {

                // 写真
                editSection {
                    VStack(alignment: .leading, spacing: 10) {
                        editSectionLabel("写真", icon: "photo")
                        photoEditRow
                        // 未購入のときだけ出る
                        DeviceOnlyPhotoNote()
                    }
                }

                // タイトル
                editSection {
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
                editSection {
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
                                    editTimeRow("始まり", time: $editedTime)

                                    // 終わりは始まりがあって初めて意味を持つ
                                    if editedEndTime != nil {
                                        editTimeRow("終わり", time: $editedEndTime)
                                    } else {
                                        editAddTimeRow("終わりの時間を追加") {
                                            let base = editedTime ?? Date()
                                            editedEndTime = Calendar.current.date(byAdding: .hour, value: 1, to: base) ?? base
                                        }
                                    }
                                } else {
                                    editAddTimeRow("時刻を設定") { editedTime = Date() }
                                }
                            }
                        }
                    }
                }

                // 繰り返し（記念日は毎年で固定なので出さない）
                if editedPlanType == .daily {
                    editSection {
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
                editSection {
                    VStack(alignment: .leading, spacing: 10) {
                        editSectionLabel("タグ", icon: "number")

                        PlanTagPicker(selectedIDs: $editedTagIDs, accentColor: editTextColor)
                    }
                }

                // 予定内容
                editSection {
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
                    editSection {
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
                editSection {
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

                // プランタイプ。
                // 作るときにどの項目を聞くかの区別でしかなく、後から変えるものではないので末尾に置く
                editSection {
                    VStack(alignment: .leading, spacing: 12) {
                        editSectionLabel("プランタイプ", icon: "tag.fill")
                        HStack(spacing: 10) {
                            editTypeButton(type: .outing, icon: PlanType.outing.icon, label: PlanType.outing.displayName)
                            editTypeButton(type: .daily,  icon: PlanType.daily.icon,  label: PlanType.daily.displayName)
                            editTypeButton(type: .anniversary, icon: PlanType.anniversary.icon, label: PlanType.anniversary.displayName)
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
                .padding(.top, 24)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
    }

    /// 写真の表紙。
    ///
    /// 以前はここにタイトルと日付を白抜きで重ねていたが、すぐ下の `planHeaderArea` が
    /// 同じものを出すので、**写真を入れた予定だけタイトルと日付が二重に出ていた**。
    /// 見出しは `planHeaderArea` に一本化し、ここは写真だけを見せる。
    /// 種別ピル・タグ・状態・日常の時刻はあちらにしか無いので、消すならこちら側になる
    private var headerImageView: some View {
        Group {
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
        }
        .frame(height: 250)
    }

    // MARK: - Header Image (Edit Mode)
    /// 編集画面の写真。
    ///
    /// 以前は編集画面の一番上を高さ260ptの写真枠が占めていて、写真が無い予定でも
    /// 種別色のグラデーションと「写真を変更」ボタンが常に出ていた。
    /// **大きな枠を置くこと自体が写真の追加を誘っていた**ので、
    /// 他の項目と同じ1セクションに落とした。位置は先頭のまま。
    ///
    /// 機能は残す。すでに写真を入れて使っている人がいる
    @ViewBuilder
    private var photoEditRow: some View {
        if let image = displayImage {
            HStack(spacing: 12) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Text("設定済み")
                    .font(.subheadline)
                    .foregroundColor(editTextColor)

                Spacer(minLength: 0)

                Button(action: { showImagePicker = true }) {
                    Text("変更")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(planColor)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(planColor.opacity(colorScheme == .dark ? 0.22 : 0.12), in: Capsule())
                }
                .buttonStyle(PlainButtonStyle())

                // 写真を外す口。これまでは差し替えしかできず、
                // 一度入れた写真を「無し」に戻す方法がどこにも無かった
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedImage = nil
                        displayImage = nil
                        isRemovingPhoto = true
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(themeManager.currentTheme.error)
                        .padding(8)
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel("写真を削除")
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                // 無いときは控えめに。種別色で塗らず、文字だけの口にする
                Button(action: { showImagePicker = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text("写真を追加")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(themeManager.currentTheme.secondaryText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        Capsule().strokeBorder(themeManager.currentTheme.secondaryText.opacity(0.25), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())

                // 消したことと、まだ取り消せることを伝える
                if isRemovingPhoto {
                    Text("保存すると写真が削除されます")
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                }
            }
        }
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
    /// 最初の場所へ地図アプリで案内させる。
    /// 座標を持っているので、URLを組み立てる必要はない
    /// 経路案内タイルの副題。最初の行き先と、2件以上あるならその数
    private var routeSubtitle: String? {
        let places = routeDestinations
        guard let first = places.first else { return nil }
        return places.count > 1 ? "\(first.name) ほか\(places.count - 1)件" : first.name
    }

    /// 案内できる行き先。タイムスケジュールに出てくる順（＝回る順）を優先し、
    /// そこに出てこない場所は後ろに足す
    private var routeDestinations: [PlannedPlace] {
        var seen = Set<String>()
        var ordered: [PlannedPlace] = []

        for item in plan.scheduleItems.sorted(by: { $0.time < $1.time }) {
            guard let id = item.placeId,
                  let place = plan.places.first(where: { $0.id == id }),
                  seen.insert(id).inserted else { continue }
            ordered.append(place)
        }

        ordered += plan.places.filter { seen.insert($0.id).inserted }
        return ordered
    }

    /// 経路案内。
    ///
    /// 以前は問答無用で1件目へ案内していたので、2件目以降に行きたいときに使えなかった。
    ///
    /// 全部をまとめて1本の経路にはしない。`MKMapItem.openMaps` で経路を出せるのは
    /// 2地点までで、3地点以上を渡したときの挙動は保証されていない
    private func startRouteGuidance() {
        let places = routeDestinations
        guard !places.isEmpty else { return }

        if places.count == 1 {
            openRoute(to: places[0])
        } else {
            showRoutePicker = true
        }
    }

    /// 開くアプリはプロフィールの「経路案内のアプリ」に従う（`mapNavigation`）
    private func openRoute(to place: PlannedPlace) {
        navigationTarget = MapDestination(name: place.name, coordinate: place.coordinate)
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
            HStack(spacing: 8) {
                Text("タイムスケジュール")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1)

                // 何件あるかは、開かなくても分かるほうがいい
                if !plan.scheduleItems.isEmpty {
                    Text("\(plan.scheduleItems.count)件")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            themeManager.currentTheme.secondaryText.opacity(colorScheme == .dark ? 0.18 : 0.10),
                            in: Capsule()
                        )
                }

                Spacer()

                Button(action: {
                    editingScheduleItem = nil
                    showScheduleEditor = true
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(planColor)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
            }
            // 上の操作タイルと近すぎたので離す
            .padding(.top, 10)

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
    /// 横スワイプで出る予定の切り替え。
    ///
    /// 見出しに種別色を敷いて白抜き文字を載せていたが、詳細の見出しを
    /// フラットにしたのと揃えて面を塗るのをやめた。
    /// 行も一覧のカード（`PlanEventCardView`）と同じ組みにしてある
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("予定の切り替え")
                    .font(.title3.bold())
                    .foregroundColor(titleColor)

                Text("\(sortedPlans.count)件")
                    .font(.subheadline)
                    .foregroundColor(themeManager.currentTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 14)

            Rectangle()
                .fill(themeManager.currentTheme.secondaryText.opacity(0.15))
                .frame(height: 1)

            // Schedule List
            ScrollView(showsIndicators: false) {
                VStack(spacing: 6) {
                    ForEach(sortedPlans) { schedulePlan in
                        sidebarPlanItem(plan: schedulePlan)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
            }
        }
        .frame(width: 280)
        .background(themeManager.currentTheme.elevatedSurface(for: colorScheme))
        .shadow(color: .black.opacity(0.2), radius: 15, x: 5, y: 0)
    }

    private func sidebarPlanItem(plan schedulePlan: Plan) -> some View {
        let isCurrent = schedulePlan.id == plan.id
        let typeColor = schedulePlan.planType.color(themeManager.currentTheme)
        let tags = tagManager.tags(for: schedulePlan.tagIDs)

        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                plan = schedulePlan
                showSidebar = false
                loadLocalImage()
            }
        }) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    // 50ptのグラデーション円をやめた。280ptの幅では場所を取りすぎるうえ、
                    // 一覧のカードは同じ情報を11ptのアイコンで足りている
                    Image(systemName: schedulePlan.planType.icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(typeColor)

                    Text(schedulePlan.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(themeManager.currentTheme.adaptiveText(for: colorScheme))
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    if isCurrent {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundColor(typeColor)
                    }
                }

                HStack(spacing: 6) {
                    if let tag = tags.first {
                        Text(tag.name)
                            .font(.system(size: 10, weight: .bold))
                            .lineLimit(1)
                            .foregroundColor(tag.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                tag.color.opacity(colorScheme == .dark ? 0.24 : 0.14),
                                in: RoundedRectangle(cornerRadius: 5)
                            )
                    }

                    Text(sidebarDateText(for: schedulePlan))
                        .font(.system(size: 11))
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    // 選んでいる1件だけ塗る。他は面を持たせない
                    .fill(isCurrent ? typeColor.opacity(colorScheme == .dark ? 0.20 : 0.10) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    /// 行に添える日付。日常は時刻、おでかけは期間、場所があれば件数を足す
    private func sidebarDateText(for schedulePlan: Plan) -> String {
        var parts: [String] = []

        if schedulePlan.planType == .outing {
            parts.append(dateRangeString(schedulePlan.startDate, schedulePlan.endDate))
        } else {
            parts.append(formatDate(schedulePlan.startDate))
        }

        if let timeText = schedulePlan.timeRangeText {
            parts.append(timeText)
        }

        if !schedulePlan.places.isEmpty {
            parts.append("\(schedulePlan.places.count)か所")
        }

        return parts.joined(separator: " · ")
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

    // MARK: - Edit Mode Functions
    private func enterEditMode() {
        isRemovingPhoto = false
        editedTitle = plan.title
        editedDescription = plan.description ?? ""
        editedLinkURL = plan.linkURL ?? ""
        editedPlanType = plan.planType
        editedStartDate = plan.startDate
        editedEndDate = plan.endDate
        editedTime = plan.time
        editedEndTime = plan.endTime
        editedPlaces = plan.places
        editedTagIDs = plan.tagIDs
        editedRecurrence = plan.recurrence
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isEditMode = true
        }
    }

    private func cancelEdit() {
        selectedImage = nil
        isRemovingPhoto = false
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
        } else if isRemovingPhoto {
            // 参照を外してから実体を消す。
            // 先にファイルを消すと、保存に失敗したときに写真だけ失われる
            let removedFileName = plan.localImageFileName
            updatePlanData(with: nil)

            if let removedFileName {
                try? FileManager.removeDocumentFile(named: removedFileName)
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
        // 始まりを消したら終わりも残さない
        updatedPlan.endTime = editedTime == nil ? nil : editedEndTime
        updatedPlan.places = editedPlaces
        updatedPlan.localImageFileName = localFileName
        updatedPlan.tagIDs = editedTagIDs
        // 記念日は毎年で固定。種別を変えたときに古い設定が残らないようにする
        updatedPlan.recurrence = editedPlanType == .anniversary ? .yearly : editedRecurrence

        // 日常と記念日は1日で完結する。終了日の欄はおでかけにしか出ないので、
        // ここで揃えないと日付を変えたときに古い終了日が残り、
        // 一覧が「◯◯まで」の複数日表示になったり、期間の判定から外れたりする
        if editedPlanType != .outing {
            updatedPlan.endDate = editedStartDate
        }

        // 記念日は時刻も場所も持たない
        if editedPlanType == .anniversary {
            updatedPlan.time = nil
            updatedPlan.endTime = nil
            updatedPlan.places = []
        }

        // おでかけも時刻は持たない。日常から変えたときに残らないようにする
        if editedPlanType == .outing {
            updatedPlan.endTime = nil
        }

        if let userId = authVM.userId {
            viewModel.update(updatedPlan, userId: userId)
        }

        DispatchQueue.main.async {
            isSaving = false
            plan = updatedPlan
            selectedImage = nil
            isRemovingPhoto = false
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
        guard let imageData = image.storedPhotoData() else {
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
        .navigationViewStyle(.stack)
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
                    searchResultNavigationTarget = MapDestination(result)
                } label: {
                    Label("経路", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(themeManager.currentTheme.actionFill.opacity(0.12))
                        .foregroundStyle(themeManager.currentTheme.actionFill)
                        .cornerRadius(10)
                }
                .mapNavigation($searchResultNavigationTarget)

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

