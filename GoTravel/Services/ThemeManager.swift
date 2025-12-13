import SwiftUI
import Combine

/// テーマを管理するシングルトンクラス
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    // MARK: - Published Properties
    @Published var currentTheme: ThemePreset {
        didSet {
            saveTheme()
        }
    }

    // MARK: - UserDefaults Key
    private let themeKey = "selectedTheme"

    // MARK: - Initialization
    private init() {
        // UserDefaultsから保存されたテーマを読み込む
        if let savedThemeRawValue = UserDefaults.standard.string(forKey: themeKey),
           let themeType = ThemePreset.ThemeType(rawValue: savedThemeRawValue) {
            self.currentTheme = ThemePreset(type: themeType)
        } else {
            // デフォルトはBlue & Purpleテーマ
            self.currentTheme = ThemePreset(type: .originalColor)
        }
    }

    // MARK: - Public Methods

    /// テーマを変更
    func setTheme(_ type: ThemePreset.ThemeType) {
        currentTheme = ThemePreset(type: type)
    }

    /// テーマを保存
    private func saveTheme() {
        UserDefaults.standard.set(currentTheme.type.rawValue, forKey: themeKey)
    }

    /// 全テーマタイプを取得
    func allThemeTypes() -> [ThemePreset.ThemeType] {
        return ThemePreset.ThemeType.allCases
    }
}

// MARK: - View Extension for Easy Theme Access
extension View {
    func themedBackground() -> some View {
        self.background(ThemeManager.shared.currentTheme.backgroundLight.ignoresSafeArea())
    }

    func themedCardBackground() -> some View {
        self.background(ThemeManager.shared.currentTheme.cardBackground2)
    }

    func themedText() -> some View {
        self.foregroundColor(ThemeManager.shared.currentTheme.text)
    }

    func themedSecondaryText() -> some View {
        self.foregroundColor(ThemeManager.shared.currentTheme.secondaryText)
    }

    func themedPrimary() -> some View {
        self.foregroundColor(ThemeManager.shared.currentTheme.primary)
    }
}
