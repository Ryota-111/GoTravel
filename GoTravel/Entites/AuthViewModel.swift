import Foundation
import FirebaseAuth
import Combine

final class AuthViewModel: ObservableObject {
    @Published var isSignedIn: Bool = false
    @Published var userId: String?

    private var handle: AuthStateDidChangeListenerHandle?

    init() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.isSignedIn = (user != nil)
                self?.userId = user?.uid
            }
        }
        let currentUser = Auth.auth().currentUser
        self.isSignedIn = (currentUser != nil)
        self.userId = currentUser?.uid
    }

    deinit {
        if let h = handle { Auth.auth().removeStateDidChangeListener(h) }
    }

    func signIn(email: String, password: String, completion: ((Result<Void, Error>) -> Void)? = nil) {
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            DispatchQueue.main.async {
                if let err = error { completion?(.failure(err)); return }
                self.isSignedIn = (Auth.auth().currentUser != nil)
                self.userId = Auth.auth().currentUser?.uid
                completion?(.success(()))
            }
        }
    }

    func signUp(email: String, password: String, completion: ((Result<Void, Error>) -> Void)? = nil) {
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            DispatchQueue.main.async {
                if let err = error { completion?(.failure(err)); return }
                self.isSignedIn = (Auth.auth().currentUser != nil)
                self.userId = Auth.auth().currentUser?.uid
                completion?(.success(()))
            }
        }
    }

    func signOut() throws {
        try Auth.auth().signOut()
        DispatchQueue.main.async {
            self.isSignedIn = false
            self.userId = nil
        }
    }

    func resetPassword(email: String, completion: ((Result<Void, Error>) -> Void)? = nil) {
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            DispatchQueue.main.async {
                if let err = error { completion?(.failure(err)); return }
                completion?(.success(()))
            }
        }
    }
}
