import SwiftUI
import WeatherKit
import MapKit

// EnjoyWorldView -> TravelPlanの詳細画面
struct TravelPlanDetailView: View {

    /// 写真の高さ。スクロール量の判定でも同じ値を使う
    static let headerHeight: CGFloat = 220

    /// タブバーの高さ。全タブで同じ高さ・同じ位置になるよう固定する
    static let tabBarHeight: CGFloat = 46

    /// ピンを押して予定へ送るときの寄せ先。
    ///
    /// `.center` だと、貼り付いている地図とDayタブの高さを考えないため、
    /// 1つ目の予定がその裏に少しだけ隠れてしまう。
    /// anchor は「行のその割合の点」を「枠のその割合の位置」に合わせる指定なので、
    /// 貼り付いている帯の下端より少し下を指す割合を渡す
    private var focusedItemAnchor: UnitPoint {
        guard scrollViewportHeight > 0 else { return .center }
        let pinnedBottom = topSafeAreaInset + Self.tabBarHeight + pinnedHeaderFrame.height
        let ratio = (pinnedBottom + 40) / scrollViewportHeight
        // 帯が画面の大半を占める小さい端末では、下に寄せすぎないようにする
        return UnitPoint(x: 0.5, y: min(max(ratio, 0.5), 0.85))
    }

    /// 写真が上に隠れているかどうか。
    /// 隠れているあいだだけ、戻るボタンをタブバーに出しステータスバーを覆う
    private var isChromeCompact: Bool { isHeaderCollapsed }

