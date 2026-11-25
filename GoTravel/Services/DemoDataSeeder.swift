#if DEBUG
import Foundation
import SwiftUI
import UIKit
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
        // 起動引数 `-TravoryDemoToday 2026-11-22` で、見本の「今日」を決められる（カメラロールの見本の写真の日付に合わせるため）
        let anchor: Date = {
            guard let text = UserDefaults.standard.string(forKey: "TravoryDemoToday") else { return Date() }
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.date(from: text) ?? Date()
        }()
        let today = calendar.startOfDay(for: anchor)
        func day(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: offset, to: today)! }
        func time(_ date: Date, _ hour: Int, _ minute: Int = 0) -> Date {
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date)!
        }

        // 写真（起動引数 `-TravoryDemoPhotosDir <フォルダ>` の jpg。無ければ写真なし）。Documents に写して名前を返す
        func cover(_ name: String) -> String? {
            guard let image = demoImage(name), let data = image.jpegData(compressionQuality: 0.85) else { return nil }
            let fileName = "demo_\(name).jpg"
            try? data.write(to: FileManager.documentsDirectory().appendingPathComponent(fileName), options: .atomic)
            return fileName
        }

        let okinawa = TravelPlan(
            id: "demo-okinawa", title: "沖縄 3泊4日", startDate: day(0), endDate: day(3), destination: "沖縄",
            latitude: 26.2124, longitude: 127.6809, localImageFileName: cover("okinawa_cover"),
            cardColor: Color(red: 0.16, green: 0.55, blue: 0.85), userId: userId,
            daySchedules: [
                DaySchedule(dayNumber: 1, date: day(0), scheduleItems: [
                    ScheduleItem(time: time(day(0), 7), title: "羽田空港を出発", location: "羽田空港 第2ターミナル", cost: 24800),
                    ScheduleItem(time: time(day(0), 10, 30), title: "レンタカーを借りる", location: "那覇空港", latitude: 26.2066, longitude: 127.6465, cost: 18000),
                    ScheduleItem(time: time(day(0), 12, 30), title: "国際通りで沖縄そば", location: "国際通り", notes: "ソーキそばが人気の店", latitude: 26.2155, longitude: 127.6855, cost: 2400),
                    ScheduleItem(time: time(day(0), 15), title: "ホテルにチェックイン", location: "ハレクラニ沖縄", latitude: 26.4864, longitude: 127.8508, cost: 96000),
                    ScheduleItem(time: time(day(0), 18, 30), title: "海を見ながら夕食", location: "恩納村", latitude: 26.474, longitude: 127.825, cost: 8000)
                ]),
                DaySchedule(dayNumber: 2, date: day(1), scheduleItems: [
                    ScheduleItem(time: time(day(1), 9), title: "美ら海水族館", location: "沖縄美ら海水族館", latitude: 26.6943, longitude: 127.8779, cost: 4360),
                    ScheduleItem(time: time(day(1), 12), title: "備瀬のフクギ並木", location: "備瀬", latitude: 26.7008, longitude: 127.8806),
                    ScheduleItem(time: time(day(1), 14), title: "古宇利島ドライブ", location: "古宇利大橋", latitude: 26.693, longitude: 128.017),
                    ScheduleItem(time: time(day(1), 17, 30), title: "サンセットビーチ", location: "瀬底ビーチ", latitude: 26.646, longitude: 127.854)
                ]),
                DaySchedule(dayNumber: 3, date: day(2), scheduleItems: [
                    ScheduleItem(time: time(day(2), 9, 30), title: "シュノーケリング", location: "青の洞窟", latitude: 26.444, longitude: 127.77, cost: 9000),
                    ScheduleItem(time: time(day(2), 15), title: "首里城", location: "首里城公園", latitude: 26.217, longitude: 127.7195, cost: 800),
                    ScheduleItem(time: time(day(2), 19), title: "居酒屋で泡盛", location: "那覇・栄町", latitude: 26.2214, longitude: 127.702, cost: 6000)
                ]),
                DaySchedule(dayNumber: 4, date: day(3), scheduleItems: [
                    ScheduleItem(time: time(day(3), 10), title: "お土産を買う", location: "牧志公設市場", latitude: 26.2144, longitude: 127.6905),
                    ScheduleItem(time: time(day(3), 11, 30), title: "レンタカーを返す", location: "那覇空港", latitude: 26.2066, longitude: 127.6465),
                    ScheduleItem(time: time(day(3), 13, 20), title: "那覇空港を出発", location: "那覇空港", latitude: 26.2066, longitude: 127.6465)
                ])
            ],
            packingItems: [
                PackingItem(name: "水着", isChecked: true), PackingItem(name: "日焼け止め", isChecked: true),
                PackingItem(name: "サングラス", isChecked: true), PackingItem(name: "充電器"), PackingItem(name: "免許証"),
                PackingItem(name: "サンダル"), PackingItem(name: "ラッシュガード"),
                PackingItem(name: "紅いもタルト", kind: .souvenir, recipient: "職場"),
                PackingItem(name: "ちんすこう", kind: .souvenir, recipient: "職場"),
                PackingItem(name: "泡盛", kind: .souvenir, recipient: "父"),
                PackingItem(name: "シーサーの置物", kind: .souvenir, recipient: "母"),
                PackingItem(name: "ジンベエザメを見る", isChecked: true, kind: .wish),
                PackingItem(name: "青の洞窟でシュノーケリング", kind: .wish),
                PackingItem(name: "ブルーシールのアイス", kind: .wish)
            ],
            reservations: [
                Reservation(kind: .flight, title: "ANA 993便", date: time(day(0), 7), confirmationNumber: "8K2M4Q",
                            transportNumber: "NH993", departurePlace: "羽田", arrivalPlace: "那覇",
                            arrivalDate: time(day(0), 9, 45), seat: "23A", cost: 24800),
                Reservation(kind: .hotel, title: "ハレクラニ沖縄", date: time(day(0), 15), confirmationNumber: "HK-58213",
                            endDate: time(day(3), 11), cost: 96000),
                Reservation(kind: .rentalCar, title: "OTSレンタカー", date: time(day(0), 10, 30), confirmationNumber: "R2611-0482",
                            endDate: time(day(3), 11, 30), cost: 18000),
                Reservation(kind: .flight, title: "ANA 998便", date: time(day(3), 13, 20), confirmationNumber: "8K2M4Q",
                            transportNumber: "NH998", departurePlace: "那覇", arrivalPlace: "羽田",
                            arrivalDate: time(day(3), 15, 45), seat: "23A", cost: 23900)
            ],
            memos: [TripMemo(title: "Wi-Fi", body: "ホテルのWi-Fiはフロントでパスワードをもらう"),
                    TripMemo(title: "集合", body: "羽田 第2ターミナル 出発ロビー 6:30")])
        let kyoto = TravelPlan(
            id: "demo-kyoto", title: "京都 紅葉めぐり", startDate: day(18), endDate: day(19), destination: "京都",
            latitude: 35.0116, longitude: 135.7681, localImageFileName: cover("kyoto_cover"),
            cardColor: Color(red: 0.86, green: 0.36, blue: 0.22), userId: userId,
            daySchedules: [DaySchedule(dayNumber: 1, date: day(18), scheduleItems: [
                ScheduleItem(time: time(day(18), 8), title: "新幹線で京都へ", location: "東京駅", cost: 14170),
                ScheduleItem(time: time(day(18), 11), title: "清水寺", location: "清水寺", cost: 500),
                ScheduleItem(time: time(day(18), 13), title: "湯豆腐ランチ", location: "南禅寺 順正", cost: 3300),
                ScheduleItem(time: time(day(18), 15), title: "永観堂の紅葉", location: "永観堂", cost: 1000)
            ]), DaySchedule(dayNumber: 2, date: day(19), scheduleItems: [
                ScheduleItem(time: time(day(19), 9), title: "嵐山の竹林", location: "竹林の小径"),
                ScheduleItem(time: time(day(19), 12), title: "金閣寺", location: "鹿苑寺", cost: 500),
                ScheduleItem(time: time(day(19), 17), title: "新幹線で東京へ", location: "京都駅", cost: 14170)
            ])],
            packingItems: [PackingItem(name: "カメラ"), PackingItem(name: "歩きやすい靴"), PackingItem(name: "八ツ橋", kind: .souvenir, recipient: "職場")])
        let sapporo = TravelPlan(
            id: "demo-sapporo", title: "札幌 雪まつり", startDate: day(-40), endDate: day(-38), destination: "札幌",
            latitude: 43.0618, longitude: 141.3545, localImageFileName: cover("sapporo_cover"),
            cardColor: Color(red: 0.35, green: 0.45, blue: 0.75), userId: userId,
            daySchedules: [DaySchedule(dayNumber: 1, date: day(-40), scheduleItems: [
                ScheduleItem(time: time(day(-40), 12), title: "大通公園", location: "大通公園"),
                ScheduleItem(time: time(day(-40), 18), title: "スープカレー", location: "すすきの", cost: 1600)
            ])])
        let osaka = TravelPlan(
            id: "demo-osaka", title: "大阪 食べ歩き", startDate: day(-75), endDate: day(-74), destination: "大阪",
            latitude: 34.6687, longitude: 135.5013, localImageFileName: cover("osaka_cover"),
            cardColor: Color(red: 0.9, green: 0.45, blue: 0.3), userId: userId,
            daySchedules: [DaySchedule(dayNumber: 1, date: day(-75), scheduleItems: [
                ScheduleItem(time: time(day(-75), 12), title: "道頓堀でたこ焼き", location: "道頓堀", cost: 800)
            ])])
        let hakone = TravelPlan(
            id: "demo-hakone", title: "箱根 温泉旅行", startDate: day(45), endDate: day(46), destination: "箱根",
            latitude: 35.2324, longitude: 139.1069, localImageFileName: cover("hakone_cover"),
            cardColor: Color(red: 0.3, green: 0.6, blue: 0.55), userId: userId,
            daySchedules: [DaySchedule(dayNumber: 1, date: day(45), scheduleItems: [
                ScheduleItem(time: time(day(45), 10), title: "ロマンスカーで箱根へ", location: "新宿駅", cost: 2470),
                ScheduleItem(time: time(day(45), 15), title: "旅館にチェックイン", location: "強羅", cost: 38000)
            ])])
        for plan in [okinawa, kyoto, sapporo, osaka, hakone] { _ = TravelPlanEntity.create(from: plan, context: context) }
        // 旅の思い出は、起動のたびにはじめから作る（前に撮ったときの文字やテンプレートが残らないように）
        for plan in [okinawa, kyoto, sapporo, osaka, hakone] {
            for kind in MemoryKind.allCases { MemoryStore.delete(planId: plan.id ?? "", kind: kind) }
        }
        // 旅行計画なしで作ったもの（3.8）も、撮るたびに消す
        for memory in FreeMemoryStore.all() { FreeMemoryStore.delete(id: memory.id) }

        let plans = [
            Plan(title: "鎌倉さんぽ", startDate: day(5), endDate: day(5), places: [],
                 cardColor: Color(red: 0.2, green: 0.65, blue: 0.5), localImageFileName: cover("kamakura"),
                 userId: userId, planType: .outing, time: time(day(5), 10),
                 scheduleItems: [PlanScheduleItem(time: time(day(5), 10), title: "鎌倉大仏"),
                                 PlanScheduleItem(time: time(day(5), 12), title: "しらす丼"),
                                 PlanScheduleItem(time: time(day(5), 14), title: "江ノ島")]),
            Plan(title: "友達とカフェ", startDate: day(8), endDate: day(8), places: [],
                 cardColor: Color(red: 0.75, green: 0.5, blue: 0.35), localImageFileName: cover("cafe"),
                 userId: userId, planType: .outing, time: time(day(8), 14)),
            Plan(title: "お寿司ディナー", startDate: day(12), endDate: day(12), places: [],
                 cardColor: Color(red: 0.85, green: 0.35, blue: 0.4), localImageFileName: cover("sushi"),
                 userId: userId, planType: .outing, time: time(day(12), 19)),
            Plan(title: "映画", startDate: day(2), endDate: day(2), places: [],
                 cardColor: Color(red: 0.6, green: 0.4, blue: 0.8), userId: userId, planType: .outing, time: time(day(2), 19)),
            Plan(title: "歯医者", startDate: day(1), endDate: day(1), places: [],
                 cardColor: Color(red: 0.9, green: 0.55, blue: 0.2), userId: userId, planType: .daily, time: time(day(1), 16, 30)),
            Plan(title: "美容院", startDate: day(6), endDate: day(6), places: [],
                 cardColor: Color(red: 0.95, green: 0.5, blue: 0.6), userId: userId, planType: .daily, time: time(day(6), 11)),
            Plan(title: "ジム", startDate: day(0), endDate: day(0), places: [],
                 cardColor: Color(red: 0.3, green: 0.6, blue: 0.9), userId: userId, planType: .daily, time: time(day(0), 20))
        ]
        for plan in plans { _ = PlanEntity.create(from: plan, context: context) }

        // 今月の前半にも、こなした予定を並べる（カレンダーが使っている感じになるように）
        let past: [(Int, String, PlanType, Int, Color)] = [
            (-21, "ジム", .daily, 20, Color(red: 0.3, green: 0.6, blue: 0.9)), (-19, "ランチ会", .outing, 12, Color(red: 0.95, green: 0.6, blue: 0.3)),
            (-17, "歯医者", .daily, 16, Color(red: 0.9, green: 0.55, blue: 0.2)), (-14, "ジム", .daily, 20, Color(red: 0.3, green: 0.6, blue: 0.9)),
            (-13, "高尾山ハイキング", .outing, 8, Color(red: 0.2, green: 0.65, blue: 0.5)), (-11, "飲み会", .outing, 19, Color(red: 0.85, green: 0.35, blue: 0.4)),
            (-9, "美術館", .outing, 13, Color(red: 0.6, green: 0.4, blue: 0.8)), (-7, "ジム", .daily, 20, Color(red: 0.3, green: 0.6, blue: 0.9)),
            (-6, "誕生日会", .outing, 18, Color(red: 0.95, green: 0.5, blue: 0.6)), (-4, "買い物", .daily, 15, Color(red: 0.75, green: 0.5, blue: 0.35)),
            (-2, "ヨガ", .daily, 9, Color(red: 0.4, green: 0.7, blue: 0.6)), (-1, "旅行の準備", .daily, 21, Color(red: 0.16, green: 0.55, blue: 0.85))
        ]
        for item in past {
            let plan = Plan(title: item.1, startDate: day(item.0), endDate: day(item.0), places: [], cardColor: item.4,
                            userId: userId, planType: item.2, time: time(day(item.0), item.3), isCompleted: true)
            _ = PlanEntity.create(from: plan, context: context)
        }

        let places = [
            VisitedPlace(id: "demo-p1", title: "沖縄美ら海水族館", notes: "ジンベエザメが目の前を泳いでいた", latitude: 26.6943, longitude: 127.8779,
                         visitedAt: day(-200), localPhotoFileName: cover("p_churaumi"),
                         address: "沖縄県国頭郡本部町石川424", categoryId: "sightseeing", userId: userId),
            VisitedPlace(id: "demo-p2", title: "ブルーボトルコーヒー 清澄白河", notes: "カフェラテがおいしい", latitude: 35.6802, longitude: 139.7996,
                         visitedAt: day(-30), localPhotoFileName: cover("p_cafe"),
                         address: "東京都江東区平野1-4-8", categoryId: "restaurant", userId: userId),
            VisitedPlace(id: "demo-p3", title: "伏見稲荷大社", latitude: 34.9671, longitude: 135.7727,
                         visitedAt: day(-90), localPhotoFileName: cover("p_inari"),
                         address: "京都府京都市伏見区深草藪之内町68", categoryId: "sightseeing", userId: userId),
            VisitedPlace(id: "demo-p5", title: "道頓堀", latitude: 34.6687, longitude: 135.5013,
                         visitedAt: day(-75), localPhotoFileName: cover("p_dotonbori"),
                         address: "大阪府大阪市中央区道頓堀", categoryId: "sightseeing", userId: userId),
            VisitedPlace(id: "demo-p4", title: "一蘭 渋谷店", notes: "友達のおすすめ", latitude: 35.6614, longitude: 139.7011,
                         localPhotoFileName: cover("p_ramen"),
                         address: "東京都渋谷区神南1-22-7", categoryId: "restaurant", userId: userId),
            VisitedPlace(id: "demo-p6", title: "嵐山 竹林の小径", latitude: 35.0170, longitude: 135.6713,
                         localPhotoFileName: cover("p_arashiyama"),
                         address: "京都府京都市右京区嵯峨天龍寺芒ノ馬場町", categoryId: "sightseeing", userId: userId),
            VisitedPlace(id: "demo-p7", title: "河口湖から見る富士山", latitude: 35.5163, longitude: 138.7519,
                         localPhotoFileName: cover("p_fuji"),
                         address: "山梨県南都留郡富士河口湖町", categoryId: "sightseeing", userId: userId),
            VisitedPlace(id: "demo-p8", title: "永観堂", notes: "紅葉のライトアップ", latitude: 35.0145, longitude: 135.7942,
                         localPhotoFileName: cover("p_eikando"),
                         address: "京都府京都市左京区永観堂町48", categoryId: "sightseeing", userId: userId),
            VisitedPlace(id: "demo-p9", title: "ハレクラニ沖縄", latitude: 26.4920, longitude: 127.8540,
                         localPhotoFileName: cover("p_resort"),
                         address: "沖縄県国頭郡恩納村名嘉真1967-1", categoryId: "hotel", userId: userId),
            VisitedPlace(id: "demo-p10", title: "首里城公園", latitude: 26.2170, longitude: 127.7195,
                         localPhotoFileName: cover("p_shuri"),
                         address: "沖縄県那覇市首里金城町1-2", categoryId: "sightseeing", userId: userId)
        ]
        for place in places { _ = VisitedPlaceEntity.create(from: place, context: context) }

        CoreDataManager.shared.saveContext()
        seedAlbums(userId: userId, context: context)
    }

    /// 見本の写真（`-TravoryDemoPhotosDir` のフォルダの `<名前>.jpg`）
    static func demoImage(_ name: String) -> UIImage? {
        guard let directory = UserDefaults.standard.string(forKey: "TravoryDemoPhotosDir"), !directory.isEmpty else { return nil }
        return UIImage(contentsOfFile: (directory as NSString).appendingPathComponent("\(name).jpg"))
    }

    /// 思い出タブの表紙を確かめるためのアルバム（3.8）。写真1〜4枚のアルバムと、写真の入ったフォトマップ。
    /// 写真は色の帯を描いた絵（実際の写真は使わない）
    private static func seedAlbums(userId: String, context: NSManagedObjectContext) {
        let palette: [(UIColor, UIColor)] = [
            (.systemTeal, .systemBlue), (.systemOrange, .systemPink), (.systemGreen, .systemTeal),
            (.systemIndigo, .systemPurple), (.systemYellow, .systemOrange), (.systemBlue, .systemIndigo)
        ]
        func photo(_ index: Int) -> UIImage {
            let colors = palette[index % palette.count]
            return UIGraphicsImageRenderer(size: CGSize(width: 600, height: 450)).image { ctx in
                let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                          colors: [colors.0.cgColor, colors.1.cgColor] as CFArray, locations: [0, 1])!
                ctx.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 600, y: 450), options: [])
                UIColor.white.withAlphaComponent(0.35).setFill()
                ctx.cgContext.fillEllipse(in: CGRect(x: 380, y: 60, width: 120, height: 120))
            }
        }

        let japan = Album(id: "demo-japan", title: AlbumType.japan.title, coverColor: AlbumType.japan.coverColor,
                          icon: AlbumType.japan.icon, isDefaultAlbum: true, type: .japan, userId: userId)
        _ = AlbumEntity.create(from: japan, context: context)
        let manager = AlbumManager.shared

        // 写真があるときは、旅行のアルバムに本物らしい写真を入れる。無ければ色の帯の見本
        if demoImage("a_sap1") != nil {
            let samples: [(id: String, title: String, planId: String?, photos: [String])] = [
                ("demo-a1", "札幌 雪まつり", "demo-sapporo", ["sapporo_cover", "a_sap1", "a_sap2", "a_sap3", "a_sap4"]),
                ("demo-a2", "大阪 食べ歩き", "demo-osaka", ["osaka_cover", "p_dotonbori", "j_tokyo"]),
                ("demo-a3", "京都 2025秋", nil, ["p_eikando", "p_inari", "p_arashiyama", "kyoto_cover"]),
                ("demo-a4", "カフェめぐり", nil, ["p_cafe", "cafe"])
            ]
            for (index, sample) in samples.enumerated() {
                let album = Album(id: sample.id, title: sample.title, coverColor: palette[index].0.swiftUIColor,
                                  icon: "photo.on.rectangle.angled", travelPlanId: sample.planId,
                                  type: sample.planId == nil ? .custom : .travel, userId: userId)
                _ = AlbumEntity.create(from: album, context: context)
            }
            CoreDataManager.shared.saveContext()
            for sample in samples { manager.addPhotos(sample.photos.compactMap(demoImage), to: sample.id) }
            let prefectures: [(Prefecture, String)] = [(.hokkaido, "sapporo_cover"), (.tokyo, "j_tokyo"), (.kyoto, "kyoto_cover"),
                                                       (.osaka, "osaka_cover"), (.kanagawa, "j_kanagawa"), (.yamanashi, "j_yamanashi"),
                                                       (.okinawa, "j_okinawa"), (.shizuoka, "hakone_cover")]
            for (prefecture, name) in prefectures {
                if let image = demoImage(name) { _ = manager.addJapanPhotos([image], prefecture: prefecture, to: japan.id) }
            }
            return
        }

        let samples: [(String, Int)] = [("demo-a1", 1), ("demo-a2", 2), ("demo-a3", 3), ("demo-a4", 5)]
        for (index, sample) in samples.enumerated() {
            let album = Album(id: sample.0, title: "写真\(sample.1)枚のアルバム", coverColor: palette[index].0.swiftUIColor,
                              icon: "photo.on.rectangle.angled", type: .custom, userId: userId)
            _ = AlbumEntity.create(from: album, context: context)
        }
        CoreDataManager.shared.saveContext()

        for sample in samples {
            manager.addPhotos((0..<sample.1).map { photo($0 + sample.1) }, to: sample.0)
        }
        for (index, prefecture) in [Prefecture.hokkaido, .tokyo, .kyoto, .osaka, .fukuoka, .okinawa, .nagano].enumerated() {
            _ = manager.addJapanPhotos([photo(index)], prefecture: prefecture, to: japan.id)
        }
    }
}

private extension UIColor {
    var swiftUIColor: Color { Color(self) }
}
#endif
