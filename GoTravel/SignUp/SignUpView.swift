import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.presentationMode) private var presentationMode
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var errorMessage: String?
    @State private var isLoading: Bool = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("アカウント")) {
                    TextField("メールアドレス", text: $email)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                    SecureField("パスワード", text: $password)
                    SecureField("パスワード（確認）", text: $confirmPassword)
                }

                if let err = errorMessage {
                    Section {
                        Text(err)
                            .foregroundColor(.red)
                            .font(.subheadline)
                    }
                }

                Section {
                    Button(action: signUpTapped) {
                        if isLoading {
                            HStack {
                                ProgressView()
                                Text("登録中...")
                            }
                        } else {
                            Text("新規登録")
                        }
                    }
                    .disabled(isLoading || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty)
                }
            }
            .navigationTitle("サインアップ")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }

    private func signUpTapped() {
        errorMessage = nil
        let mail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !mail.isEmpty else { errorMessage = "メールアドレスを入力してください"; return }
        guard !password.isEmpty else { errorMessage = "パスワードを入力してください"; return }
        guard password == confirmPassword else { errorMessage = "パスワードが一致しません"; return }

        isLoading = true
        auth.signUp(email: mail, password: password) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success():
                    presentationMode.wrappedValue.dismiss()
                case .failure(let err):
                    errorMessage = err.localizedDescription
                }
            }
        }
    }
}

struct SignUpView_Previews: PreviewProvider {
    static var previews: some View {
        SignUpView()
            .environmentObject(AuthViewModel())
    }
}
