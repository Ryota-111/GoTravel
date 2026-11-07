import Testing
import Foundation
@testable import GoTravel

/// 予約と行程の同期。どちらで直しても、前に入れた情報は残したまま直したところだけがそろう
struct ReservationItinerarySyncTests {

    private let tokyo = TimeZone(identifier: "Asia/Tokyo")!

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        ScheduleClock.calendar(in: tokyo).date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    /// 10/6〜10/8 の3日間
    private func plan() -> TravelPlan {
        var plan = TravelPlan(title: "沖縄", startDate: date(6, 0), endDate: date(8, 0), destination: "沖縄")
        plan.daySchedules = (1...3).map { DaySchedule(dayNumber: $0, date: date(5 + $0, 0), scheduleItems: []) }
        return plan
    }

    /// 行程の予定を書き換える（日程タブで直したのと同じ）
    private func editItem(in plan: inout TravelPlan, id: String, _ change: (inout ScheduleItem) -> Void) {
        for day in plan.daySchedules.indices {
            for index in plan.daySchedules[day].scheduleItems.indices where plan.daySchedules[day].scheduleItems[index].id == id {
                change(&plan.daySchedules[day].scheduleItems[index])
            }
        }
    }

    private func hotel(title: String = "ホテル海風", checkIn: Date? = nil) -> Reservation {
        Reservation(kind: .hotel, title: title, date: checkIn ?? date(6, 15), confirmationNumber: "H123",
                    timeZoneIdentifier: tokyo.identifier, endDate: date(8, 10))
    }

    @Test("予約を直して保存しても、日程タブで入れた場所・メモ・参加する人・固定は消えない（ご報告の不具合）")
    func reservationEditKeepsItineraryEdits() {
        var trip = plan()
        let original = hotel()
        trip.reservations = [original]
        trip.syncScheduleItems(for: original, isOn: true)
        let itemId = trip.scheduleItems(forReservation: original.id)[0].id

        editItem(in: &trip, id: itemId) {
            $0.location = "ホテル海風 本館"
            $0.latitude = 26.2
            $0.longitude = 127.7
            $0.notes = "駐車場は裏手。1泊1,000円"
            $0.participantIds = ["user-a"]
            $0.isPinned = true
        }

        var edited = original
        edited.confirmationNumber = "H999"
        edited.cost = 30000
        trip.reservations = [edited]
        trip.syncScheduleItems(for: edited, previous: original, isOn: true)

        let items = trip.scheduleItems(forReservation: original.id)
        #expect(items.count == 2)                            // チェックインとチェックアウト
        #expect(items[0].id == itemId)                       // 作り直さず同じ予定のまま
        #expect(items[0].location == "ホテル海風 本館")
        #expect(items[0].latitude == 26.2)
        #expect(items[0].notes == "駐車場は裏手。1泊1,000円")  // 書き換えたメモは残す
        #expect(items[0].participantIds == ["user-a"])
        #expect(items[0].isPinned == true)
        #expect(items[0].cost == 30000)                      // 費用は予約に合わせる
    }

    @Test("行程で書き換えていない名前とメモは、予約に合わせて変わる")
    func untouchedTitleAndNotesFollowReservation() {
        var trip = plan()
        let original = hotel()
        trip.reservations = [original]
        trip.syncScheduleItems(for: original, isOn: true)

        var edited = original
        edited.title = "ホテル海風 那覇"
        edited.confirmationNumber = "H999"
        edited.date = date(6, 16)
        trip.reservations = [edited]
        trip.syncScheduleItems(for: edited, previous: original, isOn: true)

        let item = trip.scheduleItems(forReservation: original.id)[0]
        #expect(item.title == "ホテル海風 那覇")
        #expect(item.notes == "予約番号 H999")
        #expect(item.time == date(6, 16))
    }

    @Test("行程で付けた名前は、予約を直しても残る（行程に出す名前を変えられる）")
    func customTitleIsKept() {
        var trip = plan()
        let flight = Reservation(kind: .flight, date: date(6, 10), transportNumber: "NH991",
                                 departurePlace: "羽田空港", arrivalPlace: "那覇空港", arrivalDate: date(6, 13),
                                 timeZoneIdentifier: tokyo.identifier, arrivalTimeZoneIdentifier: tokyo.identifier)
        trip.reservations = [flight]
        trip.syncScheduleItems(for: flight, isOn: true)
        let departure = trip.scheduleItems(forReservation: flight.id)[0]
        editItem(in: &trip, id: departure.id) { $0.title = "羽田→那覇（ANA）" }

        var edited = flight
        edited.date = date(6, 11)
        trip.reservations = [edited]
        trip.syncScheduleItems(for: edited, previous: flight, isOn: true)

        let items = trip.scheduleItems(forReservation: flight.id)
        #expect(items.map(\.title) == ["羽田→那覇（ANA）", "NH991 到着"])
        #expect(items[0].time == date(6, 11))
        #expect(items.map(\.id).first == departure.id)
    }

