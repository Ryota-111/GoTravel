import Testing
import Foundation
@testable import GoTravel

/// 2.9 に上げた人にだけ、1度だけ聞く
struct TabSwipePromptTests {

    private func freshDefaults() -> UserDefaults {
        let name = "TabSwipePromptTests-\(UUID().uuidString)"
        return UserDefaults(suiteName: name)!
    }

    @Test("聞いたあとは、もう聞かない")
    func asksOnlyOnce() {
        let defaults = freshDefaults()
        defaults.set("pending", forKey: "TabSwipePromptState")
        #expect(TabSwipePrompt.shouldAsk(defaults: defaults))
        TabSwipePrompt.markAsked(defaults: defaults)
        #expect(!TabSwipePrompt.shouldAsk(defaults: defaults))
    }

    @Test("一度決めたら、起動し直しても決め直さない")
    func preparesOnlyOnce() {
        let defaults = freshDefaults()
        defaults.set("done", forKey: "TabSwipePromptState")
        TabSwipePrompt.prepareOnLaunch(defaults: defaults)
        #expect(!TabSwipePrompt.shouldAsk(defaults: defaults))
    }
}
