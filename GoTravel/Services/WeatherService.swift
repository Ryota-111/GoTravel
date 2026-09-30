import Foundation
import WeatherKit
import CoreLocation
import Network
import os
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Date Extension for Local Date
extension Date {
    var startOfDayInLocalTimezone: Date {
        return Calendar.current.startOfDay(for: self)
    }

    static var todayInLocalTimezone: Date {
        return Calendar.current.startOfDay(for: Date())
    }
}

final class WeatherService {
    static let shared = WeatherService()
    private let service = WeatherKit.WeatherService()
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
    private var isNetworkAvailable = true

    /// 天気の取得に失敗したときの中身。Console.app で
    /// subsystem: com.gmail.taismryotasis.Travory / category: weather を見る。
    ///
    /// 以前は失敗の中身をどこにも残さず、「設定された場所には天気の情報がありませんでした」
    /// とだけ出ていたため、座標が悪いのか、日付が悪いのか、認証なのか切り分けられなかった
    static let logger = Logger(subsystem: "com.gmail.taismryotasis.Travory", category: "weather")


    /// 日別予報がある日数。**今日を含めて**この日数ぶん（今日〜9日後）。
    ///
    /// 以前は「10日後まで」として問い合わせていたため、出発がちょうど10日後の旅行で
    /// 予報の無い期間を頼み、WeatherKit から 404 が返っていた。その 404 を
    /// 「その場所には天気が無い」と読んでいたので、「設定された場所には天気の情報が
    /// ありませんでした」と、場所の問題に見える案内が出ていた
    static let forecastDays = 10

    /// 天気が見られるようになるのは、出発の何日前からか
    static var availableDaysBefore: Int { forecastDays - 1 }

    /// 予報がある最後の日の翌日 0:00（問い合わせの終端に使う。終端は含まれない）
    private static var forecastHorizonEnd: Date {
        Calendar.current.date(byAdding: .day, value: forecastDays, to: Date.todayInLocalTimezone)
            ?? Date.todayInLocalTimezone
    }

    private init() {
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

    struct WeatherAttribution {
        let combinedMarkLightURL: URL
        let combinedMarkDarkURL: URL
        let legalPageURL: URL
    }

    // MARK: - Get Weather Attribution
    func getWeatherAttribution() async throws -> WeatherAttribution {
        let attribution = try await service.attribution

        return WeatherAttribution(
            combinedMarkLightURL: attribution.combinedMarkLightURL,
            combinedMarkDarkURL: attribution.combinedMarkDarkURL,
            legalPageURL: attribution.legalPageURL
        )
    }

    // MARK: - Fetch Daily Weather
    func fetchDayWeather(latitude: Double, longitude: Double, date: Date) async throws -> DayWeather {
        let roundedLatitude = round(latitude * 1000000) / 1000000
        let roundedLongitude = round(longitude * 1000000) / 1000000
        let today = Date.todayInLocalTimezone
        let requestDate = date.startOfDayInLocalTimezone

        guard isNetworkAvailable else {
            throw WeatherError.networkError
        }

        guard roundedLatitude >= -90 && roundedLatitude <= 90 else {
            throw WeatherError.invalidCoordinates
        }

        guard roundedLongitude >= -180 && roundedLongitude <= 180 else {
            throw WeatherError.invalidCoordinates
        }

        let daysUntilDate = Calendar.current.dateComponents([.day], from: today, to: requestDate).day ?? 0

        guard daysUntilDate >= -90 else {
            throw WeatherError.dateTooFarInPast
        }

        guard daysUntilDate <= Self.availableDaysBefore else {
            throw WeatherError.dateTooFarInFuture
        }

        let location = CLLocation(latitude: roundedLatitude, longitude: roundedLongitude)

        do {
            let forecast = try await service.weather(
                for: location,
                including: .daily
            )

            let calendar = Calendar.current
            guard let dayWeather = forecast.first(where: { weatherDay in
                calendar.isDate(weatherDay.date, inSameDayAs: requestDate)
            }) else {
                throw WeatherError.noDataAvailable
            }

            return DayWeather(
                date: date,
                condition: dayWeather.condition.japaneseDescription,
                symbolName: dayWeather.symbolName,
                highTemperature: dayWeather.highTemperature.value,
                lowTemperature: dayWeather.lowTemperature.value,
                precipitation: dayWeather.precipitationChance,
                uvIndex: dayWeather.uvIndex.value
            )
        } catch {
            // Check for authentication errors
            let errorString = "\(error)"
            Self.logger.error("""
                天気の取得に失敗 lat=\(roundedLatitude, privacy: .public) \
                lng=\(roundedLongitude, privacy: .public) \
                error=\(errorString, privacy: .public)
                """)

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

        guard roundedLatitude >= -90 && roundedLatitude <= 90,
              roundedLongitude >= -180 && roundedLongitude <= 180 else {
            throw WeatherError.invalidCoordinates
        }

        // **先すぎる日付は頼まない。**
        //
        // WeatherKit の日別予報は10日先までで、それを超えると 400 が返る。
        // 1日ぶんを取る `fetchDayWeather` には上限の判定があるのに、
        // 旅行全体を取るこちらには無かった。
        // そのため先の旅行を開くたびに 400 が出て、画面には
        // 「天気を取得できませんでした」とだけ表示されていた。
        // 「〇日前になったら見られます」と正しく案内する
        let daysUntilStart = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: Date()),
            to: startDate.startOfDayInLocalTimezone
        ).day ?? 0

        guard daysUntilStart <= Self.availableDaysBefore else {
            throw WeatherError.dateTooFarInFuture
        }
        guard daysUntilStart >= -90 else {
            throw WeatherError.dateTooFarInPast
        }

        // ローカルタイムゾーンでの日付を使用（UTC のズレを補正）
        let normalizedStartDate = startDate.startOfDayInLocalTimezone

        // 期間の終端は含まれない。最終日の0時までを頼むと最終日が落ちるので、
        // 翌日の0時まで頼む
        let requestedEndDate = Calendar.current.date(
            byAdding: .day,
            value: 1,
            to: endDate.startOfDayInLocalTimezone
        ) ?? endDate.startOfDayInLocalTimezone
        // 予報の無い日まで頼まない。範囲をはみ出すと、そのぶんが 404 になり得る。
        // 範囲内の日だけ返し、残りの日は近づいてから出す
        let normalizedEndDate = min(requestedEndDate, Self.forecastHorizonEnd)

        let location = CLLocation(latitude: roundedLatitude, longitude: roundedLongitude)

        do {
            let forecast = try await service.weather(
                for: location,
                including: .daily(startDate: normalizedStartDate, endDate: normalizedEndDate)
            )

            return forecast.map { dayWeather in
                DayWeather(
                    date: dayWeather.date,
                    condition: dayWeather.condition.japaneseDescription,
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
            Self.logger.error("""
                天気の取得に失敗 lat=\(roundedLatitude, privacy: .public) \
                lng=\(roundedLongitude, privacy: .public) \
                error=\(errorString, privacy: .public)
                """)

            // HTTP 404 - 座標が無効か、天気データが無い場所
            if errorString.contains("404") {
                throw WeatherError.locationNotAvailable
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
            return "旅行開始日が先のため、天気予報はまだ利用できません。出発の\(WeatherService.availableDaysBefore)日前になったら確認できます。"
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
