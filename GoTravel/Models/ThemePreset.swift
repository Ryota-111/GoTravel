import SwiftUI

struct ThemePreset {
    // MARK: - Theme Type
    enum ThemeType: String, Codable, CaseIterable {
        case originalColor = "デフォルトカラー"
        case whiteBlack = "白黒(白色メイン)"
        case blackWhite = "白黒(黒色メイン)"
        case orangePink = "Orange & Pink"
        case greenCyan = "Green & Cyan"
        case sunset = "Sunset"
        case ocean = "Ocean"
        case forest = "Forest"

        var displayName: String { rawValue }
    }

    // MARK: - Properties
    let type: ThemeType

    // MARK: - Primary Colors
    var primary: Color
    var secondary: Color
    var tertiary: Color

    // MARK: - Background Colors
    var background: Color
    var secondaryBackground: Color
    var tertiaryBackground: Color

    // MARK: - Text Colors
    var text: Color
    var secondaryText: Color
    var tertiaryText: Color

    // MARK: - Accent Colors
    var accent1: Color
    var accent2: Color
    var accent3: Color

    // MARK: - Functional Colors
    var success: Color
    var warning: Color
    var error: Color
    var info: Color

    // MARK: - Special Colors
    var cardBackground: Color
    var cardBorder: Color
    var shadow: Color

    // MARK: - Gradient Colors
    var gradientStart: Color
    var gradientEnd: Color

