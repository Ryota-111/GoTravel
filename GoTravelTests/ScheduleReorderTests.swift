import Testing
import Foundation
import CoreImage
@testable import GoTravel

/// 行程と日程の並び替え・移動手段・予定の地図の番号（3.2）。
///
/// 並び替えで時刻や日付を取り違えると、当日の行動そのものを誤らせる
struct ScheduleReorderTests {

    private let tokyo = TimeZone(identifier: "Asia/Tokyo")!

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        ScheduleClock.calendar(in: tokyo).date(
            from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute)
        )!
    }

    private func item(_ id: String, day: Int, _ hour: Int, end: Int? = nil) -> ScheduleItem {
        ScheduleItem(id: id, time: date(day, hour), title: id,
                     timeZoneIdentifier: tokyo.identifier,
                     endTime: end.map { date(day, $0) })
    }

    /// 11/3〜11/4 の2日間。1日目は A(9時)・B(11〜12時)・C(14時)、2日目は D(10時)
    private func plan() -> TravelPlan {
        var plan = TravelPlan(title: "京都", startDate: date(3, 0), endDate: date(4, 0), destination: "京都")
        plan.daySchedules = [
            DaySchedule(dayNumber: 1, date: date(3, 0),
                        scheduleItems: [item("A", day: 3, 9), item("B", day: 3, 11, end: 12), item("C", day: 3, 14)]),
            DaySchedule(dayNumber: 2, date: date(4, 0), scheduleItems: [item("D", day: 4, 10)],
                        timeZoneIdentifier: "Asia/Tokyo"),
        ]
        return plan
    }

    private func titles(_ plan: TravelPlan, day: Int) -> [String] {
        plan.timelineScheduleItems(onDay: day).map(\.title)
    }

    @Test("時刻の枠はそのままで中身が入れ替わり、終わりの時刻は長さを保って動く")
    func reorderItems() {
        let reordered = plan().reorderingItems(onDay: 1, from: ["A", "B", "C"], to: ["B", "A", "C"])
        #expect(titles(reordered, day: 1) == ["B", "A", "C"])

        let items = reordered.daySchedules[0].scheduleItems
        let b = items.first { $0.id == "B" }!
        let a = items.first { $0.id == "A" }!
        #expect(b.time == date(3, 9))
        #expect(b.endTime == date(3, 10))
        #expect(a.time == date(3, 11))
        #expect(items.first { $0.id == "C" }!.time == date(3, 14))
    }

    @Test("同じ順や、id の合わない並びは何もしない")
    func reorderItemsNoop() {
        let original = plan()
        #expect(titles(original.reorderingItems(onDay: 1, from: ["A", "B", "C"], to: ["A", "B", "C"]), day: 1) == ["A", "B", "C"])
        #expect(titles(original.reorderingItems(onDay: 1, from: ["A", "B", "C"], to: ["A", "B", "X"]), day: 1) == ["A", "B", "C"])
    }

    @Test("日にちを入れ替えると、予定は時:分を保ったまま相手の日付へ移り、日付と何日目は残る")
    func reorderDays() {
        let swapped = plan().reorderingDays([2, 1])
        #expect(titles(swapped, day: 1) == ["D"])
        #expect(titles(swapped, day: 2) == ["A", "B", "C"])

        let day1 = swapped.daySchedules.first { $0.dayNumber == 1 }!
        let day2 = swapped.daySchedules.first { $0.dayNumber == 2 }!
        #expect(day1.date == date(3, 0))
        #expect(day1.scheduleItems.first?.time == date(3, 10))
        #expect(day1.timeZoneIdentifier == "Asia/Tokyo")
        #expect(day2.scheduleItems.first { $0.id == "B" }?.endTime == date(4, 12))
        #expect(day2.timeZoneIdentifier == nil)
    }

    @Test("移動手段は文字で持ち、知らない値は無いものとして読む")
    func transportMode() throws {
        var a = item("A", day: 3, 9)
        a.transportToNext = TransportMode.train.rawValue
        let decoded = try JSONDecoder().decode(ScheduleItem.self, from: JSONEncoder().encode(a))
        #expect(decoded.transportToNextMode == .train)

        a.transportToNext = "hoverboard"
        #expect(a.transportToNextMode == nil)
    }

    @Test("日付をまたぐ予定（翌日 0:30）は、その日の 23:00 より後ろに並ぶ")
    func nextDayItemSortsLast() {
        var plan = plan()
        var checkIn = item("チェックイン", day: 3, 0)
        checkIn.time = date(3, 0, 30)
        checkIn.dayShift = 1
        plan.daySchedules[0].scheduleItems += [item("到着", day: 3, 23), checkIn]
        #expect(titles(plan, day: 1) == ["A", "B", "C", "到着", "チェックイン"])
        // 「翌日 0:30」ではなく、その日の続きとして「24:30」と出す
        #expect(checkIn.dayShiftLabel == nil)
        #expect(checkIn.timeText == "24:30")
        checkIn.endTime = date(3, 1, 30)
        #expect(checkIn.timeRangeText == "24:30〜25:30")

        // 夜をまたぐ予定の終わりも「25:00」
        var late = item("夜行バス", day: 3, 23)
        late.endTime = date(4, 1)
        #expect(late.timeRangeText == "23:00〜25:00")

        // 時間帯を直してずれた翌日の昼は、今までどおり「翌日」
        var shifted = item("観光", day: 3, 17)
        shifted.dayShift = 1
        #expect(shifted.timeRangeText == "翌日 17:00")
        #expect(NextDayToggle.isCandidate(date(3, 0, 30), in: tokyo))
        #expect(!NextDayToggle.isCandidate(date(3, 9), in: tokyo))
    }

    @Test("移動の時間は「25分」「1時間10分」で出し、0分以下や1日以上は出さない")
    func transportDuration() {
        #expect(TransportGapRow.durationText(25 * 60) == "25分")
        #expect(TransportGapRow.durationText(60 * 60) == "1時間")
        #expect(TransportGapRow.durationText(70 * 60) == "1時間10分")
        #expect(TransportGapRow.durationText(0) == nil)
        #expect(TransportGapRow.durationText(-30 * 60) == nil)
        #expect(TransportGapRow.durationText(25 * 60 * 60) == nil)
    }

    @Test("予定の地図の番号は、何日目・時刻の順に最初に行く順で、行程に無い場所には付けない")
    func planPlaceOrder() {
        let cafe = PlannedPlace(id: "cafe", name: "カフェ", latitude: 35, longitude: 135)
        let temple = PlannedPlace(id: "temple", name: "お寺", latitude: 35.1, longitude: 135.1)
        let shop = PlannedPlace(id: "shop", name: "お店", latitude: 35.2, longitude: 135.2)
        let plan = Plan(id: "p", title: "おでかけ", startDate: date(3, 0), endDate: date(3, 0),
                        places: [cafe, temple, shop],
                        scheduleItems: [
                            PlanScheduleItem(time: date(3, 15), title: "お茶", placeId: "cafe"),
                            PlanScheduleItem(time: date(3, 10), title: "参拝", placeId: "temple"),
                            PlanScheduleItem(time: date(3, 17), title: "もう一度", placeId: "temple"),
                        ])
        #expect(plan.placeOrder == ["temple": 1, "cafe": 2])
        #expect(plan.placesInVisitOrder.map(\.id) == ["temple", "cafe"])
    }
}

