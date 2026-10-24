import Foundation
import CoreLocation

// MARK: - 旅行の「行きたい場所」（3.1）
//
// スケジュールに入れるほどではないけれど気になっている場所を、旅行に持たせる（ご要望から）。
// 旅行の地図に ☆ で出し、今いる場所から近い順に並べる。決まったら「予定に入れる」で日程へ。
//
// 「場所保存」の場所はその人の iCloud の中にあり、共有した相手からは見えない。
// そのため**旅行の中へ写して持つ**（元の場所を消しても旅行には残る）。
// Core Data と共有レコードの `wishPlacesJSON` に入る（**Production への反映が要る**）

struct WishPlace: Identifiable, Codable, Equatable {
    var id: String = UUID().uuidString
    var name: String
    var latitude: Double
    var longitude: Double
    var address: String?
    /// 「場所保存」のカテゴリ（アイコンに使う）。無ければ「その他」
    var categoryId: String?
    var note: String?
    var linkURL: String?
    /// 写した元の「場所保存」の id。同じ場所を二度足さないために使う
    var sourcePlaceId: String?
    /// 足した人（ユーザーID）。共有した旅行で誰が足したかを出す
    var addedBy: String?
    var addedAt: Date = Date()

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// 「場所保存」の場所から写す
    init(place: VisitedPlace, addedBy: String?, now: Date = Date()) {
        self.name = place.title
        self.latitude = place.latitude
        self.longitude = place.longitude
        self.address = place.address
        self.categoryId = place.categoryId
        self.note = place.notes
        self.linkURL = place.linkURL
        self.sourcePlaceId = place.id
        self.addedBy = addedBy
        self.addedAt = now
    }

    init(id: String = UUID().uuidString, name: String, latitude: Double, longitude: Double,
         address: String? = nil, categoryId: String? = nil, note: String? = nil, linkURL: String? = nil,
         sourcePlaceId: String? = nil, addedBy: String? = nil, addedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.categoryId = categoryId
        self.note = note
        self.linkURL = linkURL
        self.sourcePlaceId = sourcePlaceId
        self.addedBy = addedBy
        self.addedAt = addedAt
    }

    /// そこまでの距離（m）
    func distance(from location: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: latitude, longitude: longitude)
            .distance(from: CLLocation(latitude: location.latitude, longitude: location.longitude))
    }

    /// 「350m」「1.2km」「24km」
    static func distanceText(_ meters: CLLocationDistance) -> String {
        if meters < 1_000 { return "\(Int((meters / 10).rounded()) * 10)m" }
        if meters < 10_000 { return String(format: "%.1fkm", meters / 1_000) }
        return "\(Int((meters / 1_000).rounded()))km"
    }

    /// 今いる場所から近い順。場所が分からなければ足した順（新しいものが上）
    static func sorted(_ places: [WishPlace], near location: CLLocationCoordinate2D?) -> [WishPlace] {
        guard let location else { return places.sorted { $0.addedAt > $1.addedAt } }
        return places.sorted { $0.distance(from: location) < $1.distance(from: location) }
    }

    // MARK: 保存

    static func decode(_ json: String?) -> [WishPlace] {
        guard let data = json?.data(using: .utf8) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([WishPlace].self, from: data)) ?? []
    }

    /// 1つも無ければ nil（保存する欄を空のままにする）
    static func encode(_ places: [WishPlace]) -> String? {
        guard !places.isEmpty else { return nil }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys
        return (try? encoder.encode(places)).flatMap { String(data: $0, encoding: .utf8) }
    }
}

extension TravelPlan {
    /// 「場所保存」の場所を、行きたい場所として足す。もう足してある場所は飛ばす。足した数を返す
    @discardableResult
    mutating func addWishPlaces(_ places: [VisitedPlace], addedBy: String?, now: Date = Date()) -> Int {
        let existing = Set(wishPlaces.compactMap(\.sourcePlaceId))
        let fresh = places.filter { place in place.id.map { !existing.contains($0) } ?? true }
        wishPlaces.append(contentsOf: fresh.map { WishPlace(place: $0, addedBy: addedBy, now: now) })
        return fresh.count
    }

    /// その「場所保存」の場所を、もう行きたい場所に足してあるか
    func hasWishPlace(from place: VisitedPlace) -> Bool {
        guard let id = place.id else { return false }
        return wishPlaces.contains { $0.sourcePlaceId == id }
    }
}
