import SwiftUI

struct PasswordResetView: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.presentationMode) private var presentationMode
    @State private var email: String = ""
    @State private var isLoading: Bool = false
    @State private var message: String?
    @State private var isSuccess: Bool = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("パスワードリセット")) {
                    TextField("登録済みのメールアドレス", text: $email)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                }

                if let msg = message {
                    Section { Text(msg).foregroundColor(isSuccess ? .green : .red) }
                }

                Section {
                    Button(action: sendReset) {
                        if isLoading {
                            HStack { ProgressView(); Text("送信中...") }
                        } else {
                            Text("リセットメールを送信")
                        }
                    }
                    .disabled(isLoading || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("パスワード再設定")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }

    private func sendReset() {
        message = nil
        isSuccess = false
        let mail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !mail.isEmpty else {
            message = "メールアドレスを入力してください"
            return
        }

        isLoading = true
        auth.resetPassword(email: mail) { result in
            isLoading = false
            switch result {
            case .success():
                isSuccess = true
                message = "リセット用のメールを送信しました。メールを確認してください。"
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    presentationMode.wrappedValue.dismiss()
                }
            case .failure(let err):
                isSuccess = false
                message = err.localizedDescription
            }
        }
    }
}

struct PasswordResetView_Previews: PreviewProvider {
    static var previews: some View {
        PasswordResetView()
            .environmentObject(AuthViewModel())
    }
}
