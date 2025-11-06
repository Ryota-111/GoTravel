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
        }
    }
}
