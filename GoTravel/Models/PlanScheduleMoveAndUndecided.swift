import Foundation

// MARK: - おでかけの予定表の「移動」と「時間未定」（3.5）
//
// 3.4 で旅行の日程に入れた「移動」「時間未定」を、おでかけのタイムスケジュールにもそろえる。
// 中身の形と考え方は旅行と同じ（`ScheduleMove.swift`・`ScheduleUndecidedTime.swift`・`docs/設計_移動と時間未定.md`）。
//
// - 移動：`move` に乗り物・出発地・到着地・便を持つ。時刻（`time`）が出発。おでかけには終わりの時刻が無いので、到着の時刻は持たない
//   場所（`placeId`）は付けない。名前を入れなければ「梅田 → 京都」を名前にする（古い版でも中身が分かる）
// - 時間未定：`time` は並ぶ位置として持ち続ける。すぐ前の「時刻のある予定」と同じ分の1〜59秒目。
//   画面は分までしか出さないので秒は見えない。古い版では、前の予定と同じ時刻の予定としてすぐ後ろに出る

extension PlanScheduleItem {
    /// 時間が決まっていない予定か
    var hasUndecidedTime: Bool { isTimeUndecided == true }

    /// 出発地 → 到着地を持つ「移動」の予定か
    var isMove: Bool { move != nil }

    /// 名前が自動で付けたもの（「梅田 → 京都」）のままか。行で発着地を2度出さないのに使う
    var hasDefaultMoveTitle: Bool {
        guard let move else { return false }
        return title == move.defaultTitle
    }

    /// 行に出す時刻（「10:30」か「未定」）
    var timeText: String {
        hasUndecidedTime ? ScheduleUndecided.label : DateFormatter.japaneseTime.string(from: time)
    }

    /// 移動の中身を入れる。名前を空にしたら「梅田 → 京都」を名前にする。場所（`placeId`）は外す
    mutating func apply(move newMove: ScheduleMove, title enteredTitle: String) {
        move = newMove
        placeId = nil
        let trimmed = enteredTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        title = trimmed.isEmpty ? newMove.defaultTitle : trimmed
    }

    /// その日の中で並べる順。分が同じなら時刻のある予定を先に、未定どうしは位置の秒の順。
    /// 日付は見ない（日ごとに分けてから使う）
    static func chronologically(_ lhs: PlanScheduleItem, _ rhs: PlanScheduleItem) -> Bool {
        let left = PlanScheduleUndecided.minuteOfDay(lhs.time)
        let right = PlanScheduleUndecided.minuteOfDay(rhs.time)
        if left != right { return left < right }
        switch (lhs.hasUndecidedTime, rhs.hasUndecidedTime) {
        case (false, true): return true
        case (true, false): return false
        default: return PlanScheduleUndecided.second(lhs.time) < PlanScheduleUndecided.second(rhs.time)
        }
    }
}

enum PlanScheduleUndecided {

    static func minuteOfDay(_ date: Date) -> Int {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    static func second(_ date: Date) -> Int {
        Calendar.current.component(.second, from: date)
    }

    /// 並んでいる順（`ordered`。同じ日の予定）のまま、未定の予定に位置を付け直す。時刻のある予定は変えない
    static func normalized(_ ordered: [PlanScheduleItem]) -> [PlanScheduleItem] {
        var result = ordered
        var anchorTime: Date?
        var runLength = 0

        for index in result.indices {
            let item = result[index]
            guard item.hasUndecidedTime else {
                anchorTime = item.time
                runLength = 0
                continue
            }
            runLength += 1
            // 前に時刻のある予定が無い：すぐ後ろの予定の1分前の分を使う（その日の 0:00 より前には出ない）
            let base = anchorTime
                ?? result[index...].first { !$0.hasUndecidedTime }.map { next in
                    max(next.time.addingTimeInterval(-60), Calendar.current.startOfDay(for: next.time))
                }
                ?? item.time
            let minute = Calendar.current.dateInterval(of: .minute, for: base)?.start ?? base
            result[index].time = minute.addingTimeInterval(TimeInterval(min(runLength, 59)))
        }
        return result
    }

    /// その日の予定（`dayItems`）に、未定の予定 `item` を `anchorID` の予定のすぐ後ろに入れ、
    /// その日の予定を並べ直して返す（nil ならいちばん前）。同じ id の予定があれば置き換える
    static func inserting(_ item: PlanScheduleItem, after anchorID: String?, into dayItems: [PlanScheduleItem]) -> [PlanScheduleItem] {
        var undecided = item
        undecided.isTimeUndecided = true
        var ordered = dayItems.filter { $0.id != item.id }.sorted(by: PlanScheduleItem.chronologically)
        let position = anchorID.flatMap { id in ordered.firstIndex { $0.id == id }.map { $0 + 1 } } ?? 0
        ordered.insert(undecided, at: min(position, ordered.count))
        return normalized(ordered)
    }

    /// この予定のすぐ前にある予定の id（いちばん前なら nil）。直す画面の「入れる位置」の初期値
    static func anchorID(of itemID: String, in dayItems: [PlanScheduleItem]) -> String? {
        let ordered = dayItems.sorted(by: PlanScheduleItem.chronologically)
        guard let index = ordered.firstIndex(where: { $0.id == itemID }), index > 0 else { return nil }
        return ordered[index - 1].id
    }

    /// 時間を決めるときに入れ始める時刻。位置の秒を落とす
    static func startingTime(for item: PlanScheduleItem) -> Date {
        Calendar.current.dateInterval(of: .minute, for: item.time)?.start ?? item.time
    }
}
