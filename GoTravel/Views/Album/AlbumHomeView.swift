import SwiftUI

// MARK: - Album Home View
struct AlbumHomeView: View {
    @ObservedObject private var albumManager = AlbumManager.shared
    // MainTabView から注入済みのインスタンスを使う（自前生成すると二重管理になる）
    @EnvironmentObject var travelPlanViewModel: TravelPlanViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme
    @State private var showCreateAlbum = false
    /// 右下の＋のメニューを開いているか（3.8）
    @State private var addMenuOpen = false
    /// ＋のメニューから選んだ、作るもの（コラージュ・ポスター・日記）。旅行を選ぶ画面を開く
    @State private var makerKind: MemoryKind?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedAlbum: Album?
    /// アルバムのカードから中身へ広がる遷移
    @Namespace private var albumZoom
    @State private var editingAlbum: Album?

    // 写真一覧と同じ操作感で、まとめて削除できるようにする
    @State private var isSelectionMode = false
    @State private var selectedAlbumIds: Set<String> = []
    @State private var showDeleteConfirm = false
    /// 旅のダイジェスト動画（Travory Pro）。いちばん最近の旅行で開き、画面の上で旅行を切り替える
    /// 作った動画を見る（カードの「作成済み」から）
    @State private var playingDigest: TripDigestLibrary.Entry?
    /// 残した動画が変わった合図（ダイジェストの画面を閉じたら読み直す）
    @State private var libraryVersion = 0
    @State private var digestPlan: TravelPlan?
    /// 旅行計画なしで作ったもの（3.8）
    @State private var freeMemories: [FreeMemory] = FreeMemoryStore.all()
    @State private var settingUpFreeDigest = false
    /// 「自由に作る」で決めたもの。決める画面を閉じてからダイジェストを開く
    @State private var createdFreeDigest: FreeMemory?
    /// 旅の記録（3.1）
    @State private var showsStats = false
    /// 「旅の思い出をつくる」「旅のダイジェスト」をしまったか（3.8。アプリを閉じても覚えておく）
    @AppStorage("AlbumHomeMemoriesCollapsed") private var memoriesCollapsed = false
    @AppStorage("AlbumHomeDigestCollapsed") private var digestCollapsed = false
    /// 年末のふり返りから開いたときの年（3.8）
    @State private var recapYear: Int?
    /// 年末のふり返りの入口を閉じた（出し直さない）
    @State private var recapDismissed = false
    @EnvironmentObject private var plansViewModel: PlansViewModel

    /// 既定アルバム（日本全国フォトマップ）は削除できないので選択対象から外す
    private var deletableAlbums: [Album] {
        albumManager.albums.filter { !$0.isDefaultAlbum }
    }

    /// フォトマップも写真の並びをアルバムに持つようになったので、どのアルバムも同じ数え方
    private var totalPhotoCount: Int {
        albumManager.albums.reduce(0) { $0 + $1.photoFileNames.count }
    }

    /// 共有している旅行の id（変わったら突き合わせ直す）
    private var sharedPlanIds: [String] {
        travelPlanViewModel.travelPlans.filter(\.isShared).compactMap(\.id).sorted()
    }

    /// アルバムの旅行を共有していれば、その旅行
    private func sharedPlan(for album: Album) -> TravelPlan? {
        guard let planId = album.travelPlanId else { return nil }
        return travelPlanViewModel.travelPlans.first { $0.id == planId && $0.isShared }
    }

    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient

