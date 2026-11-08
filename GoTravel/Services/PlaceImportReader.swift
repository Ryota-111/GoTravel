import Foundation
import MapKit
import CoreGraphics

// MARK: - 共有・スクリーンショットから場所を読む（3.5）
//
// 「場所保存をいちばん使っていない。使い勝手が悪い」から。保存するのに
// 「＋」→ 地図 → 検索 → 選ぶ → 名前・カテゴリー・日付… と手順が多く、見つけたその場で保存できなかった。
//
// - Google マップ・Apple マップ・食べログなどの「共有」から送られたリンクや文章
// - Instagram・TikTok のスクリーンショット（投稿のリンクはログインしないと中身が読めないので、画像の文字を読む）
//
// から場所の候補を作り、選んで「行きたい場所」に保存してもらう。
// 文字の読み取り（Vision）と場所の検索（MapKit）は端末と Apple の地図だけで行い、画像はどこにも送らない。
// リンク先のページの題名だけは、そのページを読みに行く（食べログなどの店名を知るため）

/// 見つかった場所の候補
struct PlaceImportCandidate: Identifiable, Equatable {
    var name: String
    var address: String?
    var latitude: Double
    var longitude: Double
    /// 保存するときのカテゴリー（`CustomPlaceCategory.defaults` の id）
    var categoryId: String
    /// 保存するときのリンク（送られた地図や店のページ）
    var linkURL: String?

    var id: String { "\(name)|\((latitude * 10_000).rounded())|\((longitude * 10_000).rounded())" }
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
}

// MARK: - リンクと文字から手がかりを拾う（通信しない。テストで確かめる）

enum PlaceLinkParser {

    /// リンクから読めた手がかり。名前か位置のどちらかはある
    struct Hint: Equatable {
        var name: String?
        var latitude: Double?
        var longitude: Double?
        var address: String?

        var hasCoordinate: Bool { latitude != nil && longitude != nil }
    }

    /// 地図アプリの短いリンク（開くと本当のリンクへ飛ぶ）。読む前に開いて、本当のリンクを知る
    static func needsExpansion(_ url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""
        return host == "maps.app.goo.gl" || host == "goo.gl" || host == "g.co" || host == "maps.apple"
    }

    /// 中身をページから読めない投稿のリンク（ログインが要る）
    static func isSocialPost(_ url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""
        return ["instagram.com", "tiktok.com", "threads.net", "threads.com", "x.com", "twitter.com"]
            .contains { host == $0 || host.hasSuffix("." + $0) }
    }

    /// 地図のリンクなら、名前・位置・住所を読む。地図のリンクでなければ nil
    static func hint(from url: URL) -> Hint? {
        let host = url.host?.lowercased() ?? ""
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? {
            items.first { $0.name == name }?.value.map(clean).flatMap { $0.isEmpty ? nil : $0 }
        }

        if host.hasSuffix("maps.apple.com") {
            var hint = Hint()
            let split = splitNameAndAddress(value("name") ?? value("q"))
            hint.name = split.name
            hint.address = value("address") ?? split.address
            if let pair = (value("coordinate") ?? value("ll") ?? value("sll")).flatMap(coordinatePair) {
                hint.latitude = pair.0
                hint.longitude = pair.1
            }
            // 「q」に位置そのものが入っていることがある
            if let name = hint.name, let pair = coordinatePair(name) {
                hint.name = nil
                hint.latitude = hint.latitude ?? pair.0
                hint.longitude = hint.longitude ?? pair.1
            }
            return hint.name != nil || hint.hasCoordinate || hint.address != nil ? hint : nil
        }

        let isGoogleMapsLink = (host.contains("google.") && url.path.hasPrefix("/maps")) || host.hasPrefix("maps.google.")
        guard isGoogleMapsLink else { return nil }
        var google = googleHint(url, parts: url.path.split(separator: "/").map(String.init), value: value)
        // 「名前, 住所」や住所だけが名前の場所に入っていることがある（住所を名前にしない）
        let split = splitNameAndAddress(google.name)
        google.name = split.name
        google.address = google.address ?? split.address
        return google.name != nil || google.hasCoordinate || google.address != nil ? google : nil
    }

