import Foundation

struct Profile: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var email: String
    // avatarImageFileName はドキュメントディレクトリに保存したファイル名
    var avatarImageFileName: String?
    
    static var `default`: Profile {
        Profile(name: "Your Name", email: "you@example.com", avatarImageFileName: nil)
    }
}
