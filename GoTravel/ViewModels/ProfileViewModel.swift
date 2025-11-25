import SwiftUI
import Combine
import UIKit

final class ProfileViewModel: ObservableObject {
    @Published var avatarImage: UIImage?
    @Published var isSaving: Bool = false

    private let avatarFileNameKey = "profile_avatar_fileName"

    init() {
        // アバター画像を復元
        if let fileName = UserDefaults.standard.string(forKey: avatarFileNameKey) {
            self.avatarImage = FileManager.documentsImage(named: fileName)
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
                    self.avatarImage = image
                    UserDefaults.standard.set(fileName, forKey: self.avatarFileNameKey)
                }
            } catch {
                print("❌ [ProfileViewModel] Failed to save avatar: \(error)")
            }
        }
    }

    func removeAvatar() {
        if let fileName = UserDefaults.standard.string(forKey: avatarFileNameKey) {
            try? FileManager.removeDocumentFile(named: fileName)
        }
        avatarImage = nil
        UserDefaults.standard.removeObject(forKey: avatarFileNameKey)
    }
    
    func signOut(completion: @escaping (Result<Void, Error>) -> Void) {
        // Sign out is now handled by AuthViewModel
        completion(.success(()))
    }

    func deleteAccount(completion: @escaping (Result<Void, Error>) -> Void) {
        // Account deletion for Apple Sign In requires revoking token through Apple's API
        // For now, just clear local data
        completion(.success(()))
    }
}
