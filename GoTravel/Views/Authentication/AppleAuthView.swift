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
                        print("❌ Apple Sign In: Invalid credential")
                        return
                    }

                    // Apple IDのuserIdentifierをuserIdとして使用
                    let userId = appleIDCredential.user
                    print("✅ Apple Sign In successful")
                    print("✅ User ID: \(userId)")

                    // AuthViewModelを更新
                    auth.signInWithApple(userId: userId)

                case .failure(let error):
                    print("❌ Apple Sign In failed: \(error.localizedDescription)")
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
