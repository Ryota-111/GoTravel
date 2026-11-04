import SwiftUI
import MapKit
import UIKit

/// 経路案内に使う地図アプリ
enum MapApp: String, CaseIterable, Identifiable {
    /// 案内のたびに選ぶ
    case ask
    case apple
    case google

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ask: return "毎回選ぶ"
        case .apple: return "Apple マップ"
        case .google: return "Google マップ"
        }
    }
}

/// 経路案内の行き先
struct MapDestination: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D

    init(name: String, coordinate: CLLocationCoordinate2D) {
        self.name = name
        self.coordinate = coordinate
    }

    /// 場所の検索結果から
    init(_ mapItem: MKMapItem) {
        self.init(name: mapItem.name ?? "", coordinate: mapItem.placemark.coordinate)
    }

    static func == (lhs: MapDestination, rhs: MapDestination) -> Bool {
        lhs.id == rhs.id
    }
}

/// 地図アプリで経路案内を開く。
///
/// 以前は画面ごとに作りがばらばらで、Apple マップしか開けない画面と、
/// Google マップのアプリが入っていないと押しても何も起きない画面があった。
/// 「Google マップだとホテルやお店のページがそのまま見られる」との要望を受けて、
/// どの画面からでも同じアプリで開けるようにここへ寄せた
enum MapNavigator {
    static let preferenceKey = "preferredMapApp"

    /// プロフィールで選んだアプリ。選んでいなければ毎回選ぶ
    static var preference: MapApp {
        UserDefaults.standard.string(forKey: preferenceKey).flatMap(MapApp.init(rawValue:)) ?? .ask
    }

    /// Info.plist の `LSApplicationQueriesSchemes` に `comgooglemaps` が要る
    static var isGoogleMapsInstalled: Bool {
        guard let url = URL(string: "comgooglemaps://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    static func open(_ destination: MapDestination, in app: MapApp) {
        switch app {
        case .ask, .apple:
            let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: destination.coordinate))
            mapItem.name = destination.name
            mapItem.openInMaps(launchOptions: [
                MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
            ])

        case .google:
            if let url = googleMapsURL(for: destination, appInstalled: isGoogleMapsInstalled) {
                UIApplication.shared.open(url)
            }
        }
    }

    /// Google マップで開く URL。アプリが無ければブラウザ版。
    ///
    /// 行き先は場所の名前で渡し、Google マップ側で施設を引かせる（3.3）。
    /// 座標だけを渡すと、Apple マップの座標の点（施設の真ん中など）への経路になり、
    /// 「よみうりランドから少しずれたところに飛ぶ」とご報告をいただいた。
    /// アプリには `center` も渡し、同じ名前の別の店ではなく、その場所の近くで探させる。
    /// 名前が無いときは、これまでどおり座標で開く
    static func googleMapsURL(for destination: MapDestination, appInstalled: Bool) -> URL? {
        let latitude = destination.coordinate.latitude
        let longitude = destination.coordinate.longitude
        let coordinate = "\(latitude),\(longitude)"
        let name = destination.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let target = name.isEmpty ? coordinate : name

        var components: URLComponents
        if appInstalled {
            components = URLComponents(string: "comgooglemaps://")!
            components.queryItems = [
                URLQueryItem(name: "daddr", value: target),
                URLQueryItem(name: "center", value: coordinate),
                URLQueryItem(name: "directionsmode", value: "driving")
            ]
        } else {
            // 以前はアプリ用の URL だけを開いていたため、入っていないと何も起きなかった
            components = URLComponents(string: "https://www.google.com/maps/dir/")!
            components.queryItems = [
                URLQueryItem(name: "api", value: "1"),
                URLQueryItem(name: "destination", value: target),
                URLQueryItem(name: "travelmode", value: "driving")
            ]
        }
        // URLComponents は「+」をそのまま残し、空白と読まれてしまう（「A+B ホテル」など）
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        return components.url
    }
}

// MARK: - 画面に付ける

extension View {
    /// 経路案内を受け持つ。`destination` に行き先を入れると案内が始まる。
    ///
    /// 設定が「毎回選ぶ」のときだけ、どのアプリで開くかを聞く。
    /// 決めてあればそのアプリをすぐ開く
    func mapNavigation(_ destination: Binding<MapDestination?>) -> some View {
        modifier(MapNavigationModifier(destination: destination))
    }
}

private struct MapNavigationModifier: ViewModifier {
    @Binding var destination: MapDestination?
    @AppStorage(MapNavigator.preferenceKey) private var preference: String = MapApp.ask.rawValue

    private var asksEveryTime: Bool {
        (MapApp(rawValue: preference) ?? .ask) == .ask
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: destination) { _, newValue in
                guard let newValue, !asksEveryTime else { return }
                MapNavigator.open(newValue, in: MapNavigator.preference)
                destination = nil
            }
            .confirmationDialog(
                destination?.name ?? "",
                isPresented: Binding(
                    get: { destination != nil && asksEveryTime },
                    set: { if !$0 { destination = nil } }
                ),
                titleVisibility: .visible,
                presenting: destination
            ) { target in
                Button("Apple マップで案内") { MapNavigator.open(target, in: .apple) }
                Button("Google マップで案内") { MapNavigator.open(target, in: .google) }
                Button("キャンセル", role: .cancel) {}
            } message: { _ in
                Text("案内するアプリを選択してください。いつも使うアプリは、プロフィールの「経路案内のアプリ」で決めておけます。")
            }
    }
}
