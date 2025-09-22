import SwiftUI

struct PasswordResetView: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var email = ""
    @State private var message: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                TextField("登録したメールアドレス", text: $email)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)

                if let m = message {
                    Text(m)
                        .foregroundColor(.secondary)
                }

                Button("パスワードリセットメールを送信") {
                    auth.sendPasswordReset(email: email) { success, error in
                        if success {
                            message = "リセットメールを送信しました。メールを確認してください。"
                        } else {
                            message = error
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)

                Spacer()
            }
            .padding()
            .navigationTitle("パスワードをリセット")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
}
