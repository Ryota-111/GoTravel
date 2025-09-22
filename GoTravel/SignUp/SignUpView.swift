import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var email = ""
    @State private var password = ""
    @State private var errorLocal: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                TextField("メールアドレス", text: $email)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)

                SecureField("パスワード（6文字以上）", text: $password)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)

                if let e = errorLocal ?? auth.errorMessage {
                    Text(e)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button("登録") {
                    auth.signUp(email: email, password: password) { success, error in
                        if success {
                            presentationMode.wrappedValue.dismiss()
                        } else {
                            errorLocal = error
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
            .navigationTitle("新規登録")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
}