    private static func googleHint(_ url: URL, parts: [String], value: (String) -> String?) -> Hint {

        var hint = Hint()
        // /maps/place/<名前>/@35.6,139.7,17z/...
        if let index = parts.firstIndex(of: "place"), index + 1 < parts.count {
            let name = clean(parts[index + 1])
            if !name.hasPrefix("@") { hint.name = name }
        }
        if let index = parts.firstIndex(of: "search"), index + 1 < parts.count, hint.name == nil {
            hint.name = clean(parts[index + 1])
        }
        // 場所そのものの位置（!3d緯度!4d経度）を先に、無ければ地図の真ん中（@緯度,経度）
        let whole = url.absoluteString
        if let lat = firstNumber(after: "!3d", in: whole), let lon = firstNumber(after: "!4d", in: whole) {
            hint.latitude = lat
            hint.longitude = lon
        } else if let at = parts.first(where: { $0.hasPrefix("@") }), let pair = coordinatePair(String(at.dropFirst())) {
            hint.latitude = pair.0
            hint.longitude = pair.1
        }
        if let q = value("q") ?? value("query") ?? value("destination") {
            if let pair = coordinatePair(q) {
                hint.latitude = hint.latitude ?? pair.0
                hint.longitude = hint.longitude ?? pair.1
            } else if hint.name == nil {
                hint.name = q
            }
        }
        if let name = hint.name, coordinatePair(name) != nil { hint.name = nil }
        return hint
    }

