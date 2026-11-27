import Testing
import Foundation
@testable import GoTravel

/// 旅のダイジェストの並べ替えと、動画の使う長さ（3.9、ご要望から）
@MainActor
struct DigestReorderTests {

    private static let base = Date(timeIntervalSince1970: 1_790_000_000)

    private func clip(_ id: String, minute: Double, added: Bool = false) -> TripDigest.Clip {
        TripDigest.Clip(sourceId: id, dayNumber: 1, date: Self.base.addingTimeInterval(minute * 60),
                        timeText: "", placeName: nil, isAdded: added)
    }

    /// 並べる位置で並べ直したときの id の順
    private func sorted(_ list: [TripDigest.Clip], _ order: [String: Double]) -> [String] {
        list.sorted { TripDigest.sortTime($0, order: order) < TripDigest.sortTime($1, order: order) }.map(\.sourceId)
    }

    @Test("あとで撮った看板を、店内の写真の前へ移せる。ほかのコマの位置は変えない")
    func moveBefore() {
        let list = [clip("店内", minute: 0), clip("料理", minute: 20), clip("看板", minute: 50)]
        let changes = TripDigest.reorder(list, from: 2, to: 0, order: [:])
        #expect(Array(changes.keys) == ["看板"])
        #expect(sorted(list, changes) == ["看板", "店内", "料理"])
    }

    @Test("間・後ろへ移す。動かさない移動は何もしない")
    func moveBetweenAndEnd() {
        let list = [clip("a", minute: 0), clip("b", minute: 10), clip("c", minute: 20)]
        #expect(sorted(list, TripDigest.reorder(list, from: 0, to: 2, order: [:])) == ["b", "a", "c"])
        #expect(sorted(list, TripDigest.reorder(list, from: 0, to: 3, order: [:])) == ["b", "c", "a"])
        #expect(TripDigest.reorder(list, from: 1, to: 1, order: [:]).isEmpty)
        #expect(TripDigest.reorder(list, from: 1, to: 2, order: [:]).isEmpty)
    }

    @Test("同じ時刻のコマどうしでも並べ替えられる")
    func sameTime() {
        let list = [clip("a", minute: 0), clip("b", minute: 0), clip("c", minute: 0)]
        let changes = TripDigest.reorder(list, from: 2, to: 1, order: [:])
        #expect(sorted(list, changes) == ["a", "c", "b"])
    }

    @Test("並べ替えた順は、コマを選ぶときにも使う")
    func clipsUseOrder() {
        let plan = TravelBookletTests.sampleTrip()
        let start = Calendar.current.startOfDay(for: plan.date(forDay: 1))
        let sources = [
            TripDigest.Source(id: "店内", date: start.addingTimeInterval(10 * 3600), isVideo: false, duration: 0),
            TripDigest.Source(id: "看板", date: start.addingTimeInterval(11 * 3600), isVideo: false, duration: 0),
        ]
        #expect(TripDigest.clips(plan: plan, sources: sources, scope: .day(1)).map(\.sourceId) == ["店内", "看板"])
        let order = ["看板": start.addingTimeInterval(9 * 3600).timeIntervalSince1970]
        let clips = TripDigest.clips(plan: plan, sources: sources, scope: .day(1), order: order)
        #expect(clips.map(\.sourceId) == ["看板", "店内"])
        // 時刻は早い順のまま、写真だけが入れ替わる
        #expect(clips.map(\.timeText) == ["10:00", "11:00"])
    }

    @Test("動画の使う長さ：決めた長さを、動画の中に収めて使う")
    func videoLength() {
        var edit = DigestClipEdit(videoStart: 3)
        edit.videoLength = 5
        #expect(edit.videoRange(duration: 20, length: 2) == (3, 5))
        #expect(edit.videoRange(duration: 6, length: 2) == (1, 5))   // 終わりが出ないよう前へ
        #expect(edit.videoRange(duration: 4, length: 2) == (0, 4))   // 短い動画は全部
        edit.videoLength = 30
        #expect(edit.videoRange(duration: 60, length: 2).length == 10)  // 長くても10秒まで
    }

    @Test("並べ替えだけ・長さだけでも覚える。トリミングを戻しても並べ替えは別")
    func defaults() {
        var edit = DigestClipEdit()
        #expect(edit.isDefault)
        edit.sortTime = 1
        #expect(!edit.isDefault)
        #expect(edit.isUntrimmed)
        edit.videoLength = 4
        #expect(!edit.isUntrimmed)
    }

    @Test("動画の長さは、長さを決めたコマをその長さで数える")
    func duration() {
        let list = [clip("a", minute: 0), clip("b", minute: 1)]
        let seconds = TripDigest.clipSeconds
        #expect(TripDigest.duration(of: list) == 2 * seconds)
        #expect(TripDigest.duration(of: list, lengths: ["b": 6]) == seconds + 6)
    }
}
