import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthViewModel
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var errorMessageLocal: String? = nil
    @State private var showingSignUp: Bool = false
    @State private var showingReset: Bool = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "airplane")
                    .resizable()
                    .frame(width: 72, height: 72)
                    .foregroundColor(.blue)
                Text("GoTravel")
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }

            VStack(spacing: 12) {
                TextField("メールアドレス", text: $email)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)

                SecureField("パスワード", text: $password)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
            .padding(.horizontal)

            if let message = errorMessageLocal ?? auth.errorMessage {
                Text(message)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button(action: {
                errorMessageLocal = nil
                auth.signIn(email: email, password: password) { success, error in
                    if !success {
                        errorMessageLocal = error
                    }
                }
            }) {
                HStack {
                    if auth.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    }
                    Text("ログイン")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(auth.isLoading)
            .padding(.horizontal)

            Spacer()

            HStack {
                Button("パスワードを忘れた") {
                    showingReset = true
                }
                Spacer()
                Button("新規登録") {
                    showingSignUp = true
                }
            }
            .padding(.horizontal)
            .font(.footnote)
            .foregroundColor(.secondary)
            .padding(.bottom, 16)
        }
        .padding()
        .sheet(isPresented: $showingSignUp) {
            SignUpView()
                .environmentObject(auth)
        }
        .sheet(isPresented: $showingReset) {
            PasswordResetView()
                .environmentObject(auth)
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(AuthViewModel())
    }
}
