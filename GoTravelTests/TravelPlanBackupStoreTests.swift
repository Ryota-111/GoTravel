import Testing
import Foundation
@testable import GoTravel

/// 旅行計画の控え。iCloud が外れて一覧が空になっても、控えは消さないこと
struct TravelPlanBackupStoreTests {

    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("backup-\(UUID().uuidString).json")
    }

    private func plan(_ title: String) -> TravelPlan {
        var plan = TravelPlan(title: title, startDate: Date(timeIntervalSince1970: 0),
                              endDate: Date(timeIntervalSince1970: 86_400), destination: "沖縄")
        plan.reservations = [Reservation(kind: .flight, confirmationNumber: "ABC123", transportNumber: "NH991")]
        plan.memo = "集合は那覇空港"
        return plan
    }

    @Test("控えは保存して読み直せる（予約番号やメモも残る）")
    func roundTrips() {
        let url = tempURL()
        TravelPlanBackupStore.save([plan("沖縄旅行")], userId: "me", to: url)
        let backup = TravelPlanBackupStore.load(userId: "me", from: url)
        #expect(backup?.plans.first?.title == "沖縄旅行")
        #expect(backup?.plans.first?.reservations.first?.confirmationNumber == "ABC123")
        #expect(backup?.plans.first?.memo == "集合は那覇空港")
    }

    @Test("一覧が空になっても、控えを空で上書きしない（iCloud が外れたとき）")
    func emptyListDoesNotOverwrite() {
        let url = tempURL()
        TravelPlanBackupStore.save([plan("沖縄旅行")], userId: "me", to: url)
        TravelPlanBackupStore.save([], userId: "me", to: url)
        #expect(TravelPlanBackupStore.load(userId: "me", from: url)?.plans.count == 1)
    }

    @Test("別の人の控えは見せない（同じ端末で別の Apple ID にサインインしたとき）")
    func otherUsersBackupIsHidden() {
        let url = tempURL()
        TravelPlanBackupStore.save([plan("沖縄旅行")], userId: "me", to: url)
        #expect(TravelPlanBackupStore.load(userId: "someone-else", from: url) == nil)
    }
}
