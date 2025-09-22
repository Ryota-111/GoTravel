import SwiftUI
import FirebaseCore

@main
struct GoTravelApp_LoginExample: App {
    init() {
        let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        if isPreview {
            print("[App] Running in Preview - skip Firebase configure")
        } else {
            if let _ = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") {
                FirebaseApp.configure()
                print("[App] Firebase configured")
            } else {
                print("[App] WARNING: GoogleService-Info.plist not found - skipping Firebase")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
