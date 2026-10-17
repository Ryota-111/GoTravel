import SwiftUI

// MARK: - Calendar Timeline Item Model
struct CalendarTimelineItem: Identifiable {
    /// 行の目印。**予定の種類と予定の id から決まる、変わらない値にする。**
    ///
    /// 以前は `UUID()` で、一覧を作り直すたびに別の行になっていた。旅行計画を開いた直後に
    /// 計画が保存し直される（目的地の座標を引き直す・共有を最新にする）と、裏のカレンダーの
    /// 一覧が作り直され、開いた行が消えたとみなされて詳細画面が勝手に閉じていた
    var id: String {
        let typeKey: String
        switch type {
        case .dailyPlan: typeKey = "daily"
        case .outingPlan: typeKey = "outing"
        case .anniversary: typeKey = "anniversary"
        case .travel: typeKey = "travel"
        case .external: typeKey = "external"
        }
        return "\(typeKey):\(relatedPlan?.id ?? relatedTravelPlan?.id ?? externalEvent?.id ?? title)"
    }
    let time: Date
    let title: String
    let subtitle: String?
    let type: CalendarItemType
    let relatedPlan: Plan?
    let relatedTravelPlan: TravelPlan?

    /// 本当に時刻を持っているか。
    ///
    /// おでかけ・記念日・旅行は日付だけの予定で、`time` には並べ替えのために
    /// その日の 0:00 を入れている。**これを時刻として扱ってはいけない。**
    /// 「過ぎた予定」の判定に混ぜると、日付が変わった瞬間に
    /// 0:00 の予定として過去扱いになり、当日なのに薄く表示されてしまう
    var hasTime: Bool = false
    /// iPhone のカレンダーの予定（`.external` のときだけ）。見るだけで、開く画面は無い
    var externalEvent: ExternalCalendarEvent? = nil
}

enum CalendarItemType {
    case dailyPlan
    case outingPlan
    case anniversary
    case travel
    /// iPhone のカレンダーの予定（3.0。`CalendarExportService.externalEvents`）
    case external
}

struct CalendarView: View {
    @EnvironmentObject var viewModel: PlansViewModel
    @EnvironmentObject var travelViewModel: TravelPlanViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject var themeManager = ThemeManager.shared
    @ObservedObject var tagManager = PlanTagManager.shared
    @State private var selectedDate = Date()
    /// 長押しされた日。履歴から作る一覧を出すために持つ。
    /// `Date` は Identifiable ではないので、シートに渡すために包む
    @State private var historyTarget: HistoryTarget?

    private struct HistoryTarget: Identifiable {
        let id = UUID()
        let date: Date
    }
    @State private var currentMonth = Date()
    /// iPhone のカレンダーの予定（見ている月の分）。出す設定のときだけ入る
    @State private var externalEvents: [ExternalCalendarEvent] = []
    /// どのカテゴリ（カレンダー）を見ているか（3.0）。閉じても覚えておく
    @AppStorage("calendarCategorySelection") private var categorySelectionKey = "all"
    /// 選んでいるタグ。選んでいる間は、そのタグの予定だけを出す（どれかが付いていれば出す）
    @State private var selectedTagIDs: Set<String> = []
    @State private var editingCategory: PlanCategory?
    @State private var showsNewCategory = false
    @State private var showsTagFilter = false
    /// 共有カレンダーを作る（共有をはじめからオンにしたカテゴリの作成）
    @State private var showsNewSharedCategory = false
    @State private var showsJoin = false
    /// 「カレンダーを共有できます」の案内を閉じたか（1回だけ出す）
    @AppStorage("calendarShareTipDismissed") private var shareTipDismissed = false
    /// Travory の予定（予定と旅行計画）を出すか。カレンダーの上の出どころのボタンで切り替える
    @AppStorage("calendarShowsTravory") private var showsTravory = true
    /// カレンダーの一覧（題名を押すと出る）と、閉じたあとに行うこと
    @State private var showsCategoryList = false
    @State private var pendingCategoryAction: PlanCategoryListSheet.Action?
    /// .ics の読み込み（3.0）。メニューから選ぶか、「Travory で開く」で届く
    @State private var showsICSImporter = false
    @ObservedObject private var icsInbox = ICSImportInbox.shared
    @ObservedObject private var categoryManager = PlanCategoryManager.shared
    @ObservedObject private var calendarService = CalendarExportService.shared
    @State private var showAddSheet = false
    @State private var dragOffset: CGFloat = 0
    @State private var isTimelineExpanded = false
    @State private var hasLoadedData = false
    @State private var showAuthError = false
    @Environment(\.colorScheme) var colorScheme
    @Namespace private var animation

