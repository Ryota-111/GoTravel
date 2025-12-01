import SwiftUI

@main
struct GoTravelApp: App {
    @StateObject private var authViewModel: AuthViewModel

    init() {
        let avm = AuthViewModel()
        _authViewModel = StateObject(wrappedValue: avm)

        // Core Dataの初期化（CloudKitとの自動同期を有効化）
        _ = CoreDataManager.shared

        NotificationService.shared.requestAuthorization { granted in
            if granted {
                NotificationService.shared.checkAuthorizationStatus { status in
                    switch status {
                    case .authorized:
                        break
                    case .denied:
                        break
                    case .notDetermined:
                        break
                    case .provisional:
                        break
                    case .ephemeral:
                        break
                    @unknown default:
                        break
                    }
                }
            } else {
                // Authorization denied
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            SplashScreenView()
                .environmentObject(authViewModel)
                .environment(\.locale, Locale(identifier: "ja_JP"))
                .environment(\.managedObjectContext, CoreDataManager.shared.viewContext)
        }
    }
}
