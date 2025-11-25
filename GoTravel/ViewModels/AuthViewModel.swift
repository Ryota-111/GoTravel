import Foundation
import Combine

final class AuthViewModel: ObservableObject {
    @Published var isSignedIn: Bool = false
    @Published var userId: String?

    private let userIdKey = "appleSignInUserId"
    private let userDefaults = UserDefaults.standard

    init() {
        print("🔐 [AuthViewModel] Initializing...")
        // UserDefaultsから保存されたユーザーIDを復元
        if let savedUserId = userDefaults.string(forKey: userIdKey) {
            self.userId = savedUserId
            self.isSignedIn = true
            print("✅ [AuthViewModel] Restored userId from UserDefaults: \(savedUserId)")
        } else {
            print("⚠️ [AuthViewModel] No userId found in UserDefaults")
        }
        print("🔐 [AuthViewModel] isSignedIn: \(self.isSignedIn)")
    }

    // Apple Sign Inでのサインイン
    func signInWithApple(userId: String) {
        print("🔐 [AuthViewModel] signInWithApple() called with userId: \(userId)")
        DispatchQueue.main.async {
            self.userId = userId
            self.isSignedIn = true
            self.userDefaults.set(userId, forKey: self.userIdKey)
            print("✅ [AuthViewModel] Sign in successful, userId saved to UserDefaults")
            print("✅ [AuthViewModel] isSignedIn: \(self.isSignedIn)")
        }
    }

    // サインアウト
    func signOut() {
        print("🔐 [AuthViewModel] signOut() called")
        DispatchQueue.main.async {
            self.isSignedIn = false
            self.userId = nil
            self.userDefaults.removeObject(forKey: self.userIdKey)
            print("✅ [AuthViewModel] Sign out successful")
            print("✅ [AuthViewModel] isSignedIn: \(self.isSignedIn)")
        }
    }

    // アカウント削除
    func deleteAccount() {
        print("🔐 [AuthViewModel] deleteAccount() called")
        DispatchQueue.main.async {
            // ローカルデータを削除
            self.isSignedIn = false
            self.userId = nil
            self.userDefaults.removeObject(forKey: self.userIdKey)

            // プロフィールデータを削除
            self.userDefaults.removeObject(forKey: "profile_v1")

            // CloudKitのデータは残るが、ローカルの認証情報を削除することで
            // 再ログインしない限りアクセスできなくなる
            print("✅ [AuthViewModel] Account deleted, local data cleared")
            print("✅ [AuthViewModel] isSignedIn: \(self.isSignedIn)")
        }
    }
}
