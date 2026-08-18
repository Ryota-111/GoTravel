import SwiftUI

struct ThemePreset {
    // MARK: - Theme Type
    enum ThemeType: String, Codable, CaseIterable {
        case originalColor = "デフォルトカラー"
        case whiteBlack = "白黒(白色メイン)"
        case pastelPink = "パステルピンク"

        var displayName: String { rawValue }
    }

    // MARK: - Properties
    let type: ThemeType

    // MARK: - 主カラー
    var primary: Color
    var secondary: Color
    var tertiary: Color
    
    // MARK: - 逆主カラー(反転)
    var xprimary: Color
    var xsecondary: Color
    
    // MARK: - 逆主カラー
    var yprimary: Color
    var ysecondary: Color

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
    
    // MARK: - Album Color
    var japan: Color
    var travel: Color
    var family: Color
    var landscape: Color
    var food: Color
    var custom: Color

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
            
            yprimary = Color.blue
            ysecondary = Color.orange
            
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
            
            japan = Color.blue
            travel = Color.orange
            family = Color.pink
            landscape = Color.green
            food = Color.red
            custom = Color.purple
            
        case .whiteBlack:
            primary = Color.white
            secondary = Color.black
            tertiary = Color.white
            
            xprimary = Color.black
            xsecondary = Color.black
            
            yprimary = Color.white
            ysecondary = Color.white
            
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
            
            japan = Color.black
            travel = Color.black
            family = Color.black
            landscape = Color.black
            food = Color.black
            custom = Color.black
            
        case .pastelPink:
            // primary/secondary は白文字を載せるボタン・バッジの塗りに使われるため、
            // 白文字が読める濃さのローズピンクにする（薄いピンクだと白文字が消える）
            primary = Color(red: 0.85, green: 0.38, blue: 0.52)
            secondary = Color(red: 0.89, green: 0.44, blue: 0.57)
            tertiary = Color(red: 1.0, green: 0.92, blue: 0.94)

            xprimary = Color(red: 0.85, green: 0.38, blue: 0.52)
            xsecondary = Color(red: 0.89, green: 0.44, blue: 0.57)

            yprimary = Color(red: 0.85, green: 0.38, blue: 0.52)
            ysecondary = Color(red: 0.89, green: 0.44, blue: 0.57)

            backgroundLight = Color(red: 1, green: 1, blue: 1)
            secondaryBackgroundLight = Color(red: 0.98, green: 0.94, blue: 0.96)
            backgroundDark = Color(red: 1, green: 1, blue: 1)
            secondaryBackgroundDark = Color(red: 0.98, green: 0.94, blue: 0.96)
            tertiaryBackground = Color(red: 1.0, green: 0.88, blue: 0.85)
            separatorLight = Color(red: 0.24, green: 0.24, blue: 0.26).opacity(0.29)
            separatorDark = Color(red: 0.24, green: 0.24, blue: 0.26).opacity(0.29)

            text = Color(red: 0.2, green: 0.2, blue: 0.2)
            secondaryText = Color(red: 0.5, green: 0.4, blue: 0.45)
            tertiaryText = Color(red: 0.6, green: 0.5, blue: 0.55)
            budgetLightText = Color(white: 0.4)
            budgetDarkText = Color(white: 0.4)

            accent1 = Color(red: 0.2, green: 0.2, blue: 0.2)
            // このテーマは背景（gradientDark/dark）が白のため、
            // accent2 を白にすると文字が背景に溶けて見えなくなる。
            // 白背景で読め、かつ白文字を載せられる濃いローズにする
            accent2 = Color(red: 0.78, green: 0.33, blue: 0.45)
            accent3 = Color(red: 0.5, green: 0.4, blue: 0.45)

            success = Color.green
            warning = Color.orange
            error = Color.red
            info = Color.blue

            cardBackground1 = Color(red: 255/255, green: 209/255, blue: 220/255).opacity(0.08)
            cardBackground2 = Color(red: 255/255, green: 209/255, blue: 220/255).opacity(0.08)
            cardBorder = Color(red: 0.89, green: 0.44, blue: 0.57).opacity(0.4)
            shadow = Color(red: 0.85, green: 0.38, blue: 0.52).opacity(0.15)
            
