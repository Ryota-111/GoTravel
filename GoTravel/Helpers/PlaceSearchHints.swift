import Foundation
import MapKit

/// 場所を探すときに、どのあたりを優先して探すかを決める（3.4）。
///
/// Apple の検索は、渡した範囲の近くを優先する。日本の地図を映したまま韓国の住所を探すと、
/// 見つからないか、**日本の別の場所（1,000km 以上離れたところ）が出てしまっていた**
/// （「韓国の行きたい場所を住所で探せなかった」というご意見）。実際に試すと、行き先のあたりを
/// 渡せば、韓国語・英語・日本語のどの書き方の住所でもほぼ見つかった。
///
/// 探す範囲は、確かなものから順に：
/// 1. 入れた言葉から分かる国・町（ハングル、「ソウル」「台北」など）
/// 2. 今旅行している行き先
/// 3. 今映している地図のあたり（これまでどおり）
/// 4. これからの旅行の行き先（後ろに足すだけ。ふだんの検索で海外の結果が先に出ないように）
///
/// どの範囲でも見つからなければ、住所として探す（台湾の日本語の住所はこれでだけ見つかった）
enum PlaceSearchHints {

    struct Area {
        let pattern: Regex<Substring>
        let center: CLLocationCoordinate2D
        /// 度。国なら広く、町なら狭く
        let span: Double
    }

    /// 言葉から分かる町・国。町を先に並べる（「ソウル」は「韓国」より確か）
    static let areas: [Area] = [
        Area(pattern: /ソウル|서울|[Ss]eoul|明洞|명동|弘大|홍대|江南|강남|仁寺洞|인사동/, center: .init(latitude: 37.566, longitude: 126.978), span: 0.6),
        Area(pattern: /釜山|부산|[Bb]usan|海雲台|해운대|西面|서면/, center: .init(latitude: 35.180, longitude: 129.076), span: 0.6),
        Area(pattern: /済州|濟州|제주|[Jj]eju/, center: .init(latitude: 33.381, longitude: 126.553), span: 1.2),
        Area(pattern: /仁川|인천|[Ii]ncheon/, center: .init(latitude: 37.456, longitude: 126.705), span: 0.6),
        Area(pattern: /大邱|대구|[Dd]aegu/, center: .init(latitude: 35.871, longitude: 128.602), span: 0.6),
        Area(pattern: /台北|臺北|[Tt]aipei|九份|淡水|西門|信義/, center: .init(latitude: 25.048, longitude: 121.533), span: 0.6),
        Area(pattern: /台中|臺中|[Tt]aichung/, center: .init(latitude: 24.148, longitude: 120.674), span: 0.6),
        Area(pattern: /高雄|[Kk]aohsiung/, center: .init(latitude: 22.627, longitude: 120.301), span: 0.6),
        Area(pattern: /台南|臺南|[Tt]ainan/, center: .init(latitude: 22.999, longitude: 120.227), span: 0.6),
        Area(pattern: /香港|[Hh]ong ?[Kk]ong/, center: .init(latitude: 22.320, longitude: 114.169), span: 0.6),
        Area(pattern: /韓国|대한민국|한국|[Kk]orea|\p{Script=Hangul}/, center: .init(latitude: 36.400, longitude: 127.900), span: 6),
        Area(pattern: /台湾|臺灣|台灣|[Tt]aiwan/, center: .init(latitude: 23.700, longitude: 120.960), span: 4)
    ]

    /// 入れた言葉から分かるいちばん確かな範囲
    static func hintedRegion(for query: String) -> MKCoordinateRegion? {
        guard let area = areas.first(where: { query.contains($0.pattern) }) else { return nil }
        return MKCoordinateRegion(center: area.center,
                                  span: MKCoordinateSpan(latitudeDelta: area.span, longitudeDelta: area.span))
    }

    /// 探す範囲を、確かなものから順に
    static func regions(for query: String, trips: [TravelPlan], around center: CLLocationCoordinate2D,
                        now: Date = Date()) -> [MKCoordinateRegion] {
        var result: [MKCoordinateRegion] = []
        if let hinted = hintedRegion(for: query) { result.append(hinted) }

        let today = Calendar.current.startOfDay(for: now)
        let withPlace = trips.filter { $0.latitude != nil && $0.longitude != nil }
        let ongoing = withPlace.filter { $0.startDate <= now && Calendar.current.startOfDay(for: $0.endDate) >= today }
        // これから半年のうちの旅行（近い順に2つまで）
        let upcoming = withPlace
            .filter { $0.startDate > now && $0.startDate < now.addingTimeInterval(183 * 86_400) }
            .sorted { $0.startDate < $1.startDate }
            .prefix(2)

        result += ongoing.map(tripRegion)
        // これまでどおりの範囲：今映しているあたりを中心に広く（遠くの場所も拾えるように）
        result.append(MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 60, longitudeDelta: 60)))
        result += upcoming.map(tripRegion)
        return result
    }

    /// 旅行の行き先のあたり。旅行の予定の検索（`placeSearchRegion`）より広め（行き先の国の中のほかの町も拾えるように）
    private static func tripRegion(_ plan: TravelPlan) -> MKCoordinateRegion {
        MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: plan.latitude ?? 0, longitude: plan.longitude ?? 0),
                           span: MKCoordinateSpan(latitudeDelta: 3, longitudeDelta: 3))
    }

    // MARK: 探す

    /// それぞれの範囲で探し、結果を順にまとめる（同じ場所は1つに）。何も無ければ住所として探す
    static func search(_ query: String, in regions: [MKCoordinateRegion],
                       resultTypes: MKLocalSearch.ResultType = [.pointOfInterest, .address]) async -> [MKMapItem] {
        let found = await withTaskGroup(of: (Int, [MKMapItem]).self) { group in
            for (index, region) in regions.prefix(4).enumerated() {
                group.addTask {
                    let request = MKLocalSearch.Request()
                    request.naturalLanguageQuery = query
                    request.resultTypes = resultTypes
                    request.region = region
                    let items = (try? await MKLocalSearch(request: request).start())?.mapItems ?? []
                    return (index, items)
                }
            }
            var byIndex: [Int: [MKMapItem]] = [:]
            for await (index, items) in group { byIndex[index] = items }
            return byIndex.keys.sorted().flatMap { byIndex[$0] ?? [] }
        }

        var unique: [MKMapItem] = []
        for item in found where !unique.contains(where: { isSamePlace($0, item) }) {
            unique.append(item)
        }
        if !unique.isEmpty { return Array(unique.prefix(25)) }

        // 住所として探す（例：台湾の日本語の住所）
        guard let placemarks = try? await CLGeocoder().geocodeAddressString(query) else { return [] }
        return placemarks.map { MKMapItem(placemark: MKPlacemark(placemark: $0)) }
    }

    /// 名前が同じで100m以内なら同じ場所
    private static func isSamePlace(_ a: MKMapItem, _ b: MKMapItem) -> Bool {
        guard a.name == b.name, let la = a.placemark.location, let lb = b.placemark.location else { return false }
        return la.distance(from: lb) < 100
    }
}
