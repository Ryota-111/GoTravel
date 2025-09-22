import SwiftUI
import FirebaseCore

@main
struct GoTravelApp: App {
    @StateObject private var auth = AuthViewModel()

    init() {
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" {
            if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
                FirebaseApp.configure()
            } else {
                print("GoogleService-Info.plist not found - running without Firebase")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(auth) // ここで注入
        }
    }
}