    @Test("2.9 より前に作った予定（部分の印が無い）も、時刻の順で出発・到着に当てて残す")
    func legacyItemsWithoutPartAreMatchedByOrder() {
        var trip = plan()
        let flight = Reservation(kind: .flight, date: date(6, 10), transportNumber: "NH991",
                                 departurePlace: "羽田空港", arrivalPlace: "那覇空港", arrivalDate: date(6, 13),
                                 timeZoneIdentifier: tokyo.identifier, arrivalTimeZoneIdentifier: tokyo.identifier)
        trip.reservations = [flight]
        trip.syncScheduleItems(for: flight, isOn: true)
        for item in trip.scheduleItems(forReservation: flight.id) {
            editItem(in: &trip, id: item.id) { $0.reservationPart = nil; $0.notes = $0.notes ?? "到着ロビーで集合" }
        }

        var edited = flight
        edited.arrivalDate = date(6, 13, 30)
        trip.reservations = [edited]
        trip.syncScheduleItems(for: edited, previous: flight, isOn: true)

        let items = trip.scheduleItems(forReservation: flight.id)
        #expect(items.count == 2)
        #expect(items[1].time == date(6, 13, 30))
        #expect(items[1].notes == "到着ロビーで集合")
        #expect(items.map(\.reservationPart) == ["departure", "arrival"])
    }

    @Test("行程で宿の名前と時刻を直すと、予約にも戻る。チェックアウトも同じだけずれる")
    func itineraryEditFlowsBackToHotelReservation() {
        var trip = plan()
        let original = hotel()
        trip.reservations = [original]
        trip.syncScheduleItems(for: original, isOn: true)
        var item = trip.scheduleItems(forReservation: original.id)[0]
        item.title = "海風ホテル"
        item.time = date(6, 17)
        editItem(in: &trip, id: item.id) { $0 = item }

        trip.syncReservation(fromScheduleItem: item)

        #expect(trip.reservations[0].title == "海風ホテル")
        #expect(trip.reservations[0].date == date(6, 17))
        #expect(trip.reservations[0].endDate == date(8, 12))   // 2時間遅らせたぶん、チェックアウトも2時間
    }

    @Test("行程で飛行機の到着の時刻と場所を直すと、予約の到着にも戻る。名前は戻さない")
    func itineraryEditFlowsBackToFlightArrival() {
        var trip = plan()
        let flight = Reservation(kind: .flight, date: date(6, 10), transportNumber: "NH991",
                                 departurePlace: "羽田空港", arrivalPlace: "那覇空港", arrivalDate: date(6, 13),
                                 timeZoneIdentifier: tokyo.identifier, arrivalTimeZoneIdentifier: tokyo.identifier)
        trip.reservations = [flight]
        trip.syncScheduleItems(for: flight, isOn: true)
        var arrival = trip.scheduleItems(forReservation: flight.id)[1]
        arrival.time = date(6, 13, 20)
        arrival.location = "那覇空港 国内線ターミナル"
        arrival.title = "那覇に着く"
        editItem(in: &trip, id: arrival.id) { $0 = arrival }

        trip.syncReservation(fromScheduleItem: arrival)

        #expect(trip.reservations[0].arrivalDate == date(6, 13, 20))
        #expect(trip.reservations[0].arrivalPlace == "那覇空港 国内線ターミナル")
        #expect(trip.reservations[0].date == date(6, 10))
        #expect(trip.reservations[0].transportNumber == "NH991")
    }

    @Test("行程にも追加するをオフにすると、その予約から作った予定だけ消える")
    func turningOffRemovesOnlyLinkedItems() {
        var trip = plan()
        let original = hotel()
        trip.reservations = [original]
        trip.daySchedules[0].scheduleItems = [ScheduleItem(time: date(6, 12), title: "昼食")]
        trip.syncScheduleItems(for: original, isOn: true)

        trip.syncScheduleItems(for: original, previous: original, isOn: false)

        #expect(trip.scheduleItems(forReservation: original.id).isEmpty)
        #expect(trip.daySchedules[0].scheduleItems.map(\.title) == ["昼食"])
    }
}

