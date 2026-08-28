import Foundation
import SwiftUI

// MARK: - Plan Type
enum PlanType: String, Codable, CaseIterable {
    case outing
    case daily
    /// 記念日。時刻も場所も持たず、毎年めぐってくる日付そのもの。
    /// 「あと◯日」「何回目か」が主役で、何をするかは持たない
    case anniversary

    var displayName: String {
        switch self {
        case .outing:      return "おでかけ"
        case .daily:       return "日常"
        case .anniversary: return "記念日"
        }
    }

    var icon: String {
        switch self {
        case .outing:      return "figure.walk"
        case .daily:       return "house.fill"
        case .anniversary: return "heart.fill"
        }
    }

    /// 選ぶとこの先で何を聞かれるか。
    ///
    /// 3つの違いが分からないという声への答えがこれ。
    /// **違いは名前ではなく入力項目そのもの**なので、選んだ結果を先に見せる。
    /// 説明を別の場所に置くと読まれないため、選択の真下に出す
    var inputSummary: String {
        switch self {
        case .outing:      return "日程と、行きたい場所を登録します"
        case .daily:       return "日付・時刻と、繰り返しを登録します"
        case .anniversary: return "日付だけ。毎年くり返して、あと何日かを数えます"
        }
    }

    /// 名前欄に薄く出す例。何を入れる箱なのかは、説明文より例のほうが早い
    var titlePlaceholder: String {
        switch self {
        case .outing:      return "大阪旅行"
        case .daily:       return "ジム"
        case .anniversary: return "結婚記念日"
        }
    }
}

// MARK: - Recurrence

/// 繰り返し。旅行計画には絶対に無い概念で、日常の用事と記念日にだけある。
///
/// 「完了にすると次回分を作る」方式にしている。
/// 未来の分をあらかじめ大量に作ると、1件直したいだけのときに
/// どれを直せばいいのか分からなくなるため
enum PlanRecurrence: String, Codable, CaseIterable {
    case none
    case weekly
    case monthly
    case yearly

    var displayName: String {
        switch self {
        case .none:    return "なし"
        case .weekly:  return "毎週"
        case .monthly: return "毎月"
        case .yearly:  return "毎年"
        }
    }

    /// 次回の日付。同じ曜日・同じ日を保つよう、カレンダー計算に任せる
    func nextDate(after date: Date) -> Date? {
        let calendar = Calendar.current
        switch self {
        case .none:    return nil
        case .weekly:  return calendar.date(byAdding: .weekOfYear, value: 1, to: date)
        case .monthly: return calendar.date(byAdding: .month, value: 1, to: date)
        case .yearly:  return calendar.date(byAdding: .year, value: 1, to: date)
        }
    }
}

struct Plan: Identifiable, Codable, Equatable {
    var id: String = UUID().uuidString
    var title: String
    var startDate: Date
    var endDate: Date
    var places: [PlannedPlace]
    var cardColor: Color?
    var localImageFileName: String?
    var userId: String?
    var createdAt: Date
    var planType: PlanType = .outing
    var time: Date?
    /// 終わりの時刻。日常の用事だけが持つ任意の値。
    /// 日付は `startDate` 側が持つので、ここで見るのは時分だけ
    var endTime: Date?
    var description: String?
    var linkURL: String?
    var scheduleItems: [PlanScheduleItem] = [] // スケジュール項目（おでかけプラン用）
    /// 済んだかどうか。用事は「終わったか」が意味を持つ
    var isCompleted: Bool = false
    /// 付いているタグ（`PlanTag.id`）。予定の分類はこれが本命で、
    /// 一覧の絞り込みも、色による見分けもタグが受け持つ。
    ///
    /// 名前ではなくIDを持つのは、後からタグの名前や色を変えても
    /// 付けた予定を全部書き換えずに済むようにするため。
    /// **先頭が代表タグ**で、一覧のカードにはこれが出る
    var tagIDs: [String] = []
    var recurrence: PlanRecurrence = .none
    /// 鳴らす通知。**nil は「まだ設定していない」**で、種別ごとの既定が使われる。
    /// 空配列は「通知しない」。この2つを分けないと、
    /// 設定を足す前からある予定の通知を勝手に止めてしまう
    var reminders: [PlanReminder]?

    enum CodingKeys: String, CodingKey {
        case id, title, startDate, endDate, places, cardColorHex, localImageFileName, userId, createdAt
        case planType, time, endTime, description, linkURL, scheduleItems, isCompleted, tagIDs, recurrence
        case reminders
    }