    /// 住所らしいか。「日本、〒150-0002 東京都…」「〒…」、都道府県や市区町村と番地のあるもの。
    /// 「道の駅 〇〇町」のような名前を住所と見ないよう、番地の数字があるものだけにする
    static func isAddressLike(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("日本") || trimmed.hasPrefix("〒") || trimmed.hasPrefix("Japan") { return true }
        if trimmed.range(of: #"[0-9０-９]{3}[-ー－−‐]{1}[0-9０-９]{4}"#, options: .regularExpression) != nil { return true }
        guard trimmed.contains(where: \.isNumber) else { return false }
        // 「京橋１丁目7−１」「銀座4-6-16」「中町12番地」のような番地（都道府県や市区町村が無くても）
        if trimmed.range(of: #"[0-9０-９一二三四五六七八九十]+丁目|[0-9０-９]+番地?|[0-9０-９]+[-ー－−‐–][0-9０-９]+"#,
                         options: .regularExpression) != nil { return true }
        return trimmed.range(of: #"(都|道|府|県)[^\s]{0,8}?(市|区|町|村|郡)"#, options: .regularExpression) != nil
            || trimmed.range(of: #"^[^\s]{1,6}(市|区|町|村)[^\s]*[0-9０-９]"#, options: .regularExpression) != nil
    }

    /// 「店名, 住所」「店名、住所」を分ける。全部が住所なら名前は nil
    static func splitNameAndAddress(_ text: String?) -> (name: String?, address: String?) {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return (nil, nil) }
        for separator in [", ", ",", "、", "，"] {
            guard let range = text.range(of: separator) else { continue }
            let head = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let tail = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            if !head.isEmpty, !isAddressLike(head), isAddressLike(tail) {
                return (head, cleanAddress(tail))
            }
        }
        if isAddressLike(text) { return splitTrailingName(cleanAddress(text)) }
        return (text, nil)
    }

    /// Google マップは日本の場所を「〒104-0031 東京都中央区京橋１丁目７−１ TODA BUILDING 6階 CREATIVE MUSEUM TOKYO」の
    /// ように、住所・建物・階のあとに名前を付けて渡してくる。階の後ろ（階が無ければ番地の後ろ）を名前として取り出す
    static func splitTrailingName(_ text: String) -> (name: String?, address: String?) {
        let tokens = text.split(whereSeparator: { $0 == " " || $0 == "　" }).map(String.init)
        let floor = tokens.lastIndex { $0.range(of: #"^(地下)?[0-9０-９]+(階|[FＦ])$|^[BＢ][0-9０-９]+[FＦ]?$"#,
                                                  options: .regularExpression) != nil }
        let street = tokens.lastIndex(where: isAddressLike)
        guard let end = floor ?? street, end < tokens.count - 1 else { return (nil, text) }
        let name = tokens[(end + 1)...].joined(separator: " ")
        guard isPlausible(name), !isAddressLike(name) else { return (nil, text) }
        return (name, tokens[...end].joined(separator: " "))
    }

    /// 住所から建物・階を除いた、地図で探せる部分（「東京都中央区京橋１丁目７−１ TODA BUILDING 6階」→「東京都中央区京橋１丁目７−１」）
    static func streetAddress(_ text: String) -> String {
        let tokens = text.split(whereSeparator: { $0 == " " || $0 == "　" }).map(String.init)
        guard let street = tokens.lastIndex(where: isAddressLike) else { return text }
        return tokens[...street].joined(separator: " ")
    }

    /// 「日本、〒150-0002 東京都渋谷区…」→「東京都渋谷区…」
    static func cleanAddress(_ text: String) -> String {
        var address = text.trimmingCharacters(in: .whitespaces)
        for prefix in ["日本、", "日本,", "日本 ", "Japan, "] where address.hasPrefix(prefix) {
            address = String(address.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        }
        address = address.replacingOccurrences(of: #"^〒?\s*[0-9０-９]{3}[-ー－][0-9０-９]{4}\s*"#, with: "",
                                               options: .regularExpression)
        return address.isEmpty ? text : address
    }

    /// 文章の中のリンク
    static func urls(in text: String) -> [URL] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return [] }
        return detector.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap(\.url)
    }

    /// 文章からリンクを除いた行（Google マップの共有は「名前／住所／リンク」の順に届く）
    static func lines(in text: String) -> [String] {
        var rest = text
        for url in urls(in: text) { rest = rest.replacingOccurrences(of: url.absoluteString, with: "\n") }
        return rest.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// ページの題名から、場所の名前だけを取り出す
    /// 「スターバックス 渋谷店 (渋谷/カフェ) - 食べログ」→「スターバックス 渋谷店」
    static func name(fromPageTitle title: String) -> String? {
        var name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        for separator in [" - ", " | ", "｜", " – ", " — ", "：", " : "] {
            if let range = name.range(of: separator) { name = String(name[..<range.lowerBound]) }
        }
        // 後ろの「(渋谷/カフェ)」「【公式】」などを落とす
        name = name.replacingOccurrences(of: #"\s*[\(（][^\)）]*[\)）]\s*$"#, with: "", options: .regularExpression)
        name = name.replacingOccurrences(of: #"^【[^】]*】\s*"#, with: "", options: .regularExpression)
        name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.count >= 2 ? name : nil
    }

    // MARK: スクリーンショットの文字から、場所の名前らしい行を選ぶ

    /// 画面の部品の言葉（いいね・フォローなど）。これだけの行は場所ではない
    private static let interfaceWords: Set<String> = [
        "いいね", "いいね！", "フォロー", "フォロー中", "フォローする", "コメント", "返信", "返信する", "シェア", "共有", "保存",
        "送信", "もっと見る", "続きを読む", "翻訳を見る", "おすすめ", "ホーム", "検索", "リール", "ショップ", "プロフィール",
        "メッセージ", "通知", "投稿", "ストーリーズ", "ハイライト", "発見", "友達", "受信箱", "LIVE", "フォロワー",
        "Like", "Follow", "Following", "Comment", "Reply", "Share", "Save", "Send", "more", "See translation", "Home", "Search",
    ]

    /// 場所の名前によく付く言葉
    private static let placeWords = [
        "カフェ", "Cafe", "cafe", "CAFE", "Coffee", "coffee", "珈琲", "喫茶", "ベーカリー", "パン", "Bakery", "食堂", "ラーメン",
        "らーめん", "そば", "うどん", "寿司", "鮨", "焼肉", "居酒屋", "酒場", "バー", "Bar", "レストラン", "ビストロ", "Bistro",
        "店", "屋", "堂", "亭", "庵", "茶寮", "本舗", "寺", "神社", "大社", "宮", "城", "公園", "庭園", "美術館", "博物館",
        "水族館", "動物園", "温泉", "旅館", "ホテル", "Hotel", "HOTEL", "展望台", "タワー", "ビーチ", "海岸", "岬", "滝", "島",
        "駅", "市場", "横丁", "商店街", "テラス", "ガーデン", "ファーム", "牧場", "パーク", "Park", "ミュージアム", "Museum",
    ]

    /// 場所を探す言葉を、場所らしい順に返す（いちばん多くて `limit` 個）
    static func queries(fromRecognized text: String, limit: Int = 4) -> [String] {
        var scored: [(text: String, score: Int, order: Int)] = []
        let rawLines = text.components(separatedBy: CharacterSet(charactersIn: "\n\t"))
        for (order, raw) in rawLines.enumerated() {
            var line = raw.trimmingCharacters(in: .whitespaces)
            var score = 0
            // 「📍店名」「場所：店名」「店名：〇〇」は、その後ろが名前
            for marker in ["📍", "📌", "店名", "場所", "スポット", "Location", "住所"] {
                if let range = line.range(of: marker) {
                    let after = line[range.upperBound...].trimmingCharacters(in: CharacterSet(charactersIn: " ：:　-|｜"))
                    if after.count >= 2 {
                        line = after
                        score += marker == "住所" ? 3 : 6
                        break
                    }
                }
            }
            // 【店名】「店名」
            if let match = line.range(of: #"[【「『]([^】」』]{2,30})[】」』]"#, options: .regularExpression) {
                line = String(line[match]).trimmingCharacters(in: CharacterSet(charactersIn: "【】「」『』"))
                score += 2
            }
            line = line.replacingOccurrences(of: #"^[#＃@＠]+"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            guard isPlausible(line) else { continue }
            if placeWords.contains(where: { line.contains($0) }) { score += 3 }
            if looksLikeAddress(line) { score += 3 }
            // 1文字目が数字の行（「12:30」「1,234件」）や、文っぽい長い行は下げる
            if line.count > 24 || line.contains("。") || line.contains("！") || line.contains("!") { score -= 2 }
            if score > 0 { scored.append((line, score, order)) }
        }
        var seen = Set<String>()
        return scored
            .sorted { $0.score != $1.score ? $0.score > $1.score : $0.order < $1.order }
            .map(\.text)
            .filter { seen.insert($0).inserted }
            .prefix(limit)
            .map { $0 }
    }

    /// 文字として場所の名前になりうるか（短すぎる・数字だけ・画面の部品の言葉は外す）
    static func isPlausible(_ line: String) -> Bool {
        guard line.count >= 2, line.count <= 40, !interfaceWords.contains(line) else { return false }
        let letters = line.unicodeScalars.filter { CharacterSet.letters.contains($0) }
        guard letters.count >= 2 else { return false }
        // 「12:30」「3日前」「1.2万」のような行
        if line.range(of: #"^[0-9０-９:：.,，万千件日時分秒前後\s/年月]+$"#, options: .regularExpression) != nil { return false }
        return true
    }

    /// 住所らしい行（都道府県・市区町村と番地）
    static func looksLikeAddress(_ line: String) -> Bool {
        line.range(of: #"(都|道|府|県).*(市|区|町|村)|(市|区)[^\s]*[0-9０-９]+"#, options: .regularExpression) != nil
    }

    private static func clean(_ text: String) -> String {
        (text.replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? text)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 「35.6812,139.7671」→ (35.6812, 139.7671)
    static func coordinatePair(_ text: String) -> (Double, Double)? {
        let numbers = text.split(separator: ",").prefix(2).compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard numbers.count == 2, abs(numbers[0]) <= 90, abs(numbers[1]) <= 180, numbers != [0, 0] else { return nil }
        return (numbers[0], numbers[1])
    }

    private static func firstNumber(after marker: String, in text: String) -> Double? {
        guard let range = text.range(of: marker) else { return nil }
        let rest = text[range.upperBound...]
        let number = rest.prefix { $0.isNumber || $0 == "." || $0 == "-" }
        return Double(number)
    }

    /// 地図の分類から、保存するカテゴリーを決める（レストラン・ホテル・それ以外は風景）
    static func categoryId(for category: MKPointOfInterestCategory?) -> String {
        guard let category else { return "sightseeing" }
        switch category {
        case .restaurant, .cafe, .bakery, .brewery, .winery, .foodMarket, .nightlife: return "restaurant"
        case .hotel, .campground, .rvPark: return "hotel"
        default: return "sightseeing"
        }
    }
}

// MARK: - 候補を作る（通信・地図の検索をする）

enum PlaceImportReader {

    /// 送られた文章（リンクを含む）から候補を作る
    static func candidates(fromText text: String) async -> [PlaceImportCandidate] {
        var results: [PlaceImportCandidate] = []
        let lines = PlaceLinkParser.lines(in: text)
        let urls = PlaceLinkParser.urls(in: text)

        for original in urls {
            let url = PlaceLinkParser.needsExpansion(original) ? (await expand(original) ?? original) : original
            let link = original.absoluteString
            if let hint = PlaceLinkParser.hint(from: url) {
                // 共有の文章の名前の行（Google マップの共有は「名前／住所／リンク」）を、リンクの中の名前より先に使う。
                // 住所の行は名前にしない
                let textName = lines.first { PlaceLinkParser.isPlausible($0) && !PlaceLinkParser.isAddressLike($0) }
                let textAddress = lines.first(where: PlaceLinkParser.isAddressLike).map(PlaceLinkParser.cleanAddress)
                results += await resolve(name: textName ?? hint.name, address: hint.address ?? textAddress,
                                         latitude: hint.latitude, longitude: hint.longitude, link: link)
            } else if !PlaceLinkParser.isSocialPost(url), let title = await pageTitle(of: url),
                      let name = PlaceLinkParser.name(fromPageTitle: title) {
                results += await search(name, link: link)
            }
        }

        // リンクから見つからなければ、文章の行で探す（「店名／住所」だけを送った場合など）
        if results.isEmpty {
            let ordered = lines.prefix(3).filter { !PlaceLinkParser.isAddressLike($0) }
                + lines.prefix(3).filter(PlaceLinkParser.isAddressLike)
            for line in ordered where PlaceLinkParser.isPlausible(line) {
                results += await search(line, link: urls.first.map(\.absoluteString))
                if !results.isEmpty { break }
            }
        }
        return unique(results)
    }

    /// スクリーンショットの文字を読み、候補と、読めた文字の行（押して探し直せるように）を返す
    static func candidates(fromImage image: CGImage) async -> (candidates: [PlaceImportCandidate], queries: [String]) {
        guard let text = try? await ReservationImageTextReader.text(from: image) else { return ([], []) }
        let queries = PlaceLinkParser.queries(fromRecognized: text, limit: 6)
        var results: [PlaceImportCandidate] = []
        for query in queries.prefix(4) {
            results += Array(await search(query, link: nil).prefix(3))
        }
        return (unique(results), queries)
    }

    /// 名前で探す（いちばん合うものから、いくつか）
    static func search(_ query: String, near coordinate: CLLocationCoordinate2D? = nil,
                       link: String?) async -> [PlaceImportCandidate] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.pointOfInterest, .address]
        if let coordinate {
            request.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 2000, longitudinalMeters: 2000)
        } else {
            // 今いる場所の近くに寄せない（旅行先の店のことが多い）
            request.region = MKCoordinateRegion(MKMapRect.world)
        }
        guard let items = try? await MKLocalSearch(request: request).start().mapItems else { return [] }
        let found = items.prefix(5).map { candidate(from: $0, link: link) }
        // 住所だけの結果（名前が住所）は、店や場所の後ろへ
        return found.filter { !PlaceLinkParser.isAddressLike($0.name) } + found.filter { PlaceLinkParser.isAddressLike($0.name) }
    }

    private static func resolve(name: String?, address: String?, latitude: Double?, longitude: Double?,
                                link: String) async -> [PlaceImportCandidate] {
        if let latitude, let longitude {
            let here = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            // 位置が分かっていれば、その近くで名前を探し、いちばん近いものを使う（住所とカテゴリーが分かる）
            let location = CLLocation(latitude: latitude, longitude: longitude)
            if let name {
                let found = await search(name, near: here, link: link).filter { !PlaceLinkParser.isAddressLike($0.name) }
                if let nearest = found.min(by: {
                    CLLocation(latitude: $0.latitude, longitude: $0.longitude).distance(from: location)
                        < CLLocation(latitude: $1.latitude, longitude: $1.longitude).distance(from: location)
                }), CLLocation(latitude: nearest.latitude, longitude: nearest.longitude).distance(from: location) < 300 {
                    return [nearest]
                }
            }
            // 名前が分からなければ、その位置にある店や場所の名前を使う
            if name == nil {
                let nearby = await nearbyPointsOfInterest(to: location, link: link)
                if !nearby.isEmpty { return nearby }
            }
            return [PlaceImportCandidate(name: name ?? "地図の場所", address: address, latitude: latitude,
                                         longitude: longitude, categoryId: "sightseeing", linkURL: link)]
        }
        if let name, let address,
           let anchor = await search(PlaceLinkParser.streetAddress(address), link: link).first {
            // 住所の位置の近くで名前を探す
            let location = CLLocation(latitude: anchor.latitude, longitude: anchor.longitude)
            let found = await search(name, near: anchor.coordinate, link: link).filter {
                !PlaceLinkParser.isAddressLike($0.name)
                    && CLLocation(latitude: $0.latitude, longitude: $0.longitude).distance(from: location) < 300
            }
            if !found.isEmpty { return found }
            // Apple の地図に載っていない場所は、送られた名前のまま住所の位置で保存できるようにする。近くの場所も並べる
            let named = PlaceImportCandidate(name: name, address: address, latitude: anchor.latitude,
                                             longitude: anchor.longitude, categoryId: "sightseeing", linkURL: link)
            return [named] + (await nearbyPointsOfInterest(to: location, link: link))
        }
        if let name {
            return await search([name, address].compactMap { $0 }.joined(separator: " "), link: link)
        }
        if let address {
            // 住所しか分からないときは、その住所にある店や場所を並べる（住所そのものを名前にしない）
            let found = await search(address, link: link)
            if let first = found.first {
                let nearby = await nearbyPointsOfInterest(to: CLLocation(latitude: first.latitude, longitude: first.longitude),
                                                          link: link)
                if !nearby.isEmpty { return nearby }
            }
            return found
        }
        return []
    }

    /// その位置の近く（80m 以内）の店や場所を、近い順に。ビルの中の店のように、同じ位置にいくつもあることがあるので選んでもらう
    private static func nearbyPointsOfInterest(to location: CLLocation, link: String) async -> [PlaceImportCandidate] {
        let request = MKLocalPointsOfInterestRequest(center: location.coordinate, radius: 80)
        guard let items = try? await MKLocalSearch(request: request).start().mapItems else { return [] }
        func distance(_ candidate: PlaceImportCandidate) -> CLLocationDistance {
            CLLocation(latitude: candidate.latitude, longitude: candidate.longitude).distance(from: location)
        }
        return Array(items
            .map { candidate(from: $0, link: link) }
            .filter { !PlaceLinkParser.isAddressLike($0.name) }
            .sorted { distance($0) < distance($1) }
            .prefix(5))
    }

    private static func candidate(from item: MKMapItem, link: String?) -> PlaceImportCandidate {
        let placemark = item.placemark
        let address = [placemark.administrativeArea, placemark.locality, placemark.thoroughfare, placemark.subThoroughfare]
            .compactMap { $0 }
            .reduce(into: [String]()) { parts, part in if !parts.contains(part) { parts.append(part) } }
            .joined()
        return PlaceImportCandidate(name: item.name ?? placemark.name ?? "名前のない場所",
                                    address: address.isEmpty ? nil : address,
                                    latitude: placemark.coordinate.latitude,
                                    longitude: placemark.coordinate.longitude,
                                    categoryId: PlaceLinkParser.categoryId(for: item.pointOfInterestCategory),
                                    linkURL: link)
    }

    private static func unique(_ candidates: [PlaceImportCandidate]) -> [PlaceImportCandidate] {
        var seen = Set<String>()
        return candidates.filter { seen.insert($0.id).inserted }
    }

    /// 短いリンクを開いて、行き着いたリンクを返す
    static func expand(_ url: URL) async -> URL? {
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.httpMethod = "GET"
        guard let (_, response) = try? await URLSession.shared.data(for: request) else { return nil }
        return response.url
    }

    /// ページの題名（og:title を先に、無ければ <title>）。頭の 200KB だけ読む
    static func pageTitle(of url: URL) async -> String? {
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue("ja,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return nil }
        let html = String(decoding: data.prefix(200_000), as: UTF8.self)
        return title(fromHTML: html)
    }

    static func title(fromHTML html: String) -> String? {
        let patterns = [
            #"<meta[^>]+property=["']og:title["'][^>]+content=["']([^"']+)["']"#,
            #"<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:title["']"#,
            #"<title[^>]*>([^<]+)</title>"#,
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                  let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                  let range = Range(match.range(at: 1), in: html) else { continue }
            let title = decodeEntities(String(html[range])).trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty { return title }
        }
        return nil
    }

    private static func decodeEntities(_ text: String) -> String {
        [("&amp;", "&"), ("&quot;", "\""), ("&#39;", "'"), ("&#039;", "'"), ("&lt;", "<"), ("&gt;", ">"), ("&nbsp;", " ")]
            .reduce(text) { $0.replacingOccurrences(of: $1.0, with: $1.1) }
    }
}

// MARK: - スクリーンショットから読むお試し（3.5）

/// スクリーンショットから場所を読むのは Pro の機能。Pro でない人も、最初の数回は試せる。
///
/// 一度「投稿のスクショからお店が出てきた」を体験してもらってから、欲しくなったところで Pro を案内するため。
/// 数えるのは「スクリーンショットを読む画面を開いた回数」（何枚まとめて選んでも1回）。端末ごとに覚える
nonisolated enum PlaceScreenshotTrial {
    static let limit = 3
    static let storageKey = "placeScreenshotTrialUsed"

    static func remaining(in defaults: UserDefaults = .standard) -> Int {
        max(0, limit - defaults.integer(forKey: storageKey))
    }

    /// 1回使う。使えたら true（残りが無ければ false で、数は増やさない）
    @discardableResult
    static func consume(in defaults: UserDefaults = .standard) -> Bool {
        guard remaining(in: defaults) > 0 else { return false }
        defaults.set(defaults.integer(forKey: storageKey) + 1, forKey: storageKey)
        return true
    }
}
