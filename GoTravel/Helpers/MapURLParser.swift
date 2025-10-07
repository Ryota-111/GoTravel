import Foundation
import CoreLocation

struct MapURLParser {

    /// Google MapsやApple MapsのURLから座標を抽出
    static func extractCoordinate(from urlString: String) -> CLLocationCoordinate2D? {
        guard URL(string: urlString) != nil else {
            return nil
        }

        // Google Maps URL パターン
        // https://maps.google.com/?q=35.6812,139.7671
        // https://www.google.com/maps/place/35.6812,139.7671
        // https://www.google.com/maps/@35.6812,139.7671,15z
        // https://maps.app.goo.gl/xxx (shortened URL - 解析不可)

        let urlStr = urlString

        // パターン1: ?q=lat,lng
        if let range = urlStr.range(of: #"\?q=(-?\d+\.?\d*),(-?\d+\.?\d*)"#, options: .regularExpression) {
            let coordStr = String(urlStr[range])
            let components = coordStr.replacingOccurrences(of: "?q=", with: "").split(separator: ",")
            if components.count == 2,
               let lat = Double(components[0]),
               let lng = Double(components[1]) {
                return CLLocationCoordinate2D(latitude: lat, longitude: lng)
            }
        }

        // パターン2: /@lat,lng,zoom
        if let range = urlStr.range(of: #"/@(-?\d+\.?\d*),(-?\d+\.?\d*),"#, options: .regularExpression) {
            let coordStr = String(urlStr[range])
            let components = coordStr.replacingOccurrences(of: "/@", with: "").replacingOccurrences(of: ",", with: " ").split(separator: " ")
            if components.count >= 2,
               let lat = Double(components[0]),
               let lng = Double(components[1]) {
                return CLLocationCoordinate2D(latitude: lat, longitude: lng)
            }
        }

        // パターン3: /place/lat,lng
        if let range = urlStr.range(of: #"/place/(-?\d+\.?\d*),(-?\d+\.?\d*)"#, options: .regularExpression) {
            let coordStr = String(urlStr[range])
            let components = coordStr.replacingOccurrences(of: "/place/", with: "").split(separator: ",")
            if components.count == 2,
               let lat = Double(components[0]),
               let lng = Double(components[1]) {
                return CLLocationCoordinate2D(latitude: lat, longitude: lng)
            }
        }

        // Apple Maps URL パターン
        // https://maps.apple.com/?ll=35.6812,139.7671
        if let range = urlStr.range(of: #"ll=(-?\d+\.?\d*),(-?\d+\.?\d*)"#, options: .regularExpression) {
            let coordStr = String(urlStr[range])
            let components = coordStr.replacingOccurrences(of: "ll=", with: "").split(separator: ",")
            if components.count == 2,
               let lat = Double(components[0]),
               let lng = Double(components[1]) {
                return CLLocationCoordinate2D(latitude: lat, longitude: lng)
            }
        }

        return nil
    }

    /// 座標を含むGoogle Maps URLを生成
    static func createGoogleMapsURL(latitude: Double, longitude: Double) -> String {
        return "https://www.google.com/maps?q=\(latitude),\(longitude)"
    }
}
