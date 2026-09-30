import Foundation
import MapKit

/// 地図に出すピンがすべて入る範囲を決める。
///
/// **日付変更線をまたぐ旅行に対応する。** 経度の最小と最大の真ん中を取ると、
/// 羽田（東経139.8度）とホノルル（西経157.9度）の真ん中が大西洋（経度 −9度）になり、
/// ピンも線も映らない場所が出ていた。経度は円なので、ピンが入る**いちばん短い弧**で囲む
enum MapRegionFitting {

    /// - Parameters:
    ///   - coordinates: 入れたい地点。空なら nil
    ///   - padding: ピンが画面端に張り付かないよう、幅を何倍にするか
    ///   - minimumSpan: 1か所だけのときなどに寄りすぎない幅（度）
    static func region(fitting coordinates: [CLLocationCoordinate2D],
                       padding: Double = 1.5,
                       minimumSpan: Double = 0.01) -> MKCoordinateRegion? {
        guard !coordinates.isEmpty else { return nil }

        let latitudes = coordinates.map(\.latitude)
        let minLat = latitudes.min() ?? 0
        let maxLat = latitudes.max() ?? 0

        let arc = shortestLongitudeArc(coordinates.map(\.longitude))

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: arc.center
        )
        let span = MKCoordinateSpan(
            latitudeDelta: min(max((maxLat - minLat) * padding, minimumSpan), 170),
            longitudeDelta: min(max(arc.width * padding, minimumSpan), 360)
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    /// すべての経度が入る、いちばん短い弧の真ん中（−180〜180）と幅（度）。
    ///
    /// 経度を並べ、隣どうしの隙間がいちばん大きいところで円を切り開く。
    /// その隙間の外側が、全部を含むいちばん短い弧になる
    static func shortestLongitudeArc(_ longitudes: [Double]) -> (center: Double, width: Double) {
        let sorted = longitudes.map(normalized).sorted()
        guard let first = sorted.first, let last = sorted.last else { return (0, 0) }

        // 最後から一周して最初に戻る隙間（日付変更線をまたぐ側）
        var largestGap = first + 360 - last
        var start = first
        for index in sorted.indices.dropFirst() {
            let gap = sorted[index] - sorted[index - 1]
            if gap > largestGap {
                largestGap = gap
                start = sorted[index]
            }
        }

        let width = 360 - largestGap
        return (normalized(start + width / 2), width)
    }

    /// 経度を −180〜180 に収める
    private static func normalized(_ longitude: Double) -> Double {
        var value = longitude.truncatingRemainder(dividingBy: 360)
        if value > 180 { value -= 360 }
        if value <= -180 { value += 360 }
        return value
    }
}
