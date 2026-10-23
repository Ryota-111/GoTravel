import Testing
import Foundation
@testable import GoTravel

/// 予定ごとの時間帯（3.0）。何ヶ国も回る旅行や、現地に着いてから直すときに時刻がずれないこと
struct ScheduleTimeZonesTests {

    private let japan = TimeZone(identifier: "Asia/Tokyo")!
    private let paris = TimeZone(identifier: "Europe/Paris")!
    private let london = TimeZone(identifier: "Europe/London")!
    private let losAngeles = TimeZone(identifier: "America/Los_Angeles")!
    private let seoul = TimeZone(identifier: "Asia/Seoul")!

    /// 2026年10月10日の、その時計での時:分
    private func at(_ hour: Int, _ minute: Int = 0, in zone: TimeZone) -> Date {
        var parts = DateComponents(year: 2026, month: 10, day: 10, hour: hour, minute: minute)
        parts.timeZone = zone
        return ScheduleClock.calendar(in: zone).date(from: parts)!
    }

    private func item(_ hour: Int, in zone: TimeZone, title: String = "予定", end: Int? = nil) -> ScheduleItem {
        ScheduleItem(time: at(hour, in: zone), title: title, timeZoneIdentifier: zone.identifier,
                     endTime: end.map { at($0, in: zone) })
    }

    private func plan(days: [DaySchedule]) -> TravelPlan {
        TravelPlan(title: "ヨーロッパ", startDate: at(0, in: japan),
                   endDate: at(0, in: japan).addingTimeInterval(4 * 86_400), destination: "ヨーロッパ",
                   daySchedules: days)
    }

    // MARK: - 候補

    @Test("候補は場所・日・目的地・日本の順で、時差が同じものは1つにまとめる")
    func choices() {
        let choices = ScheduleClock.zoneChoices(place: paris, day: paris, destination: london,
                                                current: japan, recents: [seoul], at: at(12, in: japan))
        #expect(choices.map(\.zone.identifier) == ["Europe/Paris", "Europe/London", "Asia/Tokyo"])
        #expect(choices.first?.source == .place)
        // ソウルは日本と時差が無いので、日本にまとまる
        #expect(!choices.contains { $0.zone.identifier == "Asia/Seoul" })
    }

    @Test("国内旅行では時間帯の選択を出さない。海外の候補があれば出す")
    func offersChoiceOnlyAbroad() {
        let domestic = ScheduleClock.zoneChoices(place: nil, day: nil, destination: nil, current: japan, at: Date())
        #expect(!ScheduleClock.offersZoneChoice(domestic, selected: japan, at: Date()))
        let abroad = ScheduleClock.zoneChoices(place: paris, day: nil, destination: nil, current: japan, at: Date())
        #expect(ScheduleClock.offersZoneChoice(abroad, selected: japan, at: Date()))
    }

    @Test("都市名は日本語で出し、知らない都市は識別子の都市部分")
    func cityNames() {
        #expect(ScheduleClock.cityName(of: paris) == "パリ")
        #expect(ScheduleClock.cityName(of: TimeZone(identifier: "America/Port_of_Spain")!) == "Port of Spain")
        #expect(ScheduleClock.choiceTitle(of: japan) == "日本時間")
    }

    @Test("都市名で探せる（日本語・英語）")
    func search() {
        #expect(ScheduleClock.searchZones("パリ").contains { $0.identifier == "Europe/Paris" })
        #expect(ScheduleClock.searchZones("london").contains { $0.identifier == "Europe/London" })
        #expect(!ScheduleClock.searchZones("").isEmpty)
    }

    // MARK: - 直す

    @Test("数字はそのまま：日本 15:00 がパリ 15:00 になり、終わりの時刻もそろう")
    func keepWallClock() {
        let converted = item(15, in: japan, end: 17).converted(to: paris, mode: .keepWallClock)
        #expect(converted.timeText == "15:00")
        #expect(converted.endTimeText == "17:00")
        #expect(converted.timeZone.identifier == "Europe/Paris")
        #expect(converted.dayShift == nil)
    }

    @Test("同じ時刻に直す：日本 15:00 はパリ 8:00（同じ日）")
    func keepMomentSameDay() {
        let converted = item(15, in: japan).converted(to: paris, mode: .keepMoment)
        #expect(converted.timeText == "08:00")
        #expect(converted.dayShift == nil)
    }

    @Test("同じ時刻に直す：日本 9:00 はロサンゼルスの前日 17:00。日はそのまま「前日」と出す")
    func keepMomentCrossesDay() {
        let converted = item(9, in: japan).converted(to: losAngeles, mode: .keepMoment)
        #expect(converted.timeText == "17:00")
        #expect(converted.dayShift == -1)
        #expect(converted.dayShiftLabel == "前日")
        #expect(converted.timeRangeText == "前日 17:00")
        // 日本に戻せば、ずれも消える
        #expect(converted.converted(to: japan, mode: .keepMoment).dayShift == nil)
    }

