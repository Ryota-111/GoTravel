import Foundation
import WeatherKit
import CoreLocation
import Network
#if canImport(UIKit)
import UIKit
#endif

@available(iOS 16.0, *)
final class WeatherService {
    static let shared = WeatherService()
    private let service = WeatherKit.WeatherService()
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
    private var isNetworkAvailable = true
    private var hasLoggedEnvironment = false

    private init() {
        // ネットワーク接続の監視を開始
        networkMonitor.pathUpdateHandler = { [weak self] path in
            self?.isNetworkAvailable = path.status == .satisfied
        }
        networkMonitor.start(queue: monitorQueue)

        // 環境診断はfetchメソッドの最初の呼び出し時に遅延実行
        // これにより、WeatherKitの準備が完了してから診断が行われる
    }

    deinit {
        networkMonitor.cancel()
    }

    // MARK: - Diagnostic Methods
    #if DEBUG
    private func logEnvironmentInfo() {
        guard !hasLoggedEnvironment else { return }
        hasLoggedEnvironment = true

        print("🔍 ========== WeatherKit Environment Diagnostics ==========")

        // 1. Device vs Simulator
        #if targetEnvironment(simulator)
        print("⚠️ RUNNING ON SIMULATOR - WeatherKit may have limitations")
        #else
        print("✅ RUNNING ON PHYSICAL DEVICE")
        #endif

        // 2. Bundle ID
        if let bundleID = Bundle.main.bundleIdentifier {
            print("📦 Bundle ID: \(bundleID)")
        } else {
            print("❌ Bundle ID: NOT FOUND")
        }

        // 3. Entitlements Check
        if let entitlements = Bundle.main.object(forInfoDictionaryKey: "Entitlements") as? [String: Any] {
            print("📜 Entitlements found: \(entitlements.keys.joined(separator: ", "))")
            if let weatherKitEnabled = entitlements["com.apple.developer.weatherkit"] as? Bool {
                print(weatherKitEnabled ? "✅ WeatherKit entitlement: ENABLED" : "❌ WeatherKit entitlement: DISABLED")
            }
        } else {
            print("⚠️ Could not read entitlements from Info.plist")
        }

        // 4. iOS Version
        #if canImport(UIKit)
        let osVersion = UIDevice.current.systemVersion
        print("📱 iOS Version: \(osVersion)")
        #endif

        // 5. Network Status
        print("🌐 Network Available: \(isNetworkAvailable ? "YES" : "NO")")

        print("==========================================================")
    }

    private func logWeatherRequest(latitude: Double, longitude: Double, date: Date) {
        let formatter = ISO8601DateFormatter()
        print("🌤️ WeatherKit Request:")
        print("   Latitude: \(latitude)")
        print("   Longitude: \(longitude)")
        print("   Date: \(formatter.string(from: date))")
        print("   Network Available: \(isNetworkAvailable)")
    }
    #endif

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
        #if DEBUG
        // 環境診断を最初の呼び出し時に実行（WeatherKitの準備完了後）
        logEnvironmentInfo()
        logWeatherRequest(latitude: latitude, longitude: longitude, date: date)
        #endif

        // ネットワーク接続チェック
        guard isNetworkAvailable else {
            #if DEBUG
            print("❌ Network not available")
            #endif
            throw WeatherError.networkError
        }

        let location = CLLocation(latitude: latitude, longitude: longitude)

        do {
            #if DEBUG
            print("📡 Sending request to WeatherKit API...")
            #endif

            // Get daily forecast
            let forecast = try await service.weather(
                for: location,
                including: .daily(startDate: date, endDate: date)
            )

            guard let dayWeather = forecast.first else {
                #if DEBUG
                print("❌ No weather data returned from API")
                #endif
                throw WeatherError.noDataAvailable
            }

            #if DEBUG
            print("✅ Weather data received successfully")
            print("   Condition: \(dayWeather.condition.description)")
            print("   High: \(dayWeather.highTemperature.value)°C")
            print("   Low: \(dayWeather.lowTemperature.value)°C")
            #endif

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
            #if DEBUG
            print("❌ WeatherKit API Error:")
            print("   Error Type: \(type(of: error))")
            print("   Error Description: \(error)")
            print("   Localized Description: \(error.localizedDescription)")
            #endif

            // Check for authentication errors
            let errorString = "\(error)"

            // HTTP 400 with MISSING JWT
            if errorString.contains("400") || errorString.contains("MISSING JWT") {
                #if DEBUG
                print("⚠️ HTTP 400 / MISSING JWT detected")
                print("   This usually means:")
                print("   1. App is running on simulator (WeatherKit requires physical device)")
                print("   2. Provisioning profile doesn't include WeatherKit entitlement")
                print("   3. Bundle ID mismatch between app and Developer Portal")
                #endif
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