/// 旅のダイジェストの地図のカードに出す場所（3.2）
struct TripDigestMapStopsTests {
    private let tokyo = TimeZone(identifier: "Asia/Tokyo")!

    private func date(_ day: Int, _ hour: Int) -> Date {
        ScheduleClock.calendar(in: tokyo).date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
    }

    private func item(_ title: String, day: Int, _ hour: Int, lat: Double?, location: String? = nil) -> ScheduleItem {
        ScheduleItem(time: date(day, hour), title: title, location: location,
                     latitude: lat, longitude: lat.map { $0 + 100 }, timeZoneIdentifier: tokyo.identifier)
    }

    private func plan() -> TravelPlan {
        var plan = TravelPlan(title: "京都", startDate: date(3, 0), endDate: date(4, 0), destination: "京都")
        plan.daySchedules = [
            DaySchedule(dayNumber: 1, date: date(3, 0), scheduleItems: [
                item("お昼", day: 3, 12, lat: 35.01, location: "錦市場"),
                item("清水寺", day: 3, 9, lat: 35.00),
                item("移動", day: 3, 10, lat: nil),
                item("錦市場でおやつ", day: 3, 13, lat: 35.01),
            ]),
            DaySchedule(dayNumber: 2, date: date(4, 0), scheduleItems: [item("伏見稲荷", day: 4, 9, lat: 34.97)]),
        ]
        return plan
    }