    private let calendar: Calendar = {
        var cal = Calendar.current
        cal.firstWeekday = 2  // 2 = 月曜日始まり (1 = 日曜日, 2 = 月曜日)
        return cal
    }()
    private let daysOfWeek = ["月", "火", "水", "木", "金", "土", "日"]

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                LinearGradient(
                    // 下端は純黒（dark）ではなくテーマの地の色に落とす。
                    // 下部シートと同じ色だと境目が消えるので、シート側は一段上げた面を使う
                    gradient: Gradient(colors: colorScheme == .dark ? [themeManager.currentTheme.gradientDark, themeManager.currentTheme.backgroundDark] : [themeManager.currentTheme.gradientLight, themeManager.currentTheme.light]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // Calendar content
                VStack(spacing: 0) {
                    monthNavigationHeader

                    // 予定の出どころ（Travory・iCloud・Google…）。押して出す・出さない
                    sourceChips

                    // カレンダーを共有できることを、1回だけ知らせる（3.0）
                    if showsShareTip {
                        shareTip
                            .padding(.horizontal, 16)
                            .padding(.bottom, 10)
                    }

                    // タグで絞っているときだけ、何で絞っているかを小さく出す（3.0）
                    if !selectedTagIDs.isEmpty {
                        tagFilterSummary
                            .padding(.bottom, 10)
                    }

                    monthCalendarGrid
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)

                    Spacer()
                }
                .blur(radius: isTimelineExpanded ? 4 : 0)
                .opacity(isTimelineExpanded ? 0.6 : 1.0)

                // Dimming overlay when sheet is expanded
                if isTimelineExpanded {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                isTimelineExpanded = false
                            }
                        }
                }
                // Bottom timeline card
                BottomTimelineCard(
                    selectedDate: selectedDate,
                    timelineItems: dailyTimeline,
                    isExpanded: $isTimelineExpanded,
                    onAddPlan: { showAddSheet = true }
                )
                .environmentObject(viewModel)
                .environmentObject(travelViewModel)
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedDate = Date()
                            currentMonth = Date()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar.circle.fill")
                            Text("今日")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(themeManager.currentTheme.secondary)
                    }
                }

                // 題名はカテゴリ（カレンダー）の切り替え（3.0）。押すとカテゴリを選べる
                ToolbarItem(placement: .principal) {
                    categoryMenu
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 14) {
                        // タグで絞り込む。選んでいる間は塗りつぶしのアイコンにする
                        Button {
                            showsTagFilter = true
                        } label: {
                            Image(systemName: selectedTagIDs.isEmpty
                                  ? "line.3.horizontal.decrease.circle"
                                  : "line.3.horizontal.decrease.circle.fill")
                                .font(.title3)
                                .foregroundColor(themeManager.currentTheme.secondary)
                        }
                        .accessibilityLabel("タグで絞り込む")

                        Button(action: {
                            showAddSheet = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundColor(themeManager.currentTheme.secondary)
                        }
                        .accessibilityLabel("予定を追加")
                    }
                }
            }
            .sheet(isPresented: $showsCategoryList, onDismiss: runPendingCategoryAction) {
                PlanCategoryListSheet(selection: categorySelection,
                                      onSelect: { categorySelectionBinding.wrappedValue = $0 },
                                      onAction: { pendingCategoryAction = $0 })
                    .environmentObject(authVM)
                    .environmentObject(viewModel)
                    .environmentObject(travelViewModel)
            }
            .sheet(isPresented: $showsTagFilter) {
                PlanTagFilterSheet(tags: filterTags, selectedIDs: $selectedTagIDs,
                                   categoryName: categorySelectionName)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showsNewSharedCategory) {
                PlanCategoryEditorView(editing: nil, sharesOnCreate: true) { created in
                    categorySelectionKey = PlanCategorySelection.category(created.id).storageKey
                }
            }
            .sheet(isPresented: $showsJoin) {
                JoinTravelPlanView()
                    .environmentObject(travelViewModel)
            }
            .sheet(item: $editingCategory) { category in
                PlanCategoryEditorView(editing: category)
            }
            .sheet(isPresented: $showsNewCategory) {
                PlanCategoryEditorView(editing: nil) { created in
                    categorySelectionKey = PlanCategorySelection.category(created.id).storageKey
                }
            }
            .sheet(item: $historyTarget) { target in
                PlanHistoryPickerView(date: target.date) { plan in
                    createFromHistory(plan, on: target.date)
                }
                .environmentObject(viewModel)
            }
            .sheet(isPresented: $showAddSheet) {
                // 選んでいる日で始める。今日の日付で始まると、
                // 8月30日を見ていても8月30日の予定は作れない
                // 見ているカテゴリに入れ始める（「すべて」を見ているときは自分用）
                AddPlanView(historyPlans: viewModel.plans, initialDate: selectedDate,
                            initialCategoryId: categorySelection.categoryIdForNewPlan) { newPlan in
                    if let userId = authVM.userId {
                        viewModel.add(newPlan, userId: userId)
                    } else {
                        showAuthError = true
                    }
                }
            }
            .fileImporter(isPresented: $showsICSImporter, allowedContentTypes: ICSImportFile.contentTypes) { result in
                guard case .success(let url) = result else { return }
                icsInbox.open(url)
            }
            .sheet(item: $icsInbox.file) { file in
                // 見ているカテゴリに入れ始める（「すべて」を見ているときは自分用）
                ICSImportView(file: file, initialCategoryId: categorySelection.categoryIdForNewPlan)
                    .environmentObject(viewModel)
                    .environmentObject(authVM)
            }
            .alert("ファイルを読めませんでした", isPresented: $icsInbox.failed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(".ics ファイルか確かめて、もう一度お試しください。")
            }
            .alert("認証が必要です", isPresented: $showAuthError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("予定を保存するには、アプリを再起動してApple IDでサインインしてください。")
            }
            .onAppear(perform: reloadExternalEvents)
            .onChange(of: currentMonth) { _, _ in reloadExternalEvents() }
            .onChange(of: calendarService.eventsRevision) { _, _ in reloadExternalEvents() }
            .onChange(of: calendarService.showsExternalEvents) { _, _ in reloadExternalEvents() }
            .onChange(of: calendarService.hiddenCalendarIds) { _, _ in reloadExternalEvents() }
            .task {
                // Core DataのFetchedResultsControllerをセットアップ（初回のみ）
                if !hasLoadedData, let userId = authVM.userId {
                    hasLoadedData = true
                    viewModel.setupFetchedResultsController(userId: userId)
                    travelViewModel.setupFetchedResultsController(userId: userId)
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - カテゴリとタグ（3.0）

    /// 覚えているカテゴリがこの端末に無い（消した・まだ同期で届いていない・別の環境で作った）ときは「すべて」で見る。
    /// 無いカテゴリで絞ると、題名は「自分用」なのに予定が1つも出なくなる。
    /// 覚えている値は書き換えない（同期で届けば、そのカテゴリに戻る）
    private var categorySelection: PlanCategorySelection {
        let stored = PlanCategorySelection(storageKey: categorySelectionKey)
        if case .category(let id) = stored, categoryManager.category(for: id) == nil {
            return .all
        }
        return stored
    }

    private var categorySelectionBinding: Binding<PlanCategorySelection> {
        Binding(
            get: { categorySelection },
            set: { newValue in
                withAnimation(.easeInOut(duration: 0.2)) {
                    categorySelectionKey = newValue.storageKey
                    // カテゴリを変えたら、タグの絞り込みは外す（タグはカテゴリごとに違う）
                    selectedTagIDs = []
                }
            }
        )
    }

    /// 題名に出すカテゴリの名前
    private var categorySelectionName: String {
        switch categorySelection {
        case .all: return "すべて"
        case .personal: return PlanCategory.personalName
        case .category(let id): return categoryManager.name(for: id)
        }
    }

    /// 題名のカテゴリの切り替え。押すとカレンダーの一覧（`PlanCategoryListSheet`）が出て、
    /// 切り替え・編集・共有・iPhone のカレンダー・読み込みはそこから行う
    private var categoryMenu: some View {
        let textColor = colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1
        return Button {
            showsCategoryList = true
        } label: {
            HStack(spacing: 5) {
                if case .category(let id) = categorySelection, let category = categoryManager.category(for: id) {
                    Circle().fill(category.color).frame(width: 9, height: 9)
                    if category.isShared {
                        Image(systemName: "person.2.fill").font(.system(size: 11))
                    }
                }
                Text(categorySelectionName)
                    .font(.headline)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundColor(textColor)
        }
        .accessibilityLabel("カテゴリ：\(categorySelectionName)")
    }

    /// 一覧で選んだ動作を、一覧を閉じてから行う（シートの上にシートを重ねない）
    private func runPendingCategoryAction() {
        guard let action = pendingCategoryAction else { return }
        pendingCategoryAction = nil
        switch action {
        case .newCategory: showsNewCategory = true
        case .newSharedCategory: showsNewSharedCategory = true
        case .join: showsJoin = true
        case .importICS: showsICSImporter = true
        }
    }

    /// 共有したカテゴリが1つも無く、案内を閉じていなければ出す
    private var showsShareTip: Bool {
        !shareTipDismissed && !categoryManager.categories.contains(where: \.isShared)
    }

    private var shareTip: some View {
        let theme = themeManager.currentTheme
        // 地はテーマ色のグラデーションに、案内の面（secondary を 8%）を重ねた色。文字の色はそこから決める
        let ground = ThemePreset.composite(theme.secondary, over: theme.calendarScreenTop(for: colorScheme), opacity: 0.08)
        let textColor = ThemePreset.readableText(on: ground)
        let accent = theme.secondaryLabel(on: theme.calendarScreenTop(for: colorScheme), opacity: 0.08)
        let subText = ThemePreset.readableTint(theme.secondaryText, on: ground)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "person.2.fill")
                    .font(.title3)
                    .foregroundColor(accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text("カレンダーを家族や友達と共有できます")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(textColor)
                    Text("「家族」「友達」のようにカレンダーを分けて、予定を一緒に見て書けます。")
                        .font(.caption)
                        .foregroundColor(subText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button {
                    withAnimation { shareTipDismissed = true }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundColor(subText)
                }
                .accessibilityLabel("閉じる")
            }
            HStack(spacing: 10) {
                Button {
                    showsNewSharedCategory = true
                } label: {
                    Text("共有カレンダーを作る")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(accent))
                        .foregroundColor(ThemePreset.readableText(on: accent))
                }
                Button {
                    showsJoin = true
                } label: {
                    Text("コードで参加")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Capsule().stroke(accent.opacity(0.5), lineWidth: 1))
                        .foregroundColor(accent)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(themeManager.currentTheme.secondary.opacity(0.08)))
    }

    /// タグで絞っているときの表示。「✕」で絞り込みをやめる
    private var tagFilterSummary: some View {
        let names = tagManager.tags(for: Array(selectedTagIDs)).map(\.name).joined(separator: "・")
        return HStack(spacing: 8) {
            Button {
                showsTagFilter = true
            } label: {
                Label(names.isEmpty ? "タグ" : names, systemImage: "number")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
            }
            Button {
                withAnimation { selectedTagIDs = [] }
            } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .accessibilityLabel("絞り込みをやめる")
        }
        .foregroundColor(themeManager.currentTheme.secondaryLabel(on: themeManager.currentTheme.calendarScreenTop(for: colorScheme),
                                                                  opacity: 0.12))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(themeManager.currentTheme.secondary.opacity(0.12)))
    }

    /// 絞り込みに出すタグ（「すべて」では全部、カテゴリを選んでいればそのカテゴリのタグ）
    private var filterTags: [PlanTag] {
        switch categorySelection {
        case .all: return tagManager.tags
        case .personal: return tagManager.tags(inCategory: nil)
        case .category(let id): return tagManager.tags(inCategory: id)
        }
    }

    /// カテゴリとタグで絞った予定
    private var visiblePlans: [Plan] {
        guard showsTravory else { return [] }
        return viewModel.plans.filter { plan in
            categorySelection.includes(categoryId: plan.categoryId)
                && (selectedTagIDs.isEmpty || !selectedTagIDs.isDisjoint(with: plan.tagIDs))
        }
    }

    /// 旅行計画と iPhone の予定はカテゴリに入らない。「すべて」と「自分用」で、タグを選んでいないときだけ出す
    private var showsUncategorized: Bool {
        categorySelection.showsUncategorized && selectedTagIDs.isEmpty
    }

    private var visibleTravelPlans: [TravelPlan] {
        showsTravory && showsUncategorized ? travelViewModel.travelPlans : []
    }

    /// iPhone のカレンダーの予定は、出どころのボタンで出し分ける（どのカテゴリを見ていても出せる）。
    /// タグで絞っているときは出さない（タグは Travory の予定にしか付かない）
    private var visibleExternalEvents: [ExternalCalendarEvent] {
        selectedTagIDs.isEmpty ? externalEvents : []
    }

    // MARK: 予定の出どころ（Travory・iCloud・Google…）

    /// 月の下に1段だけ並べる。押すたびに出す・出さないを切り替える。
    /// iPhone のカレンダーを読めないときは、Travory だけなので出さない
    @ViewBuilder
    private var sourceChips: some View {
        let sources = calendarService.hasAccess ? calendarService.externalSources() : []
        if !sources.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    sourceChip(name: "Travory", color: themeManager.currentTheme.actionFill, isOn: showsTravory) {
                        withAnimation(.easeInOut(duration: 0.2)) { showsTravory.toggle() }
                    }
                    ForEach(sources) { source in
                        let isOn = calendarService.isShown(source)
                        sourceChip(name: source.name, color: source.color.map { Color(cgColor: $0) } ?? .gray, isOn: isOn) {
                            withAnimation(.easeInOut(duration: 0.2)) { calendarService.setShown(!isOn, source: source) }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 10)
        }
    }

    private func sourceChip(name: String, color: Color, isOn: Bool, action: @escaping () -> Void) -> some View {
        let theme = themeManager.currentTheme
        let ground = theme.calendarScreenTop(for: colorScheme)
        let label = isOn ? theme.secondaryLabel(on: ground, opacity: 0.12) : ThemePreset.readableTintEitherWay(theme.secondaryText, on: ground)
        return Button(action: action) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color.opacity(isOn ? 1 : 0.35))
                    .frame(width: 8, height: 8)
                Text(name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                if isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                }
            }
            .foregroundColor(label)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(theme.secondary.opacity(isOn ? 0.12 : 0.04)))
            .overlay(Capsule().stroke(label.opacity(isOn ? 0 : 0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(name)の予定")
        .accessibilityValue(isOn ? "表示中" : "非表示")
    }

    // MARK: - Computed Properties
    private var selectedDatePlans: [Plan] {
        visiblePlans.filter { plan in
            isDateInPlanRange(date: selectedDate, plan: plan)
        }.sorted { plan1, plan2 in
            // 時系列順にソート (0時→24時)
            let time1 = plan1.time ?? calendar.startOfDay(for: plan1.startDate)
            let time2 = plan2.time ?? calendar.startOfDay(for: plan2.startDate)

            let components1 = calendar.dateComponents([.hour, .minute], from: time1)
            let components2 = calendar.dateComponents([.hour, .minute], from: time2)

            let minutes1 = (components1.hour ?? 0) * 60 + (components1.minute ?? 0)
            let minutes2 = (components2.hour ?? 0) * 60 + (components2.minute ?? 0)

            return minutes1 < minutes2
        }
    }

    private var dailyTimeline: [CalendarTimelineItem] {
        // Daily plan items
        let dailyPlanItems = visiblePlans
            .filter { plan in
                plan.planType == .daily &&
                isDateInPlanRange(date: selectedDate, plan: plan)
            }
            .compactMap { plan -> CalendarTimelineItem? in
                let time = plan.time ?? calendar.startOfDay(for: plan.startDate)
                return CalendarTimelineItem(
                    time: time,
                    title: plan.title,
                    subtitle: plan.description,
                    type: .dailyPlan,
                    relatedPlan: plan,
                    relatedTravelPlan: nil,
                    // 日常の予定だけが時刻を持つ。それも入力は任意
                    hasTime: plan.time != nil
                )
            }

        // Outing plan items
        let outingPlanItems = visiblePlans
            .filter { plan in
                plan.planType == .outing &&
                isDateInPlanRange(date: selectedDate, plan: plan)
            }
            .map { plan -> CalendarTimelineItem in
                let time = plan.time ?? calendar.startOfDay(for: selectedDate)
                let dateInfo = formatOutingDateInfo(plan: plan)
                return CalendarTimelineItem(
                    time: time,
                    title: plan.title,
                    subtitle: dateInfo,
                    type: .outingPlan,
                    relatedPlan: plan,
                    relatedTravelPlan: nil,
                    hasTime: plan.time != nil
                )
            }

        // 記念日。時刻を持たないので、その日の先頭に置く
        let anniversaryItems = visiblePlans
            .filter { plan in
                plan.planType == .anniversary &&
                isDateInPlanRange(date: selectedDate, plan: plan)
            }
            .map { plan -> CalendarTimelineItem in
                CalendarTimelineItem(
                    time: calendar.startOfDay(for: selectedDate),
                    title: plan.title,
                    subtitle: anniversaryCountText(for: plan),
                    type: .anniversary,
                    relatedPlan: plan,
                    relatedTravelPlan: nil
                )
            }

        // Travel plan items
        let travelItems = visibleTravelPlans
            .filter { travelPlan in
                isDateInTravelPlanRange(date: selectedDate, travelPlan: travelPlan)
            }
            .map { travelPlan -> CalendarTimelineItem in
                let dateInfo = formatTravelDateInfo(travelPlan: travelPlan)
                return CalendarTimelineItem(
                    time: selectedDate,
                    title: travelPlan.title,
                    subtitle: dateInfo,
                    type: .travel,
                    relatedPlan: nil,
                    relatedTravelPlan: travelPlan
                )
            }

        // iPhone のカレンダーの予定（見るだけ）
        let externalItems = visibleExternalEvents
            .filter { $0.occurs(on: selectedDate, calendar: calendar) }
            .map { event -> CalendarTimelineItem in
                // その日に始まる時刻つきの予定だけ時刻で並べる。前の日からの続きや終日は先頭に置く
                let startsToday = calendar.isDate(event.start, inSameDayAs: selectedDate)
                let timed = !event.isAllDay && startsToday
                return CalendarTimelineItem(
                    time: timed ? event.start : calendar.startOfDay(for: selectedDate),
                    title: event.title,
                    subtitle: event.calendarName,
                    type: .external,
                    relatedPlan: nil,
                    relatedTravelPlan: nil,
                    hasTime: timed,
                    externalEvent: event
                )
            }

        // 時系列順にソート
        return (anniversaryItems + dailyPlanItems + outingPlanItems + travelItems + externalItems).sorted { item1, item2 in
            let components1 = calendar.dateComponents([.hour, .minute], from: item1.time)
            let components2 = calendar.dateComponents([.hour, .minute], from: item2.time)

            let minutes1 = (components1.hour ?? 0) * 60 + (components1.minute ?? 0)
            let minutes2 = (components2.hour ?? 0) * 60 + (components2.minute ?? 0)

            return minutes1 < minutes2
        }
    }

    // 指定日がプランの範囲内かチェック
    private func isDateInPlanRange(date: Date, plan: Plan) -> Bool {
        let startOfSelectedDate = calendar.startOfDay(for: date)
        let startOfPlanStartDate = calendar.startOfDay(for: plan.startDate)
        let startOfPlanEndDate = calendar.startOfDay(for: plan.endDate)

        if plan.planType == .daily {
            // 日常プランは完全一致
            return calendar.isDate(plan.startDate, inSameDayAs: date)
        } else {
            // おでかけプランは範囲内
            return startOfSelectedDate >= startOfPlanStartDate && startOfSelectedDate <= startOfPlanEndDate
        }
    }

    // おでかけプランの日付情報をフォーマット
    private func formatOutingDateInfo(plan: Plan) -> String {
        let isStartDate = calendar.isDate(plan.startDate, inSameDayAs: selectedDate)
        let isEndDate = calendar.isDate(plan.endDate, inSameDayAs: selectedDate)

        if isStartDate && isEndDate {
            return "日帰り旅行"
        } else if isStartDate {
            return "出発日 - \(dateRangeString(plan.startDate, plan.endDate))"
        } else if isEndDate {
            return "最終日 - \(dateRangeString(plan.startDate, plan.endDate))"
        } else {
            let dayNumber = calendar.dayDifference(from: plan.startDate, to: selectedDate)
            return "\(dayNumber + 1)日目 - \(dateRangeString(plan.startDate, plan.endDate))"
        }
    }

    // 旅行プランの日付情報をフォーマット
    private func formatTravelDateInfo(travelPlan: TravelPlan) -> String {
        let isStartDate = calendar.isDate(travelPlan.startDate, inSameDayAs: selectedDate)
        let isEndDate = calendar.isDate(travelPlan.endDate, inSameDayAs: selectedDate)

        if isStartDate && isEndDate {
            return "\(travelPlan.destination) - 日帰り旅行"
        } else if isStartDate {
            return "\(travelPlan.destination) - 出発日 (\(dateRangeString(travelPlan.startDate, travelPlan.endDate)))"
        } else if isEndDate {
            return "\(travelPlan.destination) - 最終日 (\(dateRangeString(travelPlan.startDate, travelPlan.endDate)))"
        } else {
            let dayNumber = calendar.dayDifference(from: travelPlan.startDate, to: selectedDate)
            return "\(travelPlan.destination) - \(dayNumber + 1)日目 (\(dateRangeString(travelPlan.startDate, travelPlan.endDate)))"
        }
    }

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年 M月"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: currentMonth)
    }

    private var daysInMonth: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth) else {
            return []
        }

        var days: [Date?] = []

        // 月の最初の日の曜日を取得
        let firstDayWeekday = calendar.component(.weekday, from: monthInterval.start)

        // 月曜日始まりの場合のオフセット計算
        // weekday: 1=日, 2=月, 3=火, ... 7=土
        // 月曜始まりの場合: 月=0, 火=1, 水=2, 木=3, 金=4, 土=5, 日=6
        let offset = (firstDayWeekday - calendar.firstWeekday + 7) % 7

        // 空白セルを追加
        for _ in 0..<offset {
            days.append(nil)
        }

        // 月の日付を追加
        var currentDate = monthInterval.start
        while currentDate < monthInterval.end {
            days.append(currentDate)
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }

        return days
    }

    // MARK: - Month Navigation Header
    private var monthNavigationHeader: some View {
        HStack(spacing: 20) {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    changeMonth(by: -1)
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(themeManager.currentTheme.secondary)
            }
            .accessibilityLabel("前の月")

            Spacer()

            // 年月は矢印のあいだに置く（題名はカテゴリの切り替えに使うため）
            Text(monthYearString)
                .font(.headline)
                .foregroundColor(colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1)

            Spacer()

            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    changeMonth(by: 1)
                }
            }) {
                Image(systemName: "chevron.right")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(themeManager.currentTheme.secondary)
            }
            .accessibilityLabel("次の月")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Month Calendar Grid
    private var monthCalendarGrid: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 12) {
                ForEach(Array(daysInMonth.enumerated()), id: \.offset) { _, date in
                    if let date = date {
                        calendarDayCell(date: date)
                    } else {
                        Color.clear
                            .frame(height: 50)
                    }
                }
            }
            .offset(x: dragOffset)
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation.width
                }
                .onEnded { value in
                    let threshold: CGFloat = 50

                    if value.translation.width < -threshold {
                        // 左スワイプ → 次月へ
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            changeMonth(by: 1)
                            dragOffset = 0
                        }
                    } else if value.translation.width > threshold {
                        // 右スワイプ → 前月へ
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            changeMonth(by: -1)
                            dragOffset = 0
                        }
                    } else {
                        // スワイプ距離が足りない場合は元に戻す
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = 0
                        }
                    }
                }
        )
    }

    private func calendarDayCell(date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let dotColors = dotColors(for: date)
        let dayNumber = calendar.component(.day, from: date)

        return VStack(spacing: 4) {
            Text("\(dayNumber)")
                .font(.system(size: 16, weight: isSelected ? .bold : .regular))
                .foregroundColor(isSelected ? (colorScheme == .dark ? themeManager.currentTheme.dark : themeManager.currentTheme.light) : (isToday ? themeManager.currentTheme.secondary : (colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1)
))
                .frame(width: 44, height: 44)
                .background(
                    ZStack {
                        if isSelected {
                            Circle()
                                .fill(themeManager.currentTheme.secondary)
                                .matchedGeometryEffect(id: "selectedDay", in: animation)
                        } else if isToday {
                            Circle()
                                .stroke(themeManager.currentTheme.secondary, lineWidth: 2)
                        }
                    }
                )

            // イベントインジケーター（イベントタイプごとに色分け）
            //
            // 予定の無い日で行ごと消すと、その日のマスだけ背が低くなる。
            // 週の高さは一番高いマスで決まるため、予定のある日の数字が
            // 上へ、無い日の数字が下へずれて見えていた。高さは常に確保する
            HStack(spacing: 2) {
                ForEach(dotColors.prefix(3).indices, id: \.self) { index in
                    Circle()
                        .fill(dotColors[index])
                        .frame(width: 4, height: 4)
                }
            }
            .frame(height: 4)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedDate = date
            }
        }
        // 長押しで、これまでの予定からその日に置ける。
        // 「またジム」「また同じ店」を毎回打ち直さずに済ませるため。
        // 月をめくる横スワイプとは競合しない（長押しは指が動くと成立しない）
        .onLongPressGesture(minimumDuration: 0.45) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            historyTarget = HistoryTarget(date: date)
        }
    }

    /// 履歴から作る。選ばれた予定を、長押しした日付で作り直す
    private func createFromHistory(_ plan: Plan, on date: Date) {
        guard let userId = authVM.userId else { return }

        viewModel.add(plan.recreated(on: date), userId: userId)

        // 作った日を開いて、増えたことがその場で見えるようにする
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            selectedDate = date
        }
    }

    private func hasEventsOn(date: Date) -> Bool {
        let hasPlans = visiblePlans.contains { plan in
            isDateInPlanRange(date: date, plan: plan)
        }

        let hasTravelPlans = visibleTravelPlans.contains { travelPlan in
            isDateInTravelPlanRange(date: date, travelPlan: travelPlan)
        }

        return hasPlans || hasTravelPlans
    }

    // 指定日が旅行プランの範囲内かチェック
    private func isDateInTravelPlanRange(date: Date, travelPlan: TravelPlan) -> Bool {
        let startOfSelectedDate = calendar.startOfDay(for: date)
        let startOfPlanStartDate = calendar.startOfDay(for: travelPlan.startDate)
        let startOfPlanEndDate = calendar.startOfDay(for: travelPlan.endDate)

        return startOfSelectedDate >= startOfPlanStartDate && startOfSelectedDate <= startOfPlanEndDate
    }

    // 指定日のイベントタイプのリストを取得（種別ごとに1つ、色分けが機能するよう重複排除）
    /// その日のマスに出す点の色。
    ///
    /// 予定の分類はタグが担うので、点もタグの色にする。
    /// 種別（おでかけ／日常／記念日）で塗り分けていた頃は、月を見渡しても
    /// 「日常が多い週」までしか分からなかった。
    /// 同じ画面の下にある予定リストもタグの色なので、そちらとも揃う
    private func dotColors(for date: Date) -> [Color] {
        var colors: [Color] = []

        // 旅行計画はタグを持たないので、専用の色を1つだけ
        if visibleTravelPlans.contains(where: { isDateInTravelPlanRange(date: date, travelPlan: $0) }) {
            colors.append(themeManager.currentTheme.travelColor)
        }

        let plansOfDay = visiblePlans.filter { isDateInPlanRange(date: date, plan: $0) }
        // Travory の予定が無い日も、iPhone の予定（祝日など）の点は出す。
        // 前はここで終わっていて、祝日だけの日に点が付かなかった
        guard !plansOfDay.isEmpty else { return colors + externalDotColor(for: date) }

        // 同じタグは1つにまとめる。並びは絞り込み行と同じ順にしたいので、
        // その日のタグを拾うのではなくタグ側の並びを走る
        let idsOfDay = Set(plansOfDay.flatMap(\.tagIDs))
        for tag in tagManager.tags where idsOfDay.contains(tag.id) {
            colors.append(tag.color)
        }

        // タグの付いていない予定は中立の灰色でまとめて1つ。
        // 出さないと「予定があるのに点が無い日」ができる
        if plansOfDay.contains(where: { tagManager.tags(for: $0.tagIDs).isEmpty }) {
            colors.append(themeManager.currentTheme.secondaryText.opacity(0.55))
        }

        return colors + externalDotColor(for: date)
    }

    /// iPhone の予定がある日の点。**カレンダーごとに1つずつ**、そのカレンダーの色で出す
    /// （仕事と祝日があれば2つ）。前は1日に1つしか出しておらず、予定が2つあっても点が1つだった
    private func externalDotColor(for date: Date) -> [Color] {
        var seen = Set<String>()
        return visibleExternalEvents
            .filter { $0.occurs(on: date, calendar: calendar) && seen.insert($0.calendarId).inserted }
            .map { event in event.color.map { Color(cgColor: $0) } ?? themeManager.currentTheme.secondaryText }
    }

    /// 見ている月（前後の週を含む）の、iPhone のカレンダーの予定を読み直す
    private func reloadExternalEvents() {
        guard calendarService.showsExternalEvents,
              let interval = calendar.dateInterval(of: .month, for: currentMonth) else {
            externalEvents = []
            return
        }
        let start = calendar.date(byAdding: .day, value: -7, to: interval.start) ?? interval.start
        let end = calendar.date(byAdding: .day, value: 7, to: interval.end) ?? interval.end
        externalEvents = calendarService.externalEvents(from: start, to: end)
    }

    /// 「10回目の結婚記念日」。開始年からの経過で数える
    private func anniversaryCountText(for plan: Plan) -> String {
        let years = calendar.component(.year, from: selectedDate) - calendar.component(.year, from: plan.startDate)
        return years > 0 ? "\(years + 1)回目" : "1回目"
    }

    // MARK: - Helper Methods
    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = newMonth
        }
    }

    private func formatTime(_ time: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: time)
    }

    private func dateRangeString(_ start: Date, _ end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        formatter.locale = Locale(identifier: "ja_JP")
        return "\(formatter.string(from: start))〜\(formatter.string(from: end))"
    }
}

//#Preview {
//    CalendarView()
//}