    /// ステータスバーの高さ。覆いを高さゼロで置くと何も描画されないため、
    /// 実際の値を取って明示的に埋める
    private var topSafeAreaInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })?
            .keyWindow?.safeAreaInsets.top ?? 0
    }

    /// 写真の下で切り替える画面。増やすときはここに1つ足す
    enum DetailTab: String, CaseIterable, Identifiable {
        case schedule = "日程"
        case map = "地図"
        case packing = "持ち物"
        case reservation = "予約確認"
        case budget = "費用"

        var id: String { rawValue }
    }

    // MARK: - View State
    enum ViewState {
        case loading
        case loaded(TravelPlan)
    }

    // MARK: - Properties
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var viewModel: TravelPlanViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject var themeManager = ThemeManager.shared
    @State private var selectedDay: Int = 1
    @State private var selectedTab: DetailTab = .schedule
    /// 地図タブで、地図と行程表のどちらから選んでも共有する項目
    @State private var focusedItemID: String?
    /// 1回のドラッグで何度もタブが飛ばないようにする目印
    @State private var hasSwitchedTabInDrag = false
    /// 地図タブで貼り付いている帯（地図 + Day タブ）が画面のどこにあるか。
    ///
    /// 地図は縦横に動かせるし Day タブは横スクロールなので、
    /// この中で始まったドラッグはタブ切り替えの対象から外す。
    /// **地図だけでなく Day タブまで含めること。**
    /// 地図だけにすると、Day を横スクロールするたびにタブが変わってしまう
    @State private var pinnedHeaderFrame: CGRect = .zero

    /// ScrollView の見えている高さ。scrollTo の anchor は割合指定なので必要
    @State private var scrollViewportHeight: CGFloat = 0
    /// 写真が上に隠れたかどうか。
    /// 隠れた後はスクロール中の内容がステータスバーの領域に見えてしまうので、
    /// そこを覆うかどうかの判定に使う
    @State private var isHeaderCollapsed = false
    @State private var showAddScheduleItem = false
    @State private var showBasicInfoEditor = false
    @State private var showBudgetSummary = false
    @State private var showShareView = false
    @State private var showScheduleMap = false
    @State private var showExperienceSearch = false
    /// 行き先から決まるアソビューのページ。決まらないときは都道府県一覧へ送る
    @State private var asoviewURL: URL?
    @State private var asoviewAreaName: String?
    @State private var showExperienceWeb = false
    @State private var exportItems: [Any]?
    @State private var animateContent = false
    @State private var navigatingItem: ScheduleItem?
    @State private var editingItem: ScheduleItem?

    // Weather Properties
    @State private var planWeather: WeatherService.DayWeather?
    @State private var isLoadingPlanWeather = false
    @State private var planWeatherError: String?
    @State private var weatherAttribution: WeatherService.WeatherAttribution?

    let planId: String

    // MARK: - Initialization
    init(plan: TravelPlan) {
        self.planId = plan.id ?? ""
    }

    // MARK: - Computed Properties
    private var viewState: ViewState {
        if let plan = currentPlan {
            return .loaded(plan)
        } else {
            return .loading
        }
    }

    private var currentPlan: TravelPlan? {
        viewModel.travelPlans.first(where: { $0.id == planId })
    }

    private var tripDuration: Int {
        guard let plan = currentPlan else { return 1 }
        let days = Calendar.current.dateComponents([.day], from: plan.startDate, to: plan.endDate).day ?? 0
        return days + 1
    }

    private var backgroundGradient: some View {
        let colors: [Color]
        switch themeManager.currentTheme.type {
        case .whiteBlack:
            colors = [Color(white: 0.96), Color(white: 0.91)]
        default:
            colors = colorScheme == .dark
                ? [themeManager.currentTheme.backgroundDark, themeManager.currentTheme.secondaryBackgroundDark]
                : [themeManager.currentTheme.backgroundLight, themeManager.currentTheme.secondaryBackgroundLight]
        }
        return LinearGradient(gradient: Gradient(colors: colors), startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }

    private var accentColor: Color {
        colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1
    }

    private var scheduleAccentColor: Color {
        switch themeManager.currentTheme.type {
        case .whiteBlack: return Color.black
        default: return themeManager.currentTheme.primary
        }
    }

    // MARK: - Body
    var body: some View {
        Group {
            switch viewState {
            case .loading:
                ProgressView()
            case .loaded(let plan):
                contentView(plan: plan)
            }
        }
        .navigationBarHidden(true)
        .background(SwipeBackEnabler())
    }

    // MARK: - View Components
    private func contentView(plan: TravelPlan) -> some View {
        ZStack {
            backgroundGradient

            ScrollViewReader { scrollProxy in
                ScrollView(showsIndicators: false) {
                    // 写真は LazyVStack の外に置く。中に入れると画面外で
                    // 破棄され、位置を測る GeometryReader ごと消えてしまう
                    VStack(spacing: 0) {
                        planHeaderSection(plan: plan)

                        // タブバーを上に貼り付けたいので Section の見出しに置く
                        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                            Section {
                                Group {
                                    switch selectedTab {
                                    case .schedule: scheduleTab(plan: plan)
                                    case .packing: packingTab(plan: plan)
                                    case .reservation: reservationTab(plan: plan)
                                    case .budget: budgetTab(plan: plan)
                                    case .map: mapTab(plan: plan)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            } header: {
                                VStack(spacing: 0) {
                                    detailTabBar
                                    // 地図タブでは地図も一緒に貼り付ける。
                                    // 行程を追いながら位置を確認できるようにするため
                                    if selectedTab == .map {
                                        mapPinnedHeader(plan: plan)
                                    }
                                }
                                .background(tabBarBackground)
                            }
                        }
                    }
                }
                // スクロール量を直接受け取る。GeometryReader と PreferenceKey で
                // 測る方法は、写真が画面外で破棄されると値が途切れて当てにならない。
                // ScrollView 自体に付けないと拾えないので、この位置から動かさないこと
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    geometry.contentOffset.y + geometry.contentInsets.top
                } action: { _, scrolled in
                    // 写真の残りが 72pt を切ったら貼り付いた表示に切り替える
                    let collapsed = scrolled > Self.headerHeight - 72
                    guard collapsed != isHeaderCollapsed else { return }
                    withAnimation(.easeInOut(duration: 0.2)) { isHeaderCollapsed = collapsed }
                }
                // スワイプは ScrollView に付ける。内側の要素に付けると
                // ScrollView に取り込まれて、ほとんど反応しなくなる
                .simultaneousGesture(tabSwipeGesture)
                // anchor は割合で指定するので、枠の高さが要る
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    geometry.containerSize.height
                } action: { _, height in
                    scrollViewportHeight = height
                }
                // 地図でピンを押されたら、その行まで送る
                .onChange(of: focusedItemID) { _, itemID in
                    guard selectedTab == .map, let itemID else { return }
                    withAnimation(.easeInOut(duration: 0.3)) {
                        scrollProxy.scrollTo(itemID, anchor: focusedItemAnchor)
                    }
                }
            }
        }
        // 貼り付いた帯の上（ステータスバーの領域）を、スクロール中の内容が
        // 通り抜けて見えてしまう。帯の中から ignoresSafeArea しても
        // 安全領域まで届かないため、画面の一番上に覆いを置く
        .overlay(alignment: .top) {
            if isChromeCompact {
                tabBarBackground
                    .frame(height: topSafeAreaInset)
                    .ignoresSafeArea(edges: .top)
            }
        }
        .onChange(of: selectedTab) { _, tab in
            if tab != .map { pinnedHeaderFrame = .zero }
        }
        .fullScreenCover(isPresented: $showAddScheduleItem) {
            AddScheduleItemView(plan: plan, dayNumber: selectedDay)
                .environmentObject(viewModel)
                .environmentObject(authVM)
        }
        .fullScreenCover(isPresented: $showScheduleMap) {
            TravelPlanMapView(plan: plan, initialDay: selectedDay)
        }
        .sheet(isPresented: Binding(
            get: { exportItems != nil },
            set: { if !$0 { exportItems = nil } }
        )) {
            if let exportItems {
                ShareSheet(items: exportItems)
            }
        }
        .fullScreenCover(item: $editingItem) { item in
            if let daySchedule = plan.daySchedules.first(where: { $0.dayNumber == selectedDay }) {
                EditScheduleItemView(plan: plan, daySchedule: daySchedule, item: item)
                    .environmentObject(viewModel)
                    .environmentObject(authVM)
            }
        }
        .sheet(isPresented: $showExperienceWeb) {
            if let asoviewURL {
                SafariView(url: asoviewURL)
            }
        }
        .task(id: "\(plan.destination)_\(plan.latitude ?? 0)_\(plan.longitude ?? 0)") {
            guard AffiliateLink.isAsoviewAvailable else { return }
            let area = await AsoviewArea.resolvedArea(
                latitude: plan.latitude,
                longitude: plan.longitude,
                fallbackText: plan.destination
            )
            asoviewAreaName = area?.name
            asoviewURL = area.flatMap { AffiliateLink.asoviewURL(slug: $0.slug) }
        }
        .sheet(isPresented: $showExperienceSearch) {
            NavigationStack {
                ExperienceSearchView()
            }
        }
        .sheet(isPresented: $showBasicInfoEditor) {
            EditTravelPlanBasicInfoView(plan: plan)
                .environmentObject(viewModel)
        }
        .sheet(isPresented: $showBudgetSummary) {
            if let currentPlan = currentPlan {
                BudgetSummaryView(plan: currentPlan)
                    .environmentObject(viewModel)
                    .environmentObject(authVM)
            }
        }
        .confirmationDialog(
            navigatingItem?.location ?? navigatingItem?.title ?? "",
            isPresented: Binding(
                get: { navigatingItem != nil },
                set: { if !$0 { navigatingItem = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Apple マップで案内") {
                if let item = navigatingItem, let lat = item.latitude, let lng = item.longitude {
                    openInAppleMaps(name: item.location ?? item.title, latitude: lat, longitude: lng)
                }
            }
            if UIApplication.shared.canOpenURL(URL(string: "comgooglemaps://")!) {
                Button("Google マップで案内") {
                    if let item = navigatingItem, let lat = item.latitude, let lng = item.longitude {
                        openInGoogleMaps(latitude: lat, longitude: lng)
                    }
                }
            }
            Button("キャンセル", role: .cancel) { navigatingItem = nil }
        } message: {
            Text("案内するアプリを選択してください")
        }
        .sheet(isPresented: $showShareView) {
            if let currentPlan = currentPlan {
                ShareTravelPlanView(plan: currentPlan) { shareCode in
                    guard let planId = currentPlan.id, let userId = authVM.userId else {
                        throw APIClientError.authenticationError
                    }
                    try await viewModel.updateShareCode(planId: planId, shareCode: shareCode, userId: userId)
                }
                .environmentObject(viewModel)
            }
        }
        .onAppear {
            withAnimation {
                animateContent = true
            }
            fetchPlanWeather()

            // 終わった旅行を見返すのは、思い出が良い形で残っている場面
            if Calendar.current.startOfDay(for: plan.endDate) < Calendar.current.startOfDay(for: Date()) {
                ReviewRequestManager.shared.record(.travelCompleted)
            }
        }
    }

    private func emptyScheduleMessage(plan: TravelPlan) -> some View {
        Button(action: { showAddScheduleItem = true }) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(scheduleAccentColor.opacity(0.08))
                        .frame(width: 64, height: 64)
                    Image(systemName: "plus.circle")
                        .font(.system(size: 28))
                        .foregroundColor(scheduleAccentColor.opacity(0.5))
                }
                Text("予定を追加する")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(themeManager.currentTheme.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 36)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(scheduleAccentColor.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(scheduleAccentColor.opacity(0.2), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func deleteScheduleItem(_ item: ScheduleItem, from plan: TravelPlan) {
        var updatedPlan = plan
        if let dayIndex = updatedPlan.daySchedules.firstIndex(where: { $0.dayNumber == selectedDay }) {
            updatedPlan.daySchedules[dayIndex].scheduleItems.removeAll { $0.id == item.id }
        }
        if let userId = authVM.userId {
            viewModel.update(updatedPlan, userId: userId)
        }
    }

    private func timelineItemView(item: ScheduleItem, isLast: Bool, plan: TravelPlan) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // タイムラインライン
            VStack(spacing: 0) {
                // 時刻バッジ
                Text(formatTime(item.time))
                    .font(.system(size: 12, weight: .bold))
                    // 枠が狭く、太字設定などで幅が増えると折り返していた。
                    // 折り返さずに縮める
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(scheduleAccentColor)
                    .clipShape(Capsule())
                    .frame(width: 58)

                if !isLast {
                    Rectangle()
                        .fill(scheduleAccentColor.opacity(0.25))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                        .padding(.vertical, 6)
                }
            }
            .frame(width: 58)

            // カードコンテンツ
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(accentColor)

                if let location = item.location, !location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(scheduleAccentColor.opacity(0.7))
                        Text(location)
                            .font(.system(size: 12))
                            .foregroundColor(themeManager.currentTheme.secondaryText)
                            .lineLimit(1)
                        if item.latitude != nil && item.longitude != nil {
                            Spacer()
                            Button(action: { navigatingItem = item }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                                        .font(.system(size: 10))
                                    Text("案内")
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .foregroundColor(themeManager.currentTheme.info)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(themeManager.currentTheme.info.opacity(0.12))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }

                // 実績が入っているときは予算と並べる。
                // 金額が2つ並ぶので、どちらか分かるよう「予算」と明示する
                if (item.cost ?? 0) > 0 || item.actualCost != nil {
                    HStack(spacing: 10) {
                        if let cost = item.cost, cost > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "yensign.circle")
                                    .font(.system(size: 11))
                                Text(item.actualCost == nil ? "¥\(Int(cost))" : "予算 ¥\(Int(cost))")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(themeManager.currentTheme.secondaryText)
                        }

                        if let actualCost = item.actualCost {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 11))
                                Text("実績 ¥\(Int(actualCost))")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(themeManager.currentTheme.info)
                        }
                    }
                }

                if let notes = item.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.system(size: 12))
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                        .lineLimit(2)
                }

                // 入力できるのに表示先が無く、開く手段がなかったため追加
                if let linkURL = item.linkURL {
                    LinkChip(rawURL: linkURL, tint: themeManager.currentTheme.info)
                }
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)

            // 編集・削除メニュー
            Menu {
                Button {
                    editingItem = item
                } label: {
                    Label("編集", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    deleteScheduleItem(item, from: plan)
                } label: {
                    Label("削除", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 18))
                    .foregroundColor(themeManager.currentTheme.secondaryText.opacity(0.5))
                    .padding(.top, 14)
            }
        }
        .padding(.horizontal, 4)
    }

    private func planHeaderSection(plan: TravelPlan) -> some View {
        ZStack {
            // 背景画像
            Group {
                if let planId = plan.id, let image = viewModel.planImages[planId] {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if let localImageFileName = plan.localImageFileName,
                          let image = FileManager.documentsImage(named: localImageFileName) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [
                                themeManager.currentTheme.primary.opacity(0.8),
                                themeManager.currentTheme.secondary.opacity(0.6)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .overlay(
                            Image(systemName: "airplane")
                                .font(.system(size: 80))
                                .foregroundColor(.white.opacity(0.15))
                        )
                }
            }
            .frame(height: Self.headerHeight)
            .clipped()

            // グラデーションオーバーレイ（下部を暗く）
            LinearGradient(
                // 位置は高さに対する割合なので、写真を縮めると暗くなる位置も
                // 上がってしまう。早めに暗くして文字の背景を確保する
                gradient: Gradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: Color.black.opacity(0.35), location: 0.2),
                    .init(color: Color.black.opacity(0.85), location: 1)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: Self.headerHeight)

            // テキスト情報（下部）
            //
            // 以前はバッジ・タイトル・アイコン付きの日付が同じ調子で並び、
            // 視線の行き先が定まっていなかった。
            // 目的地と日数を細い1行にまとめ、タイトルを主役にして、
            // 日付は期間で見せる。装飾のアイコンは外した
            VStack(alignment: .leading, spacing: 6) {
                Text("\(plan.destination) · \(formatTripDuration())")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.75))
                    .lineLimit(1)

                Text(plan.title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(tripDateRange(plan: plan))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Spacer(minLength: 0)

                    // 開くたびに「いま知りたいこと」が出るようにする
                    if let status = tripStatusText(plan: plan) {
                        Text(status)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(.ultraThinMaterial))
                    }
                }
            }
            .shadow(color: .black.opacity(0.45), radius: 4, x: 0, y: 1)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            // ナビゲーションボタン（上部）
            HStack {
                // 写真が見えているあいだはここに置く。
                // スクロールで写真が隠れたらタブバー側に出る
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    ZStack {
                        Circle().fill(.ultraThinMaterial).frame(width: 40, height: 40)
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.leading, 16)

                Spacer()

                HStack(spacing: 10) {
                    // アプリを持っていない相手にも旅程を渡せるようにする
                    Menu {
                        Button {
                            exportItems = [TravelPlanTextExporter.fullItinerary(for: plan)]
                        } label: {
                            Label("テキストで送る（全日程）", systemImage: "doc.plaintext")
                        }

                        Button {
                            exportCurrentDayImage(plan: plan)
                        } label: {
                            Label("画像で送る（Day \(selectedDay)）", systemImage: "photo")
                        }
                    } label: {
                        ZStack {
                            Circle().fill(.ultraThinMaterial).frame(width: 40, height: 40)
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .accessibilityLabel("旅程を書き出す")

                    Button(action: { showShareView = true }) {
                        ZStack {
                            Circle().fill(.ultraThinMaterial).frame(width: 40, height: 40)
                            Image(systemName: plan.isShared ? "person.2.fill" : "person.2")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(plan.isShared ? themeManager.currentTheme.success : .white)
                        }
                    }
                    Button(action: { showBasicInfoEditor = true }) {
                        ZStack {
                            Circle().fill(.ultraThinMaterial).frame(width: 40, height: 40)
                            Image(systemName: "pencil")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.trailing, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 12)
        }
        .frame(height: Self.headerHeight)
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : -20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animateContent)
    }

    private func budgetCard(plan: TravelPlan) -> some View {
        Button(action: { showBudgetSummary = true }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(scheduleAccentColor.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: "yensign.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(scheduleAccentColor.opacity(0.8))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("合計予算")
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                    Text(formatBudgetAmount(plan: plan))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(accentColor)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(themeManager.currentTheme.secondaryText.opacity(0.5))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(colorScheme == .dark ? themeManager.currentTheme.secondaryBackgroundDark : themeManager.currentTheme.secondaryBackgroundLight)
                    .shadow(color: themeManager.currentTheme.shadow, radius: 6, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.top, 12)
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : 10)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: animateContent)
    }

    private func dayScheduleSection(plan: TravelPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // セクションヘッダー
            HStack {
                Text("タイムスケジュール")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(accentColor)
                Spacer()

                Button(action: { showAddScheduleItem = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                        Text("追加")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(scheduleAccentColor)
                    .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
            }

            dayTabs(plan: plan)

            // スケジュールアイテムリスト
            if let daySchedule = plan.daySchedules.first(where: { $0.dayNumber == selectedDay }),
               !daySchedule.scheduleItems.isEmpty {
                let sortedItems = sortedScheduleItems(daySchedule.scheduleItems)
                VStack(spacing: 0) {
                    ForEach(Array(sortedItems.enumerated()), id: \.element.id) { index, item in
                        timelineItemView(item: item, isLast: index == sortedItems.count - 1, plan: plan)
                    }
                }
            } else {
                emptyScheduleMessage(plan: plan)
            }
        }
        .padding(.top, 4)
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : 10)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.25), value: animateContent)
    }

    // MARK: - Weather Section
    @ViewBuilder
    // MARK: - タブ

    /// 貼り付く帯の背景。中身が透けないよう不透明にする
    private var tabBarBackground: some View {
        (colorScheme == .dark
         ? themeManager.currentTheme.backgroundDark
         : themeManager.currentTheme.backgroundLight)
    }

    /// 横にはっきり振ったときだけタブを移す。
    ///
    /// 指を離した時点（onEnded）で判定していたが、ScrollView が縦スクロールを
    /// 引き受けるとこのジェスチャは取り消され、onEnded 自体が呼ばれない。
    /// そのため反応しないことが多かった。
    /// ドラッグの途中で条件を満たした時点で切り替える。
    private var tabSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .global)
            .onChanged { value in
                // 貼り付いた帯の中で始めたドラッグは、地図の操作か
                // Day タブの横スクロール。タブは動かさない
                guard !pinnedHeaderFrame.contains(value.startLocation) else { return }

                let dx = value.translation.width
                let dy = value.translation.height

                // 指を置き直した直後は解除する。
                // 取り消されると onEnded が来ないので、ここでも戻しておく
                if abs(dx) < 14 && abs(dy) < 14 {
                    hasSwitchedTabInDrag = false
                    return
                }

                guard !hasSwitchedTabInDrag else { return }
                guard abs(dx) > 70, abs(dx) > abs(dy) * 2.0 else { return }

                hasSwitchedTabInDrag = true
                moveTab(forward: dx < 0)
            }
            .onEnded { _ in hasSwitchedTabInDrag = false }
    }

    /// 隣のタブへ移る。端では止まる（一周させると今どこにいるか分からなくなる）
    private func moveTab(forward: Bool) {
        let tabs = DetailTab.allCases
        guard let index = tabs.firstIndex(of: selectedTab) else { return }
        let next = forward ? index + 1 : index - 1
        guard tabs.indices.contains(next) else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            selectedTab = tabs[next]
        }
    }

    private var detailTabBar: some View {
        HStack(spacing: 0) {
            // 写真が隠れているあいだだけ出す。写真が見えているときは
            // 写真の左上にあるので、ここには要らない
            if isChromeCompact {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(accentColor)
                        .frame(width: 40, height: 44)
                }
                .accessibilityLabel(Text("戻る"))
            }

            tabButtons
        }
        .frame(height: Self.tabBarHeight)
        .background(tabBarBackground)
        .shadow(color: themeManager.currentTheme.shadow, radius: 4, y: 2)
    }

    private var tabButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(DetailTab.allCases) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
                    } label: {
                        VStack(spacing: 6) {
                            Text(tab.rawValue)
                                .font(.system(size: 15, weight: selectedTab == tab ? .bold : .regular))
                                .foregroundColor(selectedTab == tab ? scheduleAccentColor : themeManager.currentTheme.secondaryText)

                            // 選択中の下線。幅を文字に合わせるため VStack の中に置く
                            Rectangle()
                                .fill(selectedTab == tab ? scheduleAccentColor : Color.clear)
                                .frame(height: 2)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - 各タブの中身

    private func scheduleTab(plan: TravelPlan) -> some View {
        VStack(spacing: 0) {
            planWeatherSection
            sectionSeparator
            dayScheduleSection(plan: plan)
            experienceRow
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 30)
    }

    /// 地図と行程表を上下に並べる。
    /// 地図だけだと「どの時間の場所か」が分からず、行程表だけだと位置関係が
    /// 分からない。並べると、片方を選ぶともう片方が追従する
    /// Day の切り替え。行程表タブと地図タブの両方で使う
    private func dayTabs(plan: TravelPlan) -> some View {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(1...tripDuration, id: \.self) { day in
                        let isSelected = selectedDay == day
                        let itemCount = plan.daySchedules.first(where: { $0.dayNumber == day })?.scheduleItems.count ?? 0
                        let dayDate: Date? = {
                            let d = plan.daySchedules.first(where: { $0.dayNumber == day })?.date
                            return d ?? Calendar.current.date(byAdding: .day, value: day - 1, to: plan.startDate)
                        }()

                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedDay = day
                            }
                        }) {
                            VStack(spacing: 4) {
                                Text("Day \(day)")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(isSelected ? .white : accentColor)

                                if let d = dayDate {
                                    Text(formatDate(d))
                                        .font(.system(size: 10))
                                        .foregroundColor(isSelected ? .white.opacity(0.8) : themeManager.currentTheme.secondaryText)
                                }

                                if itemCount > 0 {
                                    Text("\(itemCount)件")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(isSelected ? .white.opacity(0.8) : scheduleAccentColor)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isSelected ? scheduleAccentColor : (colorScheme == .dark ? themeManager.currentTheme.secondaryBackgroundDark : themeManager.currentTheme.secondaryBackgroundLight))
                                    .shadow(color: isSelected ? scheduleAccentColor.opacity(0.3) : themeManager.currentTheme.shadow, radius: isSelected ? 6 : 3, x: 0, y: 2)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.vertical, 4)
            }
    }

    /// タブバーと一緒に貼り付ける部分。地図と Day の切り替えを常に見せる
    private func mapPinnedHeader(plan: TravelPlan) -> some View {
        VStack(spacing: 0) {
            TravelPlanMapView(
                plan: plan,
                initialDay: selectedDay,
                isEmbedded: true,
                isSplitMode: true,
                linkedDay: $selectedDay,
                linkedItemID: $focusedItemID
            )
            .frame(height: 274)
            // 貼り付けている地図は狭いので、じっくり見たいときは全画面へ。
            // 右上は「全体を表示」が使っているので左上に置く
            .overlay(alignment: .topLeading) {
                Button(action: { showScheduleMap = true }) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(accentColor)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .padding(12)
                .accessibilityLabel(Text("地図を全画面で見る"))
            }

            compactDayTabs(plan: plan)
                .padding(.vertical, 8)
        }
        .background(tabBarBackground)
        .shadow(color: themeManager.currentTheme.shadow, radius: 4, y: 2)
        // 帯ぜんぶの位置と大きさを覚えておく。2つのことに使う。
        // ・地図の操作と Day タブの横スクロールを、タブ切り替えの対象から外す
        // ・ピンを押して予定へ送るとき、この帯の下に出す
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .global)
        } action: { frame in
            pinnedHeaderFrame = frame
        }
    }

    /// 地図タブの中身。地図と Day タブは貼り付く側にあるので、ここは予定だけ
    private func mapTab(plan: TravelPlan) -> some View {
        Group {
            if let daySchedule = plan.daySchedules.first(where: { $0.dayNumber == selectedDay }),
               !daySchedule.scheduleItems.isEmpty {
                let sortedItems = sortedScheduleItems(daySchedule.scheduleItems)
                VStack(spacing: 0) {
                    ForEach(Array(sortedItems.enumerated()), id: \.element.id) { index, item in
                        timelineItemView(item: item, isLast: index == sortedItems.count - 1, plan: plan)
                            .id(item.id)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(focusedItemID == item.id
                                          ? scheduleAccentColor.opacity(0.10)
                                          : Color.clear)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                // 上の地図をこの場所へ寄せる
                                focusedItemID = item.id
                            }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 30)
            } else {
                emptyScheduleMessage(plan: plan)
                    .padding(16)
            }
        }
    }

    /// 地図タブ用の細い Day 切り替え。
    /// 行程表タブのカード型は高さがあり、狭い下半分では場所を取りすぎる
    private func compactDayTabs(plan: TravelPlan) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(1...tripDuration, id: \.self) { day in
                    let isSelected = selectedDay == day
                    let dayDate = plan.daySchedules.first(where: { $0.dayNumber == day })?.date
                        ?? Calendar.current.date(byAdding: .day, value: day - 1, to: plan.startDate)

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedDay = day
                            focusedItemID = nil
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text("Day \(day)")
                                .font(.system(size: 13, weight: .bold))
                            if let dayDate {
                                Text(formatDate(dayDate))
                                    .font(.system(size: 11))
                                    .opacity(0.8)
                            }
                        }
                        .foregroundColor(isSelected ? .white : accentColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule().fill(isSelected
                                           ? scheduleAccentColor
                                           : (colorScheme == .dark
                                              ? themeManager.currentTheme.secondaryBackgroundDark
                                              : themeManager.currentTheme.secondaryBackgroundLight))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func packingTab(plan: TravelPlan) -> some View {
        PackingListView(plan: plan)
            .environmentObject(viewModel)
            .environmentObject(authVM)
            .padding(16)
            .padding(.bottom, 30)
    }

    private func reservationTab(plan: TravelPlan) -> some View {
        ReservationListView(plan: plan, isEmbedded: true)
            .environmentObject(viewModel)
            .environmentObject(authVM)
            .padding(16)
            .padding(.bottom, 30)
    }

    private func budgetTab(plan: TravelPlan) -> some View {
        BudgetSummaryView(plan: plan, isEmbedded: true)
            .environmentObject(viewModel)
            .environmentObject(authVM)
    }

    /// 行程を組んだ流れで体験を探せるよう、予定の下に置く
    @ViewBuilder
    private var experienceRow: some View {
        if AffiliateLink.isAsoviewAvailable {
            VStack(alignment: .leading, spacing: 6) {
                Button {
                    if asoviewURL != nil {
                        showExperienceWeb = true
                    } else {
                        showExperienceSearch = true
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16))
                            .foregroundColor(scheduleAccentColor)

                        Text(asoviewAreaName.map { "\($0)の遊び・体験を探す" } ?? "遊び・体験を探す")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(accentColor)

                        Spacer(minLength: 0)

                        Image(systemName: "arrow.up.forward.square")
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.secondaryText)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(colorScheme == .dark
                                  ? themeManager.currentTheme.secondaryBackgroundDark
                                  : themeManager.currentTheme.secondaryBackgroundLight)
                    )
                }
                .buttonStyle(.plain)

                Text("※ プロモーションを含みます")
                    .font(.system(size: 10))
                    .foregroundColor(themeManager.currentTheme.secondaryText)
            }
            .padding(.top, 20)
        }
    }

    /// セクションの区切り。両端が消えるので線が主張しすぎない
    /// （保存した場所の詳細と同じ意匠に揃えている）
    private var sectionSeparator: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [Color.clear, accentColor.opacity(0.25), Color.clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
            .padding(.vertical, 10)
    }

    /// 天気。以前は見出し・大きな円アイコン・縦積みの出典で約150pt使っていたが、
    /// 出ている情報は「天気と最高気温」だけだった。
    /// 1行に畳んで、代わりに最低気温と降水確率も出している。
    private var planWeatherSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            weatherBody
            // WeatherKit は出典の表示が必須。横1行に収める
            weatherAttributionLine
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : 10)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: animateContent)
    }

    @ViewBuilder
    private var weatherBody: some View {
        if let plan = currentPlan {
            if plan.latitude == nil || plan.longitude == nil {
                weatherNote("設定された場所には天気の情報がありませんでした", icon: "cloud.slash")
            } else if isLoadingPlanWeather {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("天気を確認しています…")
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                }
            } else if planWeatherError != nil {
                weatherNote("10日前になると天気が表示されます", icon: "calendar")
            } else if let weather = planWeather {
                weatherSummary(weather)
            }
        }
    }

    private func weatherNote(_ text: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundColor(themeManager.currentTheme.secondaryText)
    }

    private func weatherSummary(_ weather: WeatherService.DayWeather) -> some View {
        HStack(spacing: 10) {
            // font 指定だと文字枠の中に小さく描かれる。
            // resizable で枠いっぱいに描くと、行の高さはそのままで一回り大きくなる
            Image(systemName: weather.symbolName)
                .resizable()
                .scaledToFit()
                .foregroundColor(scheduleAccentColor)
                .frame(width: 42, height: 34)

            Text(weather.condition)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(accentColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 4)

            HStack(spacing: 6) {
                Text("\(Int(weather.highTemperature))°")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(accentColor)
                Text("\(Int(weather.lowTemperature))°")
                    .font(.system(size: 17))
                    .foregroundColor(themeManager.currentTheme.secondaryText)
            }

            // 傘が要るかは旅行の準備に直結するので、縮めた分ここに回す
            HStack(spacing: 3) {
                Image(systemName: "umbrella.fill")
                    .font(.caption)
                Text(weather.precipitationText)
                    .font(.system(size: 13))
            }
            .foregroundColor(themeManager.currentTheme.secondaryText)
        }
    }

    @ViewBuilder
    private var weatherAttributionLine: some View {
        if let attribution = weatherAttribution {
            HStack(spacing: 6) {
                Spacer(minLength: 0)

                AsyncImage(url: colorScheme == .dark ? attribution.combinedMarkDarkURL : attribution.combinedMarkLightURL) { image in
                    image.resizable().scaledToFit().frame(height: 10)
                } placeholder: {
                    Color.clear.frame(height: 10)
                }

                Link(destination: attribution.legalPageURL) {
                    Text("その他のデータソース")
                        .font(.system(size: 9))
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                }
            }
        }
    }

    // MARK: - Packing List Section
    private func packingListSection(plan: TravelPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("持ち物リスト")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(accentColor)
                Spacer()
            }

            if let currentPlan = currentPlan {
                PackingListView(plan: currentPlan)
                    .environmentObject(viewModel)
            }
        }
        .padding(.top, 20)
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : 10)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.35), value: animateContent)
    }

    // MARK: - Helper Methods
    /// 表示中の日の旅程を画像にして共有する
    @MainActor
    private func exportCurrentDayImage(plan: TravelPlan) {
        let daySchedule = plan.daySchedules.first { $0.dayNumber == selectedDay }
            ?? DaySchedule(
                dayNumber: selectedDay,
                date: Calendar.current.date(byAdding: .day, value: selectedDay - 1, to: plan.startDate) ?? plan.startDate
            )

        let card = TravelPlanShareCard(
            plan: plan,
            daySchedule: daySchedule,
            accentColor: scheduleAccentColor
        )

        let renderer = ImageRenderer(content: card)
        renderer.scale = 3

        guard let image = renderer.uiImage else { return }
        exportItems = [image]
    }

    /// 地図に出せる（座標を持つ）スケジュール項目が1件でもあるか
    private func sortedScheduleItems(_ items: [ScheduleItem]) -> [ScheduleItem] {
        let calendar = Calendar.current

        return items.sorted { item1, item2 in
            // Extract hour and minute components only (ignore date)
            let components1 = calendar.dateComponents([.hour, .minute], from: item1.time)
            let components2 = calendar.dateComponents([.hour, .minute], from: item2.time)

            let hour1 = components1.hour ?? 0
            let minute1 = components1.minute ?? 0
            let hour2 = components2.hour ?? 0
            let minute2 = components2.minute ?? 0

            // Compare by hour first, then by minute
            if hour1 != hour2 {
                return hour1 < hour2
            } else {
                return minute1 < minute2
            }
        }
    }

    private func formatBudgetAmount(plan: TravelPlan) -> String {
        let total = plan.daySchedules
            .flatMap { $0.scheduleItems }
            .compactMap { $0.cost }
            .reduce(0, +)

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0

        return "¥\(formatter.string(from: NSNumber(value: total)) ?? "0")"
    }

    private func formatTotalCost(plan: TravelPlan) -> String {
        let total = plan.daySchedules
            .flatMap { $0.scheduleItems }
            .compactMap { $0.cost }
            .reduce(0, +)

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0

        if total == 0 {
            return "まだ金額が登録されていません"
        } else {
            return "合計: ¥\(formatter.string(from: NSNumber(value: total)) ?? "0")"
        }
    }

    private func formatDateWithWeekday(_ date: Date) -> String {
        let formatter = DateFormatter.japanese
        formatter.dateFormat = "yyyy年MM月dd日(E)"
        return formatter.string(from: date)
    }

    private func openInAppleMaps(name: String, latitude: Double, longitude: Double) {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    private func openInGoogleMaps(latitude: Double, longitude: Double) {
        let urlString = "comgooglemaps://?daddr=\(latitude),\(longitude)&directionsmode=driving"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter.japanese
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func dateRangeString(plan: TravelPlan) -> String {
        let formatter = DateFormatter.japanese
        formatter.dateFormat = "M/d"
        return "\(formatter.string(from: plan.startDate)) - \(formatter.string(from: plan.endDate))"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter.japanese
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter.japanese
        formatter.dateFormat = "M/d HH:mm"
        return formatter.string(from: date)
    }

    /// 「8/20 (木) — 8/22 (土)」の形。年は今年と違うときだけ添える
    private func tripDateRange(plan: TravelPlan) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter.japanese
        let currentYear = calendar.component(.year, from: Date())
        let startYear = calendar.component(.year, from: plan.startDate)

        formatter.dateFormat = startYear == currentYear ? "M/d (E)" : "yyyy/M/d (E)"
        let start = formatter.string(from: plan.startDate)

        guard !calendar.isDate(plan.startDate, inSameDayAs: plan.endDate) else { return start }

        formatter.dateFormat = "M/d (E)"
        return "\(start) — \(formatter.string(from: plan.endDate))"
    }

    /// 出発前は残り日数、旅行中は何日目か。終わった旅行では出さない
    private func tripStatusText(plan: TravelPlan) -> String? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.startOfDay(for: plan.startDate)
        let end = calendar.startOfDay(for: plan.endDate)

        if today < start {
            let days = calendar.dateComponents([.day], from: today, to: start).day ?? 0
            return days == 1 ? "明日から" : "あと\(days)日"
        }
        if today <= end {
            let elapsed = calendar.dateComponents([.day], from: start, to: today).day ?? 0
            return "Day \(elapsed + 1)"
        }
        return nil
    }

    private func formatTripDuration() -> String {
        if tripDuration == 1 {
            return "1日"
        } else {
            return "\(tripDuration)日間"
        }
    }

    // MARK: - Weather Fetching
    private func fetchPlanWeather() {
        guard #available(iOS 16.0, *) else {
            return
        }

        guard let plan = currentPlan else {
            return
        }

        guard let latitude = plan.latitude,
              let longitude = plan.longitude else {
            planWeather = nil
            isLoadingPlanWeather = false
            planWeatherError = nil
            weatherAttribution = nil
            return
        }

        isLoadingPlanWeather = true
        planWeatherError = nil

        Task { @MainActor in
            // WeatherKitの準備が完了するまで少し待機
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒

            do {
                // Fetch weather data
                let fetchedWeather = try await WeatherService.shared.fetchDayWeather(
                    latitude: latitude,
                    longitude: longitude,
                    date: plan.startDate
                )

                // Fetch attribution
                let fetchedAttribution = try await WeatherService.shared.getWeatherAttribution()

                self.planWeather = fetchedWeather
                self.weatherAttribution = fetchedAttribution
                self.isLoadingPlanWeather = false
            } catch {
                self.planWeatherError = error.localizedDescription
                self.isLoadingPlanWeather = false
            }
        }
    }
}

