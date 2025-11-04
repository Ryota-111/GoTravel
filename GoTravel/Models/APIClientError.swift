import Foundation

// MARK: - API Client Error
enum APIClientError: Error {
    case authenticationError
    case networkError
    case parseError
    case firestoreError(Error)
    case storageError(Error)
    case notFound
    case unknown(Error)

    var localizedDescription: String {
        switch self {
        case .authenticationError:
            return "ログインしていません"
        case .networkError:
            return "ネットワークエラーが発生しました"
        case .parseError:
            return "データの解析に失敗しました"
        case .firestoreError(let error):
            return "Firestoreエラー: \(error.localizedDescription)"
        case .storageError(let error):
            return "Storageエラー: \(error.localizedDescription)"
        case .notFound:
            return "データが見つかりませんでした"
        case .unknown(let error):
            return "不明なエラー: \(error.localizedDescription)"
        }
    }
}
