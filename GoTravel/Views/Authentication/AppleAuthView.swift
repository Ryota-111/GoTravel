import SwiftUI
import AuthenticationServices

struct AppleAuthView: View {

    @EnvironmentObject var auth: AuthViewModel

    /// 青い背景の上に置くので、既定は白
    var buttonStyle: SignInWithAppleButton.Style = .white
    /// サインインに失敗したとき（自分で閉じたときは呼ばない）
    var onFailure: (() -> Void)?

    var body: some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.email, .fullName]

        } onCompletion: { result in
            switch result {
            case .success(let authResults):
                guard let appleIDCredential = authResults.credential as? ASAuthorizationAppleIDCredential else {
                    onFailure?()
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

            case .failure(let error):
                // 自分でやめたときは何も言わない
                if (error as? ASAuthorizationError)?.code == .canceled { return }
                onFailure?()
            }
        }
        .signInWithAppleButtonStyle(buttonStyle)
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#Preview {
    AppleAuthView()
}
