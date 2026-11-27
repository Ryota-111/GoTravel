import Foundation
import CoreLocation

// MARK: - 日程のスポットを「場所保存」に入れる（3.9、ご要望から）
//
// 旅行やおでかけの日程に入れた場所を、そのまま場所保存の「行きたい」（訪問日なし）か
// 「行った」（訪問日あり）にする。これまでは逆向き（場所保存 → 旅行の行きたい場所）しかなかった。

/// 場所保存に入れられる、日程の中の1か所
struct ScheduleSpot: Equatable {
    var name: String
    var latitude: Double
    var longitude: Double
    var address: String?
    var linkURL: String?
    /// 予定の日時。「行った」にするときの訪問日になる
    var date: Date
    /// 場所保存のカテゴリーを選ぶ手がかり
    var isLodging: Bool = false
}

/// 場所保存のどちらに入れるか
enum ScheduleSpotSaveKind {
    /// 行きたい（訪問日なし）
    case wish
    /// 行った（予定の日を訪問日にする）
    case visited
}

/// 入れた結果
enum ScheduleSpotSaveResult: Equatable {
    /// 新しく足した
    case added
    /// 「行きたい」で入っていたものを「行った」にした
    case markedVisited
    /// もう入っている（何もしない）
    case alreadySaved
}

extension ScheduleItem {
    /// 場所保存に入れられるか。地図の位置がある予定だけ。
    /// 「移動」の予定は出発地と到着地の2か所なので、どちらか1つには決められず外す
    var scheduleSpot: ScheduleSpot? {
        guard move == nil,
              let latitude, let longitude,
              !(latitude == 0 && longitude == 0) else { return nil }
        let name = [location, title]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        guard let name else { return nil }
        return ScheduleSpot(name: name, latitude: latitude, longitude: longitude,
                            address: address?.isEmpty == false ? address : nil,
                            linkURL: (mapURL?.isEmpty == false ? mapURL : nil) ?? (linkURL?.isEmpty == false ? linkURL : nil),
                            date: time,
                            isLodging: reservationPart != nil && ScheduleSpotPlaces.looksLikeLodging(title))
    }
}

extension TravelPlan {
    /// この旅行の日程に出てくる場所（同じ場所は最初の1回だけ）
    var scheduleSpots: [ScheduleSpot] {
        let items = daySchedules.sorted { $0.dayNumber < $1.dayNumber }
            .flatMap { $0.scheduleItems.sorted { $0.time < $1.time } }
        var spots: [ScheduleSpot] = []
        for spot in items.compactMap(\.scheduleSpot)
        where !spots.contains(where: { ScheduleSpotPlaces.isSamePlace($0, spot) }) {
            spots.append(spot)
        }
        return spots
    }
}

enum ScheduleSpotPlaces {
    /// 同じ場所とみなす距離。同じ店や施設の入口の違いくらいは同じにする
    static let sameDistance: CLLocationDistance = 60

    static func isSamePlace(_ a: ScheduleSpot, _ b: ScheduleSpot) -> Bool {
        distance(a.latitude, a.longitude, b.latitude, b.longitude) <= sameDistance
    }

    /// 場所保存にもう入っている同じ場所
    static func existing(_ spot: ScheduleSpot, in places: [VisitedPlace]) -> VisitedPlace? {
        places.first { distance($0.latitude, $0.longitude, spot.latitude, spot.longitude) <= sameDistance }
    }

    /// 入れたら何が起きるか（保存はしない）
    static func outcome(_ spot: ScheduleSpot, as kind: ScheduleSpotSaveKind,
                        in places: [VisitedPlace]) -> ScheduleSpotSaveResult {
        guard let saved = existing(spot, in: places) else { return .added }
        if kind == .visited && saved.visitedAt == nil { return .markedVisited }
        return .alreadySaved
    }

    /// 新しく作る場所保存の記録
    static func makePlace(_ spot: ScheduleSpot, as kind: ScheduleSpotSaveKind,
                          categoryIds: [String], travelPlanId: String?) -> VisitedPlace {
        VisitedPlace(title: spot.name,
                     latitude: spot.latitude, longitude: spot.longitude,
                     visitedAt: kind == .visited ? spot.date : nil,
                     address: spot.address, linkURL: spot.linkURL,
                     categoryId: category(for: spot, among: categoryIds),
                     travelPlanId: travelPlanId)
    }

    /// カテゴリーを名前から選ぶ（宿・食事・それ以外は風景）。無ければ先頭
    static func category(for spot: ScheduleSpot, among ids: [String]) -> String {
        let wanted: String
        if spot.isLodging || looksLikeLodging(spot.name) {
            wanted = "hotel"
        } else if looksLikeMeal(spot.name) {
            wanted = "restaurant"
        } else {
            wanted = "sightseeing"
        }
        if ids.contains(wanted) { return wanted }
        return ids.first ?? "other"
    }

    static func looksLikeLodging(_ text: String) -> Bool {
        let words = ["ホテル", "旅館", "宿", "民宿", "ゲストハウス", "ホステル", "リゾート", "inn", "hotel", "hostel", "ryokan"]
        let lower = text.lowercased()
        return words.contains { lower.contains($0.lowercased()) }
    }

    static func looksLikeMeal(_ text: String) -> Bool {
        let words = ["レストラン", "食堂", "カフェ", "喫茶", "ごはん", "ご飯", "ランチ", "ディナー", "朝食", "昼食", "夕食",
                     "居酒屋", "ラーメン", "そば", "うどん", "寿司", "鮨", "焼肉", "バー", "ベーカリー", "パン",
                     "cafe", "café", "coffee", "restaurant", "bar", "bistro", "diner"]
        let lower = text.lowercased()
        return words.contains { lower.contains($0.lowercased()) }
    }

    private static func distance(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> CLLocationDistance {
        CLLocation(latitude: lat1, longitude: lon1).distance(from: CLLocation(latitude: lat2, longitude: lon2))
    }
}

extension Plan {
    /// おでかけの予定の場所（予定に結びつけた訪問予定地）
    func scheduleSpot(for item: PlanScheduleItem) -> ScheduleSpot? {
        guard item.move == nil, let placeId = item.placeId,
              let place = places.first(where: { $0.id == placeId }),
              !(place.latitude == 0 && place.longitude == 0) else { return nil }
        return ScheduleSpot(name: place.name, latitude: place.latitude, longitude: place.longitude,
                            address: place.address?.isEmpty == false ? place.address : nil,
                            linkURL: nil, date: item.time)
    }
}
