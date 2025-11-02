import Foundation
import SwiftUI
import Combine

// MARK: - Album Manager
class AlbumManager: ObservableObject {
    static let shared = AlbumManager()

    @Published var albums: [Album] = []

    private let fileManager = FileManager.default
    private let albumsKey = "SavedAlbums"

    private var albumsDirectory: URL {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        let albumsDir = documentsDirectory.appendingPathComponent("Albums")

        if !fileManager.fileExists(atPath: albumsDir.path) {
            try? fileManager.createDirectory(at: albumsDir, withIntermediateDirectories: true)
        }

        return albumsDir
    }

    init() {
        loadAlbums()
        initializeDefaultAlbums()
    }

    // MARK: - Album Management
    func loadAlbums() {
        if let data = UserDefaults.standard.data(forKey: albumsKey),
           let decoded = try? JSONDecoder().decode([Album].self, from: data) {
            albums = decoded
        }
    }

    func saveAlbums() {
        if let encoded = try? JSONEncoder().encode(albums) {
            UserDefaults.standard.set(encoded, forKey: albumsKey)
        }
    }

    func createAlbum(title: String, type: AlbumType = .custom) {
        let album = Album(
            title: title,
            coverColor: type.coverColor,
            icon: type.icon
        )
        albums.append(album)
        saveAlbums()
    }

    func updateAlbum(_ album: Album) {
        if let index = albums.firstIndex(where: { $0.id == album.id }) {
            var updatedAlbum = album
            updatedAlbum.updatedAt = Date()
            albums[index] = updatedAlbum
            saveAlbums()
        }
    }

    func deleteAlbum(_ album: Album) {
        // Delete all photos in the album
        for fileName in album.photoFileNames {
            deletePhoto(fileName: fileName)
        }

        // Remove album from list
        albums.removeAll { $0.id == album.id }
        saveAlbums()
    }

    // MARK: - Photo Management
    func addPhoto(_ image: UIImage, to album: Album) {
        let fileName = "\(album.id)_\(UUID().uuidString).jpg"

        if savePhoto(image, fileName: fileName) {
            if let index = albums.firstIndex(where: { $0.id == album.id }) {
                var updatedAlbum = album
                updatedAlbum.photoFileNames.append(fileName)
                updatedAlbum.updatedAt = Date()
                albums[index] = updatedAlbum
                saveAlbums()
            }
        }
    }

    func removePhoto(fileName: String, from album: Album) {
        deletePhoto(fileName: fileName)

        if let index = albums.firstIndex(where: { $0.id == album.id }) {
            var updatedAlbum = album
            updatedAlbum.photoFileNames.removeAll { $0 == fileName }
            updatedAlbum.updatedAt = Date()
            albums[index] = updatedAlbum
            saveAlbums()
        }
    }

    func loadPhoto(fileName: String) -> UIImage? {
        let fileURL = albumsDirectory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }
        return image
    }

    private func savePhoto(_ image: UIImage, fileName: String) -> Bool {
        let fileURL = albumsDirectory.appendingPathComponent(fileName)

        guard let data = image.jpegData(compressionQuality: 0.8) else {
            return false
        }

        do {
            try data.write(to: fileURL)
            return true
        } catch {
            print("Error saving photo: \(error)")
            return false
        }
    }

    private func deletePhoto(fileName: String) {
        let fileURL = albumsDirectory.appendingPathComponent(fileName)
        try? fileManager.removeItem(at: fileURL)
    }

    // MARK: - Default Albums Initialization
    private func initializeDefaultAlbums() {
        if albums.isEmpty {
            let defaultAlbums: [(String, AlbumType)] = [
                ("日本全国フォトマップ", .japan),
                ("旅行", .travel),
                ("家族", .family),
                ("風景", .landscape),
                ("グルメ", .food)
            ]

            for (title, type) in defaultAlbums {
                createAlbum(title: title, type: type)
            }
        }
    }

    // MARK: - Helper Methods
    func getRecentPhotos(from album: Album, limit: Int = 4) -> [UIImage] {
        let recentFileNames = Array(album.photoFileNames.suffix(limit))
        return recentFileNames.compactMap { loadPhoto(fileName: $0) }
    }
}
