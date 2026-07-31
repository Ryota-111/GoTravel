import Foundation

// Plan用の簡易的なスケジュール項目（おでかけプラン専用）
struct PlanScheduleItem: Identifiable, Codable, Equatable {
    var id: String = UUID().uuidString
    /// 予定の日付（その日の 0:00）。既存データとの互換のため Optional。
    /// nil の場合はプラン初日の予定として扱う。
    var date: Date?
    var time: Date
    var title: String
    var placeId: String? // PlannedPlaceのIDを参照（任意）
    var note: String?

    init(id: String = UUID().uuidString,
         date: Date? = nil,
         time: Date,
         title: String,
         placeId: String? = nil,
         note: String? = nil) {
        self.id = id
        self.date = date.map { Calendar.current.startOfDay(for: $0) }
        self.time = time
        self.title = title
        self.placeId = placeId
        self.note = note
    }

    /// 日付が未設定の項目はプラン初日として扱う
    func dayKey(fallbackDate: Date) -> Date {
        Calendar.current.startOfDay(for: date ?? fallbackDate)
    }
}
