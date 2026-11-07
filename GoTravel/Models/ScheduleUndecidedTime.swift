import Foundation

// MARK: - 「時間未定」の予定（3.4）
//
// 「時間は決めてないけど、予定は入れておきたい。他の予定の前後どこにでも動かせるように」
// というご意見から（`docs/設計_移動と時間未定.md`）。
//
// **未定でも `time` は持ち続け、「並ぶ位置」として使う。** 時刻を必ず持つ前提の所
// （並び順・共有の合わせ込み・時間帯の付け替え・古い版）をそのまま動かすため。
//
// 位置の付け方：すぐ前の「時刻のある予定」と同じ分の、1〜59秒目。続けて並ぶ未定の予定は
// 1秒ずつずらす。前に時刻のある予定が無ければ、すぐ後ろの予定の1分前の分を使う。
// 画面の時刻は分までしか出さないので、秒は見えない。古い版では、前の予定と同じ時刻の予定として
// すぐ後ろに出る

extension ScheduleItem {
    /// 時間が決まっていない予定か
    var hasUndecidedTime: Bool { isTimeUndecided == true }

    /// 並ぶ位置の秒（未定の予定どうしの順に使う）
    fileprivate var positionSecond: Int {
        ScheduleClock.calendar(in: timeZone).component(.second, from: time)
    }
}

enum ScheduleUndecided {

    /// 画面に出す「時刻」
    static let label = "未定"

    /// 並べる比較の続き。**分まで同じとき**だけ呼ぶ。
    /// 時刻のある予定を先に、未定どうしは位置の秒の順
    static func comesFirst(atSameMinute lhs: ScheduleItem, _ rhs: ScheduleItem) -> Bool {
        switch (lhs.hasUndecidedTime, rhs.hasUndecidedTime) {
        case (false, true): return true
        case (true, true): return lhs.positionSecond < rhs.positionSecond
        default: return false
        }
    }

    /// 並んでいる順（`ordered`）のまま、未定の予定に位置を付け直す。時刻のある予定は変えない。
    ///
    /// 並べ替え・追加・直したあとに呼ぶ。並びの順は変わらない
    static func normalized(_ ordered: [ScheduleItem]) -> [ScheduleItem] {
        var result = ordered
        var anchor: ScheduleItem?
        var runLength = 0

        for index in result.indices {
            let item = result[index]
            guard item.hasUndecidedTime else {
                anchor = item
                runLength = 0
                continue
            }
            runLength += 1
            let base: ScheduleItem? = anchor
                ?? result[index...].first { !$0.hasUndecidedTime }.map { next in
                    // 前に時刻のある予定が無い：すぐ後ろの予定の1分前の分を使う
                    var earlier = next
                    earlier.time = next.time.addingTimeInterval(-60)
                    return earlier
                }
            result[index] = placed(item, after: base, offset: runLength)
        }
        return result
    }

    /// 未定の予定を `base` と同じ分の `offset` 秒目に置く。`base` が無ければ、今の位置の分のまま並べ直す
    private static func placed(_ item: ScheduleItem, after base: ScheduleItem?, offset: Int) -> ScheduleItem {
        var moved = item
        let source = base ?? item
        let clock = ScheduleClock.calendar(in: source.timeZone)
        let minute = clock.dateInterval(of: .minute, for: source.time)?.start ?? source.time
        moved.time = minute.addingTimeInterval(TimeInterval(min(offset, 59)))
        moved.timeZoneIdentifier = source.timeZoneIdentifier
        moved.dayShift = source.dayShift
        // 未定の予定は終わりの時刻を持たない
        moved.endTime = nil
        moved.endTimeZoneIdentifier = nil
        return moved
    }

    /// その日の予定に、未定の予定 `item` を `anchorID` の予定のすぐ後ろに入れる（nil ならいちばん前）。
    /// 同じ id の予定があれば置き換える。固定した予定（一番上に出すもの）は並びに入れず、そのまま残す
    static func inserting(_ item: ScheduleItem, after anchorID: String?, into items: [ScheduleItem]) -> [ScheduleItem] {
        var undecided = item
        undecided.isTimeUndecided = true
        let pinned = items.filter { $0.isPinned == true && $0.id != item.id }
        var ordered = items
            .filter { $0.isPinned != true && $0.id != item.id }
            .sorted(by: ScheduleItem.chronologically)
        let position = anchorID.flatMap { id in ordered.firstIndex { $0.id == id }.map { $0 + 1 } } ?? 0
        ordered.insert(undecided, at: min(position, ordered.count))
        return pinned + normalized(ordered)
    }

    /// その日の並びで、この予定のすぐ前にある予定の id（いちばん前なら nil）。直す画面の「どこに入れるか」の初期値
    static func anchorID(of itemID: String, in items: [ScheduleItem]) -> String? {
        let ordered = items.filter { $0.isPinned != true }.sorted(by: ScheduleItem.chronologically)
        guard let index = ordered.firstIndex(where: { $0.id == itemID }), index > 0 else { return nil }
        return ordered[index - 1].id
    }

    /// 時間を決めるときに入れ始める時刻。位置の秒を落とし、前の予定と同じ分にする
    static func startingTime(for item: ScheduleItem) -> Date {
        ScheduleClock.calendar(in: item.timeZone).dateInterval(of: .minute, for: item.time)?.start ?? item.time
    }
}
