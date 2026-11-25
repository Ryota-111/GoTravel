import Testing
import Foundation
@testable import GoTravel

/// 予約の読み取りで、読めた値を捨てない・誤った値を入れない（3.8。App Store のレビューから見直した）
struct ReservationReadingSafetyTests {

    private let reference: Date = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar.date(from: DateComponents(year: 2026, month: 11, day: 1))!
    }()

    private func components(_ month: Int, _ day: Int, _ hour: Int? = nil, _ minute: Int? = nil) -> DateComponents {
        DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute)
    }

    // MARK: 管理用の日付

    @Test("受付日しか無いメールでは、受付日を予約の日時にしない")
    func administrativeOnly() {
        let text = """
        ご予約ありがとうございます。
        予約番号：RX48213
        受付日：2026年11月1日 10:12
        """
        let drafts = ReservationEmailParser.parse(text, kind: .restaurant, referenceDate: reference)
        #expect(drafts.first?.start == nil)
        #expect(drafts.first?.confirmationNumber == "RX48213")
    }

    @Test("支払期限・キャンセル期限しか無いときも、予約の日時にしない")
    func deadlinesOnly() {
        let text = """
        予約番号：HT55120
        お支払期限：2026年12月3日
        キャンセル期限：2026年12月5日 23:59まで
        """
        let drafts = ReservationEmailParser.parse(text, kind: .hotel, referenceDate: reference)
        #expect(drafts.first?.start == nil)
        #expect(drafts.first?.end == nil)
    }

    // MARK: 取り込む値打ち

    @Test("チェックアウトの日だけ・発着地だけでも、下書きを残す")
    func partialDraftsAreKept() {
        var checkoutOnly = ReservationDraft(kind: .hotel)
        checkoutOnly.end = components(12, 2)
        #expect(checkoutOnly.isWorthImporting)

        var routeOnly = ReservationDraft(kind: .train)
        routeOnly.departurePlace = "東京"
        routeOnly.arrivalPlace = "新大阪"
        #expect(routeOnly.isWorthImporting)

        var namedHotel = ReservationDraft(kind: .hotel)
        namedHotel.title = "ホテル雅"
        #expect(namedHotel.isWorthImporting)
    }

    @Test("種類の分からない名前だけ・金額だけの下書きは残さない")
    func emptyDraftsAreDropped() {
        var titleOnly = ReservationDraft(kind: .other)
        titleOnly.title = "いつもご利用ありがとうございます"
        #expect(!titleOnly.isWorthImporting)

        var costOnly = ReservationDraft(kind: .other)
        costOnly.cost = 3000
        #expect(!costOnly.isWorthImporting)
        #expect(!ReservationDraft(kind: .flight).isWorthImporting)
    }

    // MARK: AI とルールの突き合わせ

    @Test("AI とルールで便の順番が違っても、同じ便どうしを合わせる")
    @available(iOS 26.0, *)
    func mergeByContent() {
        var outbound = ReservationDraft(kind: .flight)
        outbound.transportNumber = "NH123"
        outbound.start = components(12, 1, 8, 0)
        var inbound = ReservationDraft(kind: .flight)
        inbound.transportNumber = "NH456"
        inbound.start = components(12, 5, 18, 0)

        // AI は帰りの便を先に返し、行きの便には空港を足す
        var aiInbound = ReservationDraft(kind: .flight)
        aiInbound.transportNumber = "NH456"
        aiInbound.departurePlace = "那覇"
        var aiOutbound = ReservationDraft(kind: .flight)
        aiOutbound.transportNumber = "NH123"
        aiOutbound.departurePlace = "羽田"

        let merged = ReservationAIReader.merge(rules: [outbound, inbound], ai: [aiInbound, aiOutbound])
        #expect(merged.count == 2)
        #expect(merged[0].departurePlace == "羽田")
        #expect(merged[1].departurePlace == "那覇")
    }

    @Test("食い違う便は合わせず、ルールが見つけなかった便は別の便として足す")
    @available(iOS 26.0, *)
    func mergeKeepsDifferentRides() {
        var rule = ReservationDraft(kind: .flight)
        rule.transportNumber = "JL501"
        rule.start = components(12, 1, 9, 0)

        var other = ReservationDraft(kind: .flight)
        other.transportNumber = "JL510"
        other.start = components(12, 3, 17, 0)
        other.departurePlace = "新千歳"
        other.arrivalPlace = "羽田"

        let merged = ReservationAIReader.merge(rules: [rule], ai: [other])
        #expect(merged.count == 2)
        #expect(merged[0].departurePlace == nil)   // 別の便の空港を混ぜない
        #expect(merged[1].transportNumber == "JL510")
    }

    @Test("同じ便を AI がもう一度返しても、2件にしない")
    @available(iOS 26.0, *)
    func mergeDoesNotDuplicate() {
        var rule = ReservationDraft(kind: .flight)
        rule.transportNumber = "NH123"
        rule.start = components(12, 1, 8, 0)
        var same = ReservationDraft(kind: .flight)
        same.transportNumber = "NH 123"
        same.start = components(12, 1, 8, 0)
        var duplicate = same
        duplicate.arrivalPlace = "那覇"

        let merged = ReservationAIReader.merge(rules: [rule], ai: [same, duplicate])
        #expect(merged.count == 1)
    }

    @Test("宿は、日付が食い違う AI の答えでルールの値を変えない")
    @available(iOS 26.0, *)
    func mergeSingleStay() {
        var rule = ReservationDraft(kind: .hotel)
        rule.start = components(12, 1)
        var ai = ReservationDraft(kind: .hotel)
        ai.start = components(12, 9)
        ai.end = components(12, 10)
        ai.confirmationNumber = "ABC123"

        let merged = ReservationAIReader.merge(rules: [rule], ai: [ai])
        #expect(merged.count == 1)
        #expect(merged[0].start == components(12, 1))
        #expect(merged[0].end == nil)

        var agreeing = ReservationDraft(kind: .hotel)
        agreeing.end = components(12, 3)
        agreeing.confirmationNumber = "ABC123"
        let filled = ReservationAIReader.merge(rules: [rule], ai: [agreeing])
        #expect(filled[0].end == components(12, 3))
        #expect(filled[0].confirmationNumber == "ABC123")
    }
}

