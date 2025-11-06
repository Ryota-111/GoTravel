import Foundation
import UserNotifications

class NotificationService {
    static let shared = NotificationService()

    private init() {}

    // 明示的にgregorianカレンダーを使用し、現在のタイムゾーンを設定
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        return cal
    }

    // MARK: - Authorization
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    // MARK: - Travel Plan Notifications
    func scheduleTravelPlanNotifications(for plan: TravelPlan) {
        guard let planId = plan.id else { return }

        cancelTravelPlanNotifications(for: planId)

        let now = Date()

        // 1週間前の通知
        if let oneWeekBefore = calendar.date(byAdding: .day, value: -7, to: plan.startDate) {
            // 1週間前の日付に10:00の時刻を設定
            var components = calendar.dateComponents(in: TimeZone.current, from: oneWeekBefore)
            components.hour = 10
            components.minute = 0
            components.second = 0

            if let scheduledDate = calendar.date(from: components), scheduledDate > now {
                scheduleNotification(
                    id: "\(planId)_week",
                    title: "旅行が1週間後に迫っています",
                    body: "\(plan.title)への旅行が1週間後です。準備を始めましょう！",
                    dateComponents: components
                )
            }
        }

        // 1日前の通知
        if let oneDayBefore = calendar.date(byAdding: .day, value: -1, to: plan.startDate) {
            // 1日前の日付に18:00の時刻を設定
            var components = calendar.dateComponents(in: TimeZone.current, from: oneDayBefore)
            components.hour = 18
            components.minute = 0
            components.second = 0

            if let scheduledDate = calendar.date(from: components), scheduledDate > now {
                scheduleNotification(
                    id: "\(planId)_day",
                    title: "旅行が明日です",
                    body: "\(plan.title)への旅行が明日です。忘れ物がないか確認しましょう！",
                    dateComponents: components
                )
            }
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

        let now = Date()

        switch plan.planType {
        case .outing:
            // おでかけプランの1日前通知
            if let oneDayBefore = calendar.date(byAdding: .day, value: -1, to: plan.startDate) {
                var components = calendar.dateComponents(in: TimeZone.current, from: oneDayBefore)
                components.hour = 19
                components.minute = 0
                components.second = 0

                if let scheduledDate = calendar.date(from: components), scheduledDate > now {
                    scheduleNotification(
                        id: "\(plan.id)_day",
                        title: "おでかけが明日です",
                        body: "\(plan.title)が明日です。楽しみですね！",
                        dateComponents: components
                    )
                }
            }

        case .daily:
            // 日常プランの1日前通知
            if let oneDayBefore = calendar.date(byAdding: .day, value: -1, to: plan.startDate) {
                var components = calendar.dateComponents(in: TimeZone.current, from: oneDayBefore)
                components.hour = 19
                components.minute = 0
                components.second = 0

                if let scheduledDate = calendar.date(from: components), scheduledDate > now {
                    scheduleNotification(
                        id: "\(plan.id)_day",
                        title: "予定が明日です",
                        body: "\(plan.title)が明日です。準備をお忘れなく！",
                        dateComponents: components
                    )
                }
            }

            // 時刻指定がある場合の通知
            if let time = plan.time {
                // plan.timeから時刻情報を取得
                let timeComponents = calendar.dateComponents([.hour, .minute], from: time)

                // plan.startDateの日付部分と、plan.timeの時刻部分を組み合わせる
                var eventDateComponents = calendar.dateComponents(in: TimeZone.current, from: plan.startDate)
                eventDateComponents.hour = timeComponents.hour
                eventDateComponents.minute = timeComponents.minute
                eventDateComponents.second = 0

                guard let eventDate = calendar.date(from: eventDateComponents) else {
                    return
                }

                // 1時間前の通知
                if let oneHourBefore = calendar.date(byAdding: .hour, value: -1, to: eventDate) {
                    if oneHourBefore > now {
                        var components = calendar.dateComponents(in: TimeZone.current, from: oneHourBefore)
                        components.second = 0

                        scheduleNotification(
                            id: "\(plan.id)_hour",
                            title: "予定が1時間後です",
                            body: "\(plan.title)が1時間後に始まります。",
                            dateComponents: components
                        )
                    }
                }

                // 10分前の通知
                if let tenMinutesBefore = calendar.date(byAdding: .minute, value: -10, to: eventDate) {
                    if tenMinutesBefore > now {
                        var components = calendar.dateComponents(in: TimeZone.current, from: tenMinutesBefore)
                        components.second = 0

                        scheduleNotification(
                            id: "\(plan.id)_10min",
                            title: "予定が10分後です",
                            body: "\(plan.title)が10分後に始まります。準備してください！",
                            dateComponents: components
                        )
                    }
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
    private func scheduleNotification(id: String, title: String, body: String, dateComponents: DateComponents) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        // DateComponentsに必要な情報が揃っているか確認
        guard dateComponents.year != nil,
              dateComponents.month != nil,
              dateComponents.day != nil,
              dateComponents.hour != nil,
              dateComponents.minute != nil else {
            return
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            // Silent fail
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
