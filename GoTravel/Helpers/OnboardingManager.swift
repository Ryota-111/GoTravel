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
    }

    /// Reset onboarding state (for testing purposes)
    func resetOnboarding() {
        hasCompletedOnboarding = false
    }
}
