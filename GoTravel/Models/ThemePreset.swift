import SwiftUI

struct ThemePreset {
    // MARK: - Season
    /// 季節テーマ。その季節のあいだは未購入でも使える。
    enum Season: String, Codable, CaseIterable {
        case spring, summer, autumn, winter

        var displayName: String {
            switch self {
            case .spring: return "春"
            case .summer: return "夏"
            case .autumn: return "秋"
            case .winter: return "冬"
            }
        }

        var months: [Int] {
            switch self {
            case .spring: return [3, 4, 5]
            case .summer: return [6, 7, 8]
            case .autumn: return [9, 10, 11]
            case .winter: return [12, 1, 2]
            }
        }

        func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
            months.contains(calendar.component(.month, from: date))
        }
    }

    // MARK: - Theme Type
    enum ThemeType: String, Codable, CaseIterable {
        // 無料。既存ユーザーの見た目を変えないため、この3つは触らない。
        case originalColor = "デフォルトカラー"
        case whiteBlack = "白黒(白色メイン)"
        case pastelPink = "パステルピンク"

        // 有料。色だけで成立するもの。
        case aiKinari = "藍と生成り"
        case sumi = "墨"
        case sakura = "桜"
        case momiji = "紅葉"
        case setouchi = "瀬戸内"
        case yukiguni = "雪国"
        case yakouRessha = "夜行列車"

        var displayName: String { rawValue }

        /// 追加テーマかどうか。既存の3つは無料のまま据え置く。
        var isPremium: Bool {
            switch self {
            case .originalColor, .whiteBlack, .pastelPink: return false
            default: return true
            }
        }

        /// 季節テーマなら、その季節。
        var season: Season? {
            switch self {
            case .sakura: return .spring
            case .setouchi: return .summer
            case .momiji: return .autumn
            case .yukiguni: return .winter
            default: return nil
            }
        }

        var subtitle: String {
            switch self {
            case .originalColor: return "標準の配色"
            case .whiteBlack: return "白と黒だけ"
            case .pastelPink: return "やわらかいピンク"
            case .aiKinari: return "藍染の濃淡と、晒していない布の色"
            case .sumi: return "色を使わず、濃さで分ける。朱は記念日だけ"
            case .sakura: return "桜と若草と藤。春のいろ"
            case .momiji: return "柿・黄金・臙脂。秋のいろ"
            case .setouchi: return "凪いだ海と砂。夏のいろ"
            case .yukiguni: return "ほとんど無彩色。冬のいろ"
            case .yakouRessha: return "濃紺の車内に、琥珀の読書灯"
            }
        }

        /// ダークの配色を持つか。持たないテーマはライト固定で表示する。
        var followsSystemAppearance: Bool {
            switch self {
            case .whiteBlack, .pastelPink: return false
            default: return true
            }
        }

        static var freeCases: [ThemeType] { allCases.filter { !$0.isPremium } }
        static var premiumCases: [ThemeType] { allCases.filter { $0.isPremium } }
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
            primary = Color(red: 255/255, green: 182/255, blue: 193/255)
            secondary = Color(red: 255/255, green: 209/255, blue: 220/255)
            tertiary = Color.gray

            xprimary = Color(red: 255/255, green: 182/255, blue: 193/255)
            xsecondary = Color(red: 255/255, green: 209/255, blue: 220/255)

            yprimary = Color(red: 255/255, green: 182/255, blue: 193/255)
            ysecondary = Color(red: 255/255, green: 209/255, blue: 220/255)

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
            accent2 = Color.white
            accent3 = Color(red: 0.5, green: 0.4, blue: 0.45)
            
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
            
            japan    = Color(red: 0.87, green: 0.37, blue: 0.50)   // ローズ
            travel   = Color(red: 0.55, green: 0.52, blue: 0.85)   // ラベンダーブルー
            family   = Color(red: 0.95, green: 0.60, blue: 0.42)   // コーラルピーチ
            landscape = Color(red: 0.40, green: 0.72, blue: 0.55)  // セージグリーン
            food     = Color(red: 0.90, green: 0.38, blue: 0.38)   // ウォームレッド
            custom   = Color(red: 0.70, green: 0.50, blue: 0.88)   // ライラック

        default:
            // 追加テーマは Palette から組み立てる。
            // 1テーマあたり13色を決めれば、残りはここで導出される。
            let p = Palette.forType(type)

            primary = p.accent
            secondary = p.planDaily
            tertiary = p.surfaceLight

            xprimary = p.accent
            xsecondary = p.planDaily

            yprimary = p.accent
            ysecondary = p.planDaily

            backgroundLight = p.bgLight
            secondaryBackgroundLight = p.surfaceLight
            backgroundDark = p.bgDark
            secondaryBackgroundDark = p.surfaceDark
            tertiaryBackground = p.accent.opacity(0.12)
            separatorLight = p.ink.opacity(0.14)
            separatorDark = Color.white.opacity(0.16)

            text = p.ink
            secondaryText = p.ink2
            tertiaryText = p.ink3
            budgetLightText = p.ink2
            budgetDarkText = Color.white.opacity(0.7)

            accent1 = p.ink
            accent2 = p.surfaceLight
            accent3 = p.ink3

            // 機能色は意味が伝わることが優先なので、テーマに寄せすぎない
            success = Color.green
            warning = Color.orange
            error = Color.red
            info = p.accent

            cardBackground1 = p.accent.opacity(0.08)
            cardBackground2 = p.surfaceLight
            cardBorder = p.accent.opacity(0.28)
            shadow = p.accent.opacity(0.18)

            gradientLight = p.bgLight
            gradientDark = p.surfaceLight
            light = p.bgLight
            dark = p.bgDark

            dailyPlanColor = p.planDaily
            outingPlanColor = p.planOuting
            travelColor = p.planTravel

            japan = p.album[0]
            travel = p.album[1]
            family = p.album[2]
            landscape = p.album[3]
            food = p.album[4]
            custom = p.album[5]
        }
    }
}

