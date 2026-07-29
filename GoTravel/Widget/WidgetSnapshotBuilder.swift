import Foundation
import WidgetKit

/// アプリ側のデータからウィジェット用スナップショットを作り、共有領域へ書き出す。
/// 表示の優先順位は「旅行中の今日の予定」→「次の旅行までのカウントダウン」→「次の予定」。
enum WidgetSnapshotBuilder {

    /// ウィジェットが同時に見せる件数より多めに保存しておく。
    /// 時刻を過ぎた予定はウィジェット側で順に消えていくため、
    /// 表示件数ぴったりだと途中で「予定なし」になってしまう
    private static let maxUpcomingPlans = 12
    private static let maxTodayItems = 8

    @MainActor
    static func update(travelPlans: [TravelPlan], plans: [Plan]) {
        let snapshot = build(travelPlans: travelPlans, plans: plans)

        // 中身が変わっていないなら書き込みもリロードもしない
        guard snapshot != WidgetDataStore.load() else { return }

        WidgetDataStore.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func build(travelPlans: [TravelPlan], plans: [Plan], now: Date = Date()) -> WidgetSnapshot {
        var snapshot = WidgetSnapshot()
        snapshot.updatedAt = now
        snapshot.prefectureCount = JapanPhotoManager.shared.photoCount

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)

        // 進行中を優先し、無ければ今後の旅行のうち最も近いもの
        let ongoing = travelPlans.first { plan in
            let start = calendar.startOfDay(for: plan.startDate)
            let end = calendar.startOfDay(for: plan.endDate)
            return start <= today && end >= today
        }
        let upcomingTravel = travelPlans
            .filter { calendar.startOfDay(for: $0.startDate) > today }
            .min { $0.startDate < $1.startDate }

        if let travel = ongoing ?? upcomingTravel {
            snapshot.travelTitle = travel.title
            snapshot.travelDestination = travel.destination
            snapshot.travelStartDate = travel.startDate
            snapshot.travelEndDate = travel.endDate
            snapshot.isTravelOngoing = (ongoing != nil)

            if ongoing != nil {
                snapshot.todayItems = todaySchedule(of: travel, on: now)
            }
        }

        snapshot.upcomingPlans = upcomingPlanItems(from: plans, now: now)
        return snapshot
    }

    // MARK: - Helpers

    /// 旅行中の当日にあたる日程のスケジュールを時刻順で返す
    private static func todaySchedule(of travel: TravelPlan, on now: Date) -> [WidgetSnapshot.Item] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)

        let dayNumber = (calendar.dateComponents([.day], from: calendar.startOfDay(for: travel.startDate), to: today).day ?? 0) + 1

        guard let daySchedule = travel.daySchedules.first(where: { $0.dayNumber == dayNumber }) else {
            return []
        }

        return daySchedule.scheduleItems
            .sorted { minutes(of: $0.time) < minutes(of: $1.time) }
            .prefix(maxTodayItems)
            .map { item in
                WidgetSnapshot.Item(
                    id: item.id,
                    date: now,
                    time: item.time,
                    title: item.title,
                    subtitle: item.location
                )
            }
    }

    /// 今日以降の予定を日付順に返す
    private static func upcomingPlanItems(from plans: [Plan], now: Date) -> [WidgetSnapshot.Item] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)

        return plans
            .filter { plan in
                guard calendar.startOfDay(for: plan.endDate) >= today else { return false }

                // 今日の予定で、すでに時刻を過ぎているものは出さない
                if let time = plan.time,
                   calendar.startOfDay(for: plan.startDate) == today {
                    let components = calendar.dateComponents([.hour, .minute], from: time)
                    let todayAtTime = calendar.date(
                        bySettingHour: components.hour ?? 0,
                        minute: components.minute ?? 0,
                        second: 0,
                        of: now
                    ) ?? now
                    return todayAtTime >= now
                }

                return true
            }
            .sorted { lhs, rhs in
                let lDay = calendar.startOfDay(for: lhs.startDate)
                let rDay = calendar.startOfDay(for: rhs.startDate)
                if lDay != rDay { return lDay < rDay }
                return minutes(of: lhs.time) < minutes(of: rhs.time)
            }
            .prefix(maxUpcomingPlans)
            .map { plan in
                // 進行中の期間プランは今日として扱い、未来のものは開始日を見せる
                let displayDate = calendar.startOfDay(for: plan.startDate) < today ? now : plan.startDate

                return WidgetSnapshot.Item(
                    id: plan.id,
                    date: displayDate,
                    time: plan.planType == .daily ? plan.time : nil,
                    title: plan.title,
                    subtitle: plan.planType == .daily ? "日常" : "おでかけ"
                )
            }
    }

    /// 日付部分を無視して時刻だけで比較するための分換算
    private static func minutes(of date: Date?) -> Int {
        guard let date else { return 0 }
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}
