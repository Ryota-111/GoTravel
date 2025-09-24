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

    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
        }
    }
}
