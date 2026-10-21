import Foundation

// MARK: - 旅の統計（3.1）
//
// 「思い出」タブの「旅の記録」。旅行の回数・日数・使った金額・行った都道府県と国などを、
// 端末の中のデータだけから数える（通信しない。県は `TripRegionResolver` が調べて覚えた結果を使う）。
// 計算は外の世界に触らない。入れた値だけで答えを返すので、テストで確かめられる

/// 緯度・経度から分かった国と都道府県
struct TripRegion: Codable, Equatable, Hashable {
    /// "JP" / "US" など
    var countryCode: String
    /// 日本なら「沖縄県」のような都道府県名
    var prefectureName: String?

    var prefecture: Prefecture? {
        guard countryCode == "JP", let prefectureName else { return nil }
        return Prefecture.allCases.first { $0.name == prefectureName }
    }
}

enum TripStats {

    /// どの期間で数えるか
    enum Period: Hashable {
        case all
        case year(Int)
    }

    struct YearRow: Equatable, Identifiable {
        var year: Int
        var trips: Int
        var days: Int
        var spend: Double
        var id: Int { year }
    }

    struct Summary: Equatable {
        var tripCount = 0
        var dayCount = 0
        var spend: Double = 0
        var placeCount = 0
        var outingCount = 0
        var prefectures: Set<Prefecture> = []
        var countries: Set<String> = []
        /// 旅行を始めた月（1〜12）の多い順に3つまで
        var busyMonths: [Int] = []
        var longest: (title: String, days: Int)?
        var mostSpent: (title: String, amount: Double)?
        /// いちばん長い旅・使った旅の id（写真を出すため）
        var longestPlanId: String?
        var mostSpentPlanId: String?
        /// 数えた旅行の id（新しい順。写真の帯に使う）
        var tripIds: [String] = []
        var topPrefecture: (prefecture: Prefecture, trips: Int)?

        static func == (lhs: Summary, rhs: Summary) -> Bool {
            lhs.tripCount == rhs.tripCount && lhs.dayCount == rhs.dayCount && lhs.spend == rhs.spend
                && lhs.placeCount == rhs.placeCount && lhs.outingCount == rhs.outingCount
                && lhs.prefectures == rhs.prefectures && lhs.countries == rhs.countries
                && lhs.busyMonths == rhs.busyMonths
                && lhs.longest?.title == rhs.longest?.title && lhs.longest?.days == rhs.longest?.days
                && lhs.mostSpent?.title == rhs.mostSpent?.title && lhs.mostSpent?.amount == rhs.mostSpent?.amount
                && lhs.topPrefecture?.prefecture == rhs.topPrefecture?.prefecture
                && lhs.topPrefecture?.trips == rhs.topPrefecture?.trips
        }
    }

    /// 終わった旅行だけを数える（旅行中・これからの旅行は入れない）
    static func finishedTrips(_ plans: [TravelPlan], now: Date, calendar: Calendar = .current) -> [TravelPlan] {
        let today = calendar.startOfDay(for: now)
        return plans.filter { calendar.startOfDay(for: $0.endDate) < today }
    }

    /// その旅行で使った金額（実際に使った金額を優先し、無ければ予定の金額。予定にしない支出も入れる）
    static func spend(of plan: TravelPlan) -> Double {
        TripSplitLedger.entries(of: plan, myUserId: nil).map(\.amount).reduce(0, +)
    }

    /// その旅行の場所（目的地と予定の場所）
    static func coordinates(of plan: TravelPlan) -> [(latitude: Double, longitude: Double)] {
        var result: [(Double, Double)] = []
        if let lat = plan.latitude, let lon = plan.longitude { result.append((lat, lon)) }
        for item in plan.daySchedulesInRange.flatMap(\.scheduleItems) {
            if let lat = item.latitude, let lon = item.longitude { result.append((lat, lon)) }
        }
        return result.map { (latitude: $0.0, longitude: $0.1) }
    }

    /// 旅行が始まった年の一覧（新しい順）
    static func years(of plans: [TravelPlan], now: Date, calendar: Calendar = .current) -> [Int] {
        Set(finishedTrips(plans, now: now, calendar: calendar).map { calendar.component(.year, from: $0.startDate) })
            .sorted(by: >)
    }

