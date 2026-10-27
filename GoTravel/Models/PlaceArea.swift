import Foundation

// MARK: - 保存した場所を県で分ける（3.1）
//
// 場所保存の一覧と地図を、県ごとに絞り込む（「県で地図表示を分けられると分かりやすい」というご要望から）。
// 県は住所の文字から読み、住所に県が無ければ、旅の記録と同じ仕組み（`TripRegionResolver`）で
// 緯度・経度から調べて覚えた結果を使う。計算は外の世界に触らない

enum PlaceArea: Hashable {
    /// 日本のどこかの県
    case prefecture(Prefecture)
    /// 日本の外
    case abroad
    /// まだ分からない（調べている途中か、海の上など）
    case unknown

    var title: String {
        switch self {
        case .prefecture(let prefecture): return prefecture.name
        case .abroad: return "海外"
        case .unknown: return "県が分からない場所"
        }
    }

    /// その場所の県。住所に県の名前があればそれ、無ければ緯度・経度から調べた結果
    static func of(_ place: VisitedPlace, region: (Double, Double) -> TripRegion?) -> PlaceArea {
        if let address = place.address,
           let prefecture = Prefecture.allCases.first(where: { address.contains($0.name) }) {
            return .prefecture(prefecture)
        }
        guard let found = region(place.latitude, place.longitude) else { return .unknown }
        if let prefecture = found.prefecture { return .prefecture(prefecture) }
        return found.countryCode == "JP" ? .unknown : .abroad
    }

    /// 場所のある県と、その数。県は北から順、そのあと海外、分からない場所
    static func counts(of places: [VisitedPlace], region: (Double, Double) -> TripRegion?) -> [(area: PlaceArea, count: Int)] {
        let grouped = Dictionary(grouping: places) { of($0, region: region) }.mapValues(\.count)
        let prefectures = Prefecture.allCases.compactMap { prefecture in
            grouped[.prefecture(prefecture)].map { (area: PlaceArea.prefecture(prefecture), count: $0) }
        }
        let rest = [PlaceArea.abroad, .unknown].compactMap { area in grouped[area].map { (area: area, count: $0) } }
        return prefectures + rest
    }

    /// 住所から県が分からず、まだ調べていない場所（緯度・経度を調べに行く）
    static func needsLookup(_ places: [VisitedPlace], region: (Double, Double) -> TripRegion?) -> [VisitedPlace] {
        places.filter { place in
            let fromAddress = place.address.map { address in Prefecture.allCases.contains { address.contains($0.name) } } ?? false
            return !fromAddress && region(place.latitude, place.longitude) == nil
        }
    }
}