    // MARK: - Initializer
    init(type: ThemeType) {
        self.type = type

        switch type {
        case .whiteBlack:
            primary = Color.black
            secondary = Color.white
            tertiary = Color.gray

            background = Color.white
            secondaryBackground = Color(white: 0.95)
            tertiaryBackground = Color(white: 0.9)

            text = Color.black
            secondaryText = Color.gray
            tertiaryText = Color(white: 0.5)

            accent1 = Color.black
            accent2 = Color.gray
            accent3 = Color.white

            success = Color.green
            warning = Color.orange
            error = Color.red
            info = Color.blue

            cardBackground = Color.white
            cardBorder = Color.gray.opacity(0.3)
            shadow = Color.black.opacity(0.15)

            gradientStart = Color.white
            gradientEnd = Color.gray.opacity(0.3)
            
        case .blackWhite:
            primary = Color.white
            secondary = Color.black
            tertiary = Color.gray

            background = Color.black
            secondaryBackground = Color(white: 0.95)
            tertiaryBackground = Color(white: 0.9)

            text = Color.white
            secondaryText = Color.gray
            tertiaryText = Color(white: 0.5)

            accent1 = Color.white
            accent2 = Color.gray
            accent3 = Color.black

            success = Color.green
            warning = Color.orange
            error = Color.red
            info = Color.blue

            cardBackground = Color.black
            cardBorder = Color.gray.opacity(0.3)
            shadow = Color.white.opacity(0.15)

            gradientStart = Color.black
            gradientEnd = Color.gray.opacity(0.3)

        case .originalColor:
            primary = Color.blue
            secondary = Color.purple
            tertiary = Color.indigo

            background = Color(red: 0.95, green: 0.96, blue: 1.0)
            secondaryBackground = Color(red: 0.9, green: 0.92, blue: 0.98)
            tertiaryBackground = Color(red: 0.85, green: 0.88, blue: 0.96)

            text = Color(white: 0.1)
            secondaryText = Color(white: 0.4)
            tertiaryText = Color(white: 0.6)

            accent1 = Color.orange
            accent2 = Color.purple
            accent3 = Color.pink

            success = Color.green
            warning = Color.orange
            error = Color.red
            info = Color.blue

            cardBackground = Color.white.opacity(0.8)
            cardBorder = Color.blue.opacity(0.3)
            shadow = Color.blue.opacity(0.2)

            gradientStart = Color.blue.opacity(0.6)
            gradientEnd = Color.purple.opacity(0.6)

        case .orangePink:
            // Orange & Pink Theme
            primary = Color.orange
            secondary = Color.pink
            tertiary = Color.red

            background = Color(red: 1.0, green: 0.96, blue: 0.95)
            secondaryBackground = Color(red: 1.0, green: 0.92, blue: 0.9)
            tertiaryBackground = Color(red: 1.0, green: 0.88, blue: 0.85)

            text = Color(white: 0.1)
            secondaryText = Color(white: 0.4)
            tertiaryText = Color(white: 0.6)

            accent1 = Color.orange
            accent2 = Color.pink
            accent3 = Color.red

            success = Color.green
            warning = Color.orange
            error = Color.red
            info = Color.blue

            cardBackground = Color.white.opacity(0.8)
            cardBorder = Color.orange.opacity(0.3)
            shadow = Color.orange.opacity(0.2)

            gradientStart = Color.orange.opacity(0.6)
            gradientEnd = Color.pink.opacity(0.6)

        case .greenCyan:
            // Green & Cyan Theme
            primary = Color.green
            secondary = Color.cyan
            tertiary = Color.teal

            background = Color(red: 0.95, green: 1.0, blue: 0.98)
            secondaryBackground = Color(red: 0.9, green: 0.98, blue: 0.96)
            tertiaryBackground = Color(red: 0.85, green: 0.96, blue: 0.94)

            text = Color(white: 0.1)
            secondaryText = Color(white: 0.4)
            tertiaryText = Color(white: 0.6)

            accent1 = Color.green
            accent2 = Color.cyan
            accent3 = Color.blue

            success = Color.green
            warning = Color.orange
            error = Color.red
            info = Color.cyan

            cardBackground = Color.white.opacity(0.8)
            cardBorder = Color.green.opacity(0.3)
            shadow = Color.green.opacity(0.2)

            gradientStart = Color.green.opacity(0.6)
            gradientEnd = Color.cyan.opacity(0.6)

        case .sunset:
            // Sunset Theme
            primary = Color.orange
            secondary = Color.purple
            tertiary = Color.pink

            background = Color(red: 1.0, green: 0.94, blue: 0.9)
            secondaryBackground = Color(red: 0.98, green: 0.9, blue: 0.88)
            tertiaryBackground = Color(red: 0.96, green: 0.86, blue: 0.86)

            text = Color(white: 0.1)
            secondaryText = Color(white: 0.4)
            tertiaryText = Color(white: 0.6)

            accent1 = Color.orange
            accent2 = Color.pink
            accent3 = Color.purple

            success = Color.green
            warning = Color.orange
            error = Color.red
            info = Color.purple

            cardBackground = Color.white.opacity(0.8)
            cardBorder = Color.orange.opacity(0.3)
            shadow = Color.orange.opacity(0.2)

            gradientStart = Color.orange.opacity(0.7)
            gradientEnd = Color.purple.opacity(0.6)

        case .ocean:
            // Ocean Theme
            primary = Color.blue
            secondary = Color.cyan
            tertiary = Color.teal

            background = Color(red: 0.93, green: 0.97, blue: 1.0)
            secondaryBackground = Color(red: 0.88, green: 0.94, blue: 0.98)
            tertiaryBackground = Color(red: 0.83, green: 0.91, blue: 0.96)

            text = Color(white: 0.1)
            secondaryText = Color(white: 0.4)
            tertiaryText = Color(white: 0.6)

            accent1 = Color.blue
            accent2 = Color.cyan
            accent3 = Color.purple

            success = Color.green
            warning = Color.orange
            error = Color.red
            info = Color.blue

            cardBackground = Color.white.opacity(0.8)
            cardBorder = Color.blue.opacity(0.3)
            shadow = Color.blue.opacity(0.2)

            gradientStart = Color.blue.opacity(0.7)
            gradientEnd = Color.cyan.opacity(0.5)

        case .forest:
            // Forest Theme
            primary = Color.green
            secondary = Color(red: 0.4, green: 0.6, blue: 0.3)
            tertiary = Color(red: 0.3, green: 0.5, blue: 0.2)

            background = Color(red: 0.95, green: 0.98, blue: 0.93)
            secondaryBackground = Color(red: 0.92, green: 0.96, blue: 0.9)
            tertiaryBackground = Color(red: 0.89, green: 0.94, blue: 0.87)

            text = Color(white: 0.1)
            secondaryText = Color(white: 0.4)
            tertiaryText = Color(white: 0.6)

            accent1 = Color.green
            accent2 = Color(red: 0.6, green: 0.8, blue: 0.4)
            accent3 = Color(red: 0.4, green: 0.6, blue: 0.3)

            success = Color.green
            warning = Color.orange
            error = Color.red
            info = Color.blue

            cardBackground = Color.white.opacity(0.8)
            cardBorder = Color.green.opacity(0.3)
            shadow = Color.green.opacity(0.2)

            gradientStart = Color.green.opacity(0.6)
            gradientEnd = Color(red: 0.4, green: 0.6, blue: 0.3).opacity(0.6)
        }
    }
}
