import SwiftUI
import MapKit

struct MainTabView: View {
    @State private var selectedTab: Int = 0
    @State private var showICloudAlert = false
    @State private var hasCheckedICloud = false
    @State private var whatsNew: WhatsNew?
    @StateObject private var plansViewModel = PlansViewModel()
    @StateObject private var travelPlanViewModel = TravelPlanViewModel()
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) var scenePhase

    private var tabBarBackground: Color {
        colorScheme == .dark
            ? themeManager.currentTheme.backgroundDark
            : themeManager.currentTheme.backgroundLight
    }

    /// タブ本体。body に全部並べると型チェックが通らなくなるため分けている
    private var tabs: some View {
        TabView(selection: $selectedTab) {
            EnjoyWorldView()
                .tabItem{ Label("計画", systemImage: "list.clipboard") }
                .tag(0)
            CalendarView()
                .tabItem { Label("カレンダー", systemImage: "calendar") }
                .tag(1)
            PlacesListView()
                .tabItem { Label("場所保存", systemImage: "mappin.and.ellipse") }
                .tag(2)
            AlbumHomeView()
                .tabItem { Label("アルバム", systemImage: "photo.artframe") }
                .tag(3)
        }
        .environmentObject(plansViewModel)
        .environmentObject(travelPlanViewModel)
        .accentColor(themeManager.currentTheme.secondary)
        .toolbarBackground(tabBarBackground, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }

    var body: some View {
        tabs
        .onChange(of: selectedTab) { oldValue, newValue in
            if oldValue != newValue {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                updateWidgetSnapshot()
            }
        }
        .task {
            // カテゴリーとタグはどのタブからも参照されるためここで用意する。
            // タグ側は初回に、文字列だった頃のタグを実体へ移す処理も走る
            if let userId = authVM.userId {
                PlaceCategoryManager.shared.setup(userId: userId)
                PlanTagManager.shared.setup(userId: userId)
                // やることリストはホームのバッジからも数を出すので、ここで用意する。
                // 初回は UserDefaults に残っているぶんを Core Data へ移す
                TaskManager.shared.setup(userId: userId)

                // 写真の預け直し。
                // `ProStore` は起動直後に所有状態を確かめるが、そのときまだ
                // サインインが復元されておらず userId が無いことがある。
                // そこで一度取りこぼすと次の購入まで追いつく機会が来ないので、
                // ユーザーが確定したここでもう一度声をかける（済んでいれば何もしない）
                PhotoSyncService.shared.backfill()
            }

            if !hasCheckedICloud {
                hasCheckedICloud = true
                await checkICloudStatus()
            }

            // アップデート後の初回起動で新機能を知らせる。
            // iCloudアラートと重ならないよう、確認を終えてから出す
            // （動作確認中はiCloud未サインインでも出さないと確認できないため通す）
            #if DEBUG
            let canShowWhatsNew = WhatsNewManager.alwaysShowForTesting || !showICloudAlert
            #else
            let canShowWhatsNew = !showICloudAlert
            #endif

            if canShowWhatsNew, WhatsNewManager.shouldShow {
                whatsNew = WhatsNew.current
                WhatsNewManager.markAsShown()
            }
        }
        // ウィジェット用のデータを書き出す。
        // TravelPlan は Equatable ではないため配列を直接監視できないので、
        // 起動時・タブ切り替え時・バックグラウンドへ移る時に更新する
        .onAppear { updateWidgetSnapshot() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { updateWidgetSnapshot() }
        }
        .alert("iCloudが必要です", isPresented: $showICloudAlert) {
            Button("設定を開く", role: .none) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text("このアプリはデータを保存するためにiCloudを使用します。iCloudにサインインしてください。\n\n設定 > [あなたの名前] > iCloud")
        }
        .sheet(item: $whatsNew) { content in
            WhatsNewView(content: content)
        }
    }

    private func updateWidgetSnapshot() {
        WidgetSnapshotBuilder.update(
            travelPlans: travelPlanViewModel.travelPlans,
            plans: plansViewModel.plans
        )
    }

    private func checkICloudStatus() async {
        let isAvailable = await CloudKitService.shared.isICloudAvailable()
        if !isAvailable {
            showICloudAlert = true
        }
    }
}
