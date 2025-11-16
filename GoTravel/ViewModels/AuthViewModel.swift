import Foundation
import Combine

final class AuthViewModel: ObservableObject {
    @Published var isSignedIn: Bool = false
    @Published var userId: String?

    private let userIdKey = "appleSignInUserId"
    private let userDefaults = UserDefaults.standard

    init() {
        // UserDefaultsから保存されたユーザーIDを復元
        if let savedUserId = userDefaults.string(forKey: userIdKey) {
            self.userId = savedUserId
            self.isSignedIn = true
        }
    }

    // Apple Sign Inでのサインイン
    func signInWithApple(userId: String) {
        DispatchQueue.main.async {
            self.userId = userId
            self.isSignedIn = true
            self.userDefaults.set(userId, forKey: self.userIdKey)
        }
    }

    // サインアウト
    func signOut() {
        DispatchQueue.main.async {
            self.isSignedIn = false
            self.userId = nil
            self.userDefaults.removeObject(forKey: self.userIdKey)
        }
    }
}
