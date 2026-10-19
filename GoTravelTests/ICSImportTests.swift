import Testing
import Foundation
@testable import GoTravel

/// .ics の読み込み（3.0）。いろいろなカレンダーの書き方を読め、2重にならず、繰り返しを取り違えないこと
struct ICSImportTests {

    private let tokyo = TimeZone(identifier: "Asia/Tokyo")!
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .current
        return c
    }

    private func ics(_ events: String...) -> String {
        (["BEGIN:VCALENDAR", "VERSION:2.0"] + events + ["END:VCALENDAR"]).joined(separator: "\r\n")
    }

    private func components(_ date: Date, in zone: TimeZone) -> DateComponents {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = zone
        return c.dateComponents([.year, .month, .day, .hour, .minute], from: date)
    }

    // MARK: - 読み取り

    @Test("時間帯つきの時刻・折り返し・特別な文字を読める。通知（VALARM）の中身は混ぜない")
    func parsesTimedEvent() throws {
        let text = ics("""
        BEGIN:VEVENT
        UID:abc-1@example.com
        SUMMARY:歯医者\\, 定期健診
        DESCRIPTION:持ち物：保険証\\n診察券の
         再発行も
        LOCATION:渋谷
        DTSTART;TZID=Asia/Tokyo:20261020T090000
        DTEND;TZID=Asia/Tokyo:20261020T103000
        BEGIN:VALARM
        DESCRIPTION:通知の文
        TRIGGER:-PT15M
        END:VALARM
        END:VEVENT
        """)
        let events = ICSParser.parse(text)
        let event = try #require(events.first)
        #expect(events.count == 1)
        #expect(event.summary == "歯医者, 定期健診")
        #expect(event.description == "持ち物：保険証\n診察券の再発行も")
        #expect(event.location == "渋谷")
        #expect(!event.isAllDay)
        let start = components(event.start, in: tokyo)
        #expect(start.hour == 9 && start.minute == 0 && start.day == 20)
        let end = components(try #require(event.end), in: tokyo)
        #expect(end.hour == 10 && end.minute == 30)
    }

    @Test("世界時（Z）・Windows の時間帯名・終わりが長さ（DURATION）のものも読める")
    func parsesOtherTimeForms() throws {
        let events = ICSParser.parse(ics("""
        BEGIN:VEVENT
        UID:z
        SUMMARY:会議
        DTSTART:20261020T000000Z
        DURATION:PT1H30M
        END:VEVENT
        """, """
        BEGIN:VEVENT
        UID:w
        SUMMARY:Outlook の予定
        DTSTART;TZID="Tokyo Standard Time":20261021T140000
        DTEND;TZID="Tokyo Standard Time":20261021T150000
        END:VEVENT
        """))
        #expect(events.count == 2)
        let utc = components(events[0].start, in: tokyo)
        #expect(utc.hour == 9)  // 世界時 0:00 は日本の 9:00
        #expect(events[0].end == events[0].start.addingTimeInterval(5_400))
        #expect(components(events[1].start, in: tokyo).hour == 14)
    }

    @Test("取り消された予定と、繰り返しの中の1回だけを変えた予定は入れない")
    func skipsCancelledAndExceptions() {
        let events = ICSParser.parse(ics("""
        BEGIN:VEVENT
        UID:c
        SUMMARY:中止
        STATUS:CANCELLED
        DTSTART:20261020T000000Z
        END:VEVENT
        """, """
        BEGIN:VEVENT
        UID:r
        SUMMARY:この回だけ時間を変更
        RECURRENCE-ID:20261027T000000Z
        DTSTART:20261027T010000Z
        END:VEVENT
        """, """
        BEGIN:VEVENT
        UID:ok
        SUMMARY:入る予定
        DTSTART:20261020T000000Z
        END:VEVENT
        """))
        let candidates = ICSImportRule.candidates(from: events)
        #expect(candidates.map(\.plan.title) == ["入る予定"])
    }

    // MARK: - 予定にする

    @Test("時刻のある予定は「日常」、何日もの終日の予定は「おでかけ」、毎年の終日の予定は「記念日」")
    func mapsPlanTypes() throws {
        let now = try #require(ICSParser.date("20261001", params: [:])?.date)
        let events = ICSParser.parse(ics("""
        BEGIN:VEVENT
        UID:daily
        SUMMARY:ジム
        DTSTART:20261020T100000
        DTEND:20261020T110000
        END:VEVENT
        """, """
        BEGIN:VEVENT
        UID:trip
        SUMMARY:京都
        DTSTART;VALUE=DATE:20261101
        DTEND;VALUE=DATE:20261104
        END:VEVENT
        """, """
        BEGIN:VEVENT
        UID:bday
        SUMMARY:誕生日
        DTSTART;VALUE=DATE:20261215
        DTEND;VALUE=DATE:20261216
        RRULE:FREQ=YEARLY
        END:VEVENT
        """))
        let plans = ICSImportRule.candidates(from: events, now: now, calendar: calendar).map(\.plan)
        let daily = try #require(plans.first { $0.title == "ジム" })
        #expect(daily.planType == .daily)
        #expect(calendar.component(.hour, from: try #require(daily.time)) == 10)
        #expect(calendar.component(.hour, from: try #require(daily.endTime)) == 11)

        let trip = try #require(plans.first { $0.title == "京都" })
        #expect(trip.planType == .outing)
        #expect(calendar.component(.day, from: trip.startDate) == 1)
        #expect(calendar.component(.day, from: trip.endDate) == 3)  // 終日の終わり（4日）は含まない

        let bday = try #require(plans.first { $0.title == "誕生日" })
        #expect(bday.planType == .anniversary)
        #expect(bday.recurrence == .yearly)
    }

    @Test("毎週の予定の1回目が過ぎていれば、今日以降の最初の回から入れる")
    func rollsRecurringForward() throws {
        let now = try #require(ICSParser.date("20261021T120000", params: [:])?.date)  // 水曜
        let events = ICSParser.parse(ics("""
        BEGIN:VEVENT
        UID:weekly
        SUMMARY:英会話
        DTSTART:20260105T190000
        DTEND:20260105T200000
        RRULE:FREQ=WEEKLY
        END:VEVENT
        """))
        let plan = try #require(ICSImportRule.candidates(from: events, now: now, calendar: calendar).first?.plan)
        #expect(plan.recurrence == .weekly)
        #expect(plan.startDate >= calendar.startOfDay(for: now))
        #expect(calendar.component(.weekday, from: plan.startDate) == 2)  // 月曜のまま
        #expect(calendar.component(.hour, from: try #require(plan.time)) == 19)
    }

    @Test("Travory に無い繰り返しは1回目だけ入れて知らせる。終わった繰り返しは繰り返さない")
    func unsupportedAndEndedRecurrence() throws {
        let now = try #require(ICSParser.date("20261021", params: [:])?.date)
        let events = ICSParser.parse(ics("""
        BEGIN:VEVENT
        UID:everyday
        SUMMARY:散歩
        DTSTART:20261025T070000
        RRULE:FREQ=DAILY
        END:VEVENT
        """, """
        BEGIN:VEVENT
        UID:twodays
        SUMMARY:ヨガ
        DTSTART:20261026T070000
        RRULE:FREQ=WEEKLY;BYDAY=MO,WE
        END:VEVENT
        """, """
        BEGIN:VEVENT
        UID:ended
        SUMMARY:去年の講座
        DTSTART:20250105T190000
        RRULE:FREQ=WEEKLY;UNTIL=20250301T000000Z
        END:VEVENT
        """))
        let candidates = ICSImportRule.candidates(from: events, now: now, calendar: calendar)
        let walk = try #require(candidates.first { $0.plan.title == "散歩" })
        #expect(walk.plan.recurrence == .none)
        #expect(walk.notes.first?.contains("毎日") == true)
        let yoga = try #require(candidates.first { $0.plan.title == "ヨガ" })
        #expect(yoga.plan.recurrence == .none)
        #expect(!yoga.notes.isEmpty)
        let ended = try #require(candidates.first { $0.plan.title == "去年の講座" })
        #expect(ended.plan.recurrence == .none)
        #expect(ended.notes.isEmpty)
        #expect(calendar.component(.year, from: ended.plan.startDate) == 2025)
    }

    // MARK: - 2重にしない

    @Test("同じ UID なら同じ予定 id になる。ファイルの中で同じ UID が2つあっても1件だけ")
    func stableIds() {
        let a = ICSEvent(uid: "x@y", summary: "A", start: Date(timeIntervalSince1970: 0), isAllDay: false)
        var b = a
        b.summary = "名前を変えた"
        #expect(ICSImportRule.planId(for: a) == ICSImportRule.planId(for: b))
        #expect(ICSImportRule.planId(for: a).hasPrefix("ics-"))
        #expect(ICSImportRule.candidates(from: [a, b]).count == 1)
    }

    @Test("読み込み直すと、中身だけ直し、通知・済みの印・カテゴリ・タグは手元のまま")
    func mergeKeepsPersonalFields() {
        let start = Date(timeIntervalSince1970: 1_790_000_000)
        var local = Plan(id: "ics-1", title: "旧", startDate: start, endDate: start, places: [], planType: .daily,
                         time: start, tagIDs: ["tag"], reminders: [])
        local.categoryId = "family"
        let incoming = Plan(id: "ics-1", title: "新", startDate: start, endDate: start, places: [], planType: .daily,
                            time: start, description: "メモ")

        #expect(ICSImportRule.status(of: incoming, local: nil) == .new)
        #expect(ICSImportRule.status(of: incoming, local: local) == .update)
        let merged = ICSImportRule.merged(incoming, into: local)
        #expect(merged.title == "新")
        #expect(merged.description == "メモ")
        #expect(merged.categoryId == "family")
        #expect(merged.tagIDs == ["tag"])
        #expect(merged.reminders == [])
        #expect(ICSImportRule.status(of: incoming, local: merged) == .unchanged)

        var progressed = merged
        progressed.recurrence = .weekly
        progressed.isCompleted = true
        #expect(ICSImportRule.status(of: incoming, local: progressed) == .recurringInProgress)
    }

    @Test("Travory が書き出した .ics を、そのまま読み戻せる")
    func readsOwnExport() throws {
        let start = Date(timeIntervalSince1970: 1_790_000_000)
        let drafts = [
            CalendarEventDraft(key: "item:1", title: "とても長い題名の予定です。折り返しが起きるくらいの長さにしておきます。日本語の途中で切れないこと",
                               start: start, end: start.addingTimeInterval(3_600), isAllDay: false, timeZone: tokyo,
                               location: "那覇空港", notes: "メモ, 1行目\n2行目", url: URL(string: "https://example.com")),
            CalendarEventDraft(key: "trip", title: "沖縄旅行", start: start, end: start.addingTimeInterval(86_400 * 2),
                               isAllDay: true, timeZone: nil)
        ]
        let events = ICSParser.parse(CalendarICS.document(drafts, uidPrefix: "plan-1"))
        #expect(events.count == 2)
        let item = try #require(events.first { $0.uid == "plan-1-item:1@travory" })
        #expect(item.summary == drafts[0].title)
        #expect(item.start == start)
        #expect(item.description == "メモ, 1行目\n2行目")
        #expect(item.location == "那覇空港")
        #expect(item.url == "https://example.com")
        #expect(events.first { $0.summary == "沖縄旅行" }?.isAllDay == true)
    }
}
