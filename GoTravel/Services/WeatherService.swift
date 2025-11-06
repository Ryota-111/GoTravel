import Foundation
import WeatherKit
import CoreLocation

@available(iOS 16.0, *)
final class WeatherService {
    static let shared = WeatherService()
    private let service = WeatherKit.WeatherService()

    private init() {}

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
        let location = CLLocation(latitude: latitude, longitude: longitude)

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
    }

    /// TravelPlanの目的地の天気予報を取得（開始日から終了日まで）
    /// - Parameters:
    ///   - latitude: 緯度
    ///   - longitude: 経度
    ///   - startDate: 開始日
    ///   - endDate: 終了日
    /// - Returns: 期間中の天気予報の配列
    func fetchWeatherForTrip(latitude: Double, longitude: Double, startDate: Date, endDate: Date) async throws -> [DayWeather] {
        let location = CLLocation(latitude: latitude, longitude: longitude)

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

    var errorDescription: String? {
        switch self {
        case .noDataAvailable:
            return "天気データが利用できません"
        case .locationNotAvailable:
            return "位置情報が利用できません"
        case .networkError:
            return "ネットワークエラーが発生しました"
        }
    }
}
