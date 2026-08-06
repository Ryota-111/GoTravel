import Foundation
import StoreKit
import UIKit

/// レビュー依頼を出すタイミングを管理する。
///
/// これまでは「ヘルプサポート → レビューを書く」を自分でタップした人にしか
/// 表示されず、3階層下にあるため実質機能していなかった。
/// 使っていて気分が良い場面で自動的に出すようにする。
final class ReviewRequestManager {
    static let shared = ReviewRequestManager()

    /// レビューを促すのにふさわしい場面
    enum Moment {
        /// 旅行が終わったあとに、その旅行を見返した
        case travelCompleted
        /// アルバムに写真を追加した
        case photosAdded
        /// 日本全国フォトマップの都道府県が増えた
        case prefectureAdded
    }

    private let defaults = UserDefaults.standard
    private let lastRequestKey = "ReviewLastRequestedAt"
    private let momentCountKey = "ReviewMomentCount"

    /// 使い始めたばかりの人に出さないよう、良い場面がこの回数たまってから依頼する
    private let requiredMoments = 3

    /// 一度依頼したら、しばらく間隔を空ける。
    /// Apple 側でも年3回に制限されるが、こちらでも抑えておく
    private let minimumInterval: TimeInterval = 60 * 60 * 24 * 120

    private init() {}

    /// 良い場面を記録し、条件がそろっていればレビュー依頼を出す
    @MainActor
    func record(_ moment: Moment) {
        let count = defaults.integer(forKey: momentCountKey) + 1
        defaults.set(count, forKey: momentCountKey)

        guard count >= requiredMoments else { return }
        guard hasEnoughTimePassed else { return }

        requestReview()
    }

    /// 設定画面などから明示的に依頼する場合。回数や間隔の条件は見ない
    @MainActor
    func requestManually() {
        requestReview()
    }

    // MARK: - Private

    private var hasEnoughTimePassed: Bool {
        guard let last = defaults.object(forKey: lastRequestKey) as? Date else {
            return true
        }
        return Date().timeIntervalSince(last) >= minimumInterval
    }

    @MainActor
    private func requestReview() {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else {
            return
        }

        AppStore.requestReview(in: scene)

        defaults.set(Date(), forKey: lastRequestKey)
        defaults.set(0, forKey: momentCountKey)
    }
}