    @Test("前日の予定は、その日の予定より前に並ぶ")
    func sortsShiftedItemsFirst() {
        var early = item(20, in: losAngeles, title: "前日の夕食")
        early.dayShift = -1
        let morning = item(8, in: losAngeles, title: "朝食")
        #expect([morning, early].sorted(by: ScheduleItem.chronologically).map(\.title) == ["前日の夕食", "朝食"])
    }

    @Test("実際に起きる瞬間は、前日のずれも入る")
    func occurrence() {
        var shifted = item(17, in: losAngeles)
        shifted.dayShift = -1
        let day = DateComponents(year: 2026, month: 10, day: 12)
        let expected = ScheduleClock.calendar(in: losAngeles)
            .date(from: DateComponents(year: 2026, month: 10, day: 11, hour: 17))!
        #expect(shifted.occurrence(onDay: day) == expected)
    }

    // MARK: - 日の時間帯

    @Test("日の時間帯を決め、日本時間の予定だけを直す。予定の無い日も決められる")
    func settingDayZone() {
        let days = [
            DaySchedule(dayNumber: 1, date: at(0, in: japan),
                        scheduleItems: [item(10, in: japan, title: "日本"), item(12, in: london, title: "ロンドン")])
        ]
        let updated = plan(days: days).settingTimeZone(paris, onDays: [1, 2], mode: .keepWallClock, onlyFrom: japan)

        #expect(updated.dayTimeZone(1)?.identifier == "Europe/Paris")
        #expect(updated.dayTimeZone(2)?.identifier == "Europe/Paris")
        let items = updated.daySchedules[0].scheduleItems
        #expect(items.first { $0.title == "日本" }?.timeZone.identifier == "Europe/Paris")
        #expect(items.first { $0.title == "日本" }?.timeText == "10:00")
        // 日本時間でない予定は触らない
        #expect(items.first { $0.title == "ロンドン" }?.timeZone.identifier == "Europe/London")
    }

    @Test("直し方を選ばなければ、日の時間帯だけ決めて予定はそのまま")
    func settingDayZoneOnly() {
        let days = [DaySchedule(dayNumber: 1, date: at(0, in: japan), scheduleItems: [item(10, in: japan)])]
        let updated = plan(days: days).settingTimeZone(paris, onDays: [1], mode: nil)
        #expect(updated.dayTimeZone(1)?.identifier == "Europe/Paris")
        #expect(updated.daySchedules[0].scheduleItems[0].timeZone.identifier == "Asia/Tokyo")
        #expect(updated.clearingDayTimeZone(onDays: [1]).dayTimeZone(1) == nil)
    }

    @Test("現地に着いたときの案内は、日本時間で入った予定だけを数える")
    func japanTimeItems() {
        let days = [DaySchedule(dayNumber: 1, date: at(0, in: japan),
                                scheduleItems: [item(10, in: japan), item(12, in: paris)])]
        #expect(plan(days: days).japanTimeItems(onDays: [1], notIn: paris).count == 1)
        #expect(plan(days: days).japanTimeItems(onDays: [2], notIn: paris).isEmpty)
    }

    @Test("その日の予定で多い時間帯を勧める")
    func foreignZonesUsed() {
        let days = [DaySchedule(dayNumber: 1, date: at(0, in: japan),
                                scheduleItems: [item(10, in: paris), item(12, in: paris), item(9, in: london), item(8, in: japan)])]
        #expect(plan(days: days).foreignZonesUsed(onDay: 1).map(\.identifier) == ["Europe/Paris", "Europe/London"])
    }

    @Test("今日が旅行の何日目か。期間外は nil")
    func dayNumberOnDate() {
        let trip = plan(days: [])
        let calendar = ScheduleClock.calendar(in: japan)
        #expect(trip.dayNumber(on: at(9, in: japan), calendar: calendar) == 1)
        #expect(trip.dayNumber(on: at(9, in: japan).addingTimeInterval(2 * 86_400), calendar: calendar) == 3)
        #expect(trip.dayNumber(on: at(9, in: japan).addingTimeInterval(-86_400), calendar: calendar) == nil)
    }

    // MARK: - 保存

    @Test("日の時間帯と日のずれは保存して読み直せ、持たない古いデータも読める")
    func codable() throws {
        var shifted = item(17, in: losAngeles)
        shifted.dayShift = -1
        let day = DaySchedule(dayNumber: 1, date: at(0, in: japan), scheduleItems: [shifted],
                              timeZoneIdentifier: "America/Los_Angeles")
        let decoded = try JSONDecoder().decode(DaySchedule.self, from: JSONEncoder().encode(day))
        #expect(decoded == day)

        let old = #"{"id":"d","dayNumber":1,"date":0,"scheduleItems":[{"id":"i","time":0,"title":"古い予定"}]}"#
        let legacy = try JSONDecoder().decode(DaySchedule.self, from: Data(old.utf8))
        #expect(legacy.timeZoneIdentifier == nil)
        #expect(legacy.scheduleItems.first?.dayShift == nil)
    }

