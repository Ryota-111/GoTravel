import Testing
import CoreLocation
@testable import GoTravel

/// Google マップへは場所の名前で渡す（座標だけだと、施設から少しずれた点に案内される）
struct MapNavigatorTests {

    private let yomiuriland = CLLocationCoordinate2D(latitude: 35.6249, longitude: 139.5175)

    @Test("アプリには名前と、その近くで探すための中心を渡す")
    func appUsesNameAndCenter() throws {
        let url = try #require(MapNavigator.googleMapsURL(
            for: MapDestination(name: "よみうりランド", coordinate: yomiuriland), appInstalled: true))
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(url.scheme == "comgooglemaps")
        #expect(items.first { $0.name == "daddr" }?.value == "よみうりランド")
        #expect(items.first { $0.name == "center" }?.value == "35.6249,139.5175")
    }

    @Test("ブラウザ版も名前で開く")
    func webUsesName() throws {
        let url = try #require(MapNavigator.googleMapsURL(
            for: MapDestination(name: "よみうりランド", coordinate: yomiuriland), appInstalled: false))
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(url.host == "www.google.com")
        #expect(items.first { $0.name == "destination" }?.value == "よみうりランド")
    }

    @Test("名前が無ければ座標で開く")
    func fallsBackToCoordinate() throws {
        let url = try #require(MapNavigator.googleMapsURL(
            for: MapDestination(name: "  ", coordinate: yomiuriland), appInstalled: true))
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(items.first { $0.name == "daddr" }?.value == "35.6249,139.5175")
    }

    @Test("名前の「+」は空白にならない")
    func keepsPlus() throws {
        let url = try #require(MapNavigator.googleMapsURL(
            for: MapDestination(name: "A+B ホテル", coordinate: yomiuriland), appInstalled: false))
        #expect(url.absoluteString.contains("A%2BB"))
    }

    @Test("場所のページ（3.8）：アプリでは名前で探し、近くの座標を添える。ブラウザ版も名前で探す")
    func placePage() throws {
        let destination = MapDestination(name: "よみうりランド", coordinate: yomiuriland)
        let app = try #require(MapNavigator.googlePlaceURL(for: destination, appInstalled: true))
        let appItems = try #require(URLComponents(url: app, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(app.scheme == "comgooglemaps")
        #expect(appItems.first { $0.name == "q" }?.value == "よみうりランド")
        #expect(appItems.first { $0.name == "center" }?.value == "35.6249,139.5175")

        let web = try #require(MapNavigator.googlePlaceURL(for: destination, appInstalled: false))
        let webItems = try #require(URLComponents(url: web, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(web.absoluteString.hasPrefix("https://www.google.com/maps/search/?api=1"))
        #expect(webItems.first { $0.name == "query" }?.value == "よみうりランド")

        let unnamed = try #require(MapNavigator.googlePlaceURL(
            for: MapDestination(name: " ", coordinate: yomiuriland), appInstalled: false))
        #expect(URLComponents(url: unnamed, resolvingAgainstBaseURL: false)?.queryItems?
            .first { $0.name == "query" }?.value == "35.6249,139.5175")
    }
}
