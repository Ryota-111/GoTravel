import SwiftUI

// Notused
@available(iOS 16.0, *)
struct WeatherCardView: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var themeManager = ThemeManager.shared
    let weather: WeatherService.DayWeather
    let dayNumber: Int?

    var body: some View {
        HStack(spacing: 15) {
            // Weather Icon
            Image(systemName: weather.symbolName)
                .font(.system(size: 40))
                .foregroundStyle(.white, .blue)
                .frame(width: 60)

            // Weather Details
            VStack(alignment: .leading, spacing: 5) {
                if let day = dayNumber {
                    Text("Day \(day)")
                        .font(.headline)
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                }

                Text(weather.condition)
                    .font(.subheadline)
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : themeManager.currentTheme.secondaryText)

                HStack(spacing: 15) {
                    // Temperature
                    HStack(spacing: 3) {
                        Image(systemName: "thermometer")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text(weather.temperatureRange)
                            .font(.caption)
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                    }

                    // Precipitation
                    HStack(spacing: 3) {
                        Image(systemName: "drop.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text(weather.precipitationText)
                            .font(.caption)
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                    }

                    // UV Index
                    HStack(spacing: 3) {
                        Image(systemName: "sun.max.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                        Text("UV \(weather.uvIndex)")
                            .font(.caption)
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                    }
                }
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.white.opacity(0.15))
        )
    }
}

// Loading State View
struct WeatherLoadingView: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var themeManager = ThemeManager.shared

    var body: some View {
        HStack(spacing: 15) {
            ProgressView()
                .frame(width: 60)

            VStack(alignment: .leading, spacing: 5) {
                Text("天気情報を読み込み中...")
                    .font(.subheadline)
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : themeManager.currentTheme.secondaryText)
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.white.opacity(0.15))
        )
    }
}

// Error State View
struct WeatherErrorView: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var themeManager = ThemeManager.shared
    let error: String

    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 30))
                .foregroundColor(.orange)
                .frame(width: 60)

            VStack(alignment: .leading, spacing: 5) {
                Text("天気情報を取得できませんでした")
                    .font(.subheadline)
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : themeManager.currentTheme.secondaryText)

                if !error.isEmpty {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.white.opacity(0.15))
        )
    }
}
