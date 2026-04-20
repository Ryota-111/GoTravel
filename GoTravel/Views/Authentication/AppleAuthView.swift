import SwiftUI
import AuthenticationServices

struct AppleAuthView: View {

    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.colorScheme) var colorScheme
    var isDarkMode: Bool { colorScheme == .dark }

    var body: some View {
        VStack {
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.email, .fullName]

            } onCompletion: { result in
                switch result {
                case .success(let authResults):
                    guard let appleIDCredential = authResults.credential as? ASAuthorizationAppleIDCredential else {
                        return
                    }

                    // Apple IDのuserIdentifierをuserIdとして使用
                    let userId = appleIDCredential.user

                    // 名前とメールアドレスを取得（初回サインイン時のみ取得可能）
                    var fullName: String? = nil
                    if let givenName = appleIDCredential.fullName?.givenName,
                       let familyName = appleIDCredential.fullName?.familyName {
                        fullName = "\(familyName) \(givenName)"
                    }

                    let email = appleIDCredential.email

                    // AuthViewModelを更新
                    auth.signInWithApple(userId: userId, fullName: fullName, email: email)

                case .failure:
                    break
                }
            }
            .signInWithAppleButtonStyle(isDarkMode ? .white : .black)
            .frame(width: 224, height: 40)
        }
    }
}

#Preview {
    AppleAuthView()
}
