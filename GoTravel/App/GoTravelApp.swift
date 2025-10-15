import SwiftUI
import FirebaseCore

@main
struct GoTravelApp: App {
    @StateObject private var authViewModel: AuthViewModel

    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        let avm = AuthViewModel()
        _authViewModel = StateObject(wrappedValue: avm)

        // 通知の権限をリクエスト
        NotificationService.shared.requestAuthorization { granted in
            if granted {
                print("通知権限が許可されました")
                // 詳細なステータスを確認
                NotificationService.shared.checkAuthorizationStatus { status in
                    print("通知ステータス: \(status.rawValue)")
                    switch status {
                    case .authorized:
                        print("   → 許可済み")
                    case .denied:
                        print("   → 拒否済み")
                    case .notDetermined:
                        print("   → 未決定")
                    case .provisional:
                        print("   → 仮許可")
                    case .ephemeral:
                        print("   → 一時的")
                    @unknown default:
                        print("   → 不明")
                    }
                }
            } else {
                print("⚠️ 通知権限が拒否されました")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            SplashScreenView()
                .environmentObject(authViewModel)
                .environment(\.locale, Locale(identifier: "ja_JP"))
        }
    }
}