            gradientLight = Color.white
            gradientDark = Color.white
            light = Color.white
            dark = Color.white
            
            dailyPlanColor = Color.orange
            outingPlanColor = Color.blue
            travelColor = Color.green
            
            japan    = Color(red: 0.87, green: 0.37, blue: 0.50)   // ローズ
            travel   = Color(red: 0.55, green: 0.52, blue: 0.85)   // ラベンダーブルー
            family   = Color(red: 0.95, green: 0.60, blue: 0.42)   // コーラルピーチ
            landscape = Color(red: 0.40, green: 0.72, blue: 0.55)  // セージグリーン
            food     = Color(red: 0.90, green: 0.38, blue: 0.38)   // ウォームレッド
            custom   = Color(red: 0.70, green: 0.50, blue: 0.88)   // ライラック
        }
    }
}

// MARK: - コントラストを保証する色

extension ThemePreset {
    /// primary の代わりに使う、背景と必ず差がつく色。
    /// 塗りつぶしボタンの背景のほか、背景の上に直接置く文字・枠線・選択状態にも使う。
    /// 白黒テーマの primary は白で、背景も白いため、そのまま使うと消える
    var actionFill: Color {
        switch type {
        case .whiteBlack: return .black
        default: return primary
        }
    }

    /// テーマ色を薄く敷いた上に、その色で文字を置くときの色。
    ///
    /// オレンジのような明るい色はそのまま載せると読めない
    /// （デフォルトカラーの「共有に参加」で比 1.95 しかなかった）。
    /// 十分な差が出るまで暗く（暗い背景なら明るく）して返す。
    static func readableTint(_ color: Color, on background: Color) -> Color {
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        guard UIColor(color).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return color
        }

        let backgroundIsLight = luminance(of: background) > 0.4
        var adjusted = color

        // 4.5 まで寄せると色がかなり沈むため、色味を残すことを優先して 4.0 とする。
        // 同じ色を薄く敷いた上に載るので、実際の比は 3.6 前後になる。
        // 太さのある短い文言に使う前提での妥協点
        // 段階的に寄せる。色相と鮮やかさは保つので、テーマの印象は変わらない
        for _ in 0..<14 where contrastRatio(adjusted, background) < 4.0 {
            brightness = backgroundIsLight
                ? max(brightness - 0.07, 0.05)
                : min(brightness + 0.07, 1.0)
            adjusted = Color(UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: alpha))
        }
        return adjusted
    }

    static func contrastRatio(_ a: Color, _ b: Color) -> Double {
        let la = luminance(of: a), lb = luminance(of: b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    private static func luminance(of color: Color) -> Double {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)

        func channel(_ value: CGFloat) -> Double {
            let v = Double(value)
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
    }

    /// 明るい背景でも暗い背景でも読める文字色。
    /// accent1 は黒固定のため、ダークモードで背景に溶ける
    func adaptiveText(for scheme: ColorScheme) -> Color {
        scheme == .dark ? accent2 : accent1
    }

    /// 指定した背景色の上で必ず読める文字色。
    ///
    /// テーマによっては colorScheme と実際の明暗が一致しない：
    /// - 背景グラデーション（gradientDark→dark）はデフォルトカラーだけ暗く、
    ///   白黒・パステルピンクは白。ライトモードでも暗い背景になる
    /// - secondaryBackgroundDark は白黒(0.95)・パステルピンク(0.98)では
    ///   ダークモードなのに白いカードになる
    ///
    /// そのため colorScheme で判断すると背景に文字が溶ける。
    /// 背景そのものの明るさから決めることで、テーマが増えても破綻しない。
    static func readableText(on background: Color) -> Color {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(background).getRed(&r, green: &g, blue: &b, alpha: &a)
        let brightness = 0.299 * r + 0.587 * g + 0.114 * b
        return brightness > 0.6 ? Color(white: 0.12) : Color(white: 0.97)
    }
}
