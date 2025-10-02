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

    private var signInButtonText: String {
        isLoading ? "サインイン中..." : "サインイン"
    }

    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                backgroundView
                Color.black.opacity(0.25).ignoresSafeArea()
                contentView
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: - View Components
    private var backgroundView: some View {
        Group {
            if UIImage(named: "airplane") != nil {
                Image("airplane")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            } else {
                fallbackBackground
            }
        }
    }

    private var fallbackBackground: some View {
        ZStack {
            Color("Background")
                .opacity(0.6)
                .ignoresSafeArea()
            Image(systemName: "airplane")
                .resizable()
                .scaledToFit()
                .frame(width: 200, height: 200)
                .foregroundColor(.white.opacity(0.08))
                .rotationEffect(.degrees(-15))
                .offset(x: 40, y: -80)
        }
    }

    private var contentView: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 40)
            headerSection
            loginFormSection
            Spacer()
        }
        .padding(.bottom, 40)
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("GoTravel")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Text("旅の記録を、いつでもどこでも")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal)
    }

    private var loginFormSection: some View {
        VStack(spacing: 16) {
            if let err = errorMessage {
                errorMessageView(err)
            }

            inputFieldsSection
            signInButton
            actionLinksSection
        }
        .padding()
        .background(BlurView(style: .systemThinMaterialDark).opacity(0.85))
        .cornerRadius(14)
        .padding(.horizontal, 20)
    }

    private func errorMessageView(_ message: String) -> some View {
        Text(message)
            .foregroundColor(.red)
            .font(.subheadline)
            .multilineTextAlignment(.center)
            .padding(.top, 6)
    }

    private var inputFieldsSection: some View {
        Group {
            emailField
            passwordField
        }
    }

    private var emailField: some View {
        TextField("メールアドレス", text: $email)
            .keyboardType(.emailAddress)
            .autocapitalization(.none)
            .textContentType(.emailAddress)
            .padding()
            .background(Color(.systemBackground).opacity(0.9))
            .cornerRadius(8)
    }

    private var passwordField: some View {
        SecureField("パスワード", text: $password)
            .textContentType(.password)
            .padding()
            .background(Color(.systemBackground).opacity(0.9))
            .cornerRadius(8)
    }

    private var signInButton: some View {
        Button(action: signInTapped) {
            HStack {
                if isLoading {
                    ProgressView()
                }
                Text(signInButtonText)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .disabled(isSignInDisabled)
    }

    private var actionLinksSection: some View {
        HStack {
            passwordResetLink
            Spacer()
            signUpLink
        }
        .padding(.top, 6)
    }

    private var passwordResetLink: some View {
        Button(action: {}) {
            NavigationLink(destination: PasswordResetView().environmentObject(auth)) {
                Text("パスワードを忘れた場合")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.9))
            }
        }
    }

    private var signUpLink: some View {
        NavigationLink(destination: SignUpView().environmentObject(auth)) {
            Text("新規登録")
                .font(.footnote)
                .foregroundColor(.white.opacity(0.9))
        }
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