// MARK: - 予約の場所とメモ

extension ReservationItinerarySyncTests {

    private var portHotel: ReservationLocation {
        ReservationLocation(name: "ホテル海風", address: "沖縄県那覇市1-1", latitude: 26.21, longitude: 127.68)
    }

    @Test("予約の場所（地図の位置）とメモが、行程の予定にそのまま入る")
    func reservationPlaceAndMemoGoToItinerary() {
        var trip = plan()
        var stay = hotel()
        stay.location = portHotel
        stay.note = "駐車場は裏手\n1泊1,000円"
        trip.reservations = [stay]
        trip.syncScheduleItems(for: stay, isOn: true)

        let item = trip.scheduleItems(forReservation: stay.id)[0]
        #expect(item.location == "ホテル海風")
        #expect(item.latitude == 26.21)
        #expect(item.longitude == 127.68)
        #expect(item.notes == "予約番号 H123\n駐車場は裏手\n1泊1,000円")
    }

    @Test("予約で場所を選び直すと、行程の場所も変わる。行程で選び直した場所は残す")
    func reservationPlaceChangeFollowsUnlessCustomized() {
        var trip = plan()
        var stay = hotel()
        stay.location = portHotel
        trip.reservations = [stay]
        trip.syncScheduleItems(for: stay, isOn: true)

        var moved = stay
        moved.location = ReservationLocation(name: "ホテル海風 新館", address: nil, latitude: 26.30, longitude: 127.70)
        trip.reservations = [moved]
        trip.syncScheduleItems(for: moved, previous: stay, isOn: true)
        #expect(trip.scheduleItems(forReservation: stay.id)[0].location == "ホテル海風 新館")
        #expect(trip.scheduleItems(forReservation: stay.id)[0].latitude == 26.30)

        // 行程の側で駐車場に選び直したら、予約を直しても残す
        let itemId = trip.scheduleItems(forReservation: stay.id)[0].id
        editItem(in: &trip, id: itemId) {
            $0.location = "海風パーキング"
            $0.latitude = 26.31
            $0.longitude = 127.71
        }
        var renamed = moved
        renamed.title = "海風ホテル"
        trip.reservations = [renamed]
        trip.syncScheduleItems(for: renamed, previous: moved, isOn: true)
        #expect(trip.scheduleItems(forReservation: stay.id)[0].location == "海風パーキング")
    }

    @Test("行程で場所とメモを直すと、予約にも戻る（予約番号の行はメモに入れない）")
    func itineraryPlaceAndMemoFlowBack() {
        var trip = plan()
        var stay = hotel()
        stay.location = portHotel
        trip.reservations = [stay]
        trip.syncScheduleItems(for: stay, isOn: true)
        var item = trip.scheduleItems(forReservation: stay.id)[0]
        item.notes = "予約番号 H123\nチェックインは16時から"
        editItem(in: &trip, id: item.id) { $0 = item }

        trip.syncReservation(fromScheduleItem: item)
        #expect(trip.reservations[0].note == "チェックインは16時から")
        #expect(trip.reservations[0].location == portHotel)        // 同じ場所のままなら住所も残る

        item.location = "海風パーキング"
        item.latitude = 26.31
        item.longitude = 127.71
        item.address = nil          // 長押しのピンで選んだ場所は住所を持たない（編集画面も住所を差し替える）
        editItem(in: &trip, id: item.id) { $0 = item }
        trip.syncReservation(fromScheduleItem: item)
        #expect(trip.reservations[0].location?.name == "海風パーキング")
        #expect(trip.reservations[0].location?.latitude == 26.31)
        #expect(trip.reservations[0].location?.address == nil)
    }

    @Test("飛行機の出発地・到着地を地図で選んでいれば、行程の出発・到着の予定に位置が入る")
    func flightPlacesGoToItinerary() {
        var trip = plan()
        var flight = Reservation(kind: .flight, date: date(6, 10), transportNumber: "NH991",
                                 departurePlace: "羽田空港 第2ターミナル", arrivalPlace: "那覇空港",
                                 arrivalDate: date(6, 13),
                                 timeZoneIdentifier: tokyo.identifier, arrivalTimeZoneIdentifier: tokyo.identifier)
        flight.departureLocation = ReservationLocation(name: "羽田空港 第2ターミナル", latitude: 35.55, longitude: 139.79)
        flight.arrivalLocation = ReservationLocation(name: "那覇空港", latitude: 26.20, longitude: 127.65)
        trip.reservations = [flight]
        trip.syncScheduleItems(for: flight, isOn: true)

        let items = trip.scheduleItems(forReservation: flight.id)
        #expect(items[0].latitude == 35.55)
        #expect(items[1].latitude == 26.20)
        #expect(items[1].location == "那覇空港")
    }
}

