import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.presentationMode) private var presentationMode

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            ZStack {
                Group {
                    if UIImage(named: "airplane") != nil {
                        Image("airplane")
                            .resizable()
                            .scaledToFill()
                            .ignoresSafeArea()
                    } else {
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
                
                Color.black.opacity(0.25).ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer().frame(height: 40)
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

                    VStack(spacing: 16) {
                        if let err = errorMessage {
                            Text(err)
                                .foregroundColor(.red)
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                                .padding(.top, 6)
                        }

                        Group {
                            TextField("メールアドレス", text: $email)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .textContentType(.emailAddress)
                                .padding()
                                .background(Color(.systemBackground).opacity(0.9))
                                .cornerRadius(8)

                            SecureField("パスワード", text: $password)
                                .textContentType(.password)
                                .padding()
                                .background(Color(.systemBackground).opacity(0.9))
                                .cornerRadius(8)
                        }

                        Button(action: signInTapped) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                }
                                Text(isLoading ? "サインイン中..." : "サインイン")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(isLoading || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty)

                        HStack {
                            Button(action: {
                            }) {
                                NavigationLink(destination: PasswordResetView().environmentObject(auth)) {
                                    Text("パスワードを忘れた場合")
                                        .font(.footnote)
                                        .foregroundColor(.white.opacity(0.9))
                                }
                            }

                            Spacer()

                            NavigationLink(destination: SignUpView().environmentObject(auth)) {
                                Text("新規登録")
                                    .font(.footnote)
                                    .foregroundColor(.white.opacity(0.9))
                            }
                        }
                        .padding(.top, 6)
                    }
                    .padding()
                    .background(BlurView(style: .systemThinMaterialDark).opacity(0.85))
                    .cornerRadius(14)
                    .padding(.horizontal, 20)

                    Spacer()
                }
                .padding(.bottom, 40)
            }
            .navigationBarHidden(true)
        }
    }

    private func signInTapped() {
        errorMessage = nil
        let mail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !mail.isEmpty else { errorMessage = "メールアドレスを入力してください"; return }
        guard !password.isEmpty else { errorMessage = "パスワードを入力してください"; return }

        isLoading = true
        auth.signIn(email: mail, password: password) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success():
                    // ログイン成功: 親のルートが状態を監視して画面を切り替える想定
                    presentationMode.wrappedValue.dismiss()
                case .failure(let err):
                    errorMessage = err.localizedDescription
                }
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
