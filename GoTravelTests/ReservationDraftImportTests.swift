import Testing
import Foundation
@testable import GoTravel

/// メールの下書きを予約にするときの、時計と仮の時刻の決め方
struct ReservationDraftImportTests {

    private func components(_ y: Int, _ m: Int, _ d: Int, _ h: Int? = nil, _ min: Int? = nil) -> DateComponents {
        DateComponents(year: y, month: m, day: d, hour: h, minute: min)
    }

    private func wallClock(_ date: Date?, in zone: TimeZone) -> String? {
        date.map { ScheduleClock.text($0, format: "yyyy-MM-dd HH:mm", in: zone) }
    }

    @Test("海外の空港に着く便は、到着をその空港の時計で読む")
    func flightUsesAirportZones() {
        var draft = ReservationDraft(kind: .flight)
        draft.transportNumber = "NH215"
        draft.departurePlace = "羽田空港"
        draft.arrivalPlace = "パリ空港"
        draft.start = components(2026, 10, 6, 10, 0)
        draft.arrival = components(2026, 10, 6, 16, 30)
        draft.confirmationNumber = "ABC123"

        let imported = draft.makeReservation(destinationTimeZone: TimeZone(identifier: "Europe/Paris"))
        let r = imported.reservation
        #expect(r.timeZoneIdentifier == "Asia/Tokyo")
        #expect(r.arrivalTimeZoneIdentifier == "Europe/Paris")
        #expect(wallClock(r.date, in: r.dateTimeZone) == "2026-10-06 10:00")
        #expect(wallClock(r.arrivalDate, in: r.arrivalTimeZone) == "2026-10-06 16:30")
        #expect(imported.notes.isEmpty)
    }

    @Test("帰りの便は海外の空港から出るので、出発を現地の時計で読む")
    func returnFlightDepartsInLocalZone() {
        var draft = ReservationDraft(kind: .flight)
        draft.departurePlace = "ホノルル空港"
        draft.arrivalPlace = "成田空港"
        draft.start = components(2026, 10, 10, 12, 0)

        let r = draft.makeReservation(destinationTimeZone: TimeZone(identifier: "Pacific/Honolulu")).reservation
        #expect(r.timeZoneIdentifier == "Pacific/Honolulu")
        #expect(wallClock(r.date, in: r.dateTimeZone) == "2026-10-10 12:00")
    }

    @Test("海外の宿は現地の時計で、時刻が無ければチェックイン15時・チェックアウト10時")
    func hotelDefaultsInDestinationZone() {
        var draft = ReservationDraft(kind: .hotel, title: "Hotel Paris")
        draft.start = components(2026, 10, 6)
        draft.end = components(2026, 10, 8)
        draft.confirmationNumber = "123"

        let imported = draft.makeReservation(destinationTimeZone: TimeZone(identifier: "Europe/Paris"))
        let r = imported.reservation
        #expect(r.title == "Hotel Paris")
        #expect(r.timeZoneIdentifier == "Europe/Paris")
        #expect(wallClock(r.date, in: r.dateTimeZone) == "2026-10-06 15:00")
        #expect(wallClock(r.endDate, in: r.dateTimeZone) == "2026-10-08 10:00")
        #expect(imported.notes.contains { $0.contains("仮の時刻") })
    }

    @Test("国内旅行は日本時間。年を補った・予約番号が無いことを伝える")
    func domesticNotes() {
        var draft = ReservationDraft(kind: .restaurant, title: "〇〇亭")
        draft.start = components(2026, 11, 3, 18, 30)
        draft.guessedYear = true

        let imported = draft.makeReservation(destinationTimeZone: nil)
        #expect(imported.reservation.timeZoneIdentifier == "Asia/Tokyo")
        #expect(imported.notes.contains { $0.contains("年を補って") })
        #expect(imported.notes.contains { $0.contains("予約番号") })
        #expect(!imported.notes.contains { $0.contains("仮の時刻") })
    }

    @Test("日付が無ければ日時を入れない")
    func noDate() {
        var draft = ReservationDraft(kind: .ticket, title: "美術館")
        draft.confirmationNumber = "X1"
        let imported = draft.makeReservation(destinationTimeZone: nil)
        #expect(imported.reservation.date == nil)
        #expect(imported.reservation.timeZoneIdentifier == nil)
        #expect(imported.notes.contains { $0.contains("日時が読み取れません") })
    }
}