    /// - Parameters:
    ///   - region: 緯度・経度から国と都道府県を引く（まだ調べていなければ nil）
    ///   - photoMapPrefectures: フォトマップに写真のある県（日付が無いので「これまで全部」のときだけ入れる）
    ///   - visitedPrefectures: 自分で足した行った県と年（年が空なら「これまで全部」にだけ入る）
    static func summary(plans: [TravelPlan], places: [VisitedPlace], outings: [Plan],
                        photoMapPrefectures: Set<Prefecture> = [],
                        visitedPrefectures: [Prefecture: Set<Int>] = [:],
                        region: (Double, Double) -> TripRegion?,
                        period: Period, now: Date, calendar: Calendar = .current) -> Summary {
        func inPeriod(_ date: Date) -> Bool {
            switch period {
            case .all: return true
            case .year(let year): return calendar.component(.year, from: date) == year
            }
        }

        let trips = finishedTrips(plans, now: now, calendar: calendar).filter { inPeriod($0.startDate) }
        var summary = Summary()
        summary.tripIds = trips.sorted { $0.startDate > $1.startDate }.compactMap(\.id)
        summary.tripCount = trips.count
        summary.dayCount = trips.map(\.dayCount).reduce(0, +)

        var prefectureTrips: [Prefecture: Int] = [:]
        var monthCounts: [Int: Int] = [:]
        for trip in trips {
            let amount = spend(of: trip)
            summary.spend += amount
            if summary.longest.map({ trip.dayCount > $0.days }) ?? true {
                summary.longest = (trip.title, trip.dayCount)
                summary.longestPlanId = trip.id
            }
            if amount > 0, summary.mostSpent.map({ amount > $0.amount }) ?? true {
                summary.mostSpent = (trip.title, amount)
                summary.mostSpentPlanId = trip.id
            }
            monthCounts[calendar.component(.month, from: trip.startDate), default: 0] += 1

            let regions = coordinates(of: trip).compactMap { region($0.latitude, $0.longitude) }
            summary.countries.formUnion(regions.map(\.countryCode))
            let tripPrefectures = Set(regions.compactMap(\.prefecture))
            summary.prefectures.formUnion(tripPrefectures)
            for prefecture in tripPrefectures { prefectureTrips[prefecture, default: 0] += 1 }
        }

        // 保存した場所は、行った都道府県・国には数えない（行きたい場所のメモにも使うため）。数だけ出す
        summary.placeCount = places.filter { inPeriod(visitDate(of: $0, plans: plans)) }.count

        if period == .all {
            summary.prefectures.formUnion(photoMapPrefectures)
            if !photoMapPrefectures.isEmpty { summary.countries.insert("JP") }
        }
        let added = visitedPrefectures.filter { _, years in
            if case .year(let year) = period { return years.contains(year) }
            return true
        }
        summary.prefectures.formUnion(added.keys)
        if !added.isEmpty { summary.countries.insert("JP") }

        summary.outingCount = outings.filter { $0.planType == .outing && $0.startDate < now && inPeriod($0.startDate) }.count

        summary.busyMonths = monthCounts.sorted { lhs, rhs in
            lhs.value != rhs.value ? lhs.value > rhs.value : lhs.key < rhs.key
        }.prefix(3).map(\.key)

        if let top = prefectureTrips.max(by: { lhs, rhs in
            lhs.value != rhs.value ? lhs.value < rhs.value : lhs.key.rawValue > rhs.key.rawValue
        }), top.value >= 2 {
            summary.topPrefecture = (top.key, top.value)
        }
        return summary
    }