// MARK: - 2日以上の予約

extension ReservationItinerarySyncTests {

    @Test("2泊の宿は、チェックインの日とチェックアウトの日の両方に予定が入る（ご報告の不具合）")
    func multiDayStayAddsCheckoutItem() {
        var trip = plan()
        let stay = hotel()          // 10/6 15:00 〜 10/8 10:00
        trip.reservations = [stay]
        trip.syncScheduleItems(for: stay, isOn: true)

        #expect(trip.daySchedules[0].scheduleItems.map(\.title) == ["ホテル海風"])
        #expect(trip.daySchedules[2].scheduleItems.map(\.title) == ["ホテル海風 チェックアウト"])
        #expect(trip.daySchedules[2].scheduleItems.first?.cost == nil)   // 費用はチェックインの予定だけ
    }

    @Test("レンタカーは返却の日に「返却」が入る")
    func rentalCarAddsReturnItem() {
        var trip = plan()
        let car = Reservation(kind: .rentalCar, title: "OTSレンタカー", date: date(6, 9),
                              timeZoneIdentifier: tokyo.identifier, endDate: date(7, 18))
        trip.reservations = [car]
        trip.syncScheduleItems(for: car, isOn: true)
        #expect(trip.daySchedules[1].scheduleItems.map(\.title) == ["OTSレンタカー 返却"])
    }

    @Test("日程タブでチェックインを1日ずらすと、予約とチェックアウトの予定も1日ずれる")
    func movingCheckInShiftsCheckout() {
        var trip = plan()
        let stay = Reservation(kind: .hotel, title: "ホテル海風", date: date(6, 15), confirmationNumber: "H123",
                               timeZoneIdentifier: tokyo.identifier, endDate: date(7, 10))
        trip.reservations = [stay]
        trip.syncScheduleItems(for: stay, isOn: true)
        var checkIn = trip.scheduleItems(forReservation: stay.id)[0]
        checkIn.time = date(7, 15)
        editItem(in: &trip, id: checkIn.id) { $0 = checkIn }

        trip.syncReservationFromItinerary(editedItem: checkIn, reservationId: stay.id)

        #expect(trip.reservations[0].endDate == date(8, 10))
        let items = trip.scheduleItems(forReservation: stay.id)
        #expect(items.map(\.time) == [date(7, 15), date(8, 10)])
        #expect(trip.daySchedules[2].scheduleItems.map(\.title) == ["ホテル海風 チェックアウト"])
    }

    @Test("日程タブでチェックアウトの時刻を直すと、予約のチェックアウトに戻る")
    func editingCheckoutFlowsBack() {
        var trip = plan()
        let stay = hotel()
        trip.reservations = [stay]
        trip.syncScheduleItems(for: stay, isOn: true)
        var checkout = trip.scheduleItems(forReservation: stay.id)[1]
        checkout.time = date(8, 11)
        editItem(in: &trip, id: checkout.id) { $0 = checkout }

        trip.syncReservationFromItinerary(editedItem: checkout, reservationId: stay.id)
        #expect(trip.reservations[0].endDate == date(8, 11))
        #expect(trip.reservations[0].date == date(6, 15))
    }
}

// MARK: - 乗り物の予約と行程の「移動」（3.4）

extension ReservationItinerarySyncTests {

    private func nh991() -> Reservation {
        var flight = Reservation(kind: .flight, date: date(6, 10), confirmationNumber: "QX7Y2Z", transportNumber: "NH991",
                                 departurePlace: "羽田空港", arrivalPlace: "那覇空港", arrivalDate: date(6, 13),
                                 seat: "12A", terminal: "第2",
                                 timeZoneIdentifier: tokyo.identifier, arrivalTimeZoneIdentifier: tokyo.identifier)
        flight.departureLocation = ReservationLocation(name: "羽田空港", latitude: 35.55, longitude: 139.79)
        flight.arrivalLocation = ReservationLocation(name: "那覇空港", latitude: 26.20, longitude: 127.65)
        return flight
    }

