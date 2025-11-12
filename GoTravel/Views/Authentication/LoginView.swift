import SwiftUI

struct LoginView: View {

    // MARK: - Properties
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.presentationMode) private var presentationMode
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    // MARK: - Computed Properties
    private var isSignInDisabled: Bool {
        isLoading || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty
    }

    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                backgroundView
                contentView
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: - View Components
    private var backgroundView: some View {
        LinearGradient(
            gradient: Gradient(colors: [Color.orange.opacity(0.8), Color.brown.opacity(0.6)]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var contentView: some View {
        VStack(spacing: 0) {
            Spacer()

            headerSection

            Spacer()
                .frame(height: 100)

            loginFormSection
            actionLinksSection

            Spacer()
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "paperplane.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.white)

            Text("旅も日常も")
                .font(.system(size: 32, weight: .semibold))
                .foregroundColor(.white)

            Text("ひとつのアプリで")
                .font(.system(size: 32, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal)
    }

    private var loginFormSection: some View {
        VStack(spacing: 16) {
            if let err = errorMessage {
                errorMessageView(err)
            }

            emailField
            passwordField
            signInButton
            AppleAuthView()
        }
        .padding(.horizontal, 40)
    }

    private func errorMessageView(_ message: String) -> some View {
        Text(message)
            .foregroundColor(.red)
            .font(.subheadline)
            .multilineTextAlignment(.center)
            .padding(.bottom, 8)
    }

    private var emailField: some View {
        HStack {
            Image(systemName: "envelope.fill")
                .foregroundColor(.gray)
            TextField("メールアドレス", text: $email)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .textContentType(.emailAddress)
                .foregroundColor(.black)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
    }

    private var passwordField: some View {
        HStack {
            Image(systemName: "lock.fill")
                .foregroundColor(.gray)
            SecureField("パスワード", text: $password)
                .textContentType(.password)
                .foregroundColor(.black)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
    }

    private var signInButton: some View {
        Button(action: signInTapped) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("サインイン")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.black.opacity(0.7))
            .cornerRadius(12)
        }
        .disabled(isSignInDisabled)
        .padding(.top, 8)
    }

    private var actionLinksSection: some View {
        VStack(spacing: 12) {
            Button(action: {}) {
                NavigationLink(destination: PasswordResetView().environmentObject(auth)) {
                    Text("パスワードをお忘れですか？")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.9))
                }
            }

            HStack(spacing: 4) {
                Text("アカウントをお持ちでない方は")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.9))

                NavigationLink(destination: SignUpView().environmentObject(auth)) {
                    Text("アカウント作成")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.top, 20)
    }

    // MARK: - Actions
    private func signInTapped() {
        errorMessage = nil
        let mail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard validateInput(email: mail) else { return }

        isLoading = true
        auth.signIn(email: mail, password: password) { result in
            handleSignInResult(result)
        }
    }

    private func validateInput(email: String) -> Bool {
        guard !email.isEmpty else {
            errorMessage = "メールアドレスを入力してください"
            return false
        }
        guard !password.isEmpty else {
            errorMessage = "パスワードを入力してください"
            return false
        }
        return true
    }

    private func handleSignInResult(_ result: Result<Void, Error>) {
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

fileprivate struct BlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(AuthViewModel())
    }
}