// MARK: - Preview
#Preview {
    let viewModel = TravelPlanViewModel()
    let authVM = AuthViewModel()

    // サンプルのスケジュールアイテムを作成
    let sampleScheduleItems = [
        ScheduleItem(
            id: UUID().uuidString,
            time: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!,
            title: "東京タワー観光",
            location: "東京タワー",
            notes: "展望台からの眺めを楽しむ",
            latitude: 35.6586,
            longitude: 139.7454,
            cost: 1200,
            mapURL: nil,
            linkURL: "https://www.tokyotower.co.jp"
        ),
        ScheduleItem(
            id: UUID().uuidString,
            time: Calendar.current.date(bySettingHour: 12, minute: 30, second: 0, of: Date())!,
            title: "ランチ",
            location: "レストラン芝",
            notes: "和食のコース料理",
            latitude: 35.6560,
            longitude: 139.7470,
            cost: 3500,
            mapURL: nil,
            linkURL: nil
        ),
        ScheduleItem(
            id: UUID().uuidString,
            time: Calendar.current.date(bySettingHour: 15, minute: 0, second: 0, of: Date())!,
            title: "浅草観光",
            location: "浅草寺",
            notes: "雷門と仲見世通りを散策",
            latitude: 35.7148,
            longitude: 139.7967,
            cost: 0,
            mapURL: nil,
            linkURL: nil
        )
    ]

    // サンプルのDayScheduleを作成
    let sampleDaySchedules = [
        DaySchedule(
            dayNumber: 1,
            date: Date(),
            scheduleItems: sampleScheduleItems
        ),
        DaySchedule(
            dayNumber: 2,
            date: Calendar.current.date(byAdding: .day, value: 1, to: Date())!,
            scheduleItems: [
                ScheduleItem(
                    id: UUID().uuidString,
                    time: Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!,
                    title: "スカイツリー",
                    location: "東京スカイツリー",
                    notes: "展望デッキと水族館",
                    latitude: 35.7101,
                    longitude: 139.8107,
                    cost: 2500,
                    mapURL: nil,
                    linkURL: nil
                )
            ]
        )
    ]

    // サンプルのTravelPlanを作成
    let samplePlan = TravelPlan(
        id: UUID().uuidString,
        title: "東京旅行",
        startDate: Date(),
        endDate: Calendar.current.date(byAdding: .day, value: 2, to: Date())!,
        destination: "東京",
        latitude: 35.6762,
        longitude: 139.6503,
        localImageFileName: nil,
        cardColor: nil,
        createdAt: Date(),
        userId: "sample-user-id",
        daySchedules: sampleDaySchedules,
        packingItems: [],
        isShared: true,
        shareCode: "ABC123",
        sharedWith: ["user1", "user2"],
        ownerId: "sample-user-id",
        lastEditedBy: "sample-user-id",
        updatedAt: Date()
    )

    // ViewModelにサンプルプランを追加
    viewModel.travelPlans = [samplePlan]

    return NavigationView {
        TravelPlanDetailView(plan: samplePlan)
            .environmentObject(viewModel)
            .environmentObject(authVM)
    }
}

// MARK: - Native Swipe Back Enabler
// navigationBarHidden(true) で無効化された interactivePopGestureRecognizer を再有効化する
private struct SwipeBackEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ vc: UIViewController, context: Context) {
        DispatchQueue.main.async {
            vc.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
            vc.navigationController?.interactivePopGestureRecognizer?.delegate = nil
        }
    }
}
