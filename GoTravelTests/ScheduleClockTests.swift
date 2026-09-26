import Testing
import Foundation
@testable import GoTravel

/// 予定の時刻を、予定ごとの時計で読めているか。
///
/// **ここが壊れると、海外に着いた瞬間に予定の時刻がずれる。**
/// 端末の時間帯はテストの実行環境で変わるので、見ている人の時計は
/// 引数で渡し、`TimeZone.current` に頼らずに確かめる
struct ScheduleClockTests {

    private let tokyo = TimeZone(identifier: "Asia/Tokyo")!
    private let paris = TimeZone(identifier: "Europe/Paris")!
    private let honolulu = TimeZone(identifier: "Pacific/Honolulu")!
    private let seoul = TimeZone(identifier: "Asia/Seoul")!

    /// その時計での 2026/10/10 hh:mm
    private func date(_ hour: Int, _ minute: Int = 0, in zone: TimeZone) -> Date {
        ScheduleClock.calendar(in: zone).date(
            from: DateComponents(year: 2026, month: 10, day: 10, hour: hour, minute: minute)
        )!
    }

    private func item(_ hour: Int, _ minute: Int = 0, in zone: TimeZone?, title: String = "予定") -> ScheduleItem {
        ScheduleItem(time: date(hour, minute, in: zone ?? tokyo),
                     title: title,
                     timeZoneIdentifier: zone?.identifier)
    }

    // MARK: - 表示

    @Test("時間帯を持たない予定は、日本時間で読む")
    func legacyItemsReadInJapanTime() {
        let legacy = item(15, in: nil)

        #expect(legacy.timeZone.identifier == "Asia/Tokyo")
        #expect(legacy.timeText == "15:00")
    }

    /// 報告のあった症状そのもの。端末がどこにあっても入れたとおりに出る
    @Test("現地時間で入れた予定は、現地の時刻のまま出る")
    func localItemKeepsItsClock() {
        let dinner = item(19, 30, in: paris)

        #expect(dinner.timeText == "19:30")
        #expect(dinner.minutesOfDay == 19 * 60 + 30)
    }

    @Test("時間帯を持たない JSON もそのまま読める")
    func decodesOldJSON() throws {
        let json = #"{"id":"a","time":"2026-10-10T06:00:00Z","title":"朝食"}"#
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decoded = try decoder.decode(ScheduleItem.self, from: Data(json.utf8))

        #expect(decoded.timeZoneIdentifier == nil)
        #expect(decoded.timeText == "15:00")   // 06:00Z = 日本の 15:00
    }

    // MARK: - 付け替え

    @Test("時間帯を付け替えても、時:分は変わらない")
    func keepingWallClockKeepsTime() {
        let converted = item(15, in: tokyo).keepingWallClock(in: paris)

        #expect(converted.timeText == "15:00")
        #expect(converted.timeZoneIdentifier == "Europe/Paris")
        // 実際の時刻はパリの 15:00 になる（日本の 15:00 より後）
        #expect(converted.time > date(15, in: tokyo))
    }

    @Test("計画まるごと現地時間にそろえると、残りが0件になる")
    func convertsWholePlan() {
        var plan = TravelPlan(title: "パリ", startDate: date(0, in: tokyo), endDate: date(0, in: tokyo),
                              destination: "パリ")
        plan.daySchedules = [DaySchedule(dayNumber: 1, date: date(0, in: tokyo), scheduleItems: [
            item(9, in: nil, title: "美術館"),
            item(19, in: paris, title: "夕食")
        ])]

        #expect(plan.scheduleItemCount(notIn: paris) == 1)

        let converted = plan.withScheduleTimes(keptIn: paris)
        let items = converted.daySchedules[0].scheduleItems

        #expect(converted.scheduleItemCount(notIn: paris) == 0)
        #expect(items.map(\.timeText) == ["09:00", "19:00"])
    }

    // MARK: - 並び順

    /// 日付変更線をまたぐ便。時:分だけで並べると、到着が出発より前に来る
    @Test("時間帯が違っても、実際に起きる順に並ぶ")
    func sortsChronologicallyAcrossZones() {
        let departure = item(22, in: tokyo, title: "羽田を出発")      // 13:00Z
        let arrival = item(10, in: honolulu, title: "ホノルル到着")   // 20:00Z

        let sorted = [arrival, departure].sorted(by: ScheduleItem.chronologically)

        #expect(sorted.map(\.title) == ["羽田を出発", "ホノルル到着"])
    }

    @Test("同じ時間帯どうしは、時:分の順に並ぶ")
    func sortsByClockWithinZone() {
        let items = [item(18, in: nil, title: "夕食"), item(8, in: nil, title: "朝食")]

        #expect(items.sorted(by: ScheduleItem.chronologically).map(\.title) == ["朝食", "夕食"])
    }

    // MARK: - 印

    @Test("日本で見ると、現地の予定に「現地」が付く")
    func labelsLocalItemsWhenViewedFromJapan() {
        #expect(item(19, in: paris).zoneLabel(destination: paris, viewer: tokyo) == "現地")
        #expect(item(9, in: nil).zoneLabel(destination: paris, viewer: tokyo) == nil)
    }

    @Test("現地で見ると、日本時間の予定に「日本」が付く")
    func labelsJapanItemsWhenViewedAbroad() {
        #expect(item(9, in: nil).zoneLabel(destination: paris, viewer: paris) == "日本")
        #expect(item(19, in: paris).zoneLabel(destination: paris, viewer: paris) == nil)
    }