    @Test("飛行機の予約は今までどおり出発と到着の2件。出発にだけ便・座席・のりばを添え、到着は時刻と場所だけ")
    func flightLegsCarryTransport() {
        var trip = plan()
        let flight = nh991()
        trip.reservations = [flight]
        trip.syncScheduleItems(for: flight, isOn: true)

        let items = trip.scheduleItems(forReservation: flight.id)
        #expect(items.map(\.title) == ["NH991 出発", "NH991 到着"])
        #expect(items.map(\.location) == ["羽田空港", "那覇空港"])
        #expect(items.map(\.latitude) == [35.55, 26.20])          // ピンは出発地と到着地の両方
        #expect(items[0].isRouteLeg && !items[0].isSingleMove)
        #expect(items.allSatisfy { $0.endTime == nil })
        #expect(items[0].move?.transportMode == .plane)
        #expect(items[0].move?.detailText == "NH991 · 第2 · 座席 12A")
        #expect(items[1].move == nil)
    }

    @Test("予約で便や座席を直すと、出発の添え書きが変わる。到着には付かない")
    func legsFollowReservation() {
        var trip = plan()
        let flight = nh991()
        trip.reservations = [flight]
        trip.syncScheduleItems(for: flight, isOn: true)
        var edited = flight
        edited.seat = "14K"
        edited.kind = .bus
        trip.reservations = [edited]
        trip.syncScheduleItems(for: edited, previous: flight, isOn: true)

        let items = trip.scheduleItems(forReservation: flight.id)
        #expect(items.count == 2)
        #expect(items[0].move?.seat == "14K")
        #expect(items[0].move?.transportMode == .bus)
        #expect(items[1].move == nil)
    }

    @Test("3.3 までの添え書きの無い出発も、予約を直すと便・座席が付く。行程で入れたものは残る")
    func legacyLegsGainTransport() {
        var trip = plan()
        let flight = nh991()
        trip.reservations = [flight]
        trip.syncScheduleItems(for: flight, isOn: true)
        for item in trip.scheduleItems(forReservation: flight.id) {
            editItem(in: &trip, id: item.id) { $0.move = nil }
        }
        let departure = trip.scheduleItems(forReservation: flight.id)[0]
        editItem(in: &trip, id: departure.id) { $0.participantIds = ["u1"] }

        trip.syncScheduleItems(for: flight, previous: flight, isOn: true)
        let items = trip.scheduleItems(forReservation: flight.id)
        #expect(items[0].move?.line == "NH991")
        #expect(items[1].move == nil)
        #expect(items[0].participantIds == ["u1"])
    }

    // MARK: 行程の移動 → 予約

    private func busMove() -> ScheduleItem {
        var item = ScheduleItem(id: "m", time: date(6, 9), title: "", notes: "前の方の席がいい", cost: 230,
                                timeZoneIdentifier: tokyo.identifier, endTime: date(6, 9, 40))
        item.apply(move: ScheduleMove(mode: .bus, line: "市バス 206系統", platform: "D2のりば",
                                      from: MovePlace(name: "京都駅", latitude: 34.98, longitude: 135.75),
                                      to: MovePlace(name: "清水道", latitude: 34.99, longitude: 135.77)), title: "")
        return item
    }

    @Test("移動に予約番号を入れると予約として残り、その予定が出発になって到着が足される（同じものを2つ作らない）")
    func moveBecomesReservation() throws {
        var trip = plan()
        trip.daySchedules[0].scheduleItems = [busMove()]

        let made = trip.makeReservation(fromMoveItemID: "m", confirmationNumber: " B-778 ")
        let id = try #require(made)
        let reservation = try #require(trip.reservations.first { $0.id == id })
        #expect(reservation.kind == .bus)
        #expect(reservation.confirmationNumber == "B-778")
        #expect(reservation.transportNumber == "市バス 206系統")
        #expect(reservation.terminal == "D2のりば")
        #expect(reservation.departurePlace == "京都駅")
        #expect(reservation.arrivalPlace == "清水道")
        #expect(reservation.arrivalDate == date(6, 9, 40))
        #expect(reservation.cost == 230)
        #expect(reservation.note == "前の方の席がいい")

        let items = trip.scheduleItems(forReservation: id)
        #expect(items.count == 2)
        #expect(items[0].id == "m")
        #expect(items.map(\.title) == ["市バス 206系統 出発", "市バス 206系統 到着"])
        #expect(items.map(\.location) == ["京都駅", "清水道"])
        #expect(items[0].endTime == nil)
        #expect(items[0].notes == "予約番号 B-778\n前の方の席がいい")
        #expect(items.map(\.cost) == [230, nil])
        #expect(trip.daySchedules.flatMap(\.scheduleItems).count == 2)
    }

