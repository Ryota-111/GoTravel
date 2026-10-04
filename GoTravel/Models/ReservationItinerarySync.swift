import Foundation

// MARK: - 予約と行程の同期
//
// 「行程にも追加する」で作った予定は、予約と同じものを2か所で見ている。
// どちらで直しても、前に入れた情報は残したまま、直したところだけを両方にそろえる。
//
// 以前は予約を保存するたびに行程の予定を消して作り直していたため、
// 日程タブで入れた場所（地図）・メモ・参加する人などが消えていた。
// 共有した旅行では、ほかの人が入れた情報まで消える（ご報告をいただいて直した）。
//
// - 予約 → 行程（`syncScheduleItems`）：同じ予定を残し、予約から決まる項目だけを書き換える
//   - 時刻・時間帯・費用は予約に合わせる
//   - 名前とメモは、行程の側で書き換えていなければ予約に合わせる（書き換えていれば残す）
//   - 場所は、行程の側で地図から選んでいれば残す
//   - 実績の金額・リンク・一番上への固定・参加する人は行程の側のものを残す
// - 行程 → 予約（`syncReservation(fromScheduleItem:)`）：時刻・場所（地図の位置ごと）・名前・メモを予約に戻す
//
// 予約の時点で場所（地図）とメモを入れておけば、行程の予定にもそのまま入る（`Reservation.location` など）

/// 予約から作った予定のどの部分か
enum ReservationPart: String {
    /// 飛行機・新幹線以外（宿・レストランなど）の1件
    case main
    /// 飛行機・新幹線の出発
    case departure
    /// 飛行機・新幹線の到着
    case arrival
    /// 宿・レンタカーなどの終わり（チェックアウト・返却）
    case end
}

extension TravelPlan {

    /// 予約の内容を行程に反映する。`isOn` が false なら、その予約から作った予定を消す。
    ///
    /// - Parameter previous: 直す前の予約。行程の側で名前やメモを書き換えたかどうかを、
    ///   「前の予約から作られたはずの名前」と比べて見分けるのに使う
    mutating func syncScheduleItems(for reservation: Reservation, previous: Reservation? = nil, isOn: Bool) {
        let existing = scheduleItems(forReservation: reservation.id)
        removeScheduleItems(forReservation: reservation.id)
        guard isOn else { return }

        let previousGenerated = previous?.itineraryItems() ?? []
        let existingByPart = Dictionary(
            Self.withParts(existing, kind: reservation.kind).map { ($0.part, $0.item) },
            uniquingKeysWith: { first, _ in first }
        )

        for fresh in reservation.itineraryItems() {
            let part = fresh.reservationPart.flatMap(ReservationPart.init(rawValue:)) ?? .main
            var item = fresh
            if let current = existingByPart[part] {
                let generated = previousGenerated.first { $0.reservationPart == fresh.reservationPart }
                item = Self.merge(current: current, fresh: fresh, previouslyGenerated: generated)
            }
            if let dayNumber = dayNumber(forDate: item.time, in: item.timeZone) {
                addScheduleItem(item, onDay: dayNumber)
            }
        }
    }

    /// 行程の側で予定を直したとき、元の予約にも戻す。
    ///
    /// 戻すのは、予約の側にも同じ項目があるもの（時刻・出発地や到着地・宿などの名前）。
    /// 費用は `syncReservationCost` が戻す
    mutating func syncReservation(fromScheduleItem item: ScheduleItem) {
        guard let reservationId = item.reservationId,
              let index = reservations.firstIndex(where: { $0.id == reservationId }) else { return }
        var reservation = reservations[index]

        let linked = Self.withParts(scheduleItems(forReservation: reservationId), kind: reservation.kind)
        guard let part = linked.first(where: { $0.item.id == item.id })?.part else { return }

        switch part {
        case .main:
            // 宿やレストランは、行程の名前と予約の名前が同じもの
            let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty { reservation.title = title }
            reservation.location = Self.location(of: item, keepingAddressOf: reservation.location)
            reservation.note = reservation.memo(fromItineraryNotes: item.notes)
            // チェックインをずらしたら、チェックアウトも同じだけずらす（泊数を変えない）
            if let oldDate = reservation.date, let endDate = reservation.endDate {
                reservation.endDate = endDate.addingTimeInterval(item.time.timeIntervalSince(oldDate))
            }
            reservation.date = item.time
            reservation.timeZoneIdentifier = item.timeZoneIdentifier
        case .departure:
            reservation.date = item.time
            reservation.timeZoneIdentifier = item.timeZoneIdentifier
            if let location = item.location, !location.isEmpty { reservation.departurePlace = location }
            reservation.departureLocation = Self.location(of: item, keepingAddressOf: reservation.departureLocation)
            // 予約番号とメモは出発の予定に入っている
            reservation.note = reservation.memo(fromItineraryNotes: item.notes)
        case .arrival:
            reservation.arrivalDate = item.time
            reservation.arrivalTimeZoneIdentifier = item.timeZoneIdentifier
            if let location = item.location, !location.isEmpty { reservation.arrivalPlace = location }
            reservation.arrivalLocation = Self.location(of: item, keepingAddressOf: reservation.arrivalLocation)
        case .end:
            // チェックアウト・返却の時刻だけ戻す（名前と場所は始まりの予定が持つ）
            reservation.endDate = item.time
        }
        // 飛行機・新幹線の行程の名前（「ANA123 出発」）は、自由に書き換えられるよう予約へは戻さない
        reservations[index] = reservation
    }

