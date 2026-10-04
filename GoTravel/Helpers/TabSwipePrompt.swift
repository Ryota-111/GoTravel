import Foundation

/// 2.9 に上げた人に、旅行計画を初めて開いたとき1度だけ「横にスライドしてタブを移るか」を聞く。
///
/// 2.9 でこの動きをオン・オフできるようにした（アプリ設定の「操作」）。
/// 日程を横になぞって地図へ移ってしまうのがストレスだった人に、設定を探さなくても選べるようにする。
/// 新しく入れた人には聞かない（最初から設定で選べるため）。
///
/// アップデートした人かどうかは、起動したときに前に見たお知らせの版で分かる。
/// 旅行計画を開くころには、お知らせを出した時点で記録が新しい版に変わっているので、
/// **起動したとき（お知らせの判定より前）に `prepareOnLaunch()` で覚えておく**
enum TabSwipePrompt {

    private static let stateKey = "TabSwipePromptState"
    private static let pending = "pending"
    private static let done = "done"

    /// 起動したときに1回呼ぶ。まだ決めていなければ、アップデートした人なら「聞く」にする
    static func prepareOnLaunch(defaults: UserDefaults = .standard) {
        guard defaults.string(forKey: stateKey) == nil else { return }
        defaults.set(WhatsNewManager.isUpdateFromOlderVersion ? pending : done, forKey: stateKey)
    }

    /// 旅行計画を開いたときに聞くか
    static func shouldAsk(defaults: UserDefaults = .standard) -> Bool {
        defaults.string(forKey: stateKey) == pending
    }

    /// 聞いた（答えたか閉じたか）。もう聞かない
    static func markAsked(defaults: UserDefaults = .standard) {
        defaults.set(done, forKey: stateKey)
    }
}
