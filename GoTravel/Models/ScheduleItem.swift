import Foundation

// Plan用の簡易的なスケジュール項目（おでかけプラン専用）
struct PlanScheduleItem: Identifiable, Codable, Equatable {
    var id: String = UUID().uuidString
    var time: Date
    var title: String
    var placeId: String? // PlannedPlaceのIDを参照（任意）
    var note: String?

    init(id: String = UUID().uuidString,
         time: Date,
         title: String,
         placeId: String? = nil,
         note: String? = nil) {
        self.id = id
        self.time = time
        self.title = title
        self.placeId = placeId
        self.note = note
    }
}