    /// 日程タブで予約から作った予定を直したときの、ひと通りの反映。
    ///
    /// 予約に戻し（時刻・場所・名前・メモ・費用）、予約が変わったら同じ予約のほかの予定にも広げる。
    /// たとえばチェックインを1日ずらすと、チェックアウトの予定も1日ずれる
    mutating func syncReservationFromItinerary(editedItem: ScheduleItem, reservationId: String) {
        let before = reservations.first { $0.id == reservationId }
        syncReservation(fromScheduleItem: editedItem)
        syncReservationCost(fromScheduleItemsOf: reservationId)
        guard let before, let after = reservations.first(where: { $0.id == reservationId }), after != before else { return }
        syncScheduleItems(for: after, previous: before, isOn: true)
    }

    // MARK: - 中身

    /// 行程の予定の場所を、予約の場所の形にする。名前が無ければ nil。
    /// 行程の予定は住所を持たないので、同じ場所のままなら予約の住所を残す
    static func location(of item: ScheduleItem, keepingAddressOf old: ReservationLocation?) -> ReservationLocation? {
        guard let name = item.location?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { return nil }
        let sameplace = old?.name == name && old?.latitude == item.latitude && old?.longitude == item.longitude
        return ReservationLocation(name: name, address: sameplace ? old?.address : nil,
                                   latitude: item.latitude, longitude: item.longitude)
    }

    /// 予約から作った予定に、どの部分かを付ける。
    /// 2.9 より前の予定は部分を持たないので、時刻の順で当てる（飛行機は早いほうが出発）
    static func withParts(_ items: [ScheduleItem], kind: Reservation.Kind) -> [(part: ReservationPart, item: ScheduleItem)] {
        let sorted = items.sorted { $0.time < $1.time }
        return sorted.enumerated().map { index, item in
            if let part = item.reservationPart.flatMap(ReservationPart.init(rawValue:)) {
                return (part, item)
            }
            // 2.9 より前は、宿などは始まりの1件だけ、飛行機は早いほうが出発だった
            guard kind.usesRoute else { return (index == 0 ? .main : .end, item) }
            return (index == 0 ? .departure : .arrival, item)
        }
    }

    /// 行程にある予定に、直した予約の内容を重ねる
    static func merge(current: ScheduleItem, fresh: ScheduleItem, previouslyGenerated: ScheduleItem?) -> ScheduleItem {
        var item = current
        item.reservationPart = fresh.reservationPart
        item.time = fresh.time
        item.timeZoneIdentifier = fresh.timeZoneIdentifier

        // 名前とメモ：行程の側で書き換えていなければ、予約に合わせる。
        // 前の予約から作られたはずのものと同じなら「書き換えていない」とみなす。
        // 前の予約が分からないときは、名前は予約に合わせ、メモは消えると困るので空でなければ残す
        let titleUntouched = previouslyGenerated.map { $0.title == current.title } ?? true
        if titleUntouched { item.title = fresh.title }
        let notesUntouched = previouslyGenerated.map { $0.notes == current.notes } ?? (current.notes == nil || current.notes == fresh.notes)
        if notesUntouched { item.notes = fresh.notes }

        // 場所：行程の側で選び直していなければ、予約の場所（地図で選んだ位置ごと）に合わせる。
        // 前の予約が分からないときは、地図で選んだ座標があれば残す
        let locationUntouched: Bool
        if let previouslyGenerated {
            locationUntouched = previouslyGenerated.location == current.location
                && previouslyGenerated.latitude == current.latitude
                && previouslyGenerated.longitude == current.longitude
        } else {
            locationUntouched = current.latitude == nil || current.longitude == nil
        }
        if locationUntouched {
            item.location = fresh.location ?? current.location
            item.latitude = fresh.latitude ?? (fresh.location == nil ? current.latitude : nil)
            item.longitude = fresh.longitude ?? (fresh.location == nil ? current.longitude : nil)
        }

        // 費用は予約に合わせる（予約の費用は、行程の予定の金額の合計なので2重にはならない）。
        // 実績の金額は予約に無いので、行程の側のものを残す
        item.cost = fresh.cost
        let actualForeign = current.foreignCost?.actualAmount
        item.foreignCost = fresh.foreignCost
        if item.foreignCost != nil {
            item.foreignCost?.actualAmount = actualForeign
            item.actualCost = item.foreignCost?.yenActualAmount ?? current.actualCost
        }
        return item
    }
}
