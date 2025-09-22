import Foundation
import FirebaseAuth
import Combine

final class AuthViewModel: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var userEmail: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private var handle: AuthStateDidChangeListenerHandle?

    init() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            DispatchQueue.main.async {
                if let user = user {
                    self?.isLoggedIn = true
                    self?.userEmail = user.email ?? ""
                } else {
                    self?.isLoggedIn = false
                    self?.userEmail = ""
                }
            }
        }
    }

    deinit {
        if let h = handle {
            Auth.auth().removeStateDidChangeListener(h)
        }
    }

    func signIn(email: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        errorMessage = nil
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty else {
            completion(false, "メールアドレスを入力してください")
            return
        }
        guard !password.isEmpty else {
            completion(false, "パスワードを入力してください")
            return
        }

        isLoading = true
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error {
                    let msg = error.localizedDescription
                    self?.errorMessage = msg
                    completion(false, msg)
                    return
                }
                completion(true, nil)
            }
        }
    }

    func signUp(email: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        errorMessage = nil
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty else {
            completion(false, "メールアドレスを入力してください")
            return
        }
        guard password.count >= 6 else {
            completion(false, "パスワードは6文字以上にしてください")
            return
        }

        isLoading = true
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error {
                    let msg = error.localizedDescription
                    self?.errorMessage = msg
                    completion(false, msg)
                    return
                }
                completion(true, nil)
            }
        }
    }

    func sendPasswordReset(email: String, completion: @escaping (Bool, String?) -> Void) {
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty else {
            completion(false, "メールアドレスを入力してください")
            return
        }
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, error.localizedDescription)
                } else {
                    completion(true, nil)
                }
            }
        }
    }

    func signOut() -> Bool {
        do {
            try Auth.auth().signOut()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    func logout() {
        _ = signOut()
    }
}
