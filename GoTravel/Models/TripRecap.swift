import Foundation

// MARK: - 旅が終わったあとの案内（Travory Pro）
//
// 旅行が終わった次に開いたとき、ホームで1回だけ「旅のダイジェスト」（`TripDigest`）を案内する。
// Pro の人にだけ出す（使えない機能の案内は出さない）

/// 旅行が終わったあと、ホームで1回だけ「振り返りを作る」を出す
enum TripRecapPrompt {

    static let dismissedKey = "tripRecapPromptDismissed"
    /// 終わってから何日まで出すか
    static let window = 7

    /// 案内する旅行（終わってから7日以内で、まだ案内を閉じていないもののうち、いちばん最近終わったもの）
    static func plan(in plans: [TravelPlan], dismissed: Set<String>, now: Date = Date(),
                     calendar: Calendar = .current) -> TravelPlan? {
        let today = calendar.startOfDay(for: now)
        return plans
            .filter { plan in
                guard let id = plan.id, !dismissed.contains(id) else { return false }
                let end = calendar.startOfDay(for: plan.endDate)
                guard end < today else { return false }
                let days = calendar.dateComponents([.day], from: end, to: today).day ?? 0
                return days <= window && !plan.daySchedulesInRange.flatMap(\.scheduleItems).isEmpty
            }
            .max { $0.endDate < $1.endDate }
    }

    static func loadDismissed(_ defaults: UserDefaults = .standard) -> Set<String> {
        Set(defaults.stringArray(forKey: dismissedKey) ?? [])
    }

    static func dismiss(planId: String, _ defaults: UserDefaults = .standard) {
        var set = loadDismissed(defaults)
        set.insert(planId)
        defaults.set(Array(set), forKey: dismissedKey)
    }
}