    // MARK: - 予約

    private func flight() -> Reservation {
        Reservation(kind: .flight,
                    title: "AF275",
                    date: date(10, in: tokyo),
                    transportNumber: "AF275",
                    departurePlace: "羽田空港",
                    arrivalPlace: "パリ",
                    arrivalDate: date(16, in: paris),
                    timeZoneIdentifier: tokyo.identifier,
                    arrivalTimeZoneIdentifier: paris.identifier)
    }

    @Test("行程に入れると、出発は日本の時計・到着は現地の時計になる")
    func itineraryCarriesEachClock() {
        let items = flight().itineraryItems()

        #expect(items.map(\.timeText) == ["10:00", "16:00"])
        #expect(items.map(\.timeZoneIdentifier) == ["Asia/Tokyo", "Europe/Paris"])
    }

    /// 以前は両方を日本の時計で入れるしかなく、10:00 → 16:00 で「6時間」と出ていた
    @Test("時差をまたぐ便の所要時間が正しい")
    func flightDurationIncludesTimeDifference() {
        let reservation = flight()
        let hours = reservation.arrivalDate!.timeIntervalSince(reservation.date!) / 3600

        #expect(hours == 13)   // 10月のパリは夏時間で日本より7時間遅い
    }

    @Test("時間帯を持たない予約の JSON もそのまま読める")
    func decodesOldReservationJSON() throws {
        let json = #"{"id":"r","kind":"hotel","title":"ホテル","date":"2026-10-10T06:00:00Z"}"#
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decoded = try decoder.decode(Reservation.self, from: Data(json.utf8))

        #expect(decoded.timeZoneIdentifier == nil)
        #expect(decoded.dateTimeZone.identifier == "Asia/Tokyo")
    }

    /// パリの夜 23:00 は、日本ではもう翌朝。日本の暦で置くと1日ずれる
    @Test("何日目かは、その予定の時計で読んだ日付で決まる")
    func dayNumberUsesItemClock() {
        let plan = TravelPlan(title: "パリ",
                              startDate: date(0, in: tokyo),
                              endDate: date(0, in: tokyo).addingTimeInterval(86_400 * 3),
                              destination: "パリ")
        let lateNight = date(23, in: paris)   // 日本では 10/11 の朝

        #expect(plan.dayNumber(forDate: lateNight, in: paris) == 1)
        #expect(plan.dayNumber(forDate: lateNight, in: tokyo) == 2)
    }

    @Test("時差の無い国は海外扱いしない")
    func sameOffsetIsNotForeign() {
        #expect(!ScheduleClock.isForeign(seoul, at: date(12, in: tokyo)))
        #expect(ScheduleClock.isForeign(paris, at: date(12, in: tokyo)))
    }
}

/// ロック画面・ホーム画面のウィジェット。
///
/// ウィジェットは端末の時計しか知らないので、アプリ側で瞬間と日付を組み立てて渡す。
/// ここが崩れると、海外にいるときだけウィジェットの予定がずれる
struct WidgetTimeZoneTests {

    private let tokyo = TimeZone(identifier: "Asia/Tokyo")!
    private let paris = TimeZone(identifier: "Europe/Paris")!

    private func date(_ day: Int, _ hour: Int, in zone: TimeZone) -> Date {
        ScheduleClock.calendar(in: zone).date(
            from: DateComponents(year: 2026, month: 10, day: day, hour: hour)
        )!
    }

    /// 10/10〜10/15 のパリ旅行。1日目の夜にパリ時間 19:00 の夕食
    private func parisTrip() -> TravelPlan {
        var plan = TravelPlan(title: "パリ",
                              startDate: date(10, 0, in: tokyo),
                              endDate: date(15, 0, in: tokyo),
                              destination: "パリ")
        plan.daySchedules = [DaySchedule(dayNumber: 1, date: date(10, 0, in: tokyo), scheduleItems: [
            ScheduleItem(time: date(10, 19, in: paris), title: "夕食", timeZoneIdentifier: paris.identifier)
        ])]
        return plan
    }

    private func snapshot() -> WidgetSnapshot {
        // 旅行の真ん中を「今」にすれば、テストを動かす端末の時計に左右されない
        WidgetSnapshotBuilder.build(travelPlans: [parisTrip()], plans: [], now: date(12, 12, in: tokyo))
    }

    @Test("予定はパリの 19:00 という瞬間で渡り、19:00 と出る")
    func itemCarriesExactInstant() throws {
        let item = try #require(snapshot().travelScheduleItems.first)

        #expect(item.occursAt == date(10, 19, in: paris))
        #expect(item.timeText == "19:00")
        #expect(item.dayKey == "2026-10-10")
    }

    /// 日本の 0:00 という瞬間で比べると、パリでは最終日が前の日の夕方に終わっていた
    @Test("パリにいても、最終日はまだ旅行中")
    func lastDayIsOngoingAbroad() {
        let lastEvening = date(15, 20, in: paris)   // 日本ではもう 10/16 の朝

        #expect(snapshot().isTravelOngoing(asOf: lastEvening, viewer: paris))
        #expect(!snapshot().isTravelOngoing(asOf: lastEvening, viewer: tokyo))
    }

    @Test("パリの今日の予定を、パリの日付で選ぶ")
    func picksTodayByViewerDate() {
        let firstEvening = date(10, 18, in: paris)

        #expect(snapshot().travelItems(on: firstEvening, viewer: paris).map(\.title) == ["夕食"])
    }
}
