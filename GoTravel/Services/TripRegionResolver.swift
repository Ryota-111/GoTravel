import Foundation
import CoreLocation
import Combine

/// 緯度・経度から国と都道府県を調べ、端末に覚えておく（旅の統計で使う）。
///
/// Apple の住所を調べる仕組み（逆ジオコーディング）は回数に上限があるので、
/// 約1km 四方ごとに1回だけ調べ、結果を UserDefaults に残す。まだ調べていない場所は、
/// 間をあけて1つずつ調べる（画面を閉じたら止める。次に開いたとき続きから）
@MainActor
final class TripRegionResolver: ObservableObject {
    static let shared = TripRegionResolver()

    /// 調べた結果が増えた合図（画面を数え直す）
    @Published private(set) var version = 0
    /// まだ調べていない場所の数（調べている間だけ）
    @Published private(set) var remaining = 0

    private var cache: [String: TripRegion]
    /// 海の上など、調べても国が分からなかった場所（何度も調べない）
    private var unknown: Set<String>
    private var isRunning = false

    private static let cacheKey = "tripRegionCache.v1"
    private static let unknownKey = "tripRegionUnknown.v1"
    /// 1回ごとの間（上限は1分あたり50回ほど）
    private static let interval: UInt64 = 1_300_000_000

    private init() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: Self.cacheKey),
           let decoded = try? JSONDecoder().decode([String: TripRegion].self, from: data) {
            cache = decoded
        } else {
            cache = [:]
        }
        unknown = Set(defaults.stringArray(forKey: Self.unknownKey) ?? [])
    }

    /// 約1km 四方ごとの鍵
    nonisolated static func key(_ latitude: Double, _ longitude: Double) -> String {
        "\(Int((latitude * 100).rounded()))_\(Int((longitude * 100).rounded()))"
    }

    func region(_ latitude: Double, _ longitude: Double) -> TripRegion? {
        cache[Self.key(latitude, longitude)]
    }

    /// まだ調べていない場所を、1つずつ調べる。呼んだ Task を止めると止まる
    func resolve(_ points: [(latitude: Double, longitude: Double)]) async {
        guard !isRunning else { return }
        let missing = points.filter {
            let key = Self.key($0.latitude, $0.longitude)
            return cache[key] == nil && !unknown.contains(key)
        }
        guard !missing.isEmpty else { return }
        isRunning = true
        defer {
            isRunning = false
            remaining = 0
        }
        remaining = missing.count
        let geocoder = CLGeocoder()
        for point in missing {
            if Task.isCancelled { return }
            let key = Self.key(point.latitude, point.longitude)
            do {
                let placemark = try await geocoder.reverseGeocodeLocation(
                    CLLocation(latitude: point.latitude, longitude: point.longitude),
                    preferredLocale: Locale(identifier: "ja_JP")
                ).first
                if let country = placemark?.isoCountryCode {
                    cache[key] = TripRegion(countryCode: country,
                                            prefectureName: country == "JP" ? placemark?.administrativeArea : nil)
                } else {
                    unknown.insert(key)
                }
                save()
                version += 1
            } catch {
                // 通信が無い・上限に届いたときは、次に開いたときに続きから
                if let clError = error as? CLError, clError.code == .geocodeFoundNoResult {
                    unknown.insert(key)
                    save()
                } else {
                    return
                }
            }
            remaining -= 1
            try? await Task.sleep(nanoseconds: Self.interval)
        }
    }

    private func save() {
        let defaults = UserDefaults.standard
        defaults.set(try? JSONEncoder().encode(cache), forKey: Self.cacheKey)
        defaults.set(Array(unknown), forKey: Self.unknownKey)
    }
}
