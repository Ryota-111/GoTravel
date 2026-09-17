import Foundation

/// 共有された旅行計画を、手元のものとどう突き合わせるかを決める。
///
/// **ここは外の世界に触らない。**
/// ネットワークも Core Data も時計も画面も使わず、入れた値だけで答えを返す。
/// そうしておくと、実機2台と iCloud アカウントを用意しなくても
/// 「同時に編集したら消えないか」「削除が復活しないか」をテストで確かめられる。
///
/// 通信と保存は呼び出し側（`TravelPlanViewModel.refreshSharedPlans`）の仕事。
/// この関数は**何をすべきかを返すだけ**で、自分では何もしない。
///
/// ## なぜ3つ見るのか
///
/// 以前は「更新時刻が新しいほうの計画まるごと」で置き換えていた。
/// そのため自分が費用を、相手が持ち物を同時に触ると、**後に保存したほうの
/// 全体像で上書きされ、片方の編集が黙って消えた。**
///
/// かといって id をそろえて足し合わせるだけにすると、逆に
/// **相手が消した予定が手元から復活する**（手元にはまだ在るため）。
///
/// 手元・相手・**前回そろえたときの内容**の3つを見ると、どちらも解ける。
///
/// | 手元 | 相手 | 前回 | 判断 |
/// |---|---|---|---|
/// | ある | 無い | ある | 相手が消した → 消す |
/// | ある | 無い | 無い | 自分が足した → 残す |
/// | 無い | ある | ある | 自分が消した → 消す |
/// | 無い | ある | 無い | 相手が足した → 入れる |
/// | ある | ある | — | 前回から変わったほうを採る |
enum SharedPlanMerge {

    /// 突き合わせた結果、何をすべきか
    enum Decision {
        /// 相手の変更を取り込む（中身はマージ済み）
        case takeRemote(TravelPlan)
        /// 手元のほうが新しい。相手へ送る
        case pushLocal(TravelPlan)
        /// どちらも同じ。触らない
        case doNothing
    }

    /// - Parameters:
    ///   - local: 手元の計画。まだ持っていなければ nil
    ///   - remote: パブリックDBから降りてきた計画
    ///   - base: 前回そろえたときの内容。初回は nil
    ///   - myUserId: この端末のユーザーID
    static func decide(local: TravelPlan?,
                       remote: TravelPlan,
                       base: TravelPlan? = nil,
                       myUserId: String) -> Decision {
        // まだ手元に無い共有計画は、そのまま取り込む
        guard let local else {
            return .takeRemote(adopt(remote, local: nil, base: nil, myUserId: myUserId))
        }

        if remote.updatedAt > local.updatedAt {
            return .takeRemote(adopt(remote, local: local, base: base, myUserId: myUserId))
        }
        if local.updatedAt > remote.updatedAt {
            return .pushLocal(local)
        }
        // 更新時刻が同じ＝どちらも変わっていない。
        // ここで無理に送り合うと、往復し続けて落ち着かなくなる
        return .doNothing
    }

    /// 降りてきた計画を、この端末に置ける形へ整える
    private static func adopt(_ remote: TravelPlan,
                              local: TravelPlan?,
                              base: TravelPlan?,
                              myUserId: String) -> TravelPlan {
        var adopted = remote

        // 手元の行は必ず端末ユーザーの userId で持つ。
        // `NSFetchedResultsController` の条件に合わなくなると、
        // 取り込んだのに一覧へ出てこない。本来の持ち主は ownerId が覚えている
        adopted.userId = myUserId

        adopted.packingItems = mergePackingItems(local: local, remote: remote, base: base)

        // 前回そろえたときの内容が無ければ、比べようがないので相手を正とする。
        // 初回の取り込みや、この仕組みを入れる前からある計画がこれにあたる
        guard let local else { return adopted }

        adopted.reservations = merge(
            local: local.reservations,
            remote: remote.reservations,
            base: base?.reservations ?? [],
            id: \.id,
            hasBase: base != nil
        )

        adopted.daySchedules = mergeDaySchedules(local: local, remote: remote, base: base)

        return adopted
    }

    // MARK: - 予定（日ごとに入れ子になっている）

    private static func mergeDaySchedules(local: TravelPlan,
                                          remote: TravelPlan,
                                          base: TravelPlan?) -> [DaySchedule] {
        /// 予定は日ごとに分かれているが、突き合わせは id だけで行う。
        /// 相手が別の日へ動かした予定を、二重に持たないため
        func flatten(_ days: [DaySchedule]) -> [(day: Int, item: ScheduleItem)] {
            days.flatMap { day in day.scheduleItems.map { (day.dayNumber, $0) } }
        }

        let mergedItems = merge(
            local: flatten(local.daySchedules),
            remote: flatten(remote.daySchedules),
            base: flatten(base?.daySchedules ?? []),
            id: \.item.id,
            hasBase: base != nil
        )

        // 相手側の日付を土台にする。日数が変わっていれば相手に合わせる
        var days = remote.daySchedules.map { day -> DaySchedule in
            var copy = day
            copy.scheduleItems = []
            return copy
        }

        for entry in mergedItems {
            if let index = days.firstIndex(where: { $0.dayNumber == entry.day }) {
                days[index].scheduleItems.append(entry.item)
            } else {
                days.append(DaySchedule(dayNumber: entry.day,
                                        date: remote.date(forDay: entry.day),
                                        scheduleItems: [entry.item]))
            }
        }

        // 予定の無い日も残す。日タブは日数から作るので消しても表示は崩れないが、
        // 保存されている形が変わると差分の比較が毎回ずれる
        for index in days.indices {
            days[index].scheduleItems.sort { $0.time < $1.time }
        }
        return days.sorted { $0.dayNumber < $1.dayNumber }
    }

