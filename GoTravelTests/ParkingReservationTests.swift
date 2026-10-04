import Testing
import Foundation
@testable import GoTravel

/// 予約の種類「駐車場」。古いバージョンのアプリでも読める形で保存すること
struct ParkingReservationTests {

    @Test("駐車場は「その他」として保存し、印を添える（古いバージョンは「その他」として読める）")
    func encodesAsOtherWithDetail() throws {
        let parking = Reservation(kind: .parking, title: "那覇空港 P2")
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(parking)) as? [String: Any]
        #expect(json?["kind"] as? String == "other")
        #expect(json?["kindDetail"] as? String == "parking")
    }

    @Test("保存して読み直すと駐車場に戻る")
    func roundTrips() throws {
        let parking = Reservation(kind: .parking, title: "那覇空港 P2")
        let decoded = try JSONDecoder().decode(Reservation.self, from: JSONEncoder().encode(parking))
        #expect(decoded.kind == .parking)
        #expect(decoded == parking)
    }

    @Test("種類を駐車場からほかに変えると、印も外れる")
    func changingKindClearsDetail() throws {
        var reservation = Reservation(kind: .parking, title: "P")
        reservation.kind = .hotel
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(reservation)) as? [String: Any]
        #expect(json?["kind"] as? String == "hotel")
        #expect(json?["kindDetail"] == nil)
    }

    @Test("ほかの種類の保存の形は、これまでと同じ（kind の名前のまま）")
    func otherKindsUnchanged() throws {
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(Reservation(kind: .flight))) as? [String: Any]
        #expect(json?["kind"] as? String == "flight")
    }

    @Test("知らない種類は「その他」として読み、予約の一覧ごと失わない")
    func unknownKindFallsBackToOther() throws {
        let json = #"[{"id":"a","kind":"spaceship","title":"宇宙旅行"},{"id":"b","kind":"hotel","title":"宿"}]"#
        let decoded = try JSONDecoder().decode([Reservation].self, from: Data(json.utf8))
        #expect(decoded.map(\.kind) == [.other, .hotel])
    }

    @Test("駐車場の予約メールを、入庫と出庫の期間として読む")
    func parsesParkingEmail() {
        let text = """
        akippa をご利用いただきありがとうございます。駐車場の予約が完了しました。
        予約番号：AK123456
        駐車場名：那覇空港近く 第2パーキング
        入庫：2026年10月6日 9:00
        出庫：2026年10月8日 18:00
        お支払い金額：¥3,300
        """
        let draft = ReservationEmailParser.parse(text).first
        #expect(draft?.kind == .parking)
        #expect(draft?.confirmationNumber == "AK123456")
        #expect(draft?.start?.day == 6)
        #expect(draft?.end?.day == 8)
        #expect(draft?.cost == 3300)
    }
}
