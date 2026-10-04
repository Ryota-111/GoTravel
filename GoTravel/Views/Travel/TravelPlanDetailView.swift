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
        // 持ち物・お土産・やりたいことをまとめて出すので「リスト」にした
        case packing = "リスト"
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
    /// 「リスト」タブの中で見ているもの（持ち物／お土産／やりたいこと）
    @State private var selectedListKind: PackingItem.Kind = .packing
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
    /// 横にスクロールする部品の位置。ここで始めた横のドラッグではタブを変えない
    @State private var swipeExclusionZones = SwipeExclusionZones()
    /// 横にスライドして隣のタブへ移るか（アプリ設定で切り替える）。
    /// 便利だと使っている人がいる一方、日程を横になぞって地図へ移ってしまうのが
    /// ストレスだという声も続いたので、選べるようにした。最初はオン（今までどおり）
    @AppStorage(TravelPlanDetailView.tabSwipeKey) private var switchesTabBySwipe = true
    static let tabSwipeKey = "TravelPlanTabSwipeEnabled"

    /// ScrollView の見えている高さ。scrollTo の anchor は割合指定なので必要
    @State private var scrollViewportHeight: CGFloat = 0
    /// 写真が上に隠れたかどうか。
    /// 隠れた後はスクロール中の内容がステータスバーの領域に見えてしまうので、
    /// そこを覆うかどうかの判定に使う
    @State private var isHeaderCollapsed = false
    @State private var showAddScheduleItem = false
    @State private var showBasicInfoEditor = false
    @State private var showDuplicateSheet = false
    @State private var showExportOptions = false
    @State private var exportFormat: ExportOptionsView.Format = .image
    /// 選択シートが閉じるまで書き出したものを持っておく置き場
    @State private var pendingExportItems: [Any]?
    /// 画面の下に短く出す知らせ
    @State private var toastMessage: String?
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
    @State private var navigationTarget: MapDestination?
    /// 目的地の時間帯。予定に「現地」「日本」を添えるのに使う
    @State private var destinationTimeZone: TimeZone?
    /// 「現地時間にそろえますか」の案内を「このままにする」で閉じた計画
    @AppStorage("dismissedLocalTimeBanners") private var dismissedLocalTimeBanners: String = ""
    @State private var editingItem: ScheduleItem?

    // Weather Properties
    /// 日程の各日ぶんの天気。取れなかった日は入らないので、日番号とは対応しない
    @State private var planWeatherDays: [WeatherService.DayWeather] = []
    @State private var isLoadingPlanWeather = false
    /// 座標が空の計画で、目的地から座標を引き直している最中
    @State private var isResolvingDestination = false
    /// 一番上に出すものが多いとき、たたまずに全部出すか
    @State private var showsAllDayPins = false
    /// タイムスケジュールの予定をまとめて削除するための選択
    @State private var isSelectingItems = false
    @State private var selectedItemIDs: Set<String> = []
    @State private var showBulkItemDeleteConfirmation = false
    /// 共有した旅行で、誰の時間軸を見ているか。nil なら全員
    @State private var memberFilter: String?
    /// 出せなかった理由。文言とアイコンは種類ごとに変える
    @State private var planWeatherNote: WeatherNote?
    @State private var weatherAttribution: WeatherService.WeatherAttribution?

    /// 天気が出せないときに1行で出す説明
    private struct WeatherNote {
        let text: String
        let icon: String
    }

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
        let days = Calendar.current.dayDifference(from: plan.startDate, to: plan.endDate)
        return days + 1
    }

    private var backgroundGradient: some View {
        themeManager.currentTheme.backgroundGradient(for: colorScheme)
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

                        // 共有の同期で困ったとき（失敗・解除）だけ出す。
                        // 平常の様子と手動の更新は、共有ボタンから開く画面にある
                        SharedPlanSyncBar(plan: plan)
                            .environmentObject(viewModel)
                            .environmentObject(authVM)
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                            .padding(.bottom, 2)

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
                // オフのときは、このジェスチャだけ止める（中のスクロールや地図の操作はそのまま）
                .simultaneousGesture(tabSwipeGesture, including: switchesTabBySwipe ? .all : .subviews)
                // 引っぱって更新。共有中なら相手の変更を取り込み、天気も取り直す
                .refreshable { await pullToRefresh() }
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
        .overlay(alignment: .bottom) {
            if let toastMessage {
                Text(toastMessage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(ThemePreset.readableText(on: scheduleAccentColor))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(scheduleAccentColor))
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                    .padding(.bottom, 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
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
        // 日数を減らしたとき、選んでいた Day が無くなることがある。
        //
        // `selectedDay` は日タブを押したときしか変わらないので、
        // 4日間の旅行で Day 4 を見ている状態で日程を2日に縮めると、
        // タブは Day 1・2 しか出ないのに中身は Day 4 のまま残っていた。
        // どのタブも選択されていないのに、消したはずの日の予定が並ぶ。
        //
        // 範囲外の日程は消さずに持っている（期間を戻せば復活させるため）ので、
        // 見えている日に寄せ直すのはここの仕事になる
        .onChange(of: tripDuration) { _, days in
            if selectedDay > days { selectedDay = max(days, 1) }
        }
        .fullScreenCover(isPresented: $showAddScheduleItem) {
            AddScheduleItemView(plan: plan, dayNumber: selectedDay)
                .environmentObject(viewModel)
                .environmentObject(authVM)
        }
        .fullScreenCover(isPresented: $showScheduleMap) {
            TravelPlanMapView(
                plan: plan,
                initialDay: selectedDay,
                memberFilter: memberFilter,
                participantLabels: mapParticipantLabels(plan: plan)
            )
        }
        .sheet(isPresented: Binding(
            get: { exportItems != nil },
            set: { if !$0 { exportItems = nil } }
        )) {
            if let exportItems {
                ShareSheet(items: exportItems) { activityType, completed in
                    guard completed else { return }
                    // 「写真に保存」と「コピー」は共有シートが黙って閉じるだけで
                    // うまくいったのか分からない。ここだけ結果を知らせる。
                    // 他のアプリへ送った場合は送り先が反応を返すので何も出さない
                    switch activityType {
                    case .saveToCameraRoll:
                        showToast("写真に保存しました")
                    case .copyToPasteboard:
                        showToast("コピーしました")
                    default:
                        break
                    }
                }
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
        // 選択シートが閉じきってから共有シートを出す。
        // 閉じる前に exportItems を入れると、2枚目のシートが無視されて
        // 何も起きないことがある
        .sheet(isPresented: $showExportOptions, onDismiss: {
            guard let items = pendingExportItems else { return }
            pendingExportItems = nil
            exportItems = items
        }) {
            ExportOptionsView(plan: plan, format: exportFormat, accentColor: scheduleAccentColor) { items in
                pendingExportItems = items
            }
        }
        .sheet(isPresented: $showDuplicateSheet) {
            DuplicateTravelPlanView(plan: plan)
                .environmentObject(viewModel)
                .environmentObject(authVM)
        }
        .sheet(isPresented: $showBudgetSummary) {
            if let currentPlan = currentPlan {
                BudgetSummaryView(plan: currentPlan)
                    .environmentObject(viewModel)
                    .environmentObject(authVM)
            }
        }
        .mapNavigation($navigationTarget)
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
        .task(id: currentPlan?.id) {
            await refreshSharedPlanIfNeeded()
            await fillMissingDestinationCoordinate()
            if let plan = currentPlan {
                destinationTimeZone = await DestinationTimeZoneService.shared.timeZone(for: plan)
            }
        }
        // 目的地や日程を編集したら天気を取り直す。
        // 以前は最初に表示したときにしか取らず、編集で目的地を直しても
        // 画面を開き直すまで天気が出なかった
        .onChange(of: weatherRequestKey) { _, _ in
            fetchPlanWeather()
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

    /// タイムラインの1行の状態。
    /// 過ぎた・次の1件・これから、の3つは**その日が今日のときだけ**意味を持つ。
    /// 明日の日程を開いているときに「次の1件」を光らせると嘘になるので、
    /// 今日以外は全部 `flat` にする
    private enum TimelineRowState {
        case past, now, future, flat
    }

    /// 次に控えている1件の位置。今日でなければ nil
    private func nextItemIndex(in items: [ScheduleItem], dayDate: Date) -> Int? {
        guard Calendar.current.isDateInToday(dayDate) else { return nil }

        let now = Date()

        // 項目の時刻は日付を持たないため、時刻だけで比べる。
        // **予定ごとの時計で比べる。** パリの予定をパリの今と比べないと、
        // 日本時間の今と比べて「次の1件」が8時間ずれる
        return items.firstIndex {
            $0.minutesOfDay >= ScheduleClock.minutesOfDay(now, in: $0.timeZone)
        }
    }

    private func rowState(index: Int, nowIndex: Int?) -> TimelineRowState {
        guard let nowIndex else { return .flat }
        if index < nowIndex { return .past }
        if index == nowIndex { return .now }
        return .future
    }

    private func timelineItemView(item: ScheduleItem, isLast: Bool, plan: TravelPlan, state: TimelineRowState) -> some View {
        HStack(alignment: .top, spacing: 0) {
            // 時刻は塗りつぶさず、等幅で右に揃える。
            // カプセルで塗ると1行ごとに色の面ができて、レールが読めなくなる
            VStack(alignment: .trailing, spacing: 1) {
                Text(item.timeText)
                    .font(.system(size: 13, weight: .bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                // 終わりの時刻があれば、始まりの下に小さく添える（次の予定までの間が分かる）
                if let endText = item.endTimeText {
                    Text("〜\(endText)")
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .opacity(0.75)
                }

                // 見ている人の時計と違う予定だけ、どこの時刻かを添える
                if let zoneLabel = item.zoneLabel(destination: destinationTimeZone) {
                    Text(zoneLabel)
                        .font(.system(size: 9, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .foregroundColor(state == .past
                             ? themeManager.currentTheme.secondaryText.opacity(0.6)
                             : themeManager.currentTheme.secondaryText)
            .frame(width: 46, alignment: .trailing)
            .padding(.top, 1)

            // レール。点と点をつなぎ、過ぎた区間だけ色が入る
            VStack(spacing: 0) {
                timelineDot(state: state)

                if !isLast {
                    Rectangle()
                        .fill(state == .past
                              ? scheduleAccentColor.opacity(0.4)
                              : themeManager.currentTheme.secondaryText.opacity(0.18))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 12)
            .padding(.leading, 10)
            .padding(.trailing, 16)
            .padding(.top, 3)

            // 次に控えている1件だけ面を起こして、タイムラインの視点にする
            HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.system(size: 16, weight: state == .now ? .bold : .semibold))
                    .foregroundColor(state == .past ? themeManager.currentTheme.secondaryText : accentColor)

                // 全員の時間軸を見ているときだけ、全員のものでない予定に参加する人を添える
                if memberFilter == nil, let label = participantLabel(item, plan: plan) {
                    Label(label, systemImage: "person.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(scheduleAccentColor)
                        .lineLimit(1)
                }

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
                            Button(action: {
                                if let lat = item.latitude, let lng = item.longitude {
                                    navigationTarget = MapDestination(
                                        name: item.location ?? item.title,
                                        coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng)
                                    )
                                }
                            }) {
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
                if (item.cost ?? 0) > 0 || item.actualCost != nil || item.costNote != nil {
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

                        if let costNote = item.costNote {
                            Text(costNote)
                                .font(.system(size: 12))
                                .foregroundColor(themeManager.currentTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                // メモは全部の行を出す。駐車場や集合場所のように、何行かに分けて
                // 書いた情報を現地で見るため（2行で切っていたら続きが見えなかった）
                if let notes = item.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.system(size: 12))
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // 入力できるのに表示先が無く、開く手段がなかったため追加
                if let linkURL = item.linkURL {
                    LinkChip(rawURL: linkURL, tint: themeManager.currentTheme.info)
                }
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)

            // 編集・削除メニュー。選択中はチェックに替える
            if isSelectingItems {
                let isSelected = selectedItemIDs.contains(item.id)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected
                                     ? themeManager.currentTheme.error
                                     : themeManager.currentTheme.secondaryText.opacity(0.5))
                    .padding(.top, 13)
                    .accessibilityLabel(isSelected ? "選択中" : "未選択")
            } else {
            Menu {
                Button {
                    editingItem = item
                } label: {
                    Label("編集", systemImage: "pencil")
                }
                // その日ずっと気にしたい予定（集合場所など）を、時刻の並びから外して上に出す
                Button {
                    togglePin(item, in: plan)
                } label: {
                    Label("一番上に固定", systemImage: "pin")
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
            }
            .padding(.horizontal, state == .now ? 12 : 0)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(state == .now ? AnyShapeStyle(timelineCardSurface) : AnyShapeStyle(Color.clear))
                    .shadow(
                        color: state == .now && colorScheme != .dark ? Color.black.opacity(0.08) : .clear,
                        radius: 13,
                        x: 0,
                        y: 5
                    )
            )
        }
        .padding(.horizontal, 4)
    }

    // MARK: - メンバーごとの時間軸

    private func participantLabel(_ item: ScheduleItem, plan: TravelPlan) -> String? {
        SharedMembers.participantLabel(
            of: item,
            names: viewModel.memberNames(for: plan.id),
            members: plan.sharedWith,
            myUserId: authVM.userId
        )
    }

    /// 「全員 / 自分 / 〇〇」。共有していて2人以上のときだけ出す
    @ViewBuilder
    private func memberFilterBar(plan: TravelPlan) -> some View {
        if plan.isShared && plan.sharedWith.count >= 2 {
            let names = viewModel.memberNames(for: plan.id)
            let me = authVM.userId
            // 自分を「全員」の次に置く。見る場面がいちばん多いため
            let others = plan.sharedWith.filter { $0 != me }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    memberChip("全員", isSelected: memberFilter == nil) { memberFilter = nil }
                    if let me, plan.sharedWith.contains(me) {
                        memberChip("自分", isSelected: memberFilter == me) { memberFilter = me }
                    }
                    ForEach(others, id: \.self) { member in
                        let name = SharedMembers.displayName(of: member, names: names,
                                                             members: plan.sharedWith, myUserId: me)
                        memberChip(name, isSelected: memberFilter == member) { memberFilter = member }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private func memberChip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                action()
                selectedItemIDs = []
            }
        } label: {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : scheduleAccentColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(isSelected ? scheduleAccentColor : scheduleAccentColor.opacity(0.1)))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - まとめて削除

    private func toggleItemSelection(_ item: ScheduleItem) {
        if selectedItemIDs.contains(item.id) {
            selectedItemIDs.remove(item.id)
        } else {
            selectedItemIDs.insert(item.id)
        }
    }

    /// 選んでいて、いま表示している日の予定
    private func selectedVisibleItems(plan: TravelPlan) -> [ScheduleItem] {
        plan.timelineScheduleItems(onDay: selectedDay, for: memberFilter).filter { selectedItemIDs.contains($0.id) }
    }

    private func bulkItemActionBar(plan: TravelPlan) -> some View {
        let items = plan.timelineScheduleItems(onDay: selectedDay, for: memberFilter)
        let selectedCount = selectedVisibleItems(plan: plan).count
        let allSelected = !items.isEmpty && selectedCount == items.count

        return HStack {
            Button(allSelected ? "選択を解除" : "すべて選択") {
                selectedItemIDs = allSelected ? [] : Set(items.map(\.id))
            }
            .font(.subheadline)
            .foregroundColor(scheduleAccentColor)

            Spacer()

            Button {
                showBulkItemDeleteConfirmation = true
            } label: {
                Label(selectedCount == 0 ? "削除" : "\(selectedCount)件を削除", systemImage: "trash")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundColor(selectedCount == 0
                             ? themeManager.currentTheme.secondaryText.opacity(0.5)
                             : themeManager.currentTheme.error)
            .disabled(selectedCount == 0)
        }
        .padding(.horizontal, 4)
        .alert("\(selectedCount)件の予定を削除しますか？", isPresented: $showBulkItemDeleteConfirmation) {
            Button("削除", role: .destructive) { deleteSelectedItems(plan: plan) }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("Day \(selectedDay) のタイムスケジュールから削除します。")
        }
    }

    private func deleteSelectedItems(plan: TravelPlan) {
        guard let userId = authVM.userId else { return }
        let ids = Set(selectedVisibleItems(plan: plan).map(\.id))
        var updatedPlan = plan
        if let dayIndex = updatedPlan.daySchedules.firstIndex(where: { $0.dayNumber == selectedDay }) {
            updatedPlan.daySchedules[dayIndex].scheduleItems.removeAll { ids.contains($0.id) }
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            viewModel.update(updatedPlan, userId: userId)
            selectedItemIDs = []
            isSelectingItems = false
        }
        showToast("\(ids.count)件の予定を削除しました")
    }

    // MARK: - その日の一番上に出すもの

    /// 一番上に出すのは、この件数まで。増えると予定が画面の下に押し出される
    private static let visibleDayPinLimit = 3

    private enum DayPin: Identifiable {
        case reservation(ReservationOnDay)
        case item(ScheduleItem)

        var id: String {
            switch self {
            case .reservation(let entry): return "reservation-\(entry.id)"
            case .item(let item): return "item-\(item.id)"
            }
        }
    }

    /// 期間のある予約（宿・レンタカーなど）→ 固定した予定 の順
    private func dayPins(plan: TravelPlan) -> [DayPin] {
        plan.pinnedReservations(onDay: selectedDay).map(DayPin.reservation)
            + plan.pinnedScheduleItems(onDay: selectedDay, for: memberFilter).map(DayPin.item)
    }

    @ViewBuilder
    private func dayPinsSection(plan: TravelPlan) -> some View {
        let pins = dayPins(plan: plan)
        let visible = showsAllDayPins ? pins : Array(pins.prefix(Self.visibleDayPinLimit))

        if !pins.isEmpty {
            VStack(spacing: 6) {
                ForEach(visible) { pin in
                    switch pin {
                    case .reservation(let entry):
                        dayPinRow(icon: entry.icon, title: entry.name, detail: entry.detail) {
                            // 予約番号を確かめる場面が多いので、予約確認へ移る
                            withAnimation(.easeInOut(duration: 0.2)) { selectedTab = .reservation }
                        }
                    case .item(let item):
                        dayPinRow(icon: "pin.fill", title: item.title, detail: pinnedItemDetail(item)) {
                            editingItem = item
                        }
                        .contextMenu {
                            Button {
                                togglePin(item, in: plan)
                            } label: {
                                Label("固定を外す", systemImage: "pin.slash")
                            }
                        }
                    }
                }

                if pins.count > Self.visibleDayPinLimit {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showsAllDayPins.toggle() }
                    } label: {
                        Text(showsAllDayPins ? "たたむ" : "ほか\(pins.count - Self.visibleDayPinLimit)件")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(scheduleAccentColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// 固定した予定の添え書き。時刻と場所
    private func pinnedItemDetail(_ item: ScheduleItem) -> String {
        [item.timeRangeText, item.location]
            .compactMap { $0?.isEmpty == false ? $0 : nil }
            .joined(separator: "・")
    }

    private func dayPinRow(icon: String, title: String, detail: String,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(scheduleAccentColor)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(accentColor)
                        .lineLimit(1)
                    if !detail.isEmpty {
                        Text(detail)
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.secondaryText)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.secondaryText.opacity(0.6))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(scheduleAccentColor.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title)、\(detail)")
    }

    /// 予定を一番上に固定する・外す
    private func togglePin(_ item: ScheduleItem, in plan: TravelPlan) {
        guard let userId = authVM.userId else { return }
        var updatedPlan = plan
        for dayIndex in updatedPlan.daySchedules.indices {
            if let itemIndex = updatedPlan.daySchedules[dayIndex].scheduleItems.firstIndex(where: { $0.id == item.id }) {
                let pinned = updatedPlan.daySchedules[dayIndex].scheduleItems[itemIndex].isPinned == true
                // 外すときは nil に戻す。false を入れると、固定したことの無い予定と見分けが要らない差分が出る
                updatedPlan.daySchedules[dayIndex].scheduleItems[itemIndex].isPinned = pinned ? nil : true
            }
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            viewModel.update(updatedPlan, userId: userId)
        }
    }

    /// レールの点。過ぎた分は塗り、次の1件は光らせ、これからは中を抜く
    @ViewBuilder
    private func timelineDot(state: TimelineRowState) -> some View {
        switch state {
        case .now:
            Circle()
                .fill(scheduleAccentColor)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(scheduleAccentColor.opacity(0.16), lineWidth: 5)
                )
        case .past:
            Circle()
                .fill(scheduleAccentColor.opacity(0.55))
                .frame(width: 12, height: 12)
        case .future, .flat:
            Circle()
                .fill(timelineCardSurface)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .strokeBorder(
                            state == .flat
                                ? scheduleAccentColor.opacity(0.55)
                                : themeManager.currentTheme.secondaryText.opacity(0.65),
                            lineWidth: 2.5
                        )
                )
        }
    }

    private var timelineCardSurface: Color {
        colorScheme == .dark
            ? themeManager.currentTheme.secondaryBackgroundDark
            : themeManager.currentTheme.backgroundLight
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

                Text(tripDateRange(plan: plan))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .shadow(color: .black.opacity(0.45), radius: 4, x: 0, y: 1)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            // 右下の円と重ならないところで折り返す
            .padding(.trailing, tripCountdown(plan: plan) == nil ? 0 : 120)

            // 開くたびに「いま知りたいこと」が目に入るようにする
            countdownTicket(plan: plan)

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
                            exportFormat = .text
                            showExportOptions = true
                        } label: {
                            Label("テキストで送る", systemImage: "doc.plaintext")
                        }

                        Button {
                            exportFormat = .image
                            showExportOptions = true
                        } label: {
                            Label("画像で送る", systemImage: "photo")
                        }

                        Divider()

                        // 前回の行程を土台に次の旅行を作りたい、という要望から
                        Button {
                            showDuplicateSheet = true
                        } label: {
                            Label("この計画を複製", systemImage: "doc.on.doc")
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
                        // 同期の様子は、写真の下の行ではなくここに小さく出す
                        .overlay(alignment: .topTrailing) {
                            shareSyncBadge(plan: plan)
                        }
                    }
                    .accessibilityLabel(shareButtonAccessibilityLabel(plan: plan))
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

                // その日の予定があるときだけ出す
                if !plan.timelineScheduleItems(onDay: selectedDay, for: memberFilter).isEmpty || isSelectingItems {
                    Button(isSelectingItems ? "完了" : "選択") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isSelectingItems.toggle()
                            selectedItemIDs = []
                        }
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(scheduleAccentColor)
                    .padding(.trailing, 4)
                }

                if !isSelectingItems {
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
            }

            if isSelectingItems {
                bulkItemActionBar(plan: plan)
            }

            if shouldShowLocalTimeBanner(plan), let zone = destinationTimeZone {
                localTimeBanner(plan: plan, zone: zone)
            }

            excludedFromTabSwipe("dayTabs") {
                dayTabs(plan: plan)
            }

            // 共有中は、誰の時間軸を見るか選べる（出発地の違うメンバーが現地で集まる旅行のため）
            excludedFromTabSwipe("memberFilter-\(selectedTab.rawValue)") {
                memberFilterBar(plan: plan)
            }

            // その日に泊まっている宿や、固定した予定。予定より先に目に入るよう一番上に出す
            dayPinsSection(plan: plan)

            // スケジュールアイテムリスト（固定した予定は上に出しているので除く）
            let sortedItems = plan.timelineScheduleItems(onDay: selectedDay, for: memberFilter)
            if let daySchedule = plan.daySchedules.first(where: { $0.dayNumber == selectedDay }),
               !sortedItems.isEmpty {
                let nowIndex = nextItemIndex(in: sortedItems, dayDate: daySchedule.date)
                VStack(spacing: 0) {
                    ForEach(Array(sortedItems.enumerated()), id: \.element.id) { index, item in
                        timelineItemView(
                            item: item,
                            isLast: index == sortedItems.count - 1,
                            plan: plan,
                            state: rowState(index: index, nowIndex: nowIndex)
                        )
                        // 選択中は、行の中のボタン（案内・リンクなど）を止めて、どこを押しても選べるようにする
                        .allowsHitTesting(!isSelectingItems)
                        .overlay {
                            if isSelectingItems {
                                Color.clear
                                    .contentShape(Rectangle())
                                    .onTapGesture { toggleItemSelection(item) }
                            }
                        }
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
                // 天気や Day タブ、メンバーの切り替えなど、横にスクロールする部品の上でも動かさない。
                // 以前は日数の多い旅行で天気を横に送ると、地図タブへ移ってしまっていた
                guard !swipeExclusionZones.contains(value.startLocation) else { return }

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

    /// 横にスクロールする部品を、タブ切り替えのスワイプの対象から外す。
    /// 位置は縦のスクロールでも変わるので、見えている間は追いかけて覚えておく
    private func excludedFromTabSwipe<Content: View>(_ id: String,
                                                     @ViewBuilder _ content: () -> Content) -> some View {
        content()
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .global)
            } action: { frame in
                swipeExclusionZones.frames[id] = frame
            }
            .onDisappear {
                swipeExclusionZones.frames[id] = nil
            }
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

            excludedFromTabSwipe("tabButtons") {
                tabButtons
            }
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
                        let dayDate = plan.date(forDay: day)

                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedDay = day
                            }
                        }) {
                            VStack(spacing: 4) {
                                Text("Day \(day)")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(isSelected ? .white : accentColor)

                                Text(formatDate(dayDate))
                                    .font(.system(size: 10))
                                    .foregroundColor(isSelected ? .white.opacity(0.8) : themeManager.currentTheme.secondaryText)

                                // 0件のときに行ごと消すと、その日のタブだけ低くなって
                                // 帯がでこぼこになる。予定が無いことも情報なので出す
                                Text("\(itemCount)件")
                                    .font(.system(size: 10, weight: .medium))
                                    .monospacedDigit()
                                    .foregroundColor(dayTabCountColor(itemCount: itemCount, isSelected: isSelected))
                            }
                            .padding(.horizontal, 12)
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

    /// 予定が無い日の件数は弱める。出しはするが、目を引く必要はない
    private func dayTabCountColor(itemCount: Int, isSelected: Bool) -> Color {
        if isSelected {
            return .white.opacity(itemCount > 0 ? 0.8 : 0.5)
        }
        return itemCount > 0
            ? scheduleAccentColor
            : themeManager.currentTheme.secondaryText.opacity(0.5)
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
                linkedItemID: $focusedItemID,
                memberFilter: memberFilter,
                participantLabels: mapParticipantLabels(plan: plan)
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
        VStack(spacing: 0) {
            // 日程タブと同じ切り替え。上の地図と下の行程表の両方がこれに従う
            excludedFromTabSwipe("memberFilter-\(selectedTab.rawValue)") {
                memberFilterBar(plan: plan)
            }
                .padding(.horizontal, 16)
                .padding(.top, 12)

            mapTabItinerary(plan: plan)
        }
    }

    /// 予定ID → 参加する人の名前（全員のものでない予定だけ）。地図のピンに添える
    private func mapParticipantLabels(plan: TravelPlan) -> [String: String] {
        var labels: [String: String] = [:]
        for item in plan.daySchedules.flatMap(\.scheduleItems) {
            if let label = participantLabel(item, plan: plan) {
                labels[item.id] = label
            }
        }
        return labels
    }

    private func mapTabItinerary(plan: TravelPlan) -> some View {
        Group {
            let dayItems = plan.daySchedules.first(where: { $0.dayNumber == selectedDay })?.scheduleItems ?? []
            let visibleItems = dayItems.filter { SharedMembers.includes($0, member: memberFilter) }
            if let daySchedule = plan.daySchedules.first(where: { $0.dayNumber == selectedDay }),
               !visibleItems.isEmpty {
                let sortedItems = sortedScheduleItems(visibleItems)
                let nowIndex = nextItemIndex(in: sortedItems, dayDate: daySchedule.date)
                VStack(spacing: 0) {
                    ForEach(Array(sortedItems.enumerated()), id: \.element.id) { index, item in
                        timelineItemView(
                            item: item,
                            isLast: index == sortedItems.count - 1,
                            plan: plan,
                            state: rowState(index: index, nowIndex: nowIndex)
                        )
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
                    let dayDate = plan.date(forDay: day)

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedDay = day
                            focusedItemID = nil
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text("Day \(day)")
                                .font(.system(size: 13, weight: .bold))
                            Text(formatDate(dayDate))
                                .font(.system(size: 11))
                                .opacity(0.8)
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
        VStack(spacing: 14) {
            // 持ち物・お土産・やりたいことは、どれも「名前とチェック」で形が同じ。
            // 上のタブを3つ増やすと窮屈になるので、ここで切り替える
            Picker("リストの種類", selection: $selectedListKind) {
                ForEach(PackingItem.Kind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.segmented)

            PackingListView(plan: plan, kind: selectedListKind)
                .environmentObject(viewModel)
                .environmentObject(authVM)
        }
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
                if isResolvingDestination {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("目的地の位置を確認しています…")
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.secondaryText)
                    }
                } else {
                    // 「その場所に天気が無い」のではなく「位置が分からない」。
                    // 以前は天気が無い場所と同じ文言で、利用者には直しようが無かった
                    Button { showBasicInfoEditor = true } label: {
                        weatherNote("目的地「\(plan.destination)」の位置が分からないため、天気を表示できません。タップして目的地を入れ直してください",
                                    icon: "mappin.slash")
                    }
                    .buttonStyle(.plain)
                }
            } else if isLoadingPlanWeather {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("天気を確認しています…")
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                }
            } else if let note = planWeatherNote {
                weatherNote(note.text, icon: note.icon)
            } else if plan.dayCount == 1, let weather = planWeatherDays.first {
                // 1日だけの旅行に「1日目」と付けても意味がないので、今までどおり1行で出す
                weatherSummary(weather)
            } else if !planWeatherDays.isEmpty {
                tripWeatherRow(plan: plan)
            }
        }
    }

    /// 日程ぶんの天気を横に並べる。
    ///
    /// 開始日1日ぶんしか出していなかったため、旅行中は何日目にいても
    /// 初日の予報を見せられていた（しかも過去日なので取得に失敗していた）
    private func tripWeatherRow(plan: TravelPlan) -> some View {
        excludedFromTabSwipe("weather") {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(1...plan.dayCount, id: \.self) { dayNumber in
                    let date = plan.date(forDay: dayNumber)
                    if let weather = weather(forDay: date) {
                        weatherDayCell(dayNumber: dayNumber, date: date, weather: weather)
                    }
                }
            }
        }
        }
    }

    /// その日の予報。取れていない日は nil（10日より先など）
    private func weather(forDay date: Date) -> WeatherService.DayWeather? {
        planWeatherDays.first {
            Calendar.current.isDate($0.date, inSameDayAs: date)
        }
    }

    private func weatherDayCell(dayNumber: Int, date: Date, weather: WeatherService.DayWeather) -> some View {
        let isToday = Calendar.current.isDateInToday(date)

        // 日付と気温・降水をそれぞれ1行にまとめて、3行に畳んでいる。
        // 5行（日番号・日付・アイコン・気温・降水）だと縦を取りすぎる
        return VStack(spacing: 3) {
            HStack(spacing: 4) {
                Text("\(dayNumber)日目")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(isToday ? scheduleAccentColor : themeManager.currentTheme.secondaryText)

                Text(DateFormatter.japaneseMonthDayCompact.string(from: date))
                    .font(.system(size: 10))
                    .foregroundColor(themeManager.currentTheme.secondaryText)
            }

            Image(systemName: weather.symbolName)
                .resizable()
                .scaledToFit()
                .foregroundColor(scheduleAccentColor)
                .frame(width: 26, height: 20)

            HStack(spacing: 4) {
                Text("\(Int(weather.highTemperature))°")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(accentColor)
                Text("\(Int(weather.lowTemperature))°")
                    .font(.system(size: 11))
                    .foregroundColor(themeManager.currentTheme.secondaryText)

                HStack(spacing: 1) {
                    Image(systemName: "umbrella.fill")
                        .font(.system(size: 8))
                    Text(weather.precipitationText)
                        .font(.system(size: 10))
                }
                .foregroundColor(themeManager.currentTheme.secondaryText)
            }
            // 気温と降水を1行に詰めたので、セルの最小幅より広くなる日がある。
            // 理想幅を確保しないと、末尾の降水確率が「…」に潰れる
            .fixedSize(horizontal: true, vertical: false)
        }
        .frame(minWidth: 76)
        .padding(.vertical, 6)
        .padding(.horizontal, 7)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                // 今日の1枚だけ薄く敷いて、何日目にいるか分かるようにする
                .fill(isToday ? scheduleAccentColor.opacity(colorScheme == .dark ? 0.20 : 0.10) : Color.clear)
        )
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

    // MARK: - Helper Methods

    /// 画面の下に短く出して自動で消す。
    /// 保存できたことを伝えるだけなので、閉じる操作は要らない
    private func showToast(_ message: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            toastMessage = message
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeInOut(duration: 0.25)) {
                if toastMessage == message { toastMessage = nil }
            }
        }
    }
    /// 地図に出せる（座標を持つ）スケジュール項目が1件でもあるか
    // MARK: - 現地時間にそろえる案内
    //
    // 2.7 より前は予定が時間帯を持てず、海外旅行でも日本時間として入っている。
    // 「現地の 15:00」のつもりで入れた予定は、現地に着くと 8:00 などと出てしまう。
    // 必要なのは既存の海外旅行を持つ人で、その人は直せることを知らないので、
    // メニューの奥ではなくタイムラインの上で聞く

    /// 現地時間にそろえられる予定の数。目的地が日本と時差の無い場所なら 0
    private func localTimeConversionCount(_ plan: TravelPlan) -> Int {
        guard let zone = destinationTimeZone,
              ScheduleClock.isForeign(zone, at: plan.startDate) else { return 0 }
        return plan.scheduleItemCount(notIn: zone)
    }

    private func shouldShowLocalTimeBanner(_ plan: TravelPlan) -> Bool {
        guard let planId = plan.id else { return false }
        return !dismissedLocalTimeBannerIDs.contains(planId) && localTimeConversionCount(plan) > 0
    }

    private var dismissedLocalTimeBannerIDs: Set<String> {
        Set(dismissedLocalTimeBanners.split(separator: ",").map(String.init))
    }

    private func dismissLocalTimeBanner(_ plan: TravelPlan) {
        guard let planId = plan.id else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            dismissedLocalTimeBanners = dismissedLocalTimeBannerIDs.union([planId]).sorted().joined(separator: ",")
        }
    }

    private func localTimeBanner(plan: TravelPlan, zone: TimeZone) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "globe.asia.australia.fill")
                    .font(.system(size: 18))
                    .foregroundColor(scheduleAccentColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text("予定が日本時間で入っています")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(accentColor)
                    Text("現地（\(ScheduleClock.displayName(of: zone))）の時刻として扱いますか？時刻の数字はそのままです。")
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                Button {
                    convertToLocalTime()
                } label: {
                    Text("現地時間にそろえる")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(scheduleAccentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())

                Button {
                    dismissLocalTimeBanner(plan)
                } label: {
                    Text("このままにする")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(scheduleAccentColor.opacity(0.12))
                        .foregroundColor(scheduleAccentColor)
                        .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(scheduleAccentColor.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(scheduleAccentColor.opacity(0.25), lineWidth: 1)
        )
        .transition(.opacity)
    }

    private func convertToLocalTime() {
        guard let plan = currentPlan,
              let zone = destinationTimeZone,
              let userId = authVM.userId else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            viewModel.update(plan.withScheduleTimes(keptIn: zone), userId: userId)
        }
        showToast("現地時間にそろえました")
    }

    /// 起きる順に並べる。時間帯が違う予定が混ざっていても、実際の順になる
    private func sortedScheduleItems(_ items: [ScheduleItem]) -> [ScheduleItem] {
        items.sorted(by: ScheduleItem.chronologically)
    }

    private func formatBudgetAmount(plan: TravelPlan) -> String {
        let total = plan.totalPlannedCost

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0

        return "¥\(formatter.string(from: NSNumber(value: total)) ?? "0")"
    }

    private func formatTotalCost(plan: TravelPlan) -> String {
        let total = plan.totalPlannedCost

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
    private func tripCountdown(plan: TravelPlan) -> (caption: String, value: String)? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.startOfDay(for: plan.startDate)
        let end = calendar.startOfDay(for: plan.endDate)

        if today < start {
            let days = calendar.dayDifference(from: today, to: start)
            return ("旅行まで", days == 1 ? "明日" : "\(days)日")
        }
        if today <= end {
            let elapsed = calendar.dayDifference(from: start, to: today)
            return ("旅行中", "Day \(elapsed + 1)")
        }
        return nil
    }

    /// 写真の右下に置く残り日数。半券に見立てている。
    /// 明るい写真でも読めるよう、線だけでなくすりガラスで塗る
    @ViewBuilder
    private func countdownTicket(plan: TravelPlan) -> some View {
        if let countdown = tripCountdown(plan: plan) {
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    Text(countdown.caption)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))

                    Text(countdown.value)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                .frame(maxWidth: .infinity)

                Image(systemName: "airplane")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                    .rotationEffect(.degrees(-45))
                    .frame(width: Self.ticketStubWidth)
            }
            .padding(.vertical, 7)
            .frame(width: 100, height: 52)
            // 塗りは置かない。写真をそのまま見せる代わりに、
            // 枠と文字の影だけで明るい写真から浮かせる
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.5), lineWidth: 1)
            )
            // ミシン目。破線を引くより、粒を並べたほうが端の切れ方が揃う
            .overlay(alignment: .trailing) {
                VStack(spacing: 3) {
                    ForEach(0..<5, id: \.self) { _ in
                        Capsule()
                            .fill(Color.white.opacity(0.5))
                            .frame(width: 1, height: 4)
                    }
                }
                .padding(.trailing, Self.ticketStubWidth - 0.5)
            }
            .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 2)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(.trailing, 20)
            .padding(.bottom, 20)
        }
    }

    private static let ticketStubWidth: CGFloat = 22

    private func formatTripDuration() -> String {
        if tripDuration == 1 {
            return "1日"
        } else {
            return "\(tripDuration)日間"
        }
    }

    // MARK: - Weather Fetching
    // MARK: - 共有の同期

    /// 開いたときに、共有の相手の変更を取り込む。
    /// 以前は同期の行が受け持っていたが、行を普段出さなくしたのでここへ移した
    private func refreshSharedPlanIfNeeded() async {
        guard let plan = currentPlan, plan.isShared,
              let planId = plan.id, let userId = authVM.userId else { return }
        await viewModel.refreshSharedPlan(planId: planId, userId: userId)
    }

    private func syncState(of plan: TravelPlan) -> TravelPlanViewModel.SyncState? {
        plan.id.flatMap { viewModel.syncStates[$0] }
    }

    /// 共有ボタンの右上の印。同期中はぐるぐる、失敗したら赤い点。平常は何も付けない
    @ViewBuilder
    private func shareSyncBadge(plan: TravelPlan) -> some View {
        if plan.isShared {
            switch syncState(of: plan) {
            case .syncing:
                ProgressView()
                    .controlSize(.mini)
                    .tint(.white)
                    .frame(width: 16, height: 16)
                    .background(Circle().fill(.black.opacity(0.35)))
                    .offset(x: 3, y: -3)
            case .failed:
                Circle()
                    .fill(themeManager.currentTheme.error)
                    .frame(width: 11, height: 11)
                    .overlay(Circle().stroke(.white, lineWidth: 1.5))
                    .offset(x: 1, y: -1)
            default:
                EmptyView()
            }
        }
    }

    private func shareButtonAccessibilityLabel(plan: TravelPlan) -> String {
        guard plan.isShared else { return "共有" }
        switch syncState(of: plan) {
        case .syncing: return "共有中。更新しています"
        case .failed: return "共有中。更新できませんでした"
        default: return "共有中"
        }
    }

    /// 引っぱって更新。共有中なら相手の変更を取り込み、天気も取り直す
    private func pullToRefresh() async {
        await refreshSharedPlanIfNeeded()
        fetchPlanWeather()
    }

    /// 天気を取り直すきっかけ。目的地の座標か日程が変わったら変わる
    private var weatherRequestKey: String {
        guard let plan = currentPlan else { return "" }
        return "\(plan.latitude ?? .nan),\(plan.longitude ?? .nan),\(plan.startDate.timeIntervalSince1970),\(plan.endDate.timeIntervalSince1970)"
    }

    /// 座標が空のまま保存された計画を、目的地の文字から補う。
    ///
    /// 保存が座標の検索を待っていなかったため、「沖縄」と入れても
    /// 座標が空の計画ができていた。利用者が何もしなくても直るよう、開いたときに引き直す
    private func fillMissingDestinationCoordinate() async {
        guard let plan = currentPlan,
              plan.latitude == nil || plan.longitude == nil,
              let userId = authVM.userId else { return }
        let query = plan.destination.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        isResolvingDestination = true
        defer { isResolvingDestination = false }

        guard let coordinate = await DestinationGeocoder.coordinate(for: query, debounce: 0),
              var latest = currentPlan,
              latest.latitude == nil || latest.longitude == nil else { return }

        latest.latitude = coordinate.latitude
        latest.longitude = coordinate.longitude
        viewModel.update(latest, userId: userId)
    }

    private func fetchPlanWeather() {
        guard #available(iOS 16.0, *) else {
            return
        }

        guard let plan = currentPlan else {
            return
        }

        guard let latitude = plan.latitude,
              let longitude = plan.longitude else {
            planWeatherDays = []
            isLoadingPlanWeather = false
            planWeatherNote = nil
            weatherAttribution = nil
            return
        }

        isLoadingPlanWeather = true
        planWeatherNote = nil

        Task { @MainActor in
            // WeatherKitの準備が完了するまで少し待機
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒

            do {
                // 日程ぶんまとめて取る。1日ずつ問い合わせると同じ予報を人数分叩くうえ、
                // 開始日だけを見ていた頃は旅行が始まった瞬間に「過去の日付」になって落ちていた
                let fetchedDays = try await WeatherService.shared.fetchWeatherForTrip(
                    latitude: latitude,
                    longitude: longitude,
                    startDate: plan.startDate,
                    endDate: plan.endDate
                )

                // Fetch attribution
                let fetchedAttribution = try await WeatherService.shared.getWeatherAttribution()

                self.planWeatherDays = fetchedDays
                self.weatherAttribution = fetchedAttribution
                self.planWeatherNote = fetchedDays.isEmpty
                    ? WeatherNote(text: Self.notYetAvailableText, icon: "calendar")
                    : nil
                self.isLoadingPlanWeather = false
            } catch {
                self.planWeatherDays = []
                // 失敗の中身は WeatherService がログに残す（category: weather）
                self.planWeatherNote = Self.note(for: error)
                self.isLoadingPlanWeather = false
            }
        }
    }

    /// 失敗の理由をそのまま出す。
    ///
    /// 天気が見られるようになる日の案内。予報の範囲に合わせる（以前は1日ずれて「10日前」と出ていた）
    private static var notYetAvailableText: String {
        "出発の\(WeatherService.availableDaysBefore)日前になると天気が表示されます"
    }

    /// 以前はどんな失敗でも「10日前になると天気が表示されます」と出していたため、
    /// 通信断も認証エラーも日付が先すぎるように読めていた
    private static func note(for error: Error) -> WeatherNote {
        guard let weatherError = error as? WeatherError else {
            return WeatherNote(text: error.localizedDescription, icon: "exclamationmark.icloud")
        }

        switch weatherError {
        case .dateTooFarInFuture:
            return WeatherNote(text: Self.notYetAvailableText, icon: "calendar")
        case .networkError:
            return WeatherNote(text: "通信できないため天気を取得できませんでした", icon: "wifi.slash")
        case .locationNotAvailable, .invalidCoordinates:
            return WeatherNote(text: "設定された場所には天気の情報がありませんでした", icon: "exclamationmark.icloud")
        default:
            return WeatherNote(text: "天気を取得できませんでした", icon: "exclamationmark.icloud")
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
    .navigationViewStyle(.stack)
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

/// タブ切り替えのスワイプから外す範囲。
///
/// 縦のスクロールのたびに位置が変わるので、`@State` の値で持つと画面全体を
/// そのたびに描き直してしまう。参照型に入れて、書き換えても描き直さないようにする
private final class SwipeExclusionZones {
    var frames: [String: CGRect] = [:]

    func contains(_ point: CGPoint) -> Bool {
        frames.values.contains { $0.contains(point) }
    }
}
