import Foundation
import WeatherKit
import CoreLocation
import Network
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Date Extension for Local Date
extension Date {
    /// ローカルタイムゾーンでの日付の開始時刻を取得（00:00:00）
    /// WeatherKitのdaily forecastはローカルタイムゾーンでの日付の開始時刻を期待します
    var startOfDayInLocalTimezone: Date {
        return Calendar.current.startOfDay(for: self)
    }

    /// ローカルタイムゾーンでの「今日」の開始時刻を取得
    static var todayInLocalTimezone: Date {
        return Calendar.current.startOfDay(for: Date())
    }
}

//@available(iOS 16.0, *)
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
        // 座標を小数点第6位までに丸める
        let roundedLatitude = round(latitude * 1000000) / 1000000
        let roundedLongitude = round(longitude * 1000000) / 1000000

        // ローカルタイムゾーンでの日付を使用（UTC のズレを補正）
        let today = Date.todayInLocalTimezone
        let requestDate = date.startOfDayInLocalTimezone

        // ネットワーク接続チェック
        guard isNetworkAvailable else {
            throw WeatherError.networkError
        }

        // 座標の検証
        guard roundedLatitude >= -90 && roundedLatitude <= 90 else {
            throw WeatherError.invalidCoordinates
        }

        guard roundedLongitude >= -180 && roundedLongitude <= 180 else {
            throw WeatherError.invalidCoordinates
        }

        // 日付の差分を計算
        let daysUntilDate = Calendar.current.dateComponents([.day], from: today, to: requestDate).day ?? 0

        // 過去の日付もチェック（過去90日まで取得可能）
        guard daysUntilDate >= -90 else {
            throw WeatherError.dateTooFarInPast
        }

        guard daysUntilDate <= 10 else {
            throw WeatherError.dateTooFarInFuture
        }

        let location = CLLocation(latitude: roundedLatitude, longitude: roundedLongitude)

        do {
            // Get daily forecast - 日付を指定せずに取得（今日から10日間）
            // 特定の日付を指定すると404エラーになることがあるため
            let forecast = try await service.weather(
                for: location,
                including: .daily
            )

            // 指定された日付の天気を抽出
            let calendar = Calendar.current
            guard let dayWeather = forecast.first(where: { weatherDay in
                calendar.isDate(weatherDay.date, inSameDayAs: requestDate)
            }) else {
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

            // HTTP 404 - リソースが見つからない（座標が無効または天気データが利用できない場所）
            if errorString.contains("404") {
                throw WeatherError.locationNotAvailable
            }

            // HTTP 400 with MISSING JWT
            if errorString.contains("400") || errorString.contains("MISSING JWT") {
                throw WeatherError.authenticationError(errorString)
            }

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
        // 座標を小数点第6位までに丸める
        let roundedLatitude = round(latitude * 1000000) / 1000000
        let roundedLongitude = round(longitude * 1000000) / 1000000

        // ネットワーク接続チェック
        guard isNetworkAvailable else {
            throw WeatherError.networkError
        }

        // ローカルタイムゾーンでの日付を使用（UTC のズレを補正）
        let normalizedStartDate = startDate.startOfDayInLocalTimezone
        let normalizedEndDate = endDate.startOfDayInLocalTimezone

        let location = CLLocation(latitude: roundedLatitude, longitude: roundedLongitude)

        do {
            let forecast = try await service.weather(
                for: location,
                including: .daily(startDate: normalizedStartDate, endDate: normalizedEndDate)
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
    case dateTooFarInFuture
    case dateTooFarInPast
    case invalidCoordinates
    case unknownError(Error)

    var errorDescription: String? {
        switch self {
        case .noDataAvailable:
            return "天気データが利用できません"
        case .locationNotAvailable:
            return "この場所の天気データは利用できません。別の場所を試してください。"
        case .dateTooFarInFuture:
            return "旅行開始日が10日以上先のため、天気予報はまだ利用できません。出発の10日前になったら確認できます。"
        case .dateTooFarInPast:
            return "指定された日付が古すぎます。過去90日以内の日付を指定してください。"
        case .invalidCoordinates:
            return "座標が無効です。緯度は-90〜90、経度は-180〜180の範囲である必要があります。"
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
            #if targetEnvironment(simulator)
            return """
            ⚠️ WeatherKit はシミュレータでは動作しません

            このエラーはシミュレータで実行しているため発生しています。
            WeatherKit を使用するには実機（iPhone/iPad）でテストしてください。

            実機でのテスト手順：
            1. Xcode で実機を接続
            2. Product > Destination から実機を選択
            3. Command + R でビルド＆実行

            エラー詳細: \(message)
            """
            #else
            return """
            WeatherKit 認証エラー（実機）
            """
            #endif
        case .unknownError(let error):
            return "エラーが発生しました: \(error.localizedDescription)"
        }
    }
}
