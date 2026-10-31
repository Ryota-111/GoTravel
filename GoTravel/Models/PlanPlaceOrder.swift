import Foundation

// MARK: - 予定の地図に付ける行程の順番（3.2）
//
// 旅行の地図は行程の順に ①② が付くのに、予定（おでかけ）の地図は番号の無いピンだった。
// 「当日の動きが分かるように順番を付けてほしい」というご要望から。
// 番号は、タイムスケジュールで最初にその場所へ行く順（何日目 → 時刻）。
// タイムスケジュールに出てこない場所には付けない

extension Plan {
    /// 場所の id → 行程の順番（1始まり）
    var placeOrder: [String: Int] {
        var order: [String: Int] = [:]
        for item in scheduleItemsInVisitOrder {
            guard let placeId = item.placeId,
                  order[placeId] == nil,
                  places.contains(where: { $0.id == placeId }) else { continue }
            order[placeId] = order.count + 1
        }
        return order
    }

    /// 行程の順に並べた場所。地図で番号どおりに線を引くのに使う
    var placesInVisitOrder: [PlannedPlace] {
        let order = placeOrder
        return places
            .filter { order[$0.id] != nil }
            .sorted { (order[$0.id] ?? 0) < (order[$1.id] ?? 0) }
    }

    /// 何日目 → その日の時刻の順。画面のタイムスケジュールと同じ並び
    private var scheduleItemsInVisitOrder: [PlanScheduleItem] {
        let calendar = Calendar.current
        func minutes(_ date: Date) -> Int {
            let components = calendar.dateComponents([.hour, .minute], from: date)
            return (components.hour ?? 0) * 60 + (components.minute ?? 0)
        }
        return scheduleItems.sorted { lhs, rhs in
            let lhsDay = dayNumber(for: lhs), rhsDay = dayNumber(for: rhs)
            if lhsDay != rhsDay { return lhsDay < rhsDay }
            return minutes(lhs.time) < minutes(rhs.time)
        }
    }
}
