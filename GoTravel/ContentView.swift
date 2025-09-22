import SwiftUI

struct ContentView: View {
    @EnvironmentObject var auth: AuthViewModel

    var body: some View {
        Group {
            if auth.isSignedIn {
                MainTabView() // ログイン済みユーザーが見るメイン画面（マップ / リスト等）
            } else {
                LoginView()   // 未ログインはログイン画面
            }
        }
        .animation(.easeInOut, value: auth.isSignedIn)
        .transition(.opacity)
    }
}
