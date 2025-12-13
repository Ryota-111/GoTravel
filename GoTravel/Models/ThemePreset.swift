import SwiftUI

struct ThemePreset {
    // MARK: - Theme Type
    enum ThemeType: String, Codable, CaseIterable {
        case originalColor = "デフォルトカラー"
        case whiteBlack = "白黒(白色メイン)"
        case blackWhite = "白黒(黒色メイン)"
        case pastelPink = "パステルピンク"

        var displayName: String { rawValue }
    }

    // MARK: - Properties
    let type: ThemeType

    // MARK: - 主カラー
    var primary: Color
    var secondary: Color
    var tertiary: Color
    
    // MARK: - 逆主カラー
    var xprimary: Color
    var xsecondary: Color

    // MARK: - ボックスの背景の色
    var backgroundLight: Color
    var secondaryBackgroundLight: Color
    var backgroundDark: Color
    var secondaryBackgroundDark: Color
    var tertiaryBackground: Color
    var separatorLight: Color
    var separatorDark: Color

    // MARK: - テキストの色
    var text: Color
    var secondaryText: Color
    var tertiaryText: Color
    var budgetLightText: Color
    var budgetDarkText: Color

    // MARK: - Accent Colors
    var accent1: Color
    var accent2: Color
    var accent3: Color

    // MARK: - Functional Colors
    var success: Color
    var warning: Color
    var error: Color
    var info: Color

    // MARK: - カードの背景や縁や影の色
    var cardBackground1: Color
    var cardBackground2: Color
    var cardBorder: Color
    var shadow: Color

    // MARK: - グラデーションの色（ライトモードとダークモード）
    var gradientLight: Color
    var gradientDark: Color
    var light: Color
    var dark: Color
    
    // MARK: - plansの予定
    var dailyPlanColor: Color
    var outingPlanColor: Color
    var travelColor: Color

