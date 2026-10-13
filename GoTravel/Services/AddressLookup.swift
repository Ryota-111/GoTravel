import CoreLocation
import Contacts

/// 緯度・経度から住所を引く（住所を保存していなかった予定のため）。
///
/// **`MKPlacemark(coordinate:)` の `title` を住所として使わないこと。** 住所を持たない場所では、
/// iOS が端末の地域の国名などを返すため、違う国の名前が出る
enum AddressLookup {

    /// 「東京都千代田区丸の内1丁目」「Paris, Île-de-France」のような1行の住所。引けなければ nil
    static func address(latitude: Double, longitude: Double) async -> String? {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        guard let placemark = try? await CLGeocoder()
                .reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "ja_JP")).first else { return nil }
        return format(placemark.postalAddress)
    }

    /// 住所を1行にする。国名は付けない（どの国かは、たいてい名前と旅行先から分かる）
    static func format(_ postal: CNPostalAddress?) -> String? {
        guard let postal else { return nil }
        let isJapan = postal.isoCountryCode.uppercased() == "JP"
        let parts = isJapan
            ? [postal.state, postal.city, postal.subLocality, postal.street]
            : [postal.street, postal.city, postal.state]
        let text = parts.filter { !$0.isEmpty }.joined(separator: isJapan ? "" : ", ")
        return text.isEmpty ? nil : text
    }
}
