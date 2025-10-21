import SwiftUI
import Combine
import UIKit
import FirebaseAuth

final class ProfileViewModel: ObservableObject {
    @Published var profile: Profile
    @Published var avatarImage: UIImage?
    @Published var isSaving: Bool = false

    private let defaultsKey = "profile_v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode(Profile.self, from: data) {
            self.profile = decoded
            if let fileName = decoded.avatarImageFileName {
                self.avatarImage = FileManager.documentsImage(named: fileName)
            } else {
                self.avatarImage = nil
            }
        } else {
            self.profile = .default
            self.avatarImage = nil
        }
    }

    func saveProfile() {
        isSaving = true
        defer { isSaving = false }
        if let encoded = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(encoded, forKey: defaultsKey)
        }
    }

    func saveAvatar(_ image: UIImage) {
        isSaving = true
        DispatchQueue.global(qos: .userInitiated).async {
            defer { DispatchQueue.main.async { self.isSaving = false } }
            guard let data = image.jpegData(compressionQuality: 0.85) else { return }
            let fileName = "profile_avatar.jpg"
            do {
                try FileManager.saveImageDataToDocuments(data: data, named: fileName)
                DispatchQueue.main.async {
                    self.profile.avatarImageFileName = fileName
                    self.avatarImage = image
                    self.saveProfile()
                }
            } catch {
                print("Failed to save avatar image:", error)
            }
        }
    }

    func removeAvatar() {
        if let fileName = profile.avatarImageFileName {
            try? FileManager.removeDocumentFile(named: fileName)
        }
        profile.avatarImageFileName = nil
        avatarImage = nil
        saveProfile()
    }
    
    func signOut(completion: @escaping (Result<Void, Error>) -> Void) {
            do {
                try Auth.auth().signOut()
                print("Signed out")
            } catch {
                print("Sign out failed: \(error.localizedDescription)")
            }
        }

        func deleteAccount(completion: @escaping (Result<Void, Error>) -> Void) {
            guard let user = Auth.auth().currentUser else {
                completion(.failure(NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user logged in"])))
                return
            }

            user.delete { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }
}
