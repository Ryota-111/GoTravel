import SwiftUI

@main
struct GoTravelApp: App {
    @StateObject private var authViewModel: AuthViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    /// データを開けなかったときに、ふつうの画面の代わりに知らせる画面を出す（3.8）
    @ObservedObject private var coreData = CoreDataManager.shared

    init() {
        let avm = AuthViewModel()
        _authViewModel = StateObject(wrappedValue: avm)

        // Core Dataの初期化（CloudKitとの自動同期を有効化）。
        // 画面を組み立てる前に開いておく。開けなかったときは落とさず、body で知らせる画面を出す（3.8）
        CoreDataManager.shared.loadStoresIfNeeded()

        #if DEBUG
        // 画面を確かめるための見本データ（`-TravoryEmptyDataMode -TravoryDemoData` のときだけ）
        DemoDataSeeder.seedIfRequested()
        #endif

        NotificationService.shared.requestAuthorization { _ in }

        // 前回の退会で、通信できずに片付けきれなかった共有レコードがあれば続ける
        AccountDeletionCleanup.resumeIfNeeded()

        // 旅行中のライブアクティビティの「更新」ボタン。押されるとアプリが裏で起き、ここで入れた処理が動く
        TravelLiveActivity.registerRefresher()

        // 落ちた・固まった・メモリ不足で止められたことを、MetricKit から受け取って開発者に送る（設定でオフにできる）
        DiagnosticsReporter.shared.start()
    }

    // 明暗の扱いはテーマ側が決める。ライト固定・ダーク固定・システム追従の3つ
    private var preferredScheme: ColorScheme? {
        themeManager.currentTheme.type.preferredColorScheme
    }

    var body: some Scene {
        WindowGroup {
            if let failure = coreData.storeLoadFailure {
                StoreLoadFailureView(failure: failure)
                    .environment(\.locale, Locale(identifier: "ja_JP"))
            } else {
                appContent
            }
        }
    }

    private var appContent: some View {
        SplashScreenView()
            .environmentObject(authViewModel)
            .environment(\.locale, Locale(identifier: "ja_JP"))
            .environment(\.managedObjectContext, CoreDataManager.shared.viewContext)
            .preferredColorScheme(preferredScheme)
            // 「Travory で開く」で .ics が届いたとき（カレンダーの画面で確かめてから入れる）
            .onOpenURL { url in
                // travory://shared は共有メニューから切り替えてきたとき。
                // 受け取り箱は、アプリが前に出たときに MainTabView が見るので、ここでは何もしない
                guard url.isFileURL, url.pathExtension.lowercased() == "ics" else { return }
                ICSImportInbox.shared.open(url)
            }
            .task {
                // 所有を確かめてから、使えなくなったテーマを戻す。
                // 順番が逆だと、購入済みの人のテーマが起動のたびに外れる。
                await ProStore.shared.refreshEntitlements()
                ThemeManager.shared.enforceEntitlement()
            }
    }
}