    // MARK: - Initializer
    init(type: ThemeType) {
        self.type = type

        switch type {
        case .originalColor:
            primary = Color.blue
            secondary = Color.orange
            tertiary = Color.white
            
            xprimary = Color.blue
            xsecondary = Color.orange
            
            backgroundLight = Color(red: 1, green: 1, blue: 1)
            secondaryBackgroundLight = Color(red: 0.95, green: 0.95, blue: 0.97)
            backgroundDark = Color(red:0.0, green: 0.0, blue: 0.0)
            secondaryBackgroundDark = Color(red: 0.11, green: 0.11, blue: 0.12)
            tertiaryBackground = Color(red: 0.85, green: 0.88, blue: 0.96)
            separatorLight = Color(red: 0.24, green: 0.24, blue: 0.26).opacity(0.29)
            separatorDark = Color(red: 0.33, green: 0.33, blue: 0.35).opacity(0.6)
            
            text = Color(white: 0.1)
            secondaryText = Color(white: 0.4)
            tertiaryText = Color(white: 0.6)
            budgetLightText = Color(white: 0.4)
            budgetDarkText = Color.white.opacity(0.7)
            
            accent1 = Color.black
            accent2 = Color.white
            accent3 = Color.gray
            
            success = Color.green
            warning = Color.orange
            error = Color.red
            info = Color.blue
            
            cardBackground1 = Color.white.opacity(0.08)
            cardBackground2 = Color.white.opacity(0.6)
            cardBorder = Color.blue.opacity(0.3)
            shadow = Color.blue.opacity(0.2)
            
            gradientLight = Color.blue.opacity(0.6)
            gradientDark = Color.blue.opacity(0.7)
            light = Color.white
            dark = Color.black
            
            dailyPlanColor = Color.orange
            outingPlanColor = Color.blue
            travelColor = Color.green
            
        case .whiteBlack:
            primary = Color.white
            secondary = Color.black
            tertiary = Color.white
            
            xprimary = Color.black
            xsecondary = Color.black
            
            backgroundLight = Color(red: 1, green: 1, blue: 1)
            secondaryBackgroundLight = Color(red: 0.95, green: 0.95, blue: 0.97)
            backgroundDark = Color(red: 1, green: 1, blue: 1)
            secondaryBackgroundDark = Color(red: 0.95, green: 0.95, blue: 0.97)
            tertiaryBackground = Color(white: 0.9)
            separatorLight = Color(red: 0.24, green: 0.24, blue: 0.26).opacity(0.29)
            separatorDark = Color(red: 0.24, green: 0.24, blue: 0.26).opacity(0.29)
            
            text = Color.black
            secondaryText = Color.gray
            tertiaryText = Color(white: 0.5)
            budgetLightText = Color(white: 0.4)
            budgetDarkText = Color(white: 0.4)
            
            accent1 = Color.black
            accent2 = Color.black
            accent3 = Color.gray
            
            success = Color.green
            warning = Color.orange
            error = Color.red
            info = Color.blue
            
            cardBackground1 = Color.black.opacity(0.08)
            cardBackground2 = Color.black.opacity(0.08)
            cardBorder = Color.black.opacity(0.3)
            shadow = Color.black.opacity(0.15)
            
            gradientLight = Color.white
            gradientDark = Color.white
            light = Color.white
            dark = Color.white
            
            dailyPlanColor = Color.orange
            outingPlanColor = Color.blue
            travelColor = Color.green
            
        case .blackWhite:
            primary = Color.black
            secondary = Color.white
            tertiary = Color.gray
            
            xprimary = Color.white
            xsecondary = Color.white
            
            backgroundLight = Color(red:0.0, green: 0.0, blue: 0.0)
            secondaryBackgroundLight = Color(red: 0.11, green: 0.11, blue: 0.12)
            backgroundDark = Color(red:0.0, green: 0.0, blue: 0.0)
            secondaryBackgroundDark = Color(red: 0.11, green: 0.11, blue: 0.12)
            tertiaryBackground = Color(white: 0.9)
            separatorLight = Color(red: 0.33, green: 0.33, blue: 0.35).opacity(0.6)
            separatorDark = Color(red: 0.33, green: 0.33, blue: 0.35).opacity(0.6)
            
            text = Color.white
            secondaryText = Color.gray
            tertiaryText = Color(white: 0.5)
            budgetLightText = Color(white: 0.4)
            budgetDarkText = Color(white: 0.4)
            
            accent1 = Color.white
            accent2 = Color.white
            accent3 = Color.gray
            
            success = Color.green
            warning = Color.orange
            error = Color.red
            info = Color.blue
            
            cardBackground1 = Color.white.opacity(0.08)
            cardBackground2 = Color.white.opacity(0.08)
            cardBorder = Color.white.opacity(0.3)
            shadow = Color.white.opacity(0.15)
            
            gradientLight = Color.black
            gradientDark = Color.black
            light = Color.black
            dark = Color.black
            
            dailyPlanColor = Color.orange
            outingPlanColor = Color.blue
            travelColor = Color.green
            
        case .pastelPink:
            primary = Color.white
            secondary = Color(red: 255/255, green: 209/255, blue: 220/255)
            tertiary = Color.gray
            
            xprimary = Color(red: 255/255, green: 209/255, blue: 220/255)
            xsecondary = Color(red: 255/255, green: 209/255, blue: 220/255)
            
            backgroundLight = Color(red: 1, green: 1, blue: 1)
            secondaryBackgroundLight = Color(red: 0.95, green: 0.95, blue: 0.97)
            backgroundDark = Color(red: 1, green: 1, blue: 1)
            secondaryBackgroundDark = Color(red: 0.95, green: 0.95, blue: 0.97)
            tertiaryBackground = Color(red: 1.0, green: 0.88, blue: 0.85)
            separatorLight = Color(red: 0.24, green: 0.24, blue: 0.26).opacity(0.29)
            separatorDark = Color(red: 0.24, green: 0.24, blue: 0.26).opacity(0.29)
            
            text = Color.white
            secondaryText = Color.gray
            tertiaryText = Color(white: 0.6)
            budgetLightText = Color(white: 0.4)
            budgetDarkText = Color(white: 0.4)
            
            accent1 = Color(red: 255/255, green: 209/255, blue: 220/255)
            accent2 = Color(red: 255/255, green: 209/255, blue: 220/255)
            accent3 = Color.gray
            
            success = Color.green
            warning = Color.orange
            error = Color.red
            info = Color.blue
            
            cardBackground1 = Color(red: 255/255, green: 209/255, blue: 220/255).opacity(0.08)
            cardBackground2 = Color(red: 255/255, green: 209/255, blue: 220/255).opacity(0.08)
            cardBorder = Color(red: 255/255, green: 209/255, blue: 220/255).opacity(0.3)
            shadow = Color.orange.opacity(0.2)
            
            gradientLight = Color.white
            gradientDark = Color.white
            light = Color.white
            dark = Color.white
            
            dailyPlanColor = Color.orange
            outingPlanColor = Color.blue
            travelColor = Color.green
        }
    }
}
