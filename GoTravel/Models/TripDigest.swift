import Foundation
import CoreLocation

// MARK: - 旅のダイジェスト（Travory Pro）
//
// 旅行の期間にカメラロールへ撮った写真・動画から、1時間に1つずつ拾って2秒ずつつなぎ、
// 1日ごと・旅行全体の短い動画にする。韓国発の「1時間に2秒ずつ撮って1日の Vlog にする」
// アプリが流行っているのを受けて、Travory では撮り直さなくても、旅行の日程と場所から自動で作れるようにした。
//
// - 動画は端末の中だけで作り、どこにも上げない
// - どれを使うか・何と書くかはここで決める（純粋関数。テストで確かめる）。つなぐのは `TripDigestComposer`

enum TripDigest {

    /// カメラロールの1つ（写真か動画）
    struct Source: Equatable {
        var id: String
        var date: Date
        var isVideo: Bool
        var duration: TimeInterval
        var latitude: Double?
        var longitude: Double?
    }

    /// 動画の1コマ（2秒）
    struct Clip: Equatable {
        var sourceId: String
        var dayNumber: Int
        var date: Date
        /// 「14:05」
        var timeText: String
        /// 近くの予定の名前（日程の場所から 800m 以内）。無ければ nil
        var placeName: String?
        /// 自分で足したコマ（1時間に1つの決まりや上限に関係なく入る）
        var isAdded = false
    }

    /// 自分で足した写真・動画と、そのコマの日時。
    /// あとからもらった写真は日時が「保存した日」になっていることがあるので、日時はここで持つ
    struct Added: Codable, Equatable {
        var sourceId: String
        var date: Date
        var isVideo: Bool = false
        var latitude: Double?
        var longitude: Double?
    }

    enum Scope: Hashable {
        case day(Int)
        case trip
    }

    /// 1コマの長さ
    static var clipSeconds: Double { DigestPace.current }
    /// 1日の動画に入れるコマの数（1時間に1つなので、多くても起きている時間ぶん）
    static let maxClipsPerDay = 16
    /// 旅行全体の動画では、1日あたりのコマを減らす（長くなりすぎないように）
    static let maxClipsPerDayInTrip = 6