extension ReservationReadingSafetyTests {
    @Test("便名を確かめられない AI の便は、別の便として足さない（支払期限の日を出発日にしていた）")
    @available(iOS 26.0, *)
    func unverifiedRideIsNotAppended() {
        var rule = ReservationDraft(kind: .flight)
        rule.transportNumber = "SKY111"
        rule.start = DateComponents(year: 2026, month: 10, day: 6, hour: 7, minute: 30)
        var guess = ReservationDraft(kind: .flight)
        guess.start = DateComponents(year: 2026, month: 7, day: 15)
        guess.departurePlace = "神戸空港"
        guess.arrivalPlace = "那覇空港"
        #expect(ReservationAIReader.merge(rules: [rule], ai: [guess]).count == 1)
        // ルールが何も読めなかったときは、AI の答えを残す
        #expect(ReservationAIReader.merge(rules: [ReservationDraft(kind: .flight)], ai: [guess]).first?.departurePlace == "神戸空港")
    }
}

extension ReservationReadingSafetyTests {
    @Test("「SKY 111便」と「SKY111」、「神戸」と「神戸空港」は同じとみなして1件にまとめる")
    @available(iOS 26.0, *)
    func sameRideWrittenDifferently() {
        var rule = ReservationDraft(kind: .flight)
        rule.transportNumber = "SKY111"
        rule.departurePlace = "神戸空港"
        rule.start = DateComponents(year: 2026, month: 10, day: 6, hour: 7, minute: 30)
        var ai = ReservationDraft(kind: .flight)
        ai.transportNumber = "SKY 111便"
        ai.departurePlace = "神戸"
        ai.start = DateComponents(year: 2026, month: 10, day: 6, hour: 7, minute: 30)
        let merged = ReservationAIReader.merge(rules: [rule], ai: [ai])
        #expect(merged.count == 1)
        #expect(merged[0].transportNumber == "SKY111")
    }
}