    @Test("時刻の順に、場所のある予定だけを番号つきで並べ、続けて同じ場所は1つにまとめる")
    func dayStops() {
        let stops = TripDigest.mapStops(plan: plan(), scope: .day(1))
        #expect(stops.map(\.name) == ["清水寺", "錦市場"])
        #expect(stops.map(\.order) == [1, 2])
    }

    @Test("旅行全体は日をまたいで通し番号にし、上限で打ち切る")
    func tripStops() {
        #expect(TripDigest.mapStops(plan: plan(), scope: .trip).map(\.name) == ["清水寺", "錦市場", "伏見稲荷"])
        #expect(TripDigest.mapStops(plan: plan(), scope: .trip, limit: 2).count == 2)
    }

    @Test("題名のカードは背景の写真が無くても作れる")
    func openingWithoutBackground() {
        let image = TripDigestComposer.openingImage(.init(title: "京都", subtitle: "Day 1", destination: "京都"), background: nil)
        #expect(image?.extent.size == TripDigestComposer.renderSize)
    }

    @Test("題名のカードは、最後に文字が消えてぼかしが抜け、1コマ目の最初の絵そのものになる")
    func openingEndsSharp() {
        let start = TripDigestComposer.OpeningLook.at(0)
        #expect(start.blur == 1 && start.textAlpha == 0 && start.textRise == 1)
        let middle = TripDigestComposer.OpeningLook.at(0.7)
        #expect(middle.blur == 1 && middle.textAlpha == 1 && middle.textRise == 0)
        let end = TripDigestComposer.OpeningLook.at(TripDigestComposer.openingSeconds)
        #expect(end.blur == 0 && end.textAlpha == 0)
    }

    @Test("地図のカードの文字は、1日ならその日と行き先、旅行全体なら日数と旅行名")
    func mapLabel() {
        let day = DigestFinish.mapLabel(plan: plan(), scope: .day(2))
        #expect(day.caption == "Day 2" && day.headline == "京都")
        let trip = DigestFinish.mapLabel(plan: plan(), scope: .trip)
        #expect(trip.caption == "Day 1〜2" && trip.headline == "京都")
    }
}

/// 旅のダイジェストのトリミング・動画の使いはじめ・色味（3.2）
struct DigestClipEditTests {
    private let canvas = CGSize(width: 1080, height: 1920)
    /// 横長の写真（4:3）
    private let photo = CGSize(width: 4000, height: 3000)

    @Test("トリミングしていなければ、写真の真ん中を画面いっぱいに出す")
    func centered() {
        let size = DigestClipEdit.filledSize(of: photo, in: canvas, zoom: 1)
        #expect(size.height == 1920)
        let origin = DigestClipEdit.origin(of: photo, in: canvas, zoom: 1, focus: CGPoint(x: 0.5, y: 0.5))
        #expect(abs(origin.x - (1080 - size.width) / 2) < 0.001 && origin.y == 0)
    }