    // MARK: - 持ち物・お土産・やりたいこと

    private static func mergePackingItems(local: TravelPlan?,
                                          remote: TravelPlan,
                                          base: TravelPlan?) -> [PackingItem] {
        // **自分だけの持ち物・お土産は、共有側の内容で消さない。**
        //
        // パブリックDBには持ち主のいない項目（やりたいこと）しか載っていない。
        // 降りてきたものでそのまま置き換えると、自分の持ち物が毎回消える
        let myItems = local?.packingItems.filter { $0.ownerId != nil } ?? []

        guard let local else {
            return remote.packingItems.filter { $0.ownerId == nil } + myItems
        }

        let shared = merge(
            local: local.packingItems.filter { $0.ownerId == nil },
            remote: remote.packingItems.filter { $0.ownerId == nil },
            base: base?.packingItems.filter { $0.ownerId == nil } ?? [],
            id: \.id,
            hasBase: base != nil,
            isEqual: isSamePackingItem
        )

        return shared + myItems
    }

    /// `PackingItem` は `Equatable` ではないので、比べる項目を並べる。
    /// **項目を足したらここにも足すこと。** 漏れると相手の変更が伝わらない
    private static func isSamePackingItem(_ lhs: PackingItem, _ rhs: PackingItem) -> Bool {
        lhs.id == rhs.id
            && lhs.name == rhs.name
            && lhs.isChecked == rhs.isChecked
            && lhs.kind == rhs.kind
            && lhs.note == rhs.note
            && lhs.ownerId == rhs.ownerId
    }

    // MARK: - 突き合わせの本体

    /// 手元・相手・前回の3つを id で突き合わせる。
    ///
    /// `hasBase` が false のときは前回の内容が無いということなので、
    /// 相手を正として素直に置き換える（初回の取り込みなど）
    private static func merge<Element>(local: [Element],
                                       remote: [Element],
                                       base: [Element],
                                       id: KeyPath<Element, String>,
                                       hasBase: Bool,
                                       isEqual: (Element, Element) -> Bool) -> [Element] {
        guard hasBase else { return remote }

        let localByID = Dictionary(local.map { ($0[keyPath: id], $0) }, uniquingKeysWith: { first, _ in first })
        let remoteByID = Dictionary(remote.map { ($0[keyPath: id], $0) }, uniquingKeysWith: { first, _ in first })
        let baseByID = Dictionary(base.map { ($0[keyPath: id], $0) }, uniquingKeysWith: { first, _ in first })

        var result: [Element] = []

        // 相手にあるものを土台にする。並び順も相手に合わせる
        for element in remote {
            let key = element[keyPath: id]
            if localByID[key] == nil, baseByID[key] != nil {
                // 前回はあって、手元にはもう無い → 自分が消した
                continue
            }
            if let localElement = localByID[key], let baseElement = baseByID[key] {
                // 両方にある。前回から動かしたほうを採る。
                // どちらも動かしていれば相手のまま
                if isEqual(element, baseElement), !isEqual(localElement, baseElement) {
                    result.append(localElement)
                    continue
                }
            }
            result.append(element)
        }

        // 手元にしか無いものは、自分が足したぶんだけ残す
        for element in local {
            let key = element[keyPath: id]
            guard remoteByID[key] == nil else { continue }
            if baseByID[key] != nil {
                // 前回はあって、相手にはもう無い → 相手が消した
                continue
            }
            result.append(element)
        }

        return result
    }

    private static func merge<Element: Equatable>(local: [Element],
                                                  remote: [Element],
                                                  base: [Element],
                                                  id: KeyPath<Element, String>,
                                                  hasBase: Bool) -> [Element] {
        merge(local: local, remote: remote, base: base, id: id, hasBase: hasBase, isEqual: ==)
    }
}

// MARK: - 日付つきの予定を突き合わせるための入れ物

/// 予定は日ごとに入れ子になっているので、突き合わせのあいだだけ平らにする
private struct DatedScheduleItem: Equatable {
    let day: Int
    let item: ScheduleItem
}

private extension SharedPlanMerge {
    static func merge(local: [(day: Int, item: ScheduleItem)],
                      remote: [(day: Int, item: ScheduleItem)],
                      base: [(day: Int, item: ScheduleItem)],
                      id: KeyPath<(day: Int, item: ScheduleItem), String>,
                      hasBase: Bool) -> [(day: Int, item: ScheduleItem)] {
        let wrapped = merge(
            local: local.map { DatedScheduleItem(day: $0.day, item: $0.item) },
            remote: remote.map { DatedScheduleItem(day: $0.day, item: $0.item) },
            base: base.map { DatedScheduleItem(day: $0.day, item: $0.item) },
            id: \DatedScheduleItem.item.id,
            hasBase: hasBase
        )
        return wrapped.map { (day: $0.day, item: $0.item) }
    }
}

// MARK: - テストから中身を取り出すための入口

extension SharedPlanMerge.Decision {
    var takenPlan: TravelPlan? {
        if case .takeRemote(let plan) = self { return plan }
        return nil
    }

    var pushedPlan: TravelPlan? {
        if case .pushLocal(let plan) = self { return plan }
        return nil
    }

    var isDoNothing: Bool {
        if case .doNothing = self { return true }
        return false
    }
}
