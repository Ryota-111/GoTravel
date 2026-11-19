import Foundation

// MARK: - 予定を複製する（3.8、ご要望から）
//
// 「同じ場所に何度も行く」「ホテルのチェックインとチェックアウト」などで、
// 同じ中身を何度も打ち直していた、というご意見から。

extension ScheduleItem {
    /// 複製した予定。中身（名前・場所・時刻・費用・メモ・参加する人・移動）はそのまま、別の予定にする。
    ///
    /// - 予約とのつながりは外す。予約から作った予定を複製しても、予約を直したときに一緒に動かない
    ///   （予約の予定は予約の側で1組だけ持つ）
    /// - 添付は複製しない（添付は予定の id に付いていて、端末の中のファイルを2重に持たないため）
    func duplicated() -> ScheduleItem {
        var copy = self
        copy.id = UUID().uuidString
        copy.reservationId = nil
        copy.reservationPart = nil
        return copy
    }
}

extension TravelPlan {
    /// 予定を `targetNumber` 日目に複製する。時:分はそのまま、日付だけその日に合わせる。
    /// 同じ日に複製したときは、元の予定のすぐ後ろに入る。
    /// - Returns: 複製した予定を入れた計画と、複製した予定の id。元の予定が見つからなければ nil
    func duplicatingItem(_ id: String, toDay targetNumber: Int) -> (plan: TravelPlan, newId: String)? {
        guard let sourceIndex = daySchedules.firstIndex(where: { $0.scheduleItems.contains { $0.id == id } }),
              let item = daySchedules[sourceIndex].scheduleItems.first(where: { $0.id == id }),
              let targetIndex = daySchedules.firstIndex(where: { $0.dayNumber == targetNumber }) else { return nil }

        let offset = Calendar.current.dateComponents(
            [.day], from: Calendar.current.startOfDay(for: daySchedules[sourceIndex].date),
            to: Calendar.current.startOfDay(for: daySchedules[targetIndex].date)).day ?? 0
        var copy = item.duplicated()
        if offset != 0 {
            let calendar = ScheduleClock.calendar(in: item.timeZone)
            copy.time = calendar.date(byAdding: .day, value: offset, to: item.time) ?? item.time
            if let endTime = item.endTime {
                copy.endTime = calendar.date(byAdding: .day, value: offset, to: endTime) ?? endTime
            }
        }

        var updated = self
        var items = updated.daySchedules[targetIndex].scheduleItems
        if targetIndex == sourceIndex, let position = items.firstIndex(where: { $0.id == id }) {
            items.insert(copy, at: position + 1)
        } else {
            items.append(copy)
        }
        // 時間未定の予定は、並びの位置で順番を持つので付け直す（別の日へ移すときと同じ）
        if copy.hasUndecidedTime {
            let pinned = items.filter { $0.isPinned == true }
            let ordered = items.filter { $0.isPinned != true }.sorted(by: ScheduleItem.chronologically)
            items = pinned + ScheduleUndecided.normalized(ordered)
        }
        updated.daySchedules[targetIndex].scheduleItems = items
        return (updated, copy.id)
    }
}
