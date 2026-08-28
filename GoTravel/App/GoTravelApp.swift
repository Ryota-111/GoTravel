import SwiftUI

@main
struct GoTravelApp: App {
    @StateObject private var authViewModel: AuthViewModel
    @ObservedObject private var themeManager = ThemeManager.shared

    init() {
        let avm = AuthViewModel()
        _authViewModel = StateObject(wrappedValue: avm)

        // Core Dataの初期化（CloudKitとの自動同期を有効化）
        _ = CoreDataManager.shared

        NotificationService.shared.requestAuthorization { _ in }
    }

    // ダークの配色を持つテーマだけシステムに従う。持たないものはライト固定
    private var preferredScheme: ColorScheme? {
        themeManager.currentTheme.type.followsSystemAppearance ? nil : .light
    }

    var body: some Scene {
        WindowGroup {
            SplashScreenView()
                .environmentObject(authViewModel)
                .environment(\.locale, Locale(identifier: "ja_JP"))
                .environment(\.managedObjectContext, CoreDataManager.shared.viewContext)
                .preferredColorScheme(preferredScheme)
                .task {
                    // 所有を確かめてから、使えなくなったテーマを戻す。
                    // 順番が逆だと、購入済みの人のテーマが起動のたびに外れる。
                    await ProStore.shared.refreshEntitlements()
                    ThemeManager.shared.enforceEntitlement()
                }
        }
    }
}
