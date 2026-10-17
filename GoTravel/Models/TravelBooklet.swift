import SwiftUI

// MARK: - 旅のしおり（PDF）（Travory Pro）
//
// 旅行計画を、表紙のついた冊子（A5）にして書き出す。印刷して持って行ったり、
// アプリを入れていない家族に LINE で渡したりするためのもの。
// 画像の書き出し（`TravelPlanShareCard`）は1枚もので、印刷や冊子には向いていなかった。
//
// - 何を入れるかは書き出す前に選べる（`TravelBooklet.Options`）
// - 渡す相手に見せないもの（自分だけのお土産・自分だけのメモ）は入れない
// - ページ割りはここで決める（純粋関数。テストで確かめる）。描くのは `TravelBookletRenderer`

enum TravelBooklet {

    /// A5（148 × 210 mm）
    static let pageSize = CGSize(width: 420, height: 595)

    /// 入れるもの
    struct Options: Equatable {
        var includesCover = true
        var includesSchedule = true
        var includesMaps = true
        var includesPacking = true
        var includesCosts = true
        var includesMemos = true
    }

    /// デザイン
    enum Style: String, CaseIterable, Identifiable {
        case simple
        case cute
        case japanese

        var id: String { rawValue }

        var name: String {
            switch self {
            case .simple: return "シンプル"
            case .cute: return "かわいい"
            case .japanese: return "和風"
            }
        }

        var summary: String {
            switch self {
            case .simple: return "白い紙に黒い文字。印刷しても読みやすい"
            case .cute: return "今のテーマの色で、丸みのある文字"
            case .japanese: return "生成りの紙に明朝体と朱色"
            }
        }
    }

    /// 1ページ
    enum Page: Equatable {
        case cover
        /// 1日の予定。予定が多い日は何ページかに分かれる（2ページ目からは地図を載せない）
        case day(dayNumber: Int, itemIDs: [String], showsMap: Bool, isContinued: Bool)
        case packing(packingIDs: [String], souvenirIDs: [String])
        case costs
        case memo(id: String)
    }

    // MARK: ページ割り

    /// 1ページに入る予定の量。メモのある予定は2つ分と数える
    static let dayCapacityWithMap = 7
    static let dayCapacity = 14
    /// 持ち物のページは2列。1ページに入る品の数
    static let packingCapacity = 40

    static func pages(for plan: TravelPlan, options: Options, userId: String?) -> [Page] {
        var pages: [Page] = []
        if options.includesCover { pages.append(.cover) }

        if options.includesSchedule {
            for day in plan.daySchedulesInRange where !day.scheduleItems.isEmpty {
                let items = TravelPlanTextExporter.sortedByTime(day.scheduleItems)
                let hasMap = options.includesMaps && items.contains(where: \.hasCoordinate)
                var chunk: [String] = []
                var used = 0
                var isFirst = true
                func flush() {
                    pages.append(.day(dayNumber: day.dayNumber, itemIDs: chunk,
                                      showsMap: isFirst && hasMap, isContinued: !isFirst))
                    chunk = []
                    used = 0
                    isFirst = false
                }
                for item in items {
                    let weight = item.hasNotes ? 2 : 1
                    let capacity = isFirst && hasMap ? dayCapacityWithMap : dayCapacity
                    if used + weight > capacity && !chunk.isEmpty { flush() }
                    chunk.append(item.id)
                    used += weight
                }
                if !chunk.isEmpty { flush() }
            }
        }

        if options.includesPacking {
            let packing = packingItems(of: plan, userId: userId)
            let souvenirs = souvenirItems(of: plan)
            var remainingPacking = packing.map(\.id)
            var remainingSouvenirs = souvenirs.map(\.id)
            while !remainingPacking.isEmpty || !remainingSouvenirs.isEmpty {
                let p = Array(remainingPacking.prefix(packingCapacity))
                remainingPacking.removeFirst(p.count)
                let s = Array(remainingSouvenirs.prefix(packingCapacity - p.count))
                remainingSouvenirs.removeFirst(s.count)
                pages.append(.packing(packingIDs: p, souvenirIDs: s))
            }
        }

        if options.includesCosts && costTotal(of: plan) > 0 {
            pages.append(.costs)
        }

        if options.includesMemos {
            for memo in plan.sharedMemos where !memo.isEmpty {
                pages.append(.memo(id: memo.id))
            }
        }
        return pages
    }

    /// 持ち物（自分のリスト）
    static func packingItems(of plan: TravelPlan, userId: String?) -> [PackingItem] {
        plan.items(of: .packing).filter { $0.isVisible(to: userId) }
    }

    /// お土産。**「自分だけ」にした品は入れない**（同行者へのサプライズを、渡したしおりで明かさないため）
    static func souvenirItems(of plan: TravelPlan) -> [PackingItem] {
        plan.items(of: .souvenir).filter { $0.ownerId == nil }
    }

    /// 日ごとの金額（実績があれば実績）
    static func dayTotals(of plan: TravelPlan) -> [(dayNumber: Int, total: Double)] {
        plan.daySchedulesInRange.compactMap { day in
            let total = day.scheduleItems.compactMap(\.displayCost).reduce(0, +)
            return total > 0 ? (day.dayNumber, total) : nil
        }
    }

    static func costTotal(of plan: TravelPlan) -> Double {
        dayTotals(of: plan).map(\.total).reduce(0, +)
    }

    /// ファイル名（「沖縄旅行のしおり.pdf」）。ファイル名に使えない文字は置き換える
    static func fileName(for plan: TravelPlan) -> String {
        let title = plan.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let safe = (title.isEmpty ? "旅行" : title)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        return "\(safe)のしおり.pdf"
    }
}

extension ScheduleItem {
    var hasCoordinate: Bool { latitude != nil && longitude != nil }
    var hasNotes: Bool { !(notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}
