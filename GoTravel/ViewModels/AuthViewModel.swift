import Foundation
import Combine

final class AuthViewModel: ObservableObject {
    @Published var isSignedIn: Bool = false
    @Published var userId: String?
    @Published var userFullName: String?
    @Published var userEmail: String?

    private let userIdKey = "appleSignInUserId"
    private let userDefaults = UserDefaults.standard

    /// 名前とメールはユーザーごとに保存する。
    ///
    /// **Apple は `fullName` と `email` を初回の認証でしか返さない。**
    /// 2回目以降は必ず nil になるため、サインアウトで消してしまうと二度と取れない。
    /// 以前は共通のキー1つに入れてサインアウトで消していたので、
    /// 入り直したあとプロフィールが空になっていた。
    ///
    /// ユーザーごとに分けるのは、別のアカウントで入ったときに
    /// 前の人の名前が残って見えないようにするため
    private func fullNameKey(for userId: String) -> String { "appleSignInUserFullName_\(userId)" }
    private func emailKey(for userId: String) -> String { "appleSignInUserEmail_\(userId)" }

    // 共通キーだった頃の保存先。移行にだけ使う
    private let legacyFullNameKey = "appleSignInUserFullName"
    private let legacyEmailKey = "appleSignInUserEmail"

    init() {
        // UserDefaultsから保存されたユーザー情報を復元
        if let savedUserId = userDefaults.string(forKey: userIdKey) {
            migrateLegacyProfileIfNeeded(userId: savedUserId)

            self.userId = savedUserId
            self.userFullName = userDefaults.string(forKey: fullNameKey(for: savedUserId))
            self.userEmail = userDefaults.string(forKey: emailKey(for: savedUserId))
            self.isSignedIn = true
        } else {
        }
    }

    /// 共通キーに入っている名前・メールを、今のユーザーのものとして引き継ぐ
    private func migrateLegacyProfileIfNeeded(userId: String) {
        if userDefaults.string(forKey: fullNameKey(for: userId)) == nil,
           let legacyName = userDefaults.string(forKey: legacyFullNameKey) {
            userDefaults.set(legacyName, forKey: fullNameKey(for: userId))
        }

        if userDefaults.string(forKey: emailKey(for: userId)) == nil,
           let legacyEmail = userDefaults.string(forKey: legacyEmailKey) {
            userDefaults.set(legacyEmail, forKey: emailKey(for: userId))
        }
    }

    // Apple Sign Inでのサインイン
    func signInWithApple(userId: String, fullName: String? = nil, email: String? = nil) {
        DispatchQueue.main.async {
            self.userId = userId
            self.isSignedIn = true
            self.userDefaults.set(userId, forKey: self.userIdKey)

            // 初回の認証だけ値が来る。来たときに保存する
            if let fullName {
                self.userDefaults.set(fullName, forKey: self.fullNameKey(for: userId))
            }
            if let email {
                self.userDefaults.set(email, forKey: self.emailKey(for: userId))
            }

            // 2回目以降は nil で来るので、保存してあるものを出す
            self.userFullName = self.userDefaults.string(forKey: self.fullNameKey(for: userId))
            self.userEmail = self.userDefaults.string(forKey: self.emailKey(for: userId))
        }
    }

    /// プロフィールの名前とメールを自分で書き換える。
    ///
    /// Apple から貰えるのは初回の認証の1回きりで、取り直す手段がない。
    /// 表示専用にしていると、一度失った人に打つ手が無くなるので編集できるようにしてある。
    /// ここで変えるのは表示だけで、認証にも `userId` にも影響しない
    func updateProfile(fullName: String?, email: String?) {
        guard let userId else { return }

        let trimmedName = fullName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email?.trimmingCharacters(in: .whitespacesAndNewlines)

        // 空にしたときは「未設定」に戻す
        if let trimmedName, !trimmedName.isEmpty {
            userDefaults.set(trimmedName, forKey: fullNameKey(for: userId))
        } else {
            userDefaults.removeObject(forKey: fullNameKey(for: userId))
        }

        if let trimmedEmail, !trimmedEmail.isEmpty {
            userDefaults.set(trimmedEmail, forKey: emailKey(for: userId))
        } else {
            userDefaults.removeObject(forKey: emailKey(for: userId))
        }

        userFullName = userDefaults.string(forKey: fullNameKey(for: userId))
        userEmail = userDefaults.string(forKey: emailKey(for: userId))
    }

    // サインアウト
    func signOut() {
        DispatchQueue.main.async {
            self.isSignedIn = false
            self.userId = nil
            self.userFullName = nil
            self.userEmail = nil
            self.userDefaults.removeObject(forKey: self.userIdKey)

            // 名前とメールは消さない。消すと Apple から取り直せず、
            // 同じアカウントで入り直しても空のままになる
        }
    }

    // アカウント削除
    func deleteAccount() {
        // Core Data上のユーザーデータを削除（CloudKitへも削除が同期される）
        if let userId = userId {
            // アルバムは写真ファイルも消す必要があるため専用の処理を通す
            AlbumManager.shared.deleteAllData(userId: userId)
            PlaceCategoryManager.shared.deleteAllData(userId: userId)
            PlanTagManager.shared.deleteAllData(userId: userId)
            CoreDataManager.shared.deleteAllUserData(userId: userId)
        }

        let deletedUserId = userId

        DispatchQueue.main.async {
            // ローカルデータを削除
            self.isSignedIn = false
            self.userId = nil
            self.userFullName = nil
            self.userEmail = nil
            self.userDefaults.removeObject(forKey: self.userIdKey)

            // 退会なので、こちらは名前とメールも消す（サインアウトとの違い）
            if let deletedUserId {
                self.userDefaults.removeObject(forKey: self.fullNameKey(for: deletedUserId))
                self.userDefaults.removeObject(forKey: self.emailKey(for: deletedUserId))
            }
            self.userDefaults.removeObject(forKey: self.legacyFullNameKey)
            self.userDefaults.removeObject(forKey: self.legacyEmailKey)

            // プロフィールデータを削除
            self.userDefaults.removeObject(forKey: "profile_v1")
        }
    }
}
