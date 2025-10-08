import Foundation
import UserNotifications

class NotificationService {
    static let shared = NotificationService()

    private init() {}

    // MARK: - Authorization
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("通知権限リクエストエラー: \(error.localizedDescription)")
            }
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    // MARK: - Travel Plan Notifications
    func scheduleTravelPlanNotifications(for plan: TravelPlan) {
        guard let planId = plan.id else { return }

        print("🔔 旅行計画の通知をスケジュール: \(plan.title)")
        print("   開始日: \(plan.startDate)")

        cancelTravelPlanNotifications(for: planId)

        let calendar = Calendar.current
        let now = Date()

        if let oneWeekBefore = calendar.date(byAdding: .day, value: -7, to: plan.startDate) {
            var components = calendar.dateComponents([.year, .month, .day], from: oneWeekBefore)
            components.hour = 10
            components.minute = 0

            if let scheduledDate = calendar.date(from: components), scheduledDate > now {
                print("   📅 1週間前の通知をスケジュール: \(scheduledDate)")
                scheduleNotification(
                    id: "\(planId)_week",
                    title: "旅行が1週間後に迫っています",
                    body: "\(plan.title)への旅行が1週間後です。準備を始めましょう！",
                    date: oneWeekBefore,
                    hour: 10,
                    minute: 0
                )
            } else {
                print("   ⏭️ 1週間前の通知は過去のためスキップ")
            }
        }

        if let oneDayBefore = calendar.date(byAdding: .day, value: -1, to: plan.startDate) {
            var components = calendar.dateComponents([.year, .month, .day], from: oneDayBefore)
            components.hour = 18
            components.minute = 0

            if let scheduledDate = calendar.date(from: components), scheduledDate > now {
                print("   📅 1日前の通知をスケジュール: \(scheduledDate)")
                scheduleNotification(
                    id: "\(planId)_day",
                    title: "旅行が明日です",
                    body: "\(plan.title)への旅行が明日です。忘れ物がないか確認しましょう！",
                    date: oneDayBefore,
                    hour: 18,
                    minute: 0
                )
            } else {
                print("   ⏭️ 1日前の通知は過去のためスキップ")
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.listPendingNotifications()
        }
    }

    func cancelTravelPlanNotifications(for planId: String) {
        let identifiers = [
            "\(planId)_week",
            "\(planId)_day"
        ]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    // MARK: - Plan Notifications
    func schedulePlanNotifications(for plan: Plan) {

        cancelPlanNotifications(for: plan.id)

        let calendar = Calendar.current

        switch plan.planType {
        case .outing:
            if let oneDayBefore = calendar.date(byAdding: .day, value: -1, to: plan.startDate) {
                scheduleNotification(
                    id: "\(plan.id)_day",
                    title: "おでかけが明日です",
                    body: "\(plan.title)が明日です。楽しみですね！",
                    date: oneDayBefore,
                    hour: 18,
                    minute: 0
                )
            }

        case .daily:
            if let oneDayBefore = calendar.date(byAdding: .day, value: -1, to: plan.startDate) {
                scheduleNotification(
                    id: "\(plan.id)_day",
                    title: "予定が明日です",
                    body: "\(plan.title)が明日です。準備をお忘れなく！",
                    date: oneDayBefore,
                    hour: 18,
                    minute: 0
                )
            }

            if let time = plan.time {
                if let oneHourBefore = calendar.date(byAdding: .hour, value: -1, to: time) {
                    let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: oneHourBefore)
                    scheduleNotificationWithComponents(
                        id: "\(plan.id)_hour",
                        title: "予定が1時間後です",
                        body: "\(plan.title)が1時間後に始まります。",
                        dateComponents: components
                    )
                }

                if let tenMinutesBefore = calendar.date(byAdding: .minute, value: -10, to: time) {
                    let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: tenMinutesBefore)
                    scheduleNotificationWithComponents(
                        id: "\(plan.id)_10min",
                        title: "予定が10分後です",
                        body: "\(plan.title)が10分後に始まります。準備してください！",
                        dateComponents: components
                    )
                }
            }
        }
    }

    func cancelPlanNotifications(for planId: String) {
        let identifiers = [
            "\(planId)_day",
            "\(planId)_hour",
            "\(planId)_10min"
        ]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    // MARK: - Helper Methods
    private func scheduleNotification(id: String, title: String, body: String, date: Date, hour: Int, minute: Int) {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute

        scheduleNotificationWithComponents(id: id, title: title, body: body, dateComponents: components)
    }

    private func scheduleNotificationWithComponents(id: String, title: String, body: String, dateComponents: DateComponents) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("通知スケジュールエラー (\(id)): \(error.localizedDescription)")
            } else {
                print("✅ 通知をスケジュール: \(id) - \(title)")
            }
        }
    }

    // MARK: - Debug
    func listPendingNotifications(completion: @escaping () -> Void = {}) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            print("📱 保留中の通知: \(requests.count)件")
            for request in requests {
                print("  - \(request.identifier): \(request.content.title)")
                if let trigger = request.trigger as? UNCalendarNotificationTrigger,
                   let nextTriggerDate = trigger.nextTriggerDate() {
                    print("    実行予定: \(nextTriggerDate)")
                } else {
                    print("    トリガー情報なし")
                }
            }
            completion()
        }
    }

    func checkAuthorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus)
            }
        }
    }
}
