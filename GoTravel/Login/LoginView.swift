import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            TextField("メール", text: $email).autocapitalization(.none).textFieldStyle(.roundedBorder)
            SecureField("パスワード", text: $password).textFieldStyle(.roundedBorder)
            if let err = errorMessage { Text(err).foregroundColor(.red) }
            Button("ログイン") {
                auth.signIn(email: email, password: password) { result in
                    switch result {
                    case .success(): break // AuthViewModel が状態を更新するので何もしなくて良い
                    case .failure(let error):
                        errorMessage = error.localizedDescription
                    }
                }
            }
            Button("新規登録") {
                // SignUpView を sheet で出すなど
            }
        }
        .padding()
    }
}
