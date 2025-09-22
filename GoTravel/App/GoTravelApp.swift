import SwiftUI
import FirebaseCore

@main
struct GoTravelApp: App {
    @StateObject private var auth: AuthViewModel

    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        let vm = AuthViewModel()
        _auth = StateObject(wrappedValue: vm)

        // e.g. FirebaseConfiguration.shared.setLoggerLevel(.min)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(auth)
        }
    }
}
