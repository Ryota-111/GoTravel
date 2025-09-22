import SwiftUI

struct HomeView: View {
    @EnvironmentObject var auth: AuthViewModel

    var body: some View {
        VStack(spacing: 16) {
            Text("ようこそ")
                .font(.title)

            // ユーザ名表示（Optional を安全に扱う例）
            Text(auth.userId ?? "ゲスト")
                .foregroundColor(.secondary)

            // 例: ログイン状態で表示を切り替える
            if auth.isSignedIn {
                Text("ログイン済みです")
                Button("サインアウト") {
                    try? auth.signOut()
                }
            } else {
                Text("未ログインです")
                NavigationLink("ログインへ") {
                    LoginView() // LoginView でも .environmentObject(auth) が必要なら親が注入しているはず
                }
            }
        }
        .padding()
    }
}