// MARK: - Identifiable
extension ThemePreset.ThemeType: Identifiable {
    var id: String { rawValue }
}

// MARK: - Palette
extension ThemePreset {
    /// 追加テーマの配色。ここに1組足せばテーマが1つ増える。
    struct Palette {
        var bgLight: Color
        var surfaceLight: Color
        var bgDark: Color
        var surfaceDark: Color

        var ink: Color
        var ink2: Color
        var ink3: Color

        /// 主役の色。ボタンや選択状態に使われる
        var accent: Color

        /// 予定の3種類。並んだときに判別できることが条件
        var planOuting: Color
        var planDaily: Color
        var planTravel: Color

        /// アルバムの6色。japan / travel / family / landscape / food / custom の順
        var album: [Color]

        static func forType(_ type: ThemeType) -> Palette {
            switch type {
            case .aiKinari:
                return Palette(
                    bgLight: hex(0xF4F1E8), surfaceLight: hex(0xFFFFFF),
                    bgDark: hex(0x10161D), surfaceDark: hex(0x1A2129),
                    ink: hex(0x1B2733), ink2: hex(0x6B7683), ink3: hex(0x9AA3AD),
                    accent: hex(0x21456E),
                    planOuting: hex(0x21456E), planDaily: hex(0x4E8A8B), planTravel: hex(0xA33B4B),
                    album: [hex(0x21456E), hex(0x4E8A8B), hex(0xA33B4B),
                            hex(0x5C7A4E), hex(0xB5793A), hex(0x6B5B8E)]
                )

            case .sumi:
                return Palette(
                    bgLight: hex(0xFAFAF8), surfaceLight: hex(0xFFFFFF),
                    bgDark: hex(0x0B0C0E), surfaceDark: hex(0x16181B),
                    ink: hex(0x14161A), ink2: hex(0x70747A), ink3: hex(0x9CA0A6),
                    accent: hex(0x3A3F47),
                    planOuting: hex(0x3A3F47), planDaily: hex(0x8B9098), planTravel: hex(0xB03A2E),
                    album: [hex(0x2A2E35), hex(0x4A4F57), hex(0x6A6F77),
                            hex(0x8B9098), hex(0xB03A2E), hex(0xA8ADB4)]
                )

            case .sakura:
                return Palette(
                    bgLight: hex(0xFBF6F5), surfaceLight: hex(0xFFFFFF),
                    bgDark: hex(0x161014), surfaceDark: hex(0x211A20),
                    ink: hex(0x2B2028), ink2: hex(0x7A6C74), ink3: hex(0xA79AA1),
                    accent: hex(0xC96F8B),
                    planOuting: hex(0xC96F8B), planDaily: hex(0x8AA65B), planTravel: hex(0x8C7BB5),
                    album: [hex(0xC96F8B), hex(0x8AA65B), hex(0x8C7BB5),
                            hex(0xD98F7A), hex(0x6F9BB5), hex(0xB58BA8)]
                )

            case .momiji:
                return Palette(
                    bgLight: hex(0xF6F1EA), surfaceLight: hex(0xFFFDF9),
                    bgDark: hex(0x1A1512), surfaceDark: hex(0x241D19),
                    ink: hex(0x2A211C), ink2: hex(0x77685F), ink3: hex(0xA4968C),
                    accent: hex(0xC05621),
                    planOuting: hex(0xC05621), planDaily: hex(0xC99A2E), planTravel: hex(0x7E2536),
                    album: [hex(0xC05621), hex(0xC99A2E), hex(0x7E2536),
                            hex(0x6B7A3A), hex(0x8A5A3C), hex(0x9C6B4A)]
                )

            case .setouchi:
                return Palette(
                    bgLight: hex(0xF4F7F5), surfaceLight: hex(0xFFFFFF),
                    bgDark: hex(0x0C1315), surfaceDark: hex(0x16211F),
                    ink: hex(0x1B2A2E), ink2: hex(0x66787C), ink3: hex(0x95A4A7),
                    accent: hex(0x3E8FA8),
                    planOuting: hex(0x3E8FA8), planDaily: hex(0xC9A66B), planTravel: hex(0xD96A5C),
                    album: [hex(0x3E8FA8), hex(0xC9A66B), hex(0xD96A5C),
                            hex(0x5FA88C), hex(0x7F9AB5), hex(0xB58A5C)]
                )

            case .yukiguni:
                return Palette(
                    bgLight: hex(0xF7F9FB), surfaceLight: hex(0xFFFFFF),
                    bgDark: hex(0x0D1218), surfaceDark: hex(0x171E26),
                    ink: hex(0x1A2430), ink2: hex(0x6D7885), ink3: hex(0x9AA4AF),
                    accent: hex(0x3E76A6),
                    planOuting: hex(0x3E76A6), planDaily: hex(0x8C8F98), planTravel: hex(0xA94E67),
                    album: [hex(0x3E76A6), hex(0x8C8F98), hex(0xA94E67),
                            hex(0x5B8C8C), hex(0x7A6E96), hex(0x9C8B7A)]
                )

            case .yakouRessha:
                return Palette(
                    bgLight: hex(0xE9ECF2), surfaceLight: hex(0xFFFFFF),
                    bgDark: hex(0x10131A), surfaceDark: hex(0x1A1F2A),
                    ink: hex(0x171B24), ink2: hex(0x6A7181), ink3: hex(0x99A0AE),
                    accent: hex(0xC98A2E),
                    planOuting: hex(0xC98A2E), planDaily: hex(0x6E8CB5), planTravel: hex(0xC4566A),
                    album: [hex(0xC98A2E), hex(0x6E8CB5), hex(0xC4566A),
                            hex(0x5C8C7A), hex(0x8A7BA8), hex(0xA88A5C)]
                )

            case .originalColor, .whiteBlack, .pastelPink:
                // 無料の3つは init 側で直接定義しているので、ここには来ない
                return Palette(
                    bgLight: .white, surfaceLight: .white,
                    bgDark: .black, surfaceDark: .black,
                    ink: .black, ink2: .gray, ink3: .gray,
                    accent: .blue,
                    planOuting: .blue, planDaily: .orange, planTravel: .green,
                    album: [.blue, .orange, .pink, .green, .red, .purple]
                )
            }
        }

        private static func hex(_ value: UInt32) -> Color {
            Color(
                red: Double((value & 0xFF0000) >> 16) / 255.0,
                green: Double((value & 0x00FF00) >> 8) / 255.0,
                blue: Double(value & 0x0000FF) / 255.0
            )
        }
    }
}
