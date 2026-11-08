import Foundation

// Plan用の簡易的なスケジュール項目（おでかけプラン専用）
struct PlanScheduleItem: Identifiable, Codable, Equatable {
    var id: String = UUID().uuidString
    var time: Date
    var title: String
    var placeId: String? // PlannedPlaceのIDを参照（任意）
    var note: String?
    /// 次の予定までの移動手段（`TransportMode` の rawValue）。無ければ出さない（3.2）
    var transportToNext: String?
    /// 「移動」の予定の中身（乗り物・出発地 → 到着地・便）。旅行の予定と同じ形（3.5。`PlanScheduleMoveAndUndecided.swift`）
    var move: ScheduleMove?
    /// 時間が決まっていない予定か。`time` は並ぶ位置として持ち続ける（3.5）
    var isTimeUndecided: Bool?

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