    /// 都道府県ごとに、何から数えたか（テスト用の内訳。「神戸旅行（目的地：神戸）」「神戸旅行（予定：北野異人館）」）。
    /// `unresolved` は、場所はあるが県がまだ分からない（調べていない・県が返ってこない）もの
    static func prefectureSources(plans: [TravelPlan], photoMapPrefectures: Set<Prefecture> = [],
                                  visitedPrefectures: [Prefecture: Set<Int>] = [:],
                                  region: (Double, Double) -> TripRegion?,
                                  period: Period, now: Date, calendar: Calendar = .current)
        -> (byPrefecture: [Prefecture: [String]], unresolved: [String]) {
        func inPeriod(_ date: Date) -> Bool {
            switch period {
            case .all: return true
            case .year(let year): return calendar.component(.year, from: date) == year
            }
        }
        var result: [Prefecture: [String]] = [:]
        var unresolved: [String] = []
        func add(_ lat: Double, _ lon: Double, _ label: String) {
            guard let found = region(lat, lon) else { unresolved.append(label); return }
            guard let prefecture = found.prefecture else {
                unresolved.append("\(label)・\(found.countryCode)")
                return
            }
            if !(result[prefecture]?.contains(label) ?? false) { result[prefecture, default: []].append(label) }
        }
        for trip in finishedTrips(plans, now: now, calendar: calendar).filter({ inPeriod($0.startDate) })
            .sorted(by: { $0.startDate < $1.startDate }) {
            if let lat = trip.latitude, let lon = trip.longitude {
                add(lat, lon, "\(trip.title)（目的地：\(trip.destination)）")
            } else {
                unresolved.append("\(trip.title)（目的地の場所が空）")
            }
            for item in trip.daySchedulesInRange.flatMap(\.scheduleItems) {
                if let lat = item.latitude, let lon = item.longitude {
                    add(lat, lon, "\(trip.title)（予定：\(item.title)）")
                }
            }
        }
        if period == .all {
            for prefecture in photoMapPrefectures where result[prefecture] == nil {
                result[prefecture] = ["フォトマップの写真"]
            }
        }
        for (prefecture, years) in visitedPrefectures {
            if case .year(let year) = period, !years.contains(year) { continue }
            let when = years.isEmpty ? "年は分からない" : years.sorted().map { "\($0)年" }.joined(separator: "・")
            result[prefecture, default: []].append("自分で足した（\(when)）")
        }
        return (result, unresolved)
    }

    /// 保存した場所を、いつ行ったことにするか。
    /// 訪れた日 → つないだ旅行の出発日 → 保存した日 の順。
    /// 旅行のあと年が明けてから保存した場所が、次の年の旅として数えられていた
    static func visitDate(of place: VisitedPlace, plans: [TravelPlan]) -> Date {
        if let visitedAt = place.visitedAt { return visitedAt }
        if let planId = place.travelPlanId, let trip = plans.first(where: { $0.id == planId }) {
            return trip.startDate
        }
        return place.createdAt
    }

    /// 終わった旅行のうち、目的地の場所（緯度・経度）が空のもの。目的地の文字から引き直す
    static func tripsMissingDestination(_ plans: [TravelPlan], now: Date) -> [TravelPlan] {
        finishedTrips(plans, now: now).filter {
            ($0.latitude == nil || $0.longitude == nil)
                && !$0.destination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    /// 年ごとの回数・日数・金額（古い順）
    static func yearRows(plans: [TravelPlan], now: Date, calendar: Calendar = .current) -> [YearRow] {
        let grouped = Dictionary(grouping: finishedTrips(plans, now: now, calendar: calendar)) {
            calendar.component(.year, from: $0.startDate)
        }
        return grouped.map { year, trips in
            YearRow(year: year, trips: trips.count, days: trips.map(\.dayCount).reduce(0, +),
                    spend: trips.map(spend(of:)).reduce(0, +))
        }
        .sorted { $0.year < $1.year }
    }

    /// 調べたい場所（旅行の目的地・予定の場所）。同じ場所は1つにする。
    /// 保存した場所は都道府県に数えないので、調べない
    static func lookupCoordinates(plans: [TravelPlan]) -> [(latitude: Double, longitude: Double)] {
        var seen: Set<String> = []
        var result: [(latitude: Double, longitude: Double)] = []
        let all = plans.flatMap(coordinates(of:))
        for point in all where !(point.latitude == 0 && point.longitude == 0) {
            let key = TripRegionResolver.key(point.latitude, point.longitude)
            if seen.insert(key).inserted { result.append(point) }
        }
        return result
    }
}