    /// - Parameters:
    ///   - pinned: 自分で選び直した写真・動画。その時間のコマには、これを必ず使う
    ///   - captions: 自分で入れた文字（写真・動画ごと。Pro）。場所の名前の代わりに出す。空なら何も出さない
    ///   - added: 自分で足した写真・動画。決めた日時のコマとして必ず入れる（上限にも数えない）。
    ///     旅行全体の動画にも入る。足した写真は、撮った時間のコマの候補からは外す
    ///   - excludedHours: 外した時間（`hourKey`）。その時間に撮った写真からはコマを作らない（足した写真は入る）
    static func clips(plan: TravelPlan, sources: [Source], scope: Scope, pinned: Set<String> = [],
                      captions: [String: String] = [:], added: [Added] = [],
                      excludedHours: Set<String> = [],
                      calendar: Calendar = .current) -> [Clip] {
        let days: [Int]
        switch scope {
        case .day(let n): days = [n]
        case .trip: days = Array(1...max(plan.dayCount, 1))
        }
        let limit = scope == .trip ? maxClipsPerDayInTrip : maxClipsPerDay
        let addedIds = Set(added.map(\.sourceId))
        return days.flatMap { dayNumber in
            let dayStart = calendar.startOfDay(for: plan.date(forDay: dayNumber))
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [Clip]() }
            let ofDay = sources.filter { $0.date >= dayStart && $0.date < dayEnd && !addedIds.contains($0.id)
                && !excludedHours.contains(hourKey($0.date, calendar: calendar)) }
            let picked = pickHourly(ofDay, limit: limit, pinned: pinned, calendar: calendar).map { source in
                Clip(sourceId: source.id, dayNumber: dayNumber, date: source.date,
                     timeText: timeText(source.date, calendar: calendar),
                     placeName: caption(captions[source.id]) ?? placeName(near: source, plan: plan, dayNumber: dayNumber))
            }
            let mine = added.filter { $0.date >= dayStart && $0.date < dayEnd }.map { entry in
                Clip(sourceId: entry.sourceId, dayNumber: dayNumber, date: entry.date,
                     timeText: timeText(entry.date, calendar: calendar),
                     placeName: caption(captions[entry.sourceId]) ?? placeName(near: entry.source, plan: plan,
                                                                              dayNumber: dayNumber),
                     isAdded: true)
            }
            // 同じ時刻なら、撮ったコマのあとに足したコマ（「このあとに足す」で差し込んだ順）
            return (picked + mine).enumerated().sorted { lhs, rhs in
                lhs.element.date != rhs.element.date ? lhs.element.date < rhs.element.date : lhs.offset < rhs.offset
            }.map(\.element)
        }
    }

    /// 足した写真のコマの日時を決める。
    /// 1. 撮った日時がその日の中なら、その時刻
    /// 2. 写真の場所がその日の予定から 800m 以内なら、その予定の時刻
    /// 3. どちらも分からなければ nil（呼んだ側が、差し込んだコマの時刻か、選んでもらった時刻にする）
    static func addedDate(for source: Source, plan: TravelPlan, dayNumber: Int,
                          calendar: Calendar = .current) -> Date? {
        let dayStart = calendar.startOfDay(for: plan.date(forDay: dayNumber))
        if let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart),
           source.date >= dayStart, source.date < dayEnd {
            return source.date
        }
        guard let lat = source.latitude, let lon = source.longitude else { return nil }
        let here = CLLocation(latitude: lat, longitude: lon)
        let items = plan.daySchedulesInRange.first { $0.dayNumber == dayNumber }?.scheduleItems ?? []
        let nearest = items.compactMap { item -> (ScheduleItem, CLLocationDistance)? in
            guard let ilat = item.latitude, let ilon = item.longitude else { return nil }
            return (item, CLLocation(latitude: ilat, longitude: ilon).distance(from: here))
        }.min { $0.1 < $1.1 }
        guard let nearest, nearest.1 <= 800 else { return nil }
        let parts = calendar.dateComponents([.hour, .minute], from: nearest.0.time)
        return calendar.date(bySettingHour: parts.hour ?? 12, minute: parts.minute ?? 0, second: 0, of: dayStart)
    }

    /// その日の、決めた時（0〜23時）
    static func date(day dayNumber: Int, hour: Int, plan: TravelPlan, calendar: Calendar = .current) -> Date {
        let dayStart = calendar.startOfDay(for: plan.date(forDay: dayNumber))
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: dayStart) ?? dayStart
    }

    /// 1時間に1つ。自分で選び直したものがあればそれを、なければ動画を、同じ種類なら先に撮ったほうを選ぶ。
    /// 多すぎるときは、1日の中でまんべんなく間引く
    static func pickHourly(_ sources: [Source], limit: Int, pinned: Set<String> = [], calendar: Calendar) -> [Source] {
        let byHour = Dictionary(grouping: sources) { calendar.component(.hour, from: $0.date) }
        var picked = byHour.keys.sorted().compactMap { hour -> Source? in
            byHour[hour]?.sorted { lhs, rhs in
                let lp = pinned.contains(lhs.id), rp = pinned.contains(rhs.id)
                if lp != rp { return lp }
                if lhs.isVideo != rhs.isVideo { return lhs.isVideo }
                return lhs.date < rhs.date
            }.first
        }
        if picked.count > limit {
            let step = Double(picked.count) / Double(limit)
            picked = (0..<limit).map { picked[Int(Double($0) * step)] }
        }
        return picked
    }

    /// 1時間刻みで出す（17:23 → 「17:00」）。1時間に1コマなので、分まで出すと細かすぎる
    static func timeText(_ date: Date, calendar: Calendar) -> String {
        "\(calendar.component(.hour, from: date)):00"
    }

    /// 「外した時間」を覚えるための鍵（その時間の始まりの時刻）
    static func hourKey(_ date: Date, calendar: Calendar = .current) -> String {
        let start = calendar.dateInterval(of: .hour, for: date)?.start ?? date
        return String(Int(start.timeIntervalSince1970))
    }

    /// 鍵から、その時間の始まりの時刻に戻す
    static func hourStart(ofKey key: String) -> Date? {
        Double(key).map { Date(timeIntervalSince1970: $0) }
    }

    /// 同じ日・同じ時間か（選び直しで、同じ時間の前の選び直しを外すため）
    static func sameHour(_ a: Date, _ b: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(a, inSameDayAs: b) && calendar.component(.hour, from: a) == calendar.component(.hour, from: b)
    }

    /// 自分で入れた文字。入れていなければ nil（場所の名前を使う）、空にしたなら文字なし
    private static func caption(_ text: String?) -> String?? {
        guard let text else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return .some(trimmed.isEmpty ? nil : trimmed)
    }

    /// 撮った場所にいちばん近い、その日の予定の名前（800m 以内のときだけ）
    static func placeName(near source: Source, plan: TravelPlan, dayNumber: Int) -> String? {
        guard let lat = source.latitude, let lon = source.longitude else { return nil }
        let here = CLLocation(latitude: lat, longitude: lon)
        let items = plan.daySchedulesInRange.first { $0.dayNumber == dayNumber }?.scheduleItems ?? []
        let nearest = items.compactMap { item -> (String, CLLocationDistance)? in
            guard let ilat = item.latitude, let ilon = item.longitude else { return nil }
            return (item.title, CLLocation(latitude: ilat, longitude: ilon).distance(from: here))
        }.min { $0.1 < $1.1 }
        guard let nearest, nearest.1 <= 800 else { return nil }
        return nearest.0
    }

    /// 動画の長さ（秒）
    static func duration(of clips: [Clip]) -> Double {
        Double(clips.count) * clipSeconds
    }

    /// ファイル名（「沖縄旅行 Day2.mp4」「沖縄旅行.mp4」）
    static func fileName(plan: TravelPlan, scope: Scope) -> String {
        let title = plan.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let safe = (title.isEmpty ? "旅行" : title).replacingOccurrences(of: "/", with: "-")
        switch scope {
        case .day(let n): return "\(safe) Day\(n).mp4"
        case .trip: return "\(safe).mp4"
        }
    }
}

