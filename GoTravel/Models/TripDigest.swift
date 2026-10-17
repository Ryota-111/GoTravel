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
    }

    enum Scope: Hashable {
        case day(Int)
        case trip
    }

    /// 1コマの長さ
    static let clipSeconds: Double = 2
    /// 1日の動画に入れるコマの数（1時間に1つなので、多くても起きている時間ぶん）
    static let maxClipsPerDay = 16
    /// 旅行全体の動画では、1日あたりのコマを減らす（長くなりすぎないように）
    static let maxClipsPerDayInTrip = 6

    static func clips(plan: TravelPlan, sources: [Source], scope: Scope,
                      calendar: Calendar = .current) -> [Clip] {
        let days: [Int]
        switch scope {
        case .day(let n): days = [n]
        case .trip: days = Array(1...max(plan.dayCount, 1))
        }
        let limit = scope == .trip ? maxClipsPerDayInTrip : maxClipsPerDay
        return days.flatMap { dayNumber in
            let dayStart = calendar.startOfDay(for: plan.date(forDay: dayNumber))
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [Clip]() }
            let ofDay = sources.filter { $0.date >= dayStart && $0.date < dayEnd }
            return pickHourly(ofDay, limit: limit, calendar: calendar).map { source in
                Clip(sourceId: source.id, dayNumber: dayNumber, date: source.date,
                     timeText: timeText(source.date, calendar: calendar),
                     placeName: placeName(near: source, plan: plan, dayNumber: dayNumber))
            }
        }
    }

    /// 1時間に1つ。動画があれば動画を、同じ種類なら先に撮ったほうを選ぶ。
    /// 多すぎるときは、1日の中でまんべんなく間引く
    static func pickHourly(_ sources: [Source], limit: Int, calendar: Calendar) -> [Source] {
        let byHour = Dictionary(grouping: sources) { calendar.component(.hour, from: $0.date) }
        var picked = byHour.keys.sorted().compactMap { hour -> Source? in
            byHour[hour]?.sorted { lhs, rhs in
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

    static func timeText(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%d:%02d", c.hour ?? 0, c.minute ?? 0)
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
