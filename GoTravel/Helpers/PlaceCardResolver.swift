import MapKit

/// 予定の場所から、iOS の場所カード（Apple マップと同じ、写真・営業時間つきの画面）に渡す施設を引く（3.3）。
///
/// 予定は場所の名前と緯度・経度しか持っていない。座標だけで場所カードを開くと「ドロップしたピン」の
/// カードになり、写真も営業時間も出ない。名前で施設を探し、その座標のすぐ近くにあるものを使う。
/// 見つからなければ、座標だけのカード（住所は出る）にする
enum PlaceCardResolver {

    /// 予定の座標から、これより離れた施設は同じ名前の別の店とみなす
    static let matchDistance: CLLocationDistance = 300

    static func mapItem(name: String?, coordinate: CLLocationCoordinate2D) async -> MKMapItem {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty, let found = await search(trimmed, near: coordinate) {
            return found
        }
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        item.name = trimmed.isEmpty ? nil : trimmed
        return item
    }

    private static func search(_ name: String, near coordinate: CLLocationCoordinate2D) async -> MKMapItem? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = name
        request.resultTypes = .pointOfInterest
        request.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 2_000, longitudinalMeters: 2_000)
        guard let response = try? await MKLocalSearch(request: request).start() else { return nil }

        let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        func distance(_ item: MKMapItem) -> CLLocationDistance {
            let point = item.placemark.coordinate
            return CLLocation(latitude: point.latitude, longitude: point.longitude).distance(from: target)
        }
        guard let nearest = response.mapItems.min(by: { distance($0) < distance($1) }),
              distance(nearest) <= matchDistance else { return nil }
        return nearest
    }
}