extension TripDigest.Added {
    var source: TripDigest.Source {
        TripDigest.Source(id: sourceId, date: date, isVideo: isVideo, duration: 0, latitude: latitude, longitude: longitude)
    }
}

// MARK: - 地図のカード（3.2）
//
// 動画の最後に、その日（旅行全体なら全部の日）の行程の場所を、番号つきのピンと線で出す。
// ほかの Vlog アプリは撮った場所しか知らないが、Travory は日程の場所と順番を持っているので、
// 「この日はこう回った」をそのまま地図にできる

extension TripDigest {
    /// 地図に出す場所1つ
    struct MapStop: Equatable {
        var order: Int
        var dayNumber: Int
        var name: String
        var latitude: Double
        var longitude: Double
    }

    /// 地図に出す場所。予定の順（何日目 → 時刻）で、場所のある予定だけ。
    /// 続けて同じ場所（ほぼ同じ位置）の予定は1つにまとめる。旅行全体は多すぎると読めないので上限を置く
    static func mapStops(plan: TravelPlan, scope: Scope, limit: Int = 12) -> [MapStop] {
        let days: [Int]
        switch scope {
        case .day(let n): days = [n]
        case .trip: days = plan.daySchedules.map(\.dayNumber).sorted()
        }
        var stops: [MapStop] = []
        for day in days {
            for item in plan.timelineScheduleItems(onDay: day) {
                guard let latitude = item.latitude, let longitude = item.longitude,
                      latitude.isFinite, longitude.isFinite else { continue }
                if let last = stops.last,
                   abs(last.latitude - latitude) < 0.0005, abs(last.longitude - longitude) < 0.0005 { continue }
                let name = (item.location?.isEmpty == false ? item.location : nil) ?? item.title
                stops.append(MapStop(order: stops.count + 1, dayNumber: day, name: name,
                                     latitude: latitude, longitude: longitude))
                if stops.count >= limit { return stops }
            }
        }
        return stops
    }
}
