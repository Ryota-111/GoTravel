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

    /// 追加テーマを購入済みか。ProStore が所有を調べたあとに反映する。
    @Published private(set) var isPremiumUnlocked = false

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

    /// テーマを変更。使えないテーマは無視する。
    func setTheme(_ type: ThemePreset.ThemeType) {
        guard canUse(type) else { return }
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

    // MARK: - 購入状態

    /// そのテーマを今使えるか。
    /// 無料テーマは常に使える。追加テーマは購入済みか、季節テーマがその季節にあるとき。
    func canUse(_ type: ThemePreset.ThemeType, now: Date = Date()) -> Bool {
        if !type.isPremium { return true }
        if isPremiumUnlocked { return true }
        if let season = type.season, season.contains(now) { return true }
        return false
    }

    /// 未購入でも今だけ使える季節テーマか（一覧に「今だけ」と出すため）
    func isSeasonallyOpen(_ type: ThemePreset.ThemeType, now: Date = Date()) -> Bool {
        guard type.isPremium, !isPremiumUnlocked, let season = type.season else { return false }
        return season.contains(now)
    }

    /// ProStore から所有状態を受け取る
    func setPremiumUnlocked(_ unlocked: Bool) {
        guard isPremiumUnlocked != unlocked else { return }
        isPremiumUnlocked = unlocked
        enforceEntitlement()
    }

    /// 使えなくなったテーマを選んだままなら、標準に戻す。
    /// 季節が変わったときや、購入が失効したときに効く。
    func enforceEntitlement(now: Date = Date()) {
        if !canUse(currentTheme.type, now: now) {
            currentTheme = ThemePreset(type: .originalColor)
        }
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
