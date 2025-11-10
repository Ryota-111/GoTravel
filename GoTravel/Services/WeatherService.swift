import Foundation
import WeatherKit
import CoreLocation
import Network

@available(iOS 16.0, *)
final class WeatherService {
    static let shared = WeatherService()
    private let service = WeatherKit.WeatherService()
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
    private var isNetworkAvailable = true

    private init() {
        // ネットワーク接続の監視を開始
        networkMonitor.pathUpdateHandler = { [weak self] path in
            self?.isNetworkAvailable = path.status == .satisfied
        }
        networkMonitor.start(queue: monitorQueue)
    }

    deinit {
        networkMonitor.cancel()
    }

    // MARK: - Weather Data Models
    struct DayWeather: Identifiable {
        let id = UUID()
        let date: Date
        let condition: String
        let symbolName: String
        let highTemperature: Double
        let lowTemperature: Double
        let precipitation: Double
        let uvIndex: Int

        var temperatureRange: String {
            "\(Int(lowTemperature))° / \(Int(highTemperature))°"
        }

        var precipitationText: String {
            "\(Int(precipitation * 100))%"
        }
    }

    // MARK: - Fetch Daily Weather
    /// 指定された座標と日付の天気予報を取得
    /// - Parameters:
    ///   - latitude: 緯度
    ///   - longitude: 経度
    ///   - date: 予報を取得する日付
    /// - Returns: その日の天気情報
    func fetchDayWeather(latitude: Double, longitude: Double, date: Date) async throws -> DayWeather {
        // ネットワーク接続チェック
        guard isNetworkAvailable else {
            throw WeatherError.networkError
        }

        let location = CLLocation(latitude: latitude, longitude: longitude)

        do {
            // Get daily forecast
            let forecast = try await service.weather(
                for: location,
                including: .daily(startDate: date, endDate: date)
            )

            guard let dayWeather = forecast.first else {
                throw WeatherError.noDataAvailable
            }

            return DayWeather(
                date: date,
                condition: dayWeather.condition.description,
                symbolName: dayWeather.symbolName,
                highTemperature: dayWeather.highTemperature.value,
                lowTemperature: dayWeather.lowTemperature.value,
                precipitation: dayWeather.precipitationChance,
                uvIndex: dayWeather.uvIndex.value
            )
        } catch {
            // Check for authentication errors
            let errorString = "\(error)"
            if errorString.contains("WDSJWTAuthenticatorServiceListener") ||
               errorString.contains("error 2") ||
               errorString.contains("authentication") {
                throw WeatherError.authenticationError(errorString)
            }
            // Check for network errors
            if errorString.contains("network") ||
               errorString.contains("No network route") ||
               errorString.contains("NSURLErrorDomain") {
                throw WeatherError.networkError
            }
            throw WeatherError.unknownError(error)
        }
    }

    /// TravelPlanの目的地の天気予報を取得（開始日から終了日まで）
    /// - Parameters:
    ///   - latitude: 緯度
    ///   - longitude: 経度
    ///   - startDate: 開始日
    ///   - endDate: 終了日
    /// - Returns: 期間中の天気予報の配列
    func fetchWeatherForTrip(latitude: Double, longitude: Double, startDate: Date, endDate: Date) async throws -> [DayWeather] {
        // ネットワーク接続チェック
        guard isNetworkAvailable else {
            throw WeatherError.networkError
        }

        let location = CLLocation(latitude: latitude, longitude: longitude)

        do {
            let forecast = try await service.weather(
                for: location,
                including: .daily(startDate: startDate, endDate: endDate)
            )

            return forecast.map { dayWeather in
                DayWeather(
                    date: dayWeather.date,
                    condition: dayWeather.condition.description,
                    symbolName: dayWeather.symbolName,
                    highTemperature: dayWeather.highTemperature.value,
                    lowTemperature: dayWeather.lowTemperature.value,
                    precipitation: dayWeather.precipitationChance,
                    uvIndex: dayWeather.uvIndex.value
                )
            }
        } catch {
            // Check for authentication errors
            let errorString = "\(error)"
            if errorString.contains("WDSJWTAuthenticatorServiceListener") ||
               errorString.contains("error 2") ||
               errorString.contains("authentication") {
                throw WeatherError.authenticationError(errorString)
            }
            // Check for network errors
            if errorString.contains("network") ||
               errorString.contains("No network route") ||
               errorString.contains("NSURLErrorDomain") {
                throw WeatherError.networkError
            }
            throw WeatherError.unknownError(error)
        }
    }

    /// ScheduleItemの場所の天気予報を取得
    /// - Parameters:
    ///   - scheduleItem: スケジュールアイテム
    ///   - date: 予報を取得する日付
    /// - Returns: その場所の天気情報、座標がない場合はnil
    func fetchWeatherForScheduleItem(_ scheduleItem: ScheduleItem, date: Date) async throws -> DayWeather? {
        guard let latitude = scheduleItem.latitude,
              let longitude = scheduleItem.longitude else {
            return nil
        }

        return try await fetchDayWeather(latitude: latitude, longitude: longitude, date: date)
    }
}

// MARK: - Weather Error
enum WeatherError: LocalizedError {
    case noDataAvailable
    case locationNotAvailable
    case networkError
    case authenticationError(String)
    case unknownError(Error)

    var errorDescription: String? {
        switch self {
        case .noDataAvailable:
            return "天気データが利用できません"
        case .locationNotAvailable:
            return "位置情報が利用できません"
        case .networkError:
            return """
            ネットワーク接続エラー

            インターネット接続を確認してください：
            • Wi-Fi またはモバイルデータが有効か確認
            • 機内モードが無効か確認
            • VPN を使用している場合は一時的に無効化

            シミュレータの場合：
            • Mac のインターネット接続を確認
            • シミュレータを再起動
            """
        case .authenticationError(let message):
            return """
            WeatherKit 認証エラー

            このエラーは Apple Developer Portal の設定不足が原因です：

            1. developer.apple.com にアクセス
            2. Certificates, Identifiers & Profiles を選択
            3. Identifiers から App ID を選択
            4. WeatherKit capability を有効化
            5. Provisioning Profile を再生成

            重要：WeatherKit はシミュレータでは制限があります。
            実機でテストしてください。

            エラー詳細: \(message)
            """
        case .unknownError(let error):
            return "エラーが発生しました: \(error.localizedDescription)"
        }
    }
}
