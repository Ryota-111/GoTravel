import SwiftUI
import FirebaseCore

@main
struct GoTravelApp: App {
    @StateObject private var authViewModel: AuthViewModel

    init() {
        // FirebaseApp を一度だけ確実に初期化する
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        // AuthViewModel 等、Firebase を参照する ViewModel はここで生成する
        let avm = AuthViewModel() // 既存の実装に合わせて調整
        _authViewModel = StateObject(wrappedValue: avm)

        // その他の初期化（必要なら）
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
        }
    }
}
