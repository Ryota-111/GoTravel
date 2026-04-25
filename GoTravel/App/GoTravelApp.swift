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

    // originalColor のみシステムのダークモードに従う。それ以外は常にライトモード固定
    private var preferredScheme: ColorScheme? {
        themeManager.currentTheme.type == .originalColor ? nil : .light
    }

    var body: some Scene {
        WindowGroup {
            SplashScreenView()
                .environmentObject(authViewModel)
                .environment(\.locale, Locale(identifier: "ja_JP"))
                .environment(\.managedObjectContext, CoreDataManager.shared.viewContext)
                .preferredColorScheme(preferredScheme)
        }
    }
}
