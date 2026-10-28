import Foundation

// MARK: - 行程と日程の並び替え（3.2）
//
// 「①、②と決めていても当日②→①が良さそうになったとき、時刻を書き換えずに指で入れ替えたい」
// 「天気によって1日目と2日目を丸ごと入れ替えたい」というご要望から。
//
// 行程は時刻の順に並ぶので、並び替えは**時刻の枠をそのままに、中身を入れ替える**ことで表す。
// 9:00・11:00・14:00 の3件で②を先頭に動かすと、②が 9:00、①が 11:00 になる。
// 終わりの時刻は、それぞれの予定の長さを保ったまま一緒に動かす

extension TravelPlan {
    /// その日の行程を `newOrder`（予定の id）の順に並べ替える。
    ///
    /// - Parameters:
    ///   - oldOrder: 並べ替える前に画面に出ていた順。この順の時刻を枠として使う
    ///   - newOrder: 並べ替えたあとの順。`oldOrder` と同じ id の並べ替えであること
    func reorderingItems(onDay dayNumber: Int, from oldOrder: [String], to newOrder: [String]) -> TravelPlan {
        guard oldOrder.count == newOrder.count, Set(oldOrder) == Set(newOrder), oldOrder != newOrder,
              let dayIndex = daySchedules.firstIndex(where: { $0.dayNumber == dayNumber }) else { return self }

        var updated = self
        let items = daySchedules[dayIndex].scheduleItems
        func item(_ id: String) -> ScheduleItem? { items.first { $0.id == id } }

        var movedItems: [ScheduleItem] = []
        for (slotID, itemID) in zip(oldOrder, newOrder) where slotID != itemID {
            guard let slot = item(slotID), let original = item(itemID),
                  let index = updated.daySchedules[dayIndex].scheduleItems.firstIndex(where: { $0.id == itemID }) else { continue }
            var moved = original
            let delta = slot.time.timeIntervalSince(original.time)
            moved.time = slot.time
            moved.timeZoneIdentifier = slot.timeZoneIdentifier
            moved.dayShift = slot.dayShift
            moved.endTime = original.endTime?.addingTimeInterval(delta)
            updated.daySchedules[dayIndex].scheduleItems[index] = moved
            movedItems.append(moved)
        }

        // 予約から作った予定は、予約の時刻もそろえる（行程で時刻を直したときと同じ）
        for moved in movedItems where moved.reservationId != nil {
            updated.syncReservation(fromScheduleItem: moved)
        }
        return updated
    }

    /// 日程を丸ごと入れ替える。`newOrder` は日（`dayNumber`）を新しい順に並べたもの。
    ///
    /// 日付と「何日目か」はそのままで、その日の予定と時間帯だけが移る。
    /// 1日目と2日目を入れ替えると、2日目の予定が1日目の日付に移る
    func reorderingDays(_ newOrder: [Int]) -> TravelPlan {
        let sortedDays = daySchedules.sorted { $0.dayNumber < $1.dayNumber }
        guard newOrder.count == sortedDays.count,
              Set(newOrder) == Set(sortedDays.map(\.dayNumber)),
              newOrder != sortedDays.map(\.dayNumber) else { return self }

        var updated = self
        var movedItems: [ScheduleItem] = []
        updated.daySchedules = zip(sortedDays, newOrder).map { target, sourceNumber in
            guard let source = sortedDays.first(where: { $0.dayNumber == sourceNumber }),
                  source.dayNumber != target.dayNumber else { return target }
            let dayOffset = Self.dayDifference(from: source.date, to: target.date)
            var day = target
            day.timeZoneIdentifier = source.timeZoneIdentifier
            day.scheduleItems = source.scheduleItems.map { item in
                let shifted = Self.shifting(item, byDays: dayOffset)
                movedItems.append(shifted)
                return shifted
            }
            return day
        }

        for moved in movedItems where moved.reservationId != nil {
            updated.syncReservation(fromScheduleItem: moved)
        }
        return updated
    }

    private static func dayDifference(from source: Date, to target: Date) -> Int {
        let calendar = Calendar.current
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: source),
                                       to: calendar.startOfDay(for: target)).day ?? 0
    }

    /// 時:分は変えずに日付だけずらす。夏時間の切り替わりでずれないよう、予定の時計で数える
    private static func shifting(_ item: ScheduleItem, byDays days: Int) -> ScheduleItem {
        guard days != 0 else { return item }
        var moved = item
        let calendar = ScheduleClock.calendar(in: item.timeZone)
        moved.time = calendar.date(byAdding: .day, value: days, to: item.time) ?? item.time
        if let endTime = item.endTime {
            moved.endTime = calendar.date(byAdding: .day, value: days, to: endTime) ?? endTime
        }
        return moved
    }
}
