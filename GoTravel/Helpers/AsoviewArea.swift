import Foundation
import CoreLocation

/// アソビューの都道府県ページを引くための対応表。
///
/// アソビューの検索はクエリでキーワードを受け取らない。
/// `?keyword=` を付けても無視され、常に全件（すべての行き先）が返る。
/// 行き先を絞るには `https://www.asoview.com/<ローマ字>/` のパス形式を使う。
/// 47都道府県すべてで200が返ることを確認済み。
enum AsoviewArea {

    /// 座標から都道府県名を引く（例: "東京都"）。
    ///
    /// 表示言語に左右されないよう ja_JP で問い合わせる。
    /// 国外の座標は nil を返すので、そのまま導線を出さない判定に使える。
    static func prefecture(latitude: Double, longitude: Double) async -> String? {
        let key = "\(round(latitude * 1000))_\(round(longitude * 1000))"
        if let cached = prefectureCache[key] { return cached }

        let placemark = try? await CLGeocoder().reverseGeocodeLocation(
            CLLocation(latitude: latitude, longitude: longitude),
            preferredLocale: Locale(identifier: "ja_JP")
        ).first

        // アソビューは国内専用なので、日本以外は対象にしない
        guard placemark?.isoCountryCode == "JP",
              let prefecture = placemark?.administrativeArea else { return nil }

        prefectureCache[key] = prefecture
        return prefecture
    }

    /// 逆ジオコーディングは回数制限があるため、同じ地点を繰り返し引かない
    private static var prefectureCache: [String: String] = [:]

    static func url(matching text: String) -> URL? {
        guard let slug = slug(matching: text) else { return nil }
        return URL(string: "https://www.asoview.com/\(slug)/")
    }

    /// 自由入力の行き先から都道府県を推定する。
    ///
    /// 該当が無ければ nil を返し、呼び出し側は導線を出さない。
    /// 海外や地名以外のときにアソビューのトップへ送っても役に立たないため。
    static func slug(matching text: String) -> String? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }

        // 「東京都」は「京都」を含むため、正式名称を先に照合する必要がある
        for (name, slug) in officialNames where normalized.contains(name) {
            return slug
        }
        for (name, slug) in shortNames where normalized.contains(name) {
            return slug
        }
        for (name, slug) in majorCities where normalized.contains(name) {
            return slug
        }
        return nil
    }

    /// 都道府県名（接尾辞つき）。短縮名より先に照合する
    private static let officialNames: [(String, String)] = shortNames.map { name, slug in
        switch slug {
        case "hokkaido": return ("北海道", slug)
        case "tokyo": return ("東京都", slug)
        case "osaka": return ("大阪府", slug)
        case "kyoto": return ("京都府", slug)
        default: return ("\(name)県", slug)
        }
    }

    /// 都道府県の短縮名
    private static let shortNames: [(String, String)] = [
        ("北海道", "hokkaido"), ("青森", "aomori"), ("岩手", "iwate"), ("宮城", "miyagi"),
        ("秋田", "akita"), ("山形", "yamagata"), ("福島", "fukushima"), ("茨城", "ibaraki"),
        ("栃木", "tochigi"), ("群馬", "gunma"), ("埼玉", "saitama"), ("千葉", "chiba"),
        ("東京", "tokyo"), ("神奈川", "kanagawa"), ("新潟", "niigata"), ("富山", "toyama"),
        ("石川", "ishikawa"), ("福井", "fukui"), ("山梨", "yamanashi"), ("長野", "nagano"),
        ("岐阜", "gifu"), ("静岡", "shizuoka"), ("愛知", "aichi"), ("三重", "mie"),
        ("滋賀", "shiga"), ("京都", "kyoto"), ("大阪", "osaka"), ("兵庫", "hyogo"),
        ("奈良", "nara"), ("和歌山", "wakayama"), ("鳥取", "tottori"), ("島根", "shimane"),
        ("岡山", "okayama"), ("広島", "hiroshima"), ("山口", "yamaguchi"), ("徳島", "tokushima"),
        ("香川", "kagawa"), ("愛媛", "ehime"), ("高知", "kochi"), ("福岡", "fukuoka"),
        ("佐賀", "saga"), ("長崎", "nagasaki"), ("熊本", "kumamoto"), ("大分", "oita"),
        ("宮崎", "miyazaki"), ("鹿児島", "kagoshima"), ("沖縄", "okinawa")
    ]

    /// 「横浜」のように県名を書かない行き先を拾うための主要都市・観光地
    private static let majorCities: [(String, String)] = [
        ("札幌", "hokkaido"), ("函館", "hokkaido"), ("小樽", "hokkaido"), ("富良野", "hokkaido"),
        ("仙台", "miyagi"), ("横浜", "kanagawa"), ("鎌倉", "kanagawa"), ("箱根", "kanagawa"),
        ("川崎", "kanagawa"), ("日光", "tochigi"), ("草津", "gunma"), ("軽井沢", "nagano"),
        ("金沢", "ishikawa"), ("名古屋", "aichi"), ("伊勢", "mie"), ("神戸", "hyogo"),
        ("姫路", "hyogo"), ("有馬", "hyogo"), ("嵐山", "kyoto"), ("USJ", "osaka"),
        ("ユニバーサル", "osaka"), ("難波", "osaka"), ("梅田", "osaka"), ("熱海", "shizuoka"),
        ("富士", "shizuoka"), ("倉敷", "okayama"), ("宮島", "hiroshima"), ("松山", "ehime"),
        ("道後", "ehime"), ("博多", "fukuoka"), ("湯布院", "oita"), ("由布院", "oita"),
        ("別府", "oita"), ("那覇", "okinawa"), ("石垣", "okinawa"), ("宮古島", "okinawa"),
        ("ディズニー", "chiba"), ("浦安", "chiba"), ("成田", "chiba")
    ]
}
