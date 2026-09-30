import Foundation
import Combine

/// 新しく作る予定に最初から入れておく通知。
///
/// **これは新規作成時にだけ使う。**
/// 作った時点で予定そのものに焼き込むので、あとからここを変えても、
/// すでにある予定の通知は変わらない。
///
/// 既存の予定にも遡って効かせる作りにすると、
/// 予約済みの通知は入れ直されないまま表示だけが変わり、
/// 画面に出ている内容と実際に鳴る通知が食い違う。
///
/// 保存先は端末（`ThemeManager` と同じ UserDefaults 方式）。
/// 予定に付いた通知そのものは Core Data 経由で同期されるので、
/// 端末ごとに好みの初期値を持っていても困らない
final class PlanReminderDefaults: ObservableObject {
    static let shared = PlanReminderDefaults()

    /// 設定を触っていないときに使う値。**これまでの動作と同じ組み合わせ**
    static func factory(for planType: PlanType) -> [PlanReminder] {
        // 時刻の有無で絞るのは `Plan.effectiveReminders` の仕事なので、
        // ここでは時刻ありの組み合わせを持っておく
        PlanReminder.defaults(for: planType, hasTime: true)
    }

    @Published private(set) var outing: [PlanReminder]
    @Published private(set) var daily: [PlanReminder]
    @Published private(set) var anniversary: [PlanReminder]

    private static func key(for planType: PlanType) -> String {
        "plan_reminder_defaults_\(planType.rawValue)_v1"
    }

    private init() {
        outing = Self.load(for: .outing)
        daily = Self.load(for: .daily)
        anniversary = Self.load(for: .anniversary)
    }

    private static func load(for planType: PlanType) -> [PlanReminder] {
        guard let raw = UserDefaults.standard.array(forKey: key(for: planType)) as? [String] else {
            return factory(for: planType)
        }

        // 並びは選んだ順ではなく鳴る順で持つ
        let stored = Set(raw.compactMap { PlanReminder(rawValue: $0) })
        return PlanReminder.allCases.filter { stored.contains($0) }
    }

    func reminders(for planType: PlanType) -> [PlanReminder] {
        switch planType {
        case .outing:      return outing
        case .daily:       return daily
        case .anniversary: return anniversary
        }
    }

    func setReminders(_ reminders: [PlanReminder], for planType: PlanType) {
        let ordered = PlanReminder.allCases.filter { reminders.contains($0) }

        switch planType {
        case .outing:      outing = ordered
        case .daily:       daily = ordered
        case .anniversary: anniversary = ordered
        }

        UserDefaults.standard.set(ordered.map(\.rawValue), forKey: Self.key(for: planType))
    }

    /// 種別ごとに初期状態へ戻す
    func reset(_ planType: PlanType) {
        UserDefaults.standard.removeObject(forKey: Self.key(for: planType))

        let value = Self.factory(for: planType)
        switch planType {
        case .outing:      outing = value
        case .daily:       daily = value
        case .anniversary: anniversary = value
        }
    }

    /// 初期状態から変えられているか。設定画面で「戻す」を出すかの判定に使う
    func isCustomized(_ planType: PlanType) -> Bool {
        reminders(for: planType) != Self.factory(for: planType)
    }
}