// MARK: - 予約番号（3.8）

extension ReservationReadingSafetyTests {
    @Test("受付番号より予約番号を使う")
    func strongLabelWins() {
        let text = """
        受付番号：U-20261101
        予約番号：KX7Q2P
        """
        #expect(ReservationEmailParser.confirmationNumber(in: text) == "KX7Q2P")
    }

    @Test("予約番号が無ければ、受付番号を使う")
    func weakLabelAsFallback() {
        #expect(ReservationEmailParser.confirmationNumber(in: "受付番号：U20261101") == "U20261101")
    }

    @Test("電話番号・航空券の番号・日付は予約番号にしない")
    func notConfirmationShapes() {
        #expect(ReservationEmailParser.isNotConfirmation("022-395-2211"))
        #expect(ReservationEmailParser.isNotConfirmation("09012345678"))
        #expect(ReservationEmailParser.isNotConfirmation("2052423282534", kind: .flight))
        #expect(!ReservationEmailParser.isNotConfirmation("1010101010101", kind: .hotel))
        #expect(ReservationEmailParser.isNotConfirmation("2026-12-01"))
        #expect(!ReservationEmailParser.isNotConfirmation("EEF03D"))
        #expect(!ReservationEmailParser.isNotConfirmation("1234567"))
        #expect(ReservationEmailParser.isNotConfirmation("4u1b"))   // 写真の読み違い
        #expect(!ReservationEmailParser.isNotConfirmation("AB12"))
        #expect(ReservationEmailParser.confirmationNumber(in: "予約番号\n0120-123-456") == nil)
    }

    @Test("電話・航空券・部屋のラベルが付いた番号は、予約番号として使わない")
    func labeledAsOtherNumber() {
        let text = """
        航空券番号：2052423282 予約番号：EEF03D
        宿泊施設電話番号 0223952211
        部屋番号 1203
        """
        #expect(ReservationEmailParser.isLabeledAsOtherNumber("2052423282", in: text))
        #expect(ReservationEmailParser.isLabeledAsOtherNumber("1203", in: text))
        #expect(!ReservationEmailParser.isLabeledAsOtherNumber("EEF03D", in: text))
    }
}

// MARK: - AI に渡す文（3.8）

extension ReservationReadingSafetyTests {
    @Test("短い文面は、そのまま1つで渡す")
    @available(iOS 26.0, *)
    func shortTextIsOneChunk() {
        let text = "予約番号：AB1234\n2026年12月1日 NH123便"
        #expect(ReservationAIReader.chunks(of: text) == [text])
    }

    @Test("長い文面は、予約の手がかりのある行を拾い、後ろの帰りの便も落とさない")
    @available(iOS 26.0, *)
    func longTextKeepsLaterRides() {
        let filler = Array(repeating: "ご利用にあたってのご注意をお読みください。お客様の都合による変更はできません。", count: 80)
            .joined(separator: "\n")
        let text = """
        予約番号：AB1234
        【往路】2026年12月1日 NH123便 羽田 08:00 → 那覇 10:45
        \(filler)
        【復路】2026年12月4日 NH456便 那覇 18:30 → 羽田 21:05
        """
        let chunks = ReservationAIReader.chunks(of: text, limit: 600)
        let joined = chunks.joined(separator: "\n")
        #expect(chunks.count <= ReservationAIReader.maxChunks)
        #expect(chunks.allSatisfy { $0.count <= 600 })
        #expect(joined.contains("NH123"))
        #expect(joined.contains("NH456"))
        // 注意書きは、便の行のすぐ前後の分だけ（80行は入らない）
        #expect(joined.components(separatedBy: "お客様の都合").count - 1 <= 2)
    }
}
