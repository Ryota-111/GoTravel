import Foundation
import Combine

final class AuthViewModel: ObservableObject {
    @Published var isSignedIn: Bool = false
    @Published var userId: String?
    @Published var userFullName: String?
    @Published var userEmail: String?

    private let userIdKey = "appleSignInUserId"
    private let userFullNameKey = "appleSignInUserFullName"
    private let userEmailKey = "appleSignInUserEmail"
    private let userDefaults = UserDefaults.standard

    init() {
        print("🔐 [AuthViewModel] Initializing...")
        // UserDefaultsから保存されたユーザー情報を復元
        if let savedUserId = userDefaults.string(forKey: userIdKey) {
            self.userId = savedUserId
            self.userFullName = userDefaults.string(forKey: userFullNameKey)
            self.userEmail = userDefaults.string(forKey: userEmailKey)
            self.isSignedIn = true
            print("✅ [AuthViewModel] Restored userId from UserDefaults: \(savedUserId)")
            print("✅ [AuthViewModel] Restored name: \(userFullName ?? "nil"), email: \(userEmail ?? "nil")")
        } else {
            print("⚠️ [AuthViewModel] No userId found in UserDefaults")
        }
        print("🔐 [AuthViewModel] isSignedIn: \(self.isSignedIn)")
    }

    // Apple Sign Inでのサインイン
    func signInWithApple(userId: String, fullName: String? = nil, email: String? = nil) {
        print("🔐 [AuthViewModel] signInWithApple() called with userId: \(userId)")
        print("🔐 [AuthViewModel] - fullName: \(fullName ?? "nil"), email: \(email ?? "nil")")
        DispatchQueue.main.async {
            self.userId = userId
            self.isSignedIn = true
            self.userDefaults.set(userId, forKey: self.userIdKey)

            // 名前とメールアドレスが提供された場合のみ保存（初回サインイン時）
            if let fullName = fullName {
                self.userFullName = fullName
                self.userDefaults.set(fullName, forKey: self.userFullNameKey)
                print("✅ [AuthViewModel] Full name saved: \(fullName)")
            }
            if let email = email {
                self.userEmail = email
                self.userDefaults.set(email, forKey: self.userEmailKey)
                print("✅ [AuthViewModel] Email saved: \(email)")
            }

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
            self.userFullName = nil
            self.userEmail = nil
            self.userDefaults.removeObject(forKey: self.userIdKey)
            self.userDefaults.removeObject(forKey: self.userFullNameKey)
            self.userDefaults.removeObject(forKey: self.userEmailKey)
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
            self.userFullName = nil
            self.userEmail = nil
            self.userDefaults.removeObject(forKey: self.userIdKey)
            self.userDefaults.removeObject(forKey: self.userFullNameKey)
            self.userDefaults.removeObject(forKey: self.userEmailKey)

            // プロフィールデータを削除
            self.userDefaults.removeObject(forKey: "profile_v1")

            // CloudKitのデータは残るが、ローカルの認証情報を削除することで
            // 再ログインしない限りアクセスできなくなる
            print("✅ [AuthViewModel] Account deleted, local data cleared")
            print("✅ [AuthViewModel] isSignedIn: \(self.isSignedIn)")
        }
    }
}
