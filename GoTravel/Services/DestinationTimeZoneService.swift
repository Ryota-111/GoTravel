import Foundation
import CoreLocation

/// 旅行の目的地の時間帯を調べる。
///
/// 目的地の座標から逆ジオコーディングで引く。通信が要るので、
/// 一度引いた結果は座標ごとに端末へ覚えておく。
/// 座標が同じなら時間帯は変わらないので、古くなる心配は無い。
///
/// **同期しない。** 同じ座標なら誰が引いても同じ答えになるため、
/// 各端末で引き直せば足りる
@MainActor
final class DestinationTimeZoneService {
    static let shared = DestinationTimeZoneService()

    private let cacheKey = "destinationTimeZoneCache"
    private var inFlight: [String: Task<TimeZone?, Never>] = [:]

    private init() {}

    /// 覚えてある時間帯。まだ引いていなければ nil
    func cachedTimeZone(for plan: TravelPlan) -> TimeZone? {
        guard let key = Self.key(for: plan),
              let identifier = cache[key] else { return nil }
        return TimeZone(identifier: identifier)
    }

    /// 目的地の時間帯。座標が無い・引けなかったときは nil
    func timeZone(for plan: TravelPlan) async -> TimeZone? {
        guard let key = Self.key(for: plan),
              let latitude = plan.latitude,
              let longitude = plan.longitude else { return nil }

        if let cached = cachedTimeZone(for: plan) { return cached }

        // 同じ計画の画面を続けて開いたときに、同じ問い合わせを重ねない
        if let running = inFlight[key] { return await running.value }

        let task = Task<TimeZone?, Never> {
            let location = CLLocation(latitude: latitude, longitude: longitude)
            let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first
            return placemark?.timeZone
        }
        inFlight[key] = task
        let result = await task.value
        inFlight[key] = nil

        if let result {
            var updated = cache
            updated[key] = result.identifier
            UserDefaults.standard.set(updated, forKey: cacheKey)
        }
        return result
    }

    private var cache: [String: String] {
        UserDefaults.standard.dictionary(forKey: cacheKey) as? [String: String] ?? [:]
    }

    /// 小数2桁（約1km）で丸める。目的地は「パリ」のような広い言葉から引いた1点なので、
    /// これで時間帯の境目をまたぐことはまず無い
    private static func key(for plan: TravelPlan) -> String? {
        guard let latitude = plan.latitude, let longitude = plan.longitude else { return nil }
        return String(format: "%.2f,%.2f", latitude, longitude)
    }
}