    var cardColorHex: String? {
        guard let color = cardColor else { return nil }
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r*255), Int(g*255), Int(b*255))
    }

    init(id: String = UUID().uuidString,
         title: String,
         startDate: Date,
         endDate: Date,
         places: [PlannedPlace],
         cardColor: Color? = nil,
         localImageFileName: String? = nil,
         userId: String? = nil,
         createdAt: Date = Date(),
         planType: PlanType = .outing,
         time: Date? = nil,
         endTime: Date? = nil,
         description: String? = nil,
         linkURL: String? = nil,
         scheduleItems: [PlanScheduleItem] = [],
         isCompleted: Bool = false,
         tagIDs: [String] = [],
         recurrence: PlanRecurrence = .none,
         reminders: [PlanReminder]? = nil) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.places = places
        self.cardColor = cardColor
        self.localImageFileName = localImageFileName
        self.userId = userId
        self.createdAt = createdAt
        self.planType = planType
        self.time = time
        self.endTime = endTime
        self.description = description
        self.linkURL = linkURL
        self.scheduleItems = scheduleItems
        self.isCompleted = isCompleted
        self.tagIDs = tagIDs
        self.recurrence = recurrence
        self.reminders = reminders
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        title = try container.decode(String.self, forKey: .title)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decode(Date.self, forKey: .endDate)
        places = try container.decode([PlannedPlace].self, forKey: .places)
        localImageFileName = try container.decodeIfPresent(String.self, forKey: .localImageFileName)
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        planType = try container.decodeIfPresent(PlanType.self, forKey: .planType) ?? .outing
        time = try container.decodeIfPresent(Date.self, forKey: .time)
        endTime = try container.decodeIfPresent(Date.self, forKey: .endTime)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        linkURL = try container.decodeIfPresent(String.self, forKey: .linkURL)
        scheduleItems = try container.decodeIfPresent([PlanScheduleItem].self, forKey: .scheduleItems) ?? []
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        tagIDs = try container.decodeIfPresent([String].self, forKey: .tagIDs) ?? []
        recurrence = try container.decodeIfPresent(PlanRecurrence.self, forKey: .recurrence) ?? .none
        reminders = try container.decodeIfPresent([PlanReminder].self, forKey: .reminders)
        if let hex = try container.decodeIfPresent(String.self, forKey: .cardColorHex) {
            cardColor = Color(hex: hex)
        } else {
            cardColor = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(endDate, forKey: .endDate)
        try container.encode(places, forKey: .places)
        try container.encodeIfPresent(cardColorHex, forKey: .cardColorHex)
        try container.encodeIfPresent(localImageFileName, forKey: .localImageFileName)
        try container.encodeIfPresent(userId, forKey: .userId)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(planType, forKey: .planType)
        try container.encodeIfPresent(time, forKey: .time)
        try container.encodeIfPresent(endTime, forKey: .endTime)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(linkURL, forKey: .linkURL)
        try container.encode(scheduleItems, forKey: .scheduleItems)
        try container.encode(isCompleted, forKey: .isCompleted)
        try container.encode(tagIDs, forKey: .tagIDs)
        try container.encode(recurrence, forKey: .recurrence)
        try container.encodeIfPresent(reminders, forKey: .reminders)
    }
}

extension Color {
    init?(hex: String) {
        let r, g, b: CGFloat
        if hex.hasPrefix("#") {
            let start = hex.index(hex.startIndex, offsetBy: 1)
            let hexColor = String(hex[start...])
            if hexColor.count == 6 {
                let scanner = Scanner(string: hexColor)
                var hexNumber: UInt64 = 0
                if scanner.scanHexInt64(&hexNumber) {
                    r = CGFloat((hexNumber & 0xff0000) >> 16) / 255
                    g = CGFloat((hexNumber & 0x00ff00) >> 8) / 255
                    b = CGFloat(hexNumber & 0x0000ff) / 255
                    self.init(red: r, green: g, blue: b)
                    return
                }
            }
        }
        return nil
    }

    func toHex() -> String? {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r*255), Int(g*255), Int(b*255))
    }
}

// MARK: - 時刻の表示

extension Plan {
    /// 「14:00 〜 15:30」。終わりの時刻が無ければ開始だけを返す。
    /// 時刻そのものが無ければ nil（＝終日）
    var timeRangeText: String? {
        guard let time else { return nil }

        let start = DateFormatter.japaneseTime.string(from: time)
        guard let endTime else { return start }

        return start + " 〜 " + DateFormatter.japaneseTime.string(from: endTime)
    }
}

// MARK: - 複数日のスケジュール

extension Plan {
    /// 予定の日数（1始まり）
    var dayCount: Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: startDate),
            to: calendar.startOfDay(for: endDate)
        ).day ?? 0
        return max(days + 1, 1)
    }

    /// 2日以上にまたがるか。日付の選択欄や見出しを出すかの判定に使う
    var isMultiDay: Bool { dayCount > 1 }

    /// スケジュール項目が何日目かを返す（1始まり）。
    /// 日付を指定できなかった頃のデータは期間外の日付を持つため、1日目として扱う
    func dayNumber(for item: PlanScheduleItem) -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let itemDay = calendar.startOfDay(for: item.time)

        guard itemDay >= start else { return 1 }

        let diff = calendar.dateComponents([.day], from: start, to: itemDay).day ?? 0
        return min(diff + 1, dayCount)
    }

    /// 指定の日番号に対応する日付
    func date(forDay dayNumber: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: dayNumber - 1, to: startDate) ?? startDate
    }
}

// MARK: - Plan Type Color

extension PlanType {
    /// 種別の色。3つとも全テーマで同じ色を使う。
    /// 予定カードの小さなタグや点にだけ出るので、白黒テーマでも色が付いてよい
    func color(_ theme: ThemePreset) -> Color {
        switch self {
        case .outing:      return theme.outingPlanColor
        case .daily:       return theme.dailyPlanColor
        case .anniversary: return theme.anniversaryPlanColor
        }
    }
}
