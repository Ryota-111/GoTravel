import SwiftUI
import CryptoKit
import FirebaseAuth
import AuthenticationServices

struct AppleAuthView: View {
    
    @Environment(\.colorScheme) var colorScheme
    var isDarkMode: Bool { colorScheme == .dark }
    
    
    
    // MARK: - Firebase用
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError(
                        "Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)"
                    )
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    // MARK: - Firebase用
    @available(iOS 13, *)
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
    // MARK: - Firebase用
    @State  var currentNonce:String?
    
    var body: some View {
        VStack {
            SignInWithAppleButton(.signIn) { request in
                // MARK: - Request
                request.requestedScopes = [.email,.fullName]
                let nonce = randomNonceString()
                currentNonce = nonce
                request.nonce = sha256(nonce)
                
            } onCompletion: { result in
                switch result {
                    // MARK: - Result
                    
                case .success(let authResults):
                    let appleIDCredential = authResults.credential as? ASAuthorizationAppleIDCredential
                    
                    guard let nonce = currentNonce else {
                        fatalError("Invalid state: A login callback was received, but no login request was sent.")
                    }
                    guard let appleIDToken = appleIDCredential?.identityToken else {
                        fatalError("Invalid state: A login callback was received, but no login request was sent.")
                    }
                    guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                        print("Unable to serialize token string from data: \(appleIDToken.debugDescription)")
                        return
                    }
                    
                    let credential = OAuthProvider.appleCredential(withIDToken: idTokenString, rawNonce: nonce, fullName: appleIDCredential?.fullName)
                    Auth.auth().signIn(with: credential) { result, error in
                        if let error = error {
                            print("Firebase sign-in failed: \(error.localizedDescription)")
                            return
                        }
                        if result?.user != nil {
                            print("ログイン")
                        }
                    }
                    
                case .failure(let error):
                    print("Authentication failed: \(error.localizedDescription)")
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
