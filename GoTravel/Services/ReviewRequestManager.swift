import Foundation
import StoreKit
import UIKit

/// レビュー依頼を出すタイミングを管理する。
///
/// 出すのは次の2つの場面だけ（3.8 で絞った）。
/// - 日本全国フォトマップの写真が、合わせて3枚になったとき（1回だけ）
/// - 旅行が終わった次の日に、アプリを開いたとき（旅行ごとに1回）
///
/// どちらも、旅の思い出が良い形で残っている場面。うまくいかなかった操作の直後（予約を読み取れなかったなど）には出さない。
/// 一度出したら、しばらく（120日）は出さない。Apple 側でも年3回に制限される
final class ReviewRequestManager {
    static let shared = ReviewRequestManager()

    private let defaults = UserDefaults.standard
    private let lastRequestKey = "ReviewLastRequestedAt"
    private let photoMapAskedKey = "ReviewPhotoMapAsked"
    private let tripsAskedKey = "ReviewDayAfterTripAsked"

    /// フォトマップの写真がこの枚数になったら
    static let photoMapPhotoCount = 3

    /// 一度依頼したら、しばらく間隔を空ける
    private let minimumInterval: TimeInterval = 60 * 60 * 24 * 120

    private init() {}

    // MARK: - 場面

    /// フォトマップに写真を入れたあとに呼ぶ。合わせて3枚以上になっていれば、1回だけ依頼する
    @MainActor
    func photoMapPhotosAdded(albumId: String) {
        guard !defaults.bool(forKey: photoMapAskedKey) else { return }
        let count = AlbumManager.shared.photoCount(albumId: albumId)
        guard Self.reachedPhotoMapCount(count) else { return }
        defaults.set(true, forKey: photoMapAskedKey)
        requestIfAllowed()
    }

    /// アプリを開いたときに呼ぶ。今日が、どれかの旅行が終わった次の日なら、その旅行で1回だけ依頼する
    @MainActor
    func checkDayAfterTrip(plans: [TravelPlan], now: Date = Date()) {
        var asked = Set(defaults.stringArray(forKey: tripsAskedKey) ?? [])
        guard let plan = Self.tripEndedYesterday(plans, now: now, excluding: asked), let planId = plan.id else { return }
        asked.insert(planId)
        defaults.set(Array(asked), forKey: tripsAskedKey)
        requestIfAllowed()
    }

    /// 設定画面などから明示的に依頼する場合。回数や間隔の条件は見ない
    @MainActor
    func requestManually() {
        requestReview()
    }

    // MARK: - 判断（テストで確かめる）

    static func reachedPhotoMapCount(_ count: Int) -> Bool {
        count >= photoMapPhotoCount
    }

    /// 昨日終わった旅行（まだ依頼していないもの）
    static func tripEndedYesterday(_ plans: [TravelPlan], now: Date, excluding asked: Set<String>,
                                   calendar: Calendar = .current) -> TravelPlan? {
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now) else { return nil }
        return plans.first { plan in
            guard let id = plan.id, !asked.contains(id) else { return false }
            return calendar.isDate(plan.endDate, inSameDayAs: yesterday)
        }
    }

    // MARK: - Private

    private var hasEnoughTimePassed: Bool {
        guard let last = defaults.object(forKey: lastRequestKey) as? Date else {
            return true
        }
        return Date().timeIntervalSince(last) >= minimumInterval
    }

    @MainActor
    private func requestIfAllowed() {
        guard hasEnoughTimePassed else { return }
        requestReview()
    }

    @MainActor
    private func requestReview() {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else {
            return
        }

        AppStore.requestReview(in: scene)

        defaults.set(Date(), forKey: lastRequestKey)
    }
}
