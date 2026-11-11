import Testing
import Foundation
@testable import GoTravel

/// お土産を渡す相手ごとにまとめる（3.5、ご要望から）
struct SouvenirGroupingTests {

    private func souvenir(_ name: String, to recipient: String?, checked: Bool = false) -> PackingItem {
        PackingItem(id: name, name: name, isChecked: checked, kind: .souvenir, recipient: recipient)
    }

    @Test("相手は最初に出てきた順、「相手なし」はいちばん下。中は買っていないものが上")
    func groups() {
        let items = [
            souvenir("白い恋人", to: "お母さん", checked: true),
            souvenir("ロイズ", to: "会社"),
            souvenir("六花亭", to: " お母さん "),
            souvenir("マグネット", to: nil),
            souvenir("じゃがポックル", to: ""),
        ]
        let groups = SouvenirGrouping.groups(items)
        #expect(groups.map(\.recipient) == ["お母さん", "会社", nil])
        #expect(groups[0].items.map(\.name) == ["六花亭", "白い恋人"])
        #expect(groups[0].checkedCount == 1)
        #expect(groups[2].items.map(\.name) == ["マグネット", "じゃがポックル"])
    }

    @Test("相手を1つも書いていなければ、今までどおり1列に並べる")
    func flatWhenNoRecipients() {
        #expect(!SouvenirGrouping.usesGroups([souvenir("ロイズ", to: nil), souvenir("六花亭", to: "  ")]))
        #expect(SouvenirGrouping.usesGroups([souvenir("ロイズ", to: "会社")]))
    }

    @Test("候補の相手は出てきた順で、重ねない")
    func recipients() {
        let items = [souvenir("a", to: "会社"), souvenir("b", to: "お母さん"), souvenir("c", to: "会社")]
        #expect(SouvenirGrouping.recipients(items) == ["会社", "お母さん"])
    }

    @Test("渡す相手は保存して読み戻せる。古いデータ（相手の無いもの）も読める")
    func codable() throws {
        let item = souvenir("ロイズ", to: "会社")
        let decoded = try JSONDecoder().decode(PackingItem.self, from: JSONEncoder().encode(item))
        #expect(decoded.recipient == "会社")

        let old = Data(#"{"id":"x","name":"ロイズ","isChecked":false,"kind":"souvenir","note":"会社"}"#.utf8)
        let legacy = try JSONDecoder().decode(PackingItem.self, from: old)
        #expect(legacy.recipient == nil)
        #expect(legacy.note == "会社")
    }

    @Test("しおりなどでは、相手とメモを1行にする")
    func recipientAndNote() {
        var item = souvenir("ロイズ", to: "会社")
        #expect(item.recipientAndNote == "会社へ")
        item.note = "2箱"
        #expect(item.recipientAndNote == "会社へ ・ 2箱")
        item.recipient = nil
        #expect(item.recipientAndNote == "2箱")
        item.note = " "
        #expect(item.recipientAndNote == nil)
    }

    private func plan(_ items: [PackingItem]) -> TravelPlan {
        var plan = TravelPlan(title: "札幌", startDate: Date(), endDate: Date(), destination: "札幌")
        plan.packingItems = items
        return plan
    }

    @Test("ドラッグで別の相手へ移すと、その相手のいちばん下に並ぶ。相手なしへも移せる")
    func assign() {
        var trip = plan([
            souvenir("白い恋人", to: "お母さん"),
            souvenir("ロイズ", to: "会社"),
            PackingItem(id: "充電器", name: "充電器", kind: .packing),
            souvenir("六花亭", to: "お母さん"),
        ])
        trip.assignSouvenirs(["ロイズ"], to: "お母さん")
        #expect(trip.packingItems.map(\.name) == ["白い恋人", "充電器", "六花亭", "ロイズ"])
        #expect(SouvenirGrouping.groups(trip.packingItems.filter { $0.kind == .souvenir }).map(\.recipient) == ["お母さん"])

        trip.assignSouvenirs(["白い恋人"], to: "  ")
        #expect(trip.packingItems.first { $0.id == "白い恋人" }?.recipient == nil)

        // 持ち物は相手を持たないので動かさない
        trip.assignSouvenirs(["充電器"], to: "会社")
        #expect(trip.packingItems.first { $0.id == "充電器" }?.recipient == nil)
    }

    @Test("複製はチェックを外して新しい id で入る。相手を選べばその相手の下に、選ばなければすぐ下に")
    func duplicate() throws {
        var trip = plan([
            souvenir("白い恋人", to: "お母さん", checked: true),
            souvenir("ロイズ", to: "会社"),
        ])
        let sameResult = trip.duplicatePackingItem("白い恋人")
        let sameID = try #require(sameResult)
        #expect(trip.packingItems.map(\.name) == ["白い恋人", "白い恋人", "ロイズ"])
        let same = try #require(trip.packingItems.first { $0.id == sameID })
        #expect(!same.isChecked)
        #expect(same.recipient == "お母さん")

        let otherResult = trip.duplicatePackingItem("白い恋人", recipient: .some("会社"))
        let otherID = try #require(otherResult)
        #expect(trip.packingItems.last?.id == otherID)
        #expect(trip.packingItems.last?.recipient == "会社")

        let noneResult = trip.duplicatePackingItem("ロイズ", recipient: .some(nil))
        let noneID = try #require(noneResult)
        #expect(trip.packingItems.first { $0.id == noneID }?.recipient == nil)
        let missing = trip.duplicatePackingItem("無い")
        #expect(missing == nil)
    }

    @Test("前の旅行から取り込むとき、お土産は相手が違えば別のものとして入る")
    func importKey() {
        #expect(SouvenirGrouping.importKey(of: souvenir("白い恋人", to: "会社"))
                != SouvenirGrouping.importKey(of: souvenir("白い恋人", to: "お母さん")))
        #expect(SouvenirGrouping.importKey(of: souvenir("白い恋人", to: " 会社"))
                == SouvenirGrouping.importKey(of: souvenir("白い恋人", to: "会社")))
        #expect(SouvenirGrouping.importKey(of: PackingItem(name: "充電器", kind: .packing, recipient: "x")) == "充電器")
    }

    @Test("相手の候補は、書いたことのある相手を先に、はじめの候補をあとに出す")
    func suggestedRecipients() {
        #expect(SouvenirGrouping.suggestedRecipients([]) == SouvenirGrouping.starterRecipients)
        #expect(SouvenirGrouping.suggestedRecipients([souvenir("a", to: "お母さん"), souvenir("b", to: "職場")])
                == ["お母さん", "職場", "家族", "友人", "自分用"])
    }

    @Test("よく使うお土産は物の名前。3.4 までの相手の名前の候補は、物の名前に置き換える")
    func presets() {
        let defaults = PackingPresetManager.defaults[.souvenir] ?? []
        #expect(!defaults.contains { $0.hasSuffix("へ") || $0 == "自分用" })
        let renamed = PackingPresetManager.legacySouvenirRenames
        #expect(Set(renamed.map(\.from)) == ["家族へ", "職場へ", "友人へ", "自分用"])
        #expect(renamed.allSatisfy { defaults.contains($0.to) })
    }
}
