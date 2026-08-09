import WeatherKit

extension WeatherCondition {
    /// 日本語の天気表現。
    ///
    /// `description` は端末やアプリの言語設定に依存し、
    /// このアプリはローカライズを持たない（knownRegions が en のみ）ため英語のままになる。
    /// UIは日本語で統一しているので、ここで明示的に対応付ける。
    var japaneseDescription: String {
        switch self {
        case .clear: return "快晴"
        case .mostlyClear: return "晴れ"
        case .partlyCloudy: return "晴れ時々くもり"
        case .mostlyCloudy: return "くもり時々晴れ"
        case .cloudy: return "くもり"
        case .haze: return "かすみ"
        case .foggy: return "霧"
        case .smoky: return "煙霧"
        case .breezy: return "そよ風"
        case .windy: return "強風"
        case .blowingDust: return "砂じん"
        case .drizzle: return "霧雨"
        case .rain: return "雨"
        case .heavyRain: return "大雨"
        case .isolatedThunderstorms: return "所により雷雨"
        case .scatteredThunderstorms: return "ところどころ雷雨"
        case .strongStorms: return "激しい雷雨"
        case .thunderstorms: return "雷雨"
        case .freezingDrizzle: return "着氷性の霧雨"
        case .freezingRain: return "着氷性の雨"
        case .sunShowers: return "天気雨"
        case .hail: return "ひょう"
        case .flurries: return "にわか雪"
        case .snow: return "雪"
        case .heavySnow: return "大雪"
        case .sleet: return "みぞれ"
        case .wintryMix: return "雨まじりの雪"
        case .blowingSnow: return "地ふぶき"
        case .blizzard: return "ふぶき"
        case .sunFlurries: return "晴れ時々にわか雪"
        case .frigid: return "厳寒"
        case .hot: return "猛暑"
        case .tropicalStorm: return "熱帯低気圧"
        case .hurricane: return "ハリケーン"
        @unknown default: return description
        }
    }
}
