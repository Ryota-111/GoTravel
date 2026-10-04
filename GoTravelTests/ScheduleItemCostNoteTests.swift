import Testing
import Foundation
@testable import GoTravel

/// 費用のメモ。JSON の中の項目なので、前のバージョンのデータもそのまま読めること
struct ScheduleItemCostNoteTests {

    @Test("費用のメモは保存して読み直しても残る")
    func roundTrips() throws {
        let item = ScheduleItem(time: Date(timeIntervalSince1970: 0), title: "夕食", cost: 8000, costNote: "2人分")
        let decoded = try JSONDecoder().decode(ScheduleItem.self, from: JSONEncoder().encode(item))
        #expect(decoded.costNote == "2人分")
        #expect(decoded == item)
    }

    @Test("費用のメモが無い前のデータも読める")
    func decodesOldData() throws {
        let json = #"{"id":"a","time":0,"title":"夕食","cost":8000}"#
        let decoded = try JSONDecoder().decode(ScheduleItem.self, from: Data(json.utf8))
        #expect(decoded.costNote == nil)
        #expect(decoded.cost == 8000)
    }
}