    @Test("写真の外が見えるところまでは寄せない")
    func clampsToEdges() {
        let left = DigestClipEdit.origin(of: photo, in: canvas, zoom: 1, focus: CGPoint(x: 0, y: 0))
        #expect(left.x == 0 && left.y == 0)
        let edit = DigestClipEdit(focusX: -1, focusY: 2, zoom: 9).clamped(source: photo, canvas: canvas)
        #expect(edit.zoom == DigestClipEdit.maxZoom)
        let size = DigestClipEdit.filledSize(of: photo, in: canvas, zoom: edit.zoom)
        #expect(abs(edit.focusX - canvas.width / 2 / size.width) < 0.0001)
        #expect(abs(edit.focusY - (1 - canvas.height / 2 / size.height)) < 0.0001)
    }

    @Test("動画は決めていなければ真ん中、決めたらそこから。後ろにはみ出さず、短い動画は全部使う")
    func videoRange() {
        #expect(DigestClipEdit().videoRange(duration: 10, length: 2) == (4, 2))
        #expect(DigestClipEdit(videoStart: 1.5).videoRange(duration: 10, length: 2) == (1.5, 2))
        #expect(DigestClipEdit(videoStart: 9.5).videoRange(duration: 10, length: 2) == (8, 2))
        #expect(DigestClipEdit(videoStart: 3).videoRange(duration: 1.2, length: 2) == (0, 1.2))
    }

    @Test("何も変えていなければ覚えない")
    func isDefault() {
        #expect(DigestClipEdit().isDefault)
        #expect(!DigestClipEdit(zoom: 1.5).isDefault)
        #expect(!DigestClipEdit(videoStart: 0).isDefault)
    }

    @Test("色味をかけても絵の大きさは変わらず、白黒は色が無くなる", arguments: DigestLook.allCases)
    func looks(look: DigestLook) throws {
        let image = CIImage(color: CIColor(red: 0.8, green: 0.3, blue: 0.2)).cropped(to: CGRect(x: 0, y: 0, width: 8, height: 8))
        let output = look.apply(to: image)
        #expect(output.extent == image.extent)
        var pixel = [UInt8](repeating: 0, count: 4)
        CIContext().render(output, toBitmap: &pixel, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                           format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        if look == .mono {
            #expect(abs(Int(pixel[0]) - Int(pixel[2])) <= 2)
        } else if look == .warm {
            #expect(pixel[0] > 200 && pixel[2] < 51)
        }
    }
}

/// 旅のダイジェストの無料と Pro の分け方（3.2）
@Suite(.serialized)
struct DigestProFeatureTests {
    @Test("色味（そのまま以外）と正方形・横長は Pro。外すと、そのまま・縦長に戻る")
    func proFeatures() {
        let defaults = UserDefaults.standard
        let saved = (defaults.object(forKey: DigestLook.storageKey), defaults.object(forKey: DigestShape.storageKey))
        defer {
            defaults.set(saved.0, forKey: DigestLook.storageKey)
            defaults.set(saved.1, forKey: DigestShape.storageKey)
        }
        defaults.set(DigestLook.natural.rawValue, forKey: DigestLook.storageKey)
        defaults.set(DigestShape.vertical.rawValue, forKey: DigestShape.storageKey)
        #expect(DigestFinish.proFeatures.isEmpty)

        defaults.set(DigestLook.film.rawValue, forKey: DigestLook.storageKey)
        defaults.set(DigestShape.square.rawValue, forKey: DigestShape.storageKey)
        #expect(DigestFinish.proFeatures == ["「フィルム」の色味", "正方形の形"])

        DigestFinish.dropPro()
        #expect(DigestLook.current == .natural && DigestShape.current == .vertical)
        #expect(DigestFinish.proFeatures.isEmpty)
    }
}
