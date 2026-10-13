import Testing
import Foundation
import Contacts
@testable import GoTravel

/// 予定の住所（「現在地の国名が出る」の修正）
struct ScheduleItemAddressTests {

    private let tokyo = TimeZone(identifier: "Asia/Tokyo")!

    private func date(_ day: Int, _ hour: Int) -> Date {
        ScheduleClock.calendar(in: tokyo).date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
    }

    @Test("住所は保存して読み直しても残り、住所の無い前のデータも読める")
    func codable() throws {
        let item = ScheduleItem(time: date(6, 10), title: "首里城", address: "沖縄県那覇市首里金城町1丁目")
        let decoded = try JSONDecoder().decode(ScheduleItem.self, from: JSONEncoder().encode(item))
        #expect(decoded.address == "沖縄県那覇市首里金城町1丁目")

        let old = try JSONDecoder().decode(ScheduleItem.self, from: Data(#"{"id":"a","time":0,"title":"首里城"}"#.utf8))
        #expect(old.address == nil)
    }

    @Test("住所を1行にする。日本はつなげて、海外はカンマで区切る。国名は付けない")
    func formatsAddress() {
        let japan = CNMutablePostalAddress()
        japan.isoCountryCode = "JP"; japan.country = "日本"
        japan.state = "沖縄県"; japan.city = "那覇市"; japan.subLocality = "首里金城町"; japan.street = "1丁目"
        #expect(AddressLookup.format(japan) == "沖縄県那覇市首里金城町1丁目")

        let france = CNMutablePostalAddress()
        france.isoCountryCode = "FR"; france.country = "フランス"
        france.street = "Rue de Rivoli"; france.city = "Paris"; france.state = "Île-de-France"
        #expect(AddressLookup.format(france) == "Rue de Rivoli, Paris, Île-de-France")

        #expect(AddressLookup.format(CNPostalAddress()) == nil)
        #expect(AddressLookup.format(nil) == nil)
    }

    @Test("予約の場所の住所が、行程の予定にも入る（飛行機は出発地・到着地の住所）")
    func reservationAddressGoesToItinerary() {
        var hotel = Reservation(kind: .hotel, title: "ホテル海風", date: date(6, 15), timeZoneIdentifier: tokyo.identifier)
        hotel.location = ReservationLocation(name: "ホテル海風", address: "沖縄県那覇市1-1", latitude: 26.2, longitude: 127.7)
        #expect(hotel.itineraryItems().first?.address == "沖縄県那覇市1-1")

        var flight = Reservation(kind: .flight, date: date(6, 10), transportNumber: "NH991",
                                 departurePlace: "羽田空港", arrivalPlace: "那覇空港", arrivalDate: date(6, 13),
                                 timeZoneIdentifier: tokyo.identifier, arrivalTimeZoneIdentifier: tokyo.identifier)
        flight.departureLocation = ReservationLocation(name: "羽田空港", address: "東京都大田区羽田空港", latitude: 35.5, longitude: 139.7)
        flight.arrivalLocation = ReservationLocation(name: "那覇空港", address: "沖縄県那覇市鏡水", latitude: 26.2, longitude: 127.6)
        #expect(flight.itineraryItems().map(\.address) == ["東京都大田区羽田空港", "沖縄県那覇市鏡水"])
    }

    @Test("行程で選び直した場所の住所が、予約の場所の住所に戻る")
    func itineraryAddressFlowsBack() {
        var trip = TravelPlan(title: "沖縄", startDate: date(6, 0), endDate: date(8, 0), destination: "沖縄")
        trip.daySchedules = [DaySchedule(dayNumber: 1, date: date(6, 0))]
        var hotel = Reservation(kind: .hotel, title: "ホテル海風", date: date(6, 15), timeZoneIdentifier: tokyo.identifier)
        hotel.location = ReservationLocation(name: "ホテル海風", address: "沖縄県那覇市1-1", latitude: 26.2, longitude: 127.7)
        trip.reservations = [hotel]
        trip.syncScheduleItems(for: hotel, isOn: true)

        var item = trip.scheduleItems(forReservation: hotel.id)[0]
        item.location = "海風パーキング"
        item.latitude = 26.3
        item.longitude = 127.8
        item.address = "沖縄県那覇市2-2"
        trip.daySchedules[0].scheduleItems = [item]
        trip.syncReservation(fromScheduleItem: item)

        #expect(trip.reservations[0].location?.address == "沖縄県那覇市2-2")
    }
}