    @Test("最近使った時間帯は新しい順で、日本は入れない")
    func recents() {
        let defaults = UserDefaults(suiteName: "RecentTimeZonesTests-\(UUID().uuidString)")!
        RecentTimeZones.record(paris, defaults: defaults)
        RecentTimeZones.record(japan, defaults: defaults)
        RecentTimeZones.record(london, defaults: defaults)
        RecentTimeZones.record(paris, defaults: defaults)
        #expect(RecentTimeZones.list(defaults: defaults).map(\.identifier) == ["Europe/Paris", "Europe/London"])
    }

    // MARK: - 共有

    @Test("共有した旅行で、相手が予定を足しても、こちらが決めた日の時間帯は消えない")
    func mergeKeepsDayZone() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        func shared(updatedAt: Date, zone: String?, items: [ScheduleItem]) -> TravelPlan {
            TravelPlan(id: "p", title: "旅", startDate: start, endDate: start.addingTimeInterval(86_400),
                       destination: "パリ", userId: "me",
                       daySchedules: [DaySchedule(id: "d1", dayNumber: 1, date: start, scheduleItems: items,
                                                  timeZoneIdentifier: zone)],
                       isShared: true, shareCode: "TRAVEL-TEST", sharedWith: ["owner", "me"], ownerId: "owner",
                       updatedAt: updatedAt)
        }
        let base = shared(updatedAt: start, zone: nil, items: [])
        let local = shared(updatedAt: start.addingTimeInterval(5), zone: "Europe/Paris", items: [])
        let remote = shared(updatedAt: start.addingTimeInterval(10), zone: nil,
                            items: [ScheduleItem(id: "x", time: start, title: "相手の予定")])

        let decision = SharedPlanMerge.decide(local: local, remote: remote, base: base, myUserId: "me")
        let merged: TravelPlan?
        switch decision {
        case .takeAndPush(let plan), .pushLocal(let plan), .takeRemote(let plan): merged = plan
        case .doNothing: merged = nil
        }
        #expect(merged?.dayTimeZone(1)?.identifier == "Europe/Paris")
        #expect(merged?.daySchedules.first?.scheduleItems.count == 1)
    }

    // MARK: - 時差をまたぐ移動（3.1）

    @Test("終わりを着いた先の時計で入れる：パリ 15:00 発 → ドーハ 23:00 着は7時間")
    func endInOtherZone() throws {
        let doha = TimeZone(identifier: "Asia/Qatar")!
        let start = at(15, in: paris)
        let end = ScheduleItem.endTime(hourAndMinuteOf: at(23, in: doha), after: start, in: paris, endZone: doha)
        #expect(end.timeIntervalSince(start) == 7 * 3600)

        let flight = ScheduleItem(time: start, title: "QR40", timeZoneIdentifier: paris.identifier,
                                  endTime: end, endTimeZoneIdentifier: doha.identifier)
        #expect(flight.crossesTimeZones)
        #expect(flight.endTimeText == "23:00")
        #expect(flight.timeRangeText == "15:00 パリ → 23:00 ドーハ")
        #expect(flight.endTimeColumnText == "→23:00")
        #expect(flight.departureZoneLabel == "パリ発")
        #expect(flight.arrivalZoneLabel == "ドーハ着")

        // 古い版で読んでも壊れず、書き戻しても残る
        let decoded = try JSONDecoder().decode(ScheduleItem.self, from: JSONEncoder().encode(flight))
        #expect(decoded.endTimeZoneIdentifier == "Asia/Qatar")

        // 予定をまとめて現地の時計に直しても、着く時刻は動かさない
        #expect(flight.keepingWallClock(in: japan).endTime == end)
    }

    @Test("夜に出て翌朝に着く便と、日付変更線を東へ越える便")
    func endAcrossDays() {
        let doha = TimeZone(identifier: "Asia/Qatar")!
        let honolulu = TimeZone(identifier: "Pacific/Honolulu")!
        let night = at(22, in: paris)
        let morning = ScheduleItem.endTime(hourAndMinuteOf: at(6, in: doha), after: night, in: paris, endZone: doha)
        #expect(morning.timeIntervalSince(night) == 7 * 3600)

        // 東京 10:00 発 → ホノルル 22:00 着（ホノルルではまだ前日）
        let tokyo = at(10, in: japan)
        let arrival = ScheduleItem.endTime(hourAndMinuteOf: at(22, in: honolulu), after: tokyo, in: japan, endZone: honolulu)
        #expect(arrival.timeIntervalSince(tokyo) == 7 * 3600)
    }

    @Test("同じ時計なら今までどおり「10:00〜11:30」")
    func endInSameZone() {
        let lunch = item(12, in: paris, end: 13)
        #expect(!lunch.crossesTimeZones)
        #expect(lunch.timeRangeText == "12:00〜13:00")
        #expect(lunch.endTimeColumnText == "〜13:00")
        #expect(lunch.departureZoneLabel == nil)
        #expect(ScheduleClock.durationText(6.5 * 3600) == "6時間30分")
        #expect(ScheduleClock.durationText(45 * 60) == "45分")
    }
}
