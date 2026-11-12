#if DEBUG
import Foundation
import SwiftUI
import CoreData

/// 画面を確かめるための見本データ（開発用のビルドだけ）。
///
/// 起動引数 `-TravoryEmptyDataMode -TravoryDemoData -appleSignInUserId demo -hasCompletedOnboarding YES`
/// で起動すると、メモリの中だけに旅行計画・予定・場所を作る。
/// 空データモードのとき以外は何もしないので、実データに混ざることはない
enum DemoDataSeeder {
    static func seedIfRequested() {
        guard CoreDataManager.isEmptyDataMode,
              ProcessInfo.processInfo.arguments.contains("-TravoryDemoData"),
              let userId = UserDefaults.standard.string(forKey: "appleSignInUserId") else { return }
        let context = CoreDataManager.shared.viewContext
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        func day(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: offset, to: today)! }
        func time(_ date: Date, _ hour: Int, _ minute: Int = 0) -> Date {
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date)!
        }

        let okinawa = TravelPlan(
            id: "demo-okinawa", title: "沖縄 3泊4日", startDate: day(0), endDate: day(3), destination: "沖縄",
            latitude: 26.2124, longitude: 127.6809, cardColor: Color(red: 0.16, green: 0.55, blue: 0.85), userId: userId,
            daySchedules: [
                DaySchedule(dayNumber: 1, date: day(0), scheduleItems: [
                    ScheduleItem(time: time(day(0), 7), title: "羽田空港を出発", location: "羽田空港 第2ターミナル", cost: 24800),
                    ScheduleItem(time: time(day(0), 10, 30), title: "レンタカーを借りる", location: "那覇空港", cost: 18000),
                    ScheduleItem(time: time(day(0), 12, 30), title: "国際通りでお昼", location: "国際通り", notes: "タコライスの店", cost: 2400),
                    ScheduleItem(time: time(day(0), 15), title: "ホテルにチェックイン", location: "ハレクラニ沖縄", cost: 96000),
                    ScheduleItem(time: time(day(0), 18, 30), title: "夕食", location: "恩納村", cost: 8000)
                ]),
                DaySchedule(dayNumber: 2, date: day(1), scheduleItems: [
                    ScheduleItem(time: time(day(1), 9), title: "美ら海水族館", location: "沖縄美ら海水族館", cost: 4360),
                    ScheduleItem(time: time(day(1), 13), title: "古宇利島", location: "古宇利大橋"),
                    ScheduleItem(time: time(day(1), 17), title: "サンセットビーチ", location: "瀬底ビーチ")
                ]),
                DaySchedule(dayNumber: 3, date: day(2), scheduleItems: [
                    ScheduleItem(time: time(day(2), 10), title: "首里城", location: "首里城公園", cost: 800)
                ]),
                DaySchedule(dayNumber: 4, date: day(3), scheduleItems: [
                    ScheduleItem(time: time(day(3), 11), title: "レンタカーを返す", location: "那覇空港"),
                    ScheduleItem(time: time(day(3), 13, 20), title: "那覇空港を出発", location: "那覇空港")
                ])
            ],
            packingItems: [
                PackingItem(name: "水着", isChecked: true), PackingItem(name: "日焼け止め", isChecked: true),
                PackingItem(name: "充電器"), PackingItem(name: "免許証"), PackingItem(name: "サンダル"),
                PackingItem(name: "紅いもタルト", kind: .souvenir, recipient: "職場"),
                PackingItem(name: "泡盛", kind: .souvenir, recipient: "父")
            ])
        let kyoto = TravelPlan(
            id: "demo-kyoto", title: "京都 紅葉めぐり", startDate: day(18), endDate: day(19), destination: "京都",
            latitude: 35.0116, longitude: 135.7681, cardColor: Color(red: 0.86, green: 0.36, blue: 0.22), userId: userId,
            daySchedules: [DaySchedule(dayNumber: 1, date: day(18), scheduleItems: [
                ScheduleItem(time: time(day(18), 9), title: "清水寺", location: "清水寺", cost: 500),
                ScheduleItem(time: time(day(18), 14), title: "嵐山", location: "渡月橋")
            ]), DaySchedule(dayNumber: 2, date: day(19))])
        let sapporo = TravelPlan(
            id: "demo-sapporo", title: "札幌 雪まつり", startDate: day(-40), endDate: day(-38), destination: "札幌",
            latitude: 43.0618, longitude: 141.3545, cardColor: Color(red: 0.35, green: 0.45, blue: 0.75), userId: userId,
            daySchedules: [DaySchedule(dayNumber: 1, date: day(-40), scheduleItems: [
                ScheduleItem(time: time(day(-40), 12), title: "大通公園", location: "大通公園")
            ])])
        for plan in [okinawa, kyoto, sapporo] { _ = TravelPlanEntity.create(from: plan, context: context) }

        let plans = [
            Plan(title: "鎌倉さんぽ", startDate: day(5), endDate: day(5), places: [],
                 cardColor: Color(red: 0.2, green: 0.65, blue: 0.5), userId: userId, planType: .outing, time: time(day(5), 10)),
            Plan(title: "映画", startDate: day(2), endDate: day(2), places: [],
                 cardColor: Color(red: 0.6, green: 0.4, blue: 0.8), userId: userId, planType: .outing, time: time(day(2), 19)),
            Plan(title: "歯医者", startDate: day(1), endDate: day(1), places: [],
                 cardColor: Color(red: 0.9, green: 0.55, blue: 0.2), userId: userId, planType: .daily, time: time(day(1), 16, 30)),
            Plan(title: "ジム", startDate: day(0), endDate: day(0), places: [],
                 cardColor: Color(red: 0.3, green: 0.6, blue: 0.9), userId: userId, planType: .daily, time: time(day(0), 20))
        ]
        for plan in plans { _ = PlanEntity.create(from: plan, context: context) }

        let places = [
            VisitedPlace(id: "demo-p1", title: "沖縄美ら海水族館", notes: "ジンベエザメ", latitude: 26.6943, longitude: 127.8779,
                         visitedAt: day(-200), address: "沖縄県国頭郡本部町石川424", categoryId: "sightseeing", userId: userId),
            VisitedPlace(id: "demo-p2", title: "ブルーボトルコーヒー 清澄白河", latitude: 35.6802, longitude: 139.7996,
                         visitedAt: day(-30), address: "東京都江東区平野1-4-8", categoryId: "cafe", userId: userId),
            VisitedPlace(id: "demo-p3", title: "伏見稲荷大社", latitude: 34.9671, longitude: 135.7727,
                         visitedAt: day(-90), address: "京都府京都市伏見区深草藪之内町68", categoryId: "sightseeing", userId: userId),
            VisitedPlace(id: "demo-p4", title: "一蘭 渋谷店", latitude: 35.6614, longitude: 139.7011,
                         address: "東京都渋谷区神南1-22-7", categoryId: "restaurant", userId: userId)
        ]
        for place in places { _ = VisitedPlaceEntity.create(from: place, context: context) }

        CoreDataManager.shared.saveContext()
    }
}
#endif
