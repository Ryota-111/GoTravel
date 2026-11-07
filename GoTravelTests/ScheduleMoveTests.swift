import Testing
import Foundation
@testable import GoTravel

/// 「移動」の予定と、予約のバス・船（3.4。`docs/設計_移動と時間未定.md`）。
///
/// 乗り場や便を取り違えると、当日に乗り遅れる。古い版でも中身が分かる形で残すこと
struct ScheduleMoveTests {

    private let umeda = MovePlace(name: "梅田", address: "大阪府大阪市北区", latitude: 34.70, longitude: 135.50)
    private let kyoto = MovePlace(name: "京都", latitude: 34.98, longitude: 135.76)

    private func item() -> ScheduleItem {
        ScheduleItem(time: Date(timeIntervalSince1970: 1_790_000_000), title: "", timeZoneIdentifier: "Asia/Tokyo")
    }

    @Test("名前を入れなければ「梅田 → 京都」を名前にし、場所には出発地を入れる")
    func defaultTitleAndLocation() {
        var schedule = item()
        schedule.apply(move: ScheduleMove(mode: .bus, line: "阪急バス 12系統", from: umeda, to: kyoto), title: "  ")
        #expect(schedule.title == "梅田 → 京都")
        #expect(schedule.hasDefaultMoveTitle)
        #expect(schedule.location == "梅田")
        #expect(schedule.latitude == 34.70)
        #expect(schedule.address == "大阪府大阪市北区")
    }

    @Test("名前を入れたら、その名前のまま。発着地は名前の下に出すため、自動の名前ではないと分かる")
    func customTitle() {
        var schedule = item()
        schedule.apply(move: ScheduleMove(mode: .bus, from: umeda, to: kyoto), title: "京都へ")
        #expect(schedule.title == "京都へ")
        #expect(!schedule.hasDefaultMoveTitle)
    }

    @Test("発着地が片方だけ・どちらも無いときの名前")
    func partialRoute() {
        #expect(ScheduleMove(mode: .train, from: umeda).defaultTitle == "梅田 →")
        #expect(ScheduleMove(mode: .train, to: kyoto).defaultTitle == "→ 京都")
        #expect(ScheduleMove(mode: .bus).defaultTitle == "バスで移動")
        // 空白だけの発着地は無いものとして扱う
        #expect(ScheduleMove(mode: .bus, from: MovePlace(name: " ")).from == nil)
    }

    @Test("便・のりば・座席を1行にまとめる")
    func detailText() {
        let move = ScheduleMove(mode: .bus, line: "阪急バス 12系統", platform: "3番のりば", seat: "5A")
        #expect(move.detailText == "阪急バス 12系統 · 3番のりば · 座席 5A")
        #expect(ScheduleMove(mode: .bus).detailText == nil)
    }

    @Test("入れ替えると出発地と到着地が逆になり、案内は出発地へ向かう")
    func swapAndNavigation() {
        let move = ScheduleMove(mode: .train, from: umeda, to: kyoto)
        #expect(move.swapped.from == kyoto)
        #expect(move.swapped.to == umeda)
        #expect(move.navigationPlace == umeda)
        // 出発地の位置が無ければ、到着地へ
        #expect(ScheduleMove(mode: .train, from: MovePlace(name: "梅田"), to: kyoto).navigationPlace == kyoto)
    }

    @Test("保存して読み直しても同じ。移動の無い古い予定もそのまま読める")
    func codable() throws {
        var schedule = item()
        schedule.apply(move: ScheduleMove(mode: .ship, line: "さんふらわあ", from: umeda, to: kyoto), title: "")
        let decoded = try JSONDecoder().decode(ScheduleItem.self, from: JSONEncoder().encode(schedule))
        #expect(decoded == schedule)
        #expect(decoded.move?.transportMode == .ship)

        let old = #"{"id":"x","time":0,"title":"浅草寺"}"#
        let oldItem = try JSONDecoder().decode(ScheduleItem.self, from: Data(old.utf8))
        #expect(oldItem.move == nil)
        #expect(!oldItem.isMove)
    }

    @Test("知らない乗り物（新しい版で増えたもの）は電車として扱う")
    func unknownMode() throws {
        let json = #"{"mode":"hoverboard"}"#
        let move = try JSONDecoder().decode(ScheduleMove.self, from: Data(json.utf8))
        #expect(move.transportMode == .train)
    }

    // MARK: - 予約のバス・船

    @Test("予約のバス・船は「電車」として保存し、印を添える（古い版でも発着地まで出る）")
    func reservationStorage() throws {
        for (kind, detail) in [(Reservation.Kind.bus, "bus"), (.ferry, "ferry")] {
            let reservation = Reservation(kind: kind, title: "夜行バス")
            let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(reservation)) as? [String: Any]
            #expect(json?["kind"] as? String == "train")
            #expect(json?["kindDetail"] as? String == detail)
            let decoded = try JSONDecoder().decode(Reservation.self, from: JSONEncoder().encode(reservation))
            #expect(decoded.kind == kind)
            #expect(decoded.kind.usesRoute)
        }
    }

    @Test("バスから電車に変えると印が外れ、駐車場は今までどおり")
    func reservationKindChange() throws {
        var reservation = Reservation(kind: .bus)
        reservation.kind = .train
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(reservation)) as? [String: Any]
        #expect(json?["kind"] as? String == "train")
        #expect(json?["kindDetail"] == nil)
        #expect(Reservation(kind: .parking).kind == .parking)
    }

    @Test("予定の名前からバス・フェリーを当てる。「船」だけの言葉では当てない")
    func guessKind() {
        #expect(Reservation.guessedKind(title: "高速バス 梅田→新宿", location: nil) == .bus)
        #expect(Reservation.guessedKind(title: "フェリーで大分へ", location: nil) == .ferry)
        #expect(Reservation.guessedKind(title: "船場センタービル", location: nil) != .ferry)
    }

    @Test("バスの予約は出発と到着の2件として行程に入り、出発にだけ便を添える")
    func busItinerary() {
        let reservation = Reservation(kind: .bus, title: "夜行バス", date: Date(timeIntervalSince1970: 1_790_000_000),
                                      transportNumber: "VIP 3便", departurePlace: "梅田", arrivalPlace: "新宿",
                                      arrivalDate: Date(timeIntervalSince1970: 1_790_030_000))
        let items = reservation.itineraryItems()
        #expect(items.map(\.title) == ["VIP 3便 出発", "VIP 3便 到着"])
        #expect(items.map(\.location) == ["梅田", "新宿"])
        #expect(items[0].move?.line == "VIP 3便")
        #expect(items[0].move?.transportMode == .bus)
        #expect(items[1].move == nil)
    }
}