    @Test("自分で名前を付けた移動は、予約にしても出発の名前が残る")
    func moveCustomTitleKept() {
        var trip = plan()
        var item = busMove()
        item.title = "清水寺へ"
        trip.daySchedules[0].scheduleItems = [item]
        let id = trip.makeReservation(fromMoveItemID: "m", confirmationNumber: "Z9")!
        #expect(trip.scheduleItems(forReservation: id).first?.title == "清水寺へ")
    }

    @Test("車・タクシー・徒歩、時間未定、すでにつながった移動は予約にしない")
    func moveWithoutReservation() {
        var trip = plan()
        var car = busMove()
        car.move?.mode = TransportMode.car.rawValue
        var undecided = busMove()
        undecided.id = "u"
        undecided.isTimeUndecided = true
        trip.daySchedules[0].scheduleItems = [car, undecided]
        #expect(trip.makeReservation(fromMoveItemID: "m", confirmationNumber: "X") == nil)
        #expect(trip.makeReservation(fromMoveItemID: "u", confirmationNumber: "X") == nil)
        #expect(trip.reservations.isEmpty)
    }

    @Test("つないだ予約の予約番号を行程から直すと、予約とメモの行がそろう")
    func editConfirmationFromItinerary() throws {
        var trip = plan()
        trip.daySchedules[0].scheduleItems = [busMove()]
        let made = trip.makeReservation(fromMoveItemID: "m", confirmationNumber: "B-778")
        let id = try #require(made)
        trip.setConfirmationNumber("B-779", forReservation: id)
        #expect(trip.reservations[0].confirmationNumber == "B-779")
        #expect(trip.scheduleItems(forReservation: id).first?.notes == "予約番号 B-779\n前の方の席がいい")
    }

    @Test("予約の画面で行程の宿の予定を選んで保存すると、その予定をつなぐ（新しく作らない）")
    func linkPickedItem() {
        var trip = plan()
        let picked = ScheduleItem(id: "h", time: date(6, 15), title: "ホテル海風", notes: "朝食付き",
                                  timeZoneIdentifier: tokyo.identifier)
        trip.daySchedules[0].scheduleItems = [picked]
        let hotel = Reservation(kind: .hotel, title: "ホテル海風", date: date(6, 15), confirmationNumber: "H1",
                                note: "朝食付き", timeZoneIdentifier: tokyo.identifier)
        trip.reservations = [hotel]

        trip.link(scheduleItemID: "h", to: hotel)
        trip.syncScheduleItems(for: hotel, isOn: true)

        let items = trip.daySchedules.flatMap(\.scheduleItems)
        #expect(items.count == 1)
        #expect(items[0].id == "h")
        #expect(items[0].reservationId == hotel.id)
        #expect(items[0].notes == "予約番号 H1\n朝食付き")
    }

    @Test("到着に添え書きの付いた予定（開発中の版で作ったもの）は、直すと外れる")
    func arrivalLosesTransport() {
        var trip = plan()
        let flight = nh991()
        trip.reservations = [flight]
        trip.syncScheduleItems(for: flight, isOn: true)
        let arrival = trip.scheduleItems(forReservation: flight.id)[1]
        editItem(in: &trip, id: arrival.id) { $0.move = flight.scheduleMove }
        trip.syncScheduleItems(for: flight, previous: flight, isOn: true)
        #expect(trip.scheduleItems(forReservation: flight.id)[1].move == nil)
    }

    @Test("移動の1件の予定（予約の移動の印）は、出発の予定として引き継ぐ")
    func singleMovePartBecomesDeparture() {
        var trip = plan()
        let flight = nh991()
        var item = busMove()
        item.reservationId = flight.id
        item.reservationPart = ReservationPart.move.rawValue
        trip.daySchedules[0].scheduleItems = [item]
        trip.reservations = [flight]

        trip.syncScheduleItems(for: flight, isOn: true)
        let items = trip.scheduleItems(forReservation: flight.id)
        #expect(items.map(\.reservationPart) == ["departure", "arrival"])
        #expect(items[0].id == "m")
        #expect(items[0].endTime == nil)
    }
}
