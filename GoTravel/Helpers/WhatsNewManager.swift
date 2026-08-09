import Foundation

/// アップデート後に一度だけ「新機能のお知らせ」を出すための状態管理。
///
/// リリースノートを読むユーザーはごく一部なので、追加した機能や
/// 意見の送り先はアプリ内でも伝えないと気付かれない。
enum WhatsNewManager {
    private static let lastShownVersionKey = "lastShownWhatsNewVersion"

    /// 動作確認用。true の間は起動のたびにお知らせを出す。
    ///
    /// 本来の「1バージョンにつき1回」の挙動を確認したくなったら false に戻す。
    /// DEBUG ビルド限定なので、消し忘れてもTestFlightやApp Storeには影響しない。
    #if DEBUG
    static let alwaysShowForTesting = true
    #endif

    /// 現在のアプリバージョン（"2.4" など。ビルド番号は含めない）
    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    /// お知らせを出すべきか。
    ///
    /// 新規インストールでは出さない。オンボーディング直後に
    /// 「新機能」と言われても、その人にとっては全部が新機能で意味がないため。
    static var shouldShow: Bool {
        guard WhatsNew.current != nil else { return false }

        #if DEBUG
        if alwaysShowForTesting { return true }
        #endif

        guard let lastShown = UserDefaults.standard.string(forKey: lastShownVersionKey) else {
            // 記録が無い = 初回起動、または この仕組みを入れる前から使っている人。
            // 後者にはお知らせを見せたいので、オンボーディング済みかで判定する
            return OnboardingManager.shared.hasCompletedOnboarding
        }
        return lastShown != currentVersion
    }

    /// 表示済みとして記録する
    static func markAsShown() {
        UserDefaults.standard.set(currentVersion, forKey: lastShownVersionKey)
    }

    /// 動作確認用
    static func reset() {
        UserDefaults.standard.removeObject(forKey: lastShownVersionKey)
    }
}

// MARK: - お知らせの中身

/// バージョンごとのお知らせ。リリースのたびにここだけ書き換える
struct WhatsNew: Identifiable {
    struct Item: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let detail: String
    }

    let version: String
    let items: [Item]

    var id: String { version }

    /// 現在のバージョンのお知らせ。用意していないバージョンでは nil（＝表示しない）
    static var current: WhatsNew? {
        all.first { $0.version == WhatsNewManager.currentVersion }
    }

    private static let all: [WhatsNew] = [
        WhatsNew(
            version: "2.4",
            items: [
                Item(
                    icon: "lightbulb.fill",
                    title: "ご意見・ご要望を送れるようになりました",
                    detail: "「ヘルプ・サポート」から、欲しい機能や気になった点をそのまま送れます。いただいた声は必ず目を通しています。"
                ),
                Item(
                    icon: "person.2.fill",
                    title: "共有コードの不具合を修正",
                    detail: "共有コードが相手に届かないことがある問題を修正しました。コードは発行が完了してから表示されます。"
                ),
                Item(
                    icon: "globe",
                    title: "海外でも時刻が正しく表示されます",
                    detail: "現地の時間帯に合わせて予定の時刻を表示するようになりました。"
                ),
                Item(
                    icon: "lock.fill",
                    title: "ロック画面ウィジェットの更新を改善",
                    detail: "予定の時間を過ぎたら、次の予定に自動で切り替わるようになりました。"
                )
            ]
        )
    ]
}