                VStack(spacing: 0) {
                    headerBar
                        .readableWidth(WideLayout.galleryWidth)

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            // 年末の「◯年の旅をふり返る」（3.8。12月〜1月15日だけ）
                            if !isSelectionMode, !recapDismissed,
                               let year = YearRecap.yearToShow(plans: travelPlanViewModel.travelPlans) {
                                yearRecapBanner(year)
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 18)
                            }
                            // 旅の思い出をつくる（3.8。写真コラージュ・ポスター・日記）
                            if !isSelectionMode {
                                MemoriesMakerSection(plans: travelPlanViewModel.travelPlans, isCollapsed: $memoriesCollapsed)
                                    .padding(.top, 4)
                                    .padding(.bottom, 22)
                            }
                            // 旅のダイジェスト（選んで消しているあいだは出さない）
                            if !isSelectionMode {
                                digestSection
                                    .padding(.bottom, 22)
                            }
                            sectionTitle("アルバム")
                                .padding(.horizontal, 20)
                            if albumManager.albums.isEmpty {
                                emptyState
                            } else {
                                albumGrid
                            }
                        }
                        .padding(.bottom, isSelectionMode ? 20 : 100)
                        // iPad・Mac の広い画面では、見出しと同じ幅にそろえる（iPhone では何もしない）
                        .readableWidth(WideLayout.galleryWidth)
                    }
                }

                if !isSelectionMode {
                    // ＋のメニューを開いているあいだは、うしろを暗くする（押すと閉じる）
                    FloatingAddMenuBackdrop(isOpen: $addMenuOpen.animation(.easeInOut(duration: 0.2)))
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            fabButton
                        }
                        .padding(.trailing, FloatingAddButtonLabel.margin)
                        .padding(.bottom, FloatingAddButtonLabel.margin)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if isSelectionMode {
                    selectionToolbar
                }
            }
            .task {
                if let userId = authVM.userId {
                    albumManager.setup(userId: userId)
                }
            }
            // 共有した旅行のアルバムの写真を、同行者と突き合わせる（3.8）
            .task(id: sharedPlanIds) {
                guard let userId = authVM.userId, !sharedPlanIds.isEmpty else { return }
                await SharedAlbumSync.shared.syncAll(plans: travelPlanViewModel.travelPlans, userId: userId)
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        .sheet(item: $playingDigest) { entry in
            NavigationStack {
                TripDigestPlayerView(result: .init(url: TripDigestLibrary.url(of: entry), title: entry.title))
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("閉じる") { playingDigest = nil }
                        }
                    }
            }
        }
        // ＋のメニューから、旅の思い出（コラージュ・ポスター・日記）を作る。広い画面では全画面
        .sheet(item: horizontalSizeClass == .regular ? .constant(nil) : $makerKind) { kind in
            MemoryTripPicker(kind: kind, plans: makerPlans)
        }
        .fullScreenCover(item: horizontalSizeClass == .regular ? $makerKind : .constant(nil)) { kind in
            MemoryTripPicker(kind: kind, plans: makerPlans)
        }
        .sheet(isPresented: $settingUpFreeDigest, onDismiss: {
            // 決める画面が閉じてから開く（続けて別の画面を出すと、出ないことがあるため）
            if let createdFreeDigest { digestPlan = createdFreeDigest.plan }
            createdFreeDigest = nil
        }) {
            NavigationStack {
                FreeMemorySetupView(purpose: "旅のダイジェスト") { memory in
                    freeMemories = FreeMemoryStore.all()
                    createdFreeDigest = memory
                    settingUpFreeDigest = false
                }
            }
        }
        .sheet(item: $digestPlan, onDismiss: {
            libraryVersion += 1
            freeMemories = FreeMemoryStore.all()
        }) { plan in
            // 上の旅行名から、ほかの旅行にも切り替えられる
            TripDigestView(plan: plan, otherPlans: digestCandidates)
        }
        .sheet(item: Binding(get: { recapYear.map(RecapYear.init) }, set: { recapYear = $0?.year })) { recap in
            TripStatsView(initialPeriod: .year(recap.year))
                .environmentObject(travelPlanViewModel)
                .environmentObject(plansViewModel)
                .environmentObject(authVM)
        }
        .sheet(isPresented: $showsStats) {
            TripStatsView()
                .environmentObject(travelPlanViewModel)
                .environmentObject(plansViewModel)
                .environmentObject(authVM)
        }
        .sheet(isPresented: $showCreateAlbum) {
            CreateAlbumView(travelPlans: travelPlanViewModel.travelPlans)
        }
        .sheet(item: $editingAlbum) { album in
            AlbumEditorView(album: album)
        }
        .fullScreenCover(item: $selectedAlbum) { album in
            // タイトル文字列ではなく種別で判定する
            Group {
                if album.isJapanPhotoMap {
                    JapanPhotoView(albumId: album.id)
                } else {
                    AlbumDetailView(album: album, sharedPlan: sharedPlan(for: album), userId: authVM.userId)
                }
            }
            .zoomDestination(id: album.id, in: albumZoom)
        }
        .confirmationDialog(deleteConfirmTitle, isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("削除", role: .destructive) { deleteSelectedAlbums() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("アルバム内の写真もすべて削除されます。この操作は取り消せません。")
        }
    }

    // MARK: - Album Grid
    private var albumGrid: some View {
        // iPad・Mac の広い画面では4列にする。2列のままだと、1枚のアルバムが窓の半分（1,000pt 以上）の
        // 大きな正方形になり、右半分が空いていた（iPhone は今までどおり2列）
        IsWideLayoutReader { isWide in
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: isWide ? 4 : 2),
                      spacing: 14) {
                ForEach(albumManager.albums) { album in
                    AlbumCard(
                        album: album,
                        isSelectionMode: isSelectionMode,
                        isSelected: selectedAlbumIds.contains(album.id),
                        onTap: { handleTap(on: album) },
                        onEdit: { editingAlbum = album },
                        onDelete: { requestDelete(album) },
                        onStartSelection: { startSelection(with: album) }
                    )
                    .zoomSource(id: album.id, in: albumZoom)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
    }

    // MARK: - Background
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: colorScheme == .dark ? [themeManager.currentTheme.gradientDark, themeManager.currentTheme.dark] : [themeManager.currentTheme.gradientLight, themeManager.currentTheme.light]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Colors
    private var accentColor: Color {
        colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1
    }

    private var mainColor: Color {
        themeManager.currentTheme.xprimary
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(isSelectionMode ? selectionTitle : "思い出")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .foregroundColor(accentColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer(minLength: 0)

                if isSelectionMode {
                    Button("キャンセル") { exitSelectionMode() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(mainColor)
                } else {
                    if !deletableAlbums.isEmpty {
                        Button("選択") { enterSelectionMode() }
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(mainColor)
                    }
                    statsButton
                }
            }

            if isSelectionMode {
                Button(action: toggleSelectAll) {
                    Text(selectedAlbumIds.count == deletableAlbums.count ? "すべて解除" : "すべて選択")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(mainColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(mainColor.opacity(0.12), in: Capsule())
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                if !albumManager.albums.isEmpty {
                    HStack(spacing: 8) {
                        statChip(icon: "rectangle.stack.fill", text: "\(albumManager.albums.count)個のアルバム")
                        statChip(icon: "photo.on.rectangle.angled", text: "\(totalPhotoCount)枚")
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 14)
    }

    /// 旅のダイジェスト。旅行ごとのカードを横に並べる（作るのは無料。印なしは Pro）
    private var digestSection: some View {
        let _ = libraryVersion
        return VStack(alignment: .leading, spacing: 10) {
            // 見出しを押すと、しまう・出す（3.8）
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { digestCollapsed.toggle() }
            } label: {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        sectionTitle("旅のダイジェスト")
                        if !digestCollapsed {
                            Text("旅行中に撮った写真と動画を、2秒ずつつないだ動画に")
                                .font(.caption)
                                .foregroundColor(themeManager.currentTheme.secondaryText)
                        }
                    }
                    Spacer()
                    CollapseChevron(isCollapsed: digestCollapsed, color: themeManager.currentTheme.secondaryText)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(digestCollapsed ? "押すと出します" : "押すとしまいます")
            .padding(.horizontal, 20)
            if digestCollapsed {
                EmptyView()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(digestCandidates.prefix(12)) { plan in
                            DigestTripCard(plan: plan,
                                           saved: TripDigestLibrary.entries(planId: plan.id).first,
                                           onOpen: { digestPlan = plan },
                                           onPlay: { entry in playingDigest = entry })
                                .contextMenu {
                                    if FreeMemoryStore.isFree(planId: plan.id), let id = plan.id {
                                        Button(role: .destructive) {
                                            FreeMemoryStore.delete(id: id)
                                            withAnimation { freeMemories = FreeMemoryStore.all() }
                                        } label: {
                                            Label("削除", systemImage: "trash")
                                        }
                                    }
                                }
                        }
                        freeDigestCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(.top, 4)
    }

    /// 旅の記録の入口。見出しの右の「記録」（画面の中にカードを置くと、写真や動画より目立ってしまうため）。
    /// 印だけだと何のボタンか分からないので、文字にする
    private var statsButton: some View {
        Button { showsStats = true } label: {
            Text("記録")
                .font(.body.weight(.semibold))
                .foregroundColor(mainColor)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(Capsule().fill(mainColor.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("旅の記録")
    }

    /// 年末の「◯年の旅をふり返る」の入口（3.8）。押すと、その年の「記録」が開く（ストーリー用の画像も作れる）
    private func yearRecapBanner(_ year: Int) -> some View {
        HStack(spacing: 12) {
            Button { recapYear = year } label: {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(mainColor))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(String(year))年の旅をふり返る")
                            .font(.headline)
                            .foregroundColor(accentColor)
                        Text("行った県・旅の日数を1枚にまとめて、ストーリーに載せられます")
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                YearRecap.dismiss(year)
                withAnimation { recapDismissed = true }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundColor(themeManager.currentTheme.secondaryText)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("閉じる")
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: AppRadius.large).fill(mainColor.opacity(0.12)))
    }

    private struct RecapYear: Identifiable {
        let year: Int
        var id: Int { year }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundColor(accentColor)
    }

    /// ダイジェストを作れる旅行（もう始まっている旅行と、旅行計画なしで作ったもの。新しい順）
    private var digestCandidates: [TravelPlan] {
        let today = Calendar.current.startOfDay(for: Date())
        return (travelPlanViewModel.travelPlans
            .filter { Calendar.current.startOfDay(for: $0.startDate) <= today }
            + freeMemories.map(\.plan))
            .sorted { $0.startDate > $1.startDate }
    }

    /// 旅行計画なしでダイジェストを作る入口（3.8）。旅行のカードと同じ大きさで、列の最後に置く
    private var freeDigestCard: some View {
        Button { settingUpFreeDigest = true } label: {
            VStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(mainColor)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(mainColor.opacity(0.12)))
                Text("自由に作る")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(accentColor)
                Text(digestCandidates.isEmpty ? "旅行計画がなくても\n期間か写真を選んで" : "期間か写真を\n選んで作る")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(themeManager.currentTheme.secondaryText)
            }
            .frame(width: DigestTripCard.size.width, height: DigestTripCard.size.height)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                    .strokeBorder(mainColor.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            )
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("旅行計画なしでダイジェストを自由に作る")
    }

    private func statChip(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption2.weight(.semibold))
            Text(text)
                .font(.caption.weight(.semibold))
        }
        .foregroundColor(mainColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(mainColor.opacity(0.12), in: Capsule())
    }

    // MARK: - Selection
    private var selectionTitle: String {
        selectedAlbumIds.isEmpty ? "アルバムを選択" : "\(selectedAlbumIds.count)個を選択中"
    }

    private var deleteConfirmTitle: String {
        selectedAlbumIds.count == 1
            ? "このアルバムを削除しますか？"
            : "\(selectedAlbumIds.count)個のアルバムを削除しますか？"
    }

    private var selectionToolbar: some View {
        Button(action: { showDeleteConfirm = true }) {
            HStack(spacing: 6) {
                Image(systemName: "trash.fill")
                Text("削除")
            }
            .font(.headline)
            .foregroundColor(selectedAlbumIds.isEmpty ? themeManager.currentTheme.secondaryText : .white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(selectedAlbumIds.isEmpty
                          ? themeManager.currentTheme.secondaryText.opacity(0.15)
                          : themeManager.currentTheme.error)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(selectedAlbumIds.isEmpty)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private func handleTap(on album: Album) {
        if isSelectionMode {
            // 既定アルバムは削除できないため選択させない
            guard !album.isDefaultAlbum else { return }
            if selectedAlbumIds.contains(album.id) {
                selectedAlbumIds.remove(album.id)
            } else {
                selectedAlbumIds.insert(album.id)
            }
        } else {
            selectedAlbum = album
        }
    }

    private func enterSelectionMode() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isSelectionMode = true
        }
    }

    private func startSelection(with album: Album) {
        guard !album.isDefaultAlbum else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isSelectionMode = true
            selectedAlbumIds = [album.id]
        }
    }

    private func exitSelectionMode() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isSelectionMode = false
            selectedAlbumIds.removeAll()
        }
    }

    private func toggleSelectAll() {
        if selectedAlbumIds.count == deletableAlbums.count {
            selectedAlbumIds.removeAll()
        } else {
            selectedAlbumIds = Set(deletableAlbums.map(\.id))
        }
    }

    private func requestDelete(_ album: Album) {
        guard !album.isDefaultAlbum else { return }
        selectedAlbumIds = [album.id]
        showDeleteConfirm = true
    }

    private func deleteSelectedAlbums() {
        let targets = albumManager.albums.filter { selectedAlbumIds.contains($0.id) }
        for album in targets {
            albumManager.deleteAlbum(album)
        }
        exitSelectionMode()
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 20) {

            ZStack {
                Circle()
                    .fill(themeManager.currentTheme.xprimary.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 44))
                    .foregroundColor(themeManager.currentTheme.xprimary.opacity(0.5))
            }

            VStack(spacing: 8) {
                Text("アルバムがありません")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(accentColor)
                Text("「+」ボタンからアルバムを作成しましょう")
                    .font(.subheadline)
                    .foregroundColor(themeManager.currentTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }

            Button(action: { showCreateAlbum = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("アルバムを作成")
                }
                .font(.headline.weight(.bold))
                .foregroundColor(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.large)
                        .fill(themeManager.currentTheme.xprimary)
                        .shadow(color: themeManager.currentTheme.xprimary.opacity(0.4), radius: 8, x: 0, y: 4)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
        .padding(.vertical, 36)
    }

    // MARK: - FAB
    /// 右下の＋。押すと、作れるもの（コラージュ・ポスター・日記・ダイジェスト・アルバム）のメニューが開く（3.8）
    private var fabButton: some View {
        MemoriesAddMenu(isOpen: $addMenuOpen.animation(.easeInOut(duration: 0.2))) { item in
            switch item {
            case .collage: makerKind = .photoDump
            case .poster: makerKind = .poster
            case .diary: makerKind = .diary
            case .digest:
                // いちばん新しい旅行で開く（上の名前から、ほかの旅行にも切り替えられる）。
                // 作れる旅行が無ければ、旅行計画なしで作る画面を出す
                if let latest = digestCandidates.first {
                    digestPlan = latest
                } else {
                    settingUpFreeDigest = true
                }
            case .album: showCreateAlbum = true
            }
        }
    }

    /// 旅の思い出を作れる旅行（もう始まった旅行。新しい順）
    private var makerPlans: [TravelPlan] {
        let today = Calendar.current.startOfDay(for: Date())
        return travelPlanViewModel.travelPlans
            .filter { Calendar.current.startOfDay(for: $0.startDate) <= today }
            .sorted { $0.startDate > $1.startDate }
    }
}

// MARK: - Album Card
struct AlbumCard: View {
    let album: Album
    let isSelectionMode: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onStartSelection: () -> Void

    @ObservedObject private var albumManager = AlbumManager.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme

    /// 計算プロパティのままだと参照のたびにディスクから読み直すため、一度だけ読んで保持する
    @State private var recentPhotos: [UIImage] = []
    /// フォトマップの、写真のある県の代表写真（3.8。表紙の地図に使う）
    @State private var prefectureCovers: [Prefecture: UIImage] = [:]

    private var photoCount: Int {
        album.photoFileNames.count
    }

    /// フォトマップの写真は `JapanPhotos` にあるので、読み出し先だけ分ける。
    /// フォトマップの表紙は日本地図にするので、県ごとの代表写真を読む（3.8）
    private func loadRecentPhotos() {
        if album.isJapanPhotoMap {
            var covers: [Prefecture: UIImage] = [:]
            for prefecture in Prefecture.allCases {
                if let name = PhotoMapFiles.cover(of: prefecture, in: album.photoFileNames),
                   let image = JapanPhotoManager.shared.thumbnail(name) {
                    covers[prefecture] = image
                }
            }
            prefectureCovers = covers
        } else {
            recentPhotos = albumManager.recentThumbnails(from: album, limit: 4)
        }
    }

    private var resolvedCoverColor: Color {
        let fallback = themeManager.currentTheme.xprimary
        guard let color = album.coverColor else { return fallback }
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else { return fallback }
        let brightness = 0.299 * r + 0.587 * g + 0.114 * b
        return brightness < 0.85 ? color : fallback
    }

    private var cardBg: Color {
        colorScheme == .dark
            ? themeManager.currentTheme.secondaryBackgroundDark
            : themeManager.currentTheme.backgroundLight
    }

    private var accentColor: Color {
        colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1
    }

    /// 選択モード中、既定アルバムは削除できないので選べないことを見た目でも示す
    private var isDimmed: Bool {
        isSelectionMode && album.isDefaultAlbum
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            photoPreviewSection
            albumInfoSection
        }
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.large))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .stroke(
                    isSelected ? resolvedCoverColor : resolvedCoverColor.opacity(0.3),
                    lineWidth: isSelected ? 3 : 1
                )
        )
        .overlay(alignment: .topTrailing) { selectionBadge }
        .shadow(color: resolvedCoverColor.opacity(0.18), radius: 8, x: 0, y: 4)
        .opacity(isDimmed ? 0.45 : 1)
        .scaleEffect(isSelected ? 0.95 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelectionMode)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .contextMenu {
            // 長押しは標準のメニューにする（独自の編集モードより見つけやすい）
            if !isSelectionMode {
                Button {
                    onEdit()
                } label: {
                    Label("アルバムを編集", systemImage: "slider.horizontal.3")
                }

                if !album.isDefaultAlbum {
                    Button {
                        onStartSelection()
                    } label: {
                        Label("選択", systemImage: "checkmark.circle")
                    }

                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                }
            }
        }
        .task(id: album.photoFileNames) {
            loadRecentPhotos()
        }
    }

    // MARK: - Selection Badge
    @ViewBuilder
    private var selectionBadge: some View {
        if isSelectionMode && !album.isDefaultAlbum {
            ZStack {
                Circle()
                    .fill(isSelected ? resolvedCoverColor : Color.black.opacity(0.35))
                    .frame(width: 26, height: 26)
                Circle()
                    .stroke(Color.white, lineWidth: 1.5)
                    .frame(width: 26, height: 26)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .padding(8)
            .allowsHitTesting(false)
            .transition(.scale.combined(with: .opacity))
        }
    }

    // MARK: - Photo Preview
    private var photoPreviewSection: some View {
        // 4:3 の可変サイズにして、端末幅が変わっても崩れないようにする
        Color.clear
            .aspectRatio(4.0 / 3.0, contentMode: .fit)
            .overlay {
                if album.isJapanPhotoMap {
                    photoMapPreview
                } else if recentPhotos.isEmpty {
                    emptyPhotoPreview
                } else {
                    mosaicPreview
                }
            }
            .overlay(alignment: .bottomLeading) {
                if !album.isJapanPhotoMap { photoCountBadge }
            }
            .clipped()
    }

    private func photoFill(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
    }

    private var emptyPhotoPreview: some View {
        ZStack {
            LinearGradient(
                colors: [resolvedCoverColor.opacity(0.75), resolvedCoverColor.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: album.icon)
                .font(.system(size: 44))
                .foregroundColor(.white.opacity(0.85))
        }
    }

    /// 写真の枚数に合わせて並べる（3.8）。4枚に満たないときに、空いたマスを色の四角で埋めていた。
    /// 1枚は全面、2枚は左右、3枚は左に大きく1枚と右に2枚、4枚以上は 2x2
    @ViewBuilder
    private var mosaicPreview: some View {
        let photos = recentPhotos
        switch photos.count {
        case 1:
            tile(photos[0])
        case 2:
            HStack(spacing: 2) {
                tile(photos[0])
                tile(photos[1])
            }
        case 3:
            // 表紙の枠（4:3 で決まっている）の幅を測り、左の1枚を6割にする
            GeometryReader { geo in
                HStack(spacing: 2) {
                    tile(photos[0])
                        .frame(width: max(geo.size.width - 2, 0) * 0.6)
                    VStack(spacing: 2) {
                        tile(photos[1])
                        tile(photos[2])
                    }
                }
            }
        default:
            VStack(spacing: 2) {
                HStack(spacing: 2) {
                    tile(photos[0])
                    tile(photos[1])
                }
                HStack(spacing: 2) {
                    tile(photos[2])
                    tile(photos[3])
                }
            }
        }
    }

    /// 写真1枚を、与えられた枠いっぱいに切り抜いて敷く
    private func tile(_ image: UIImage) -> some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay { photoFill(image) }
            .clipped()
    }

    // MARK: - フォトマップの表紙（3.8）

    /// 日本地図（写真のある県は写真で、無い県は薄く）と、埋まった県の数
    private var photoMapPreview: some View {
        let filled = prefectureCovers.count
        let total = Prefecture.allCases.count
        return ZStack {
            LinearGradient(
                colors: [resolvedCoverColor.opacity(0.22), resolvedCoverColor.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            // 地図は縦に長いので、表紙の幅の6割強を地図に使い、高さいっぱいに描く
            GeometryReader { geo in
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Spacer(minLength: 0)
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("\(filled)")
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundColor(resolvedCoverColor)
                                .monospacedDigit()
                                .minimumScaleFactor(0.6)
                            Text("/\(total)")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(themeManager.currentTheme.secondaryText)
                        }
                        .lineLimit(1)
                        Text("都道府県")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(themeManager.currentTheme.secondaryText)
                        // 埋まった割合
                        ZStack(alignment: .leading) {
                            Capsule().fill(resolvedCoverColor.opacity(0.18))
                            Capsule().fill(resolvedCoverColor)
                                .frame(width: geo.size.width * 0.3 * CGFloat(filled) / CGFloat(max(total, 1)))
                        }
                        .frame(width: geo.size.width * 0.3, height: 5)
                        .padding(.top, 4)
                    }
                    .padding(.leading, 12)
                    .padding(.bottom, 12)
                    .frame(width: geo.size.width * 0.38, height: geo.size.height, alignment: .bottomLeading)

                    // 写真の無い県は文字の色で薄く描く（表紙の色だと、下地に溶けて見えない）
                    PhotoMapCanvas(covers: prefectureCovers, ink: accentColor, onTap: { _ in })
                        .allowsHitTesting(false)
                        .padding(.vertical, 6)
                        .padding(.trailing, 4)
                        .frame(width: geo.size.width * 0.62, height: geo.size.height)
                        .accessibilityHidden(true)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("日本全国フォトマップ、47都道府県のうち\(filled)")
    }

    @ViewBuilder
    private var photoCountBadge: some View {
        if !recentPhotos.isEmpty {
            HStack(spacing: 4) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 10, weight: .semibold))
                Text("\(photoCount)")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial, in: Capsule())
            .environment(\.colorScheme, .dark)
            .padding(8)
        }
    }

    // MARK: - Info Section
    private var albumInfoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: album.icon)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(resolvedCoverColor)
                Text(album.title)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundColor(accentColor)
                    .lineLimit(1)
            }

            HStack(spacing: 6) {
                Text(photoCount == 0 ? "写真なし" : "\(photoCount)枚")
                    .font(.caption2)
                    .foregroundColor(themeManager.currentTheme.secondaryText)

                if album.travelPlanId != nil {
                    badge(icon: "airplane.departure", text: "旅行")
                }

                if album.isDefaultAlbum {
                    badge(icon: "lock.fill", text: "既定")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func badge(icon: String, text: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(text)
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundColor(resolvedCoverColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(resolvedCoverColor.opacity(0.14), in: Capsule())
    }
}

#Preview {
    AlbumHomeView()
        .environmentObject(AuthViewModel())
        .environmentObject(TravelPlanViewModel())
}
