import Foundation

/// Manages onboarding state using UserDefaults
class OnboardingManager {
    static let shared = OnboardingManager()

    private let hasCompletedOnboardingKey = "hasCompletedOnboarding"

    private init() {}

    /// Check if user has completed onboarding
    var hasCompletedOnboarding: Bool {
        get {
            UserDefaults.standard.bool(forKey: hasCompletedOnboardingKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: hasCompletedOnboardingKey)
        }
    }

    /// Mark onboarding as completed
    func completeOnboarding() {
        hasCompletedOnboarding = true

        // 新機能のお知らせは、この人にとっては全部が新機能なので出さない。
        // 今のバージョンを見たことにして塞ぐ。
        //
        // ここで塞がないと、オンボーディングを終えた直後に
        // 「タグで予定を仕分けられます」と出る。WhatsNewManager 側は
        // 記録が無いときに hasCompletedOnboarding で
        // 「新規の人」と「この仕組みより前から使っている人」を見分けているが、
        // オンボーディングは起動直後に終わるので、新規の人も true になる
        WhatsNewManager.markAsShown()
    }

    /// Reset onboarding state (for testing purposes)
    func resetOnboarding() {
        hasCompletedOnboarding = false
    }
}
