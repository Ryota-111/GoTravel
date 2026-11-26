import Testing
import Foundation
@testable import GoTravel

/// 日程のスポットを場所保存に入れる（3.9、ご要望から）
struct ScheduleSpotToPlacesTests {

    private static let start = Date(timeIntervalSince1970: 1_790_000_000)
    private let categories = ["hotel", "restaurant", "sightseeing"]

    private func item(_ title: String, location: String? = nil, lat: Double? = 26.2124, lon: Double? = 127.6792,
                      hour: Double = 0) -> ScheduleItem {
        ScheduleItem(time: Self.start.addingTimeInterval(hour * 3600), title: title, location: location,
                     latitude: lat, longitude: lon)
    }

    private func trip(_ items: [ScheduleItem], day2: [ScheduleItem] = []) -> TravelPlan {
        TravelPlan(id: "t", title: "沖縄", startDate: Self.start, endDate: Self.start.addingTimeInterval(86_400),
                   destination: "沖縄",
                   daySchedules: [DaySchedule(dayNumber: 2, date: Self.start.addingTimeInterval(86_400), scheduleItems: day2),
                                  DaySchedule(dayNumber: 1, date: Self.start, scheduleItems: items)])
    }

    @Test("位置のある予定だけ入れられる。名前は場所の名前を先に使う")
    func onlyItemsWithLocation() {
        #expect(item("昼ごはん", location: "首里そば").scheduleSpot?.name == "首里そば")
        #expect(item("美ら海水族館").scheduleSpot?.name == "美ら海水族館")
        #expect(item("自由時間", lat: nil, lon: nil).scheduleSpot == nil)
        #expect(item("どこか", lat: 0, lon: 0).scheduleSpot == nil)

        var move = item("那覇 → 名護")
        move.move = ScheduleMove(mode: .bus, from: MovePlace(name: "那覇"), to: MovePlace(name: "名護"))
        #expect(move.scheduleSpot == nil)
    }

    @Test("旅行のスポットは日の順に、同じ場所は1回だけ")
    func tripSpotsInOrderWithoutDuplicates() {
        let plan = trip([item("首里城", lat: 26.217, lon: 127.719, hour: 2), item("国際通り", lat: 26.215, lon: 127.689, hour: 1)],
                        day2: [item("首里城（2回目）", lat: 26.2171, lon: 127.7191), item("美ら海", lat: 26.694, lon: 127.878)])
        #expect(plan.scheduleSpots.map(\.name) == ["国際通り", "首里城", "美ら海"])
    }

    @Test("場所保存にあるかどうかで、足す・「行った」に変える・何もしない")
    func outcomes() throws {
        let spot = try #require(item("美ら海水族館", lat: 26.6943, lon: 127.8779).scheduleSpot)
        let wish = VisitedPlace(id: "w", title: "美ら海", latitude: 26.6944, longitude: 127.8780, visitedAt: nil)
        let visited = VisitedPlace(id: "v", title: "美ら海", latitude: 26.6944, longitude: 127.8780, visitedAt: Self.start)
        let far = VisitedPlace(id: "f", title: "首里城", latitude: 26.217, longitude: 127.719)

        #expect(ScheduleSpotPlaces.outcome(spot, as: .wish, in: [far]) == .added)
        #expect(ScheduleSpotPlaces.outcome(spot, as: .wish, in: [wish]) == .alreadySaved)
        #expect(ScheduleSpotPlaces.outcome(spot, as: .visited, in: [wish]) == .markedVisited)
        #expect(ScheduleSpotPlaces.outcome(spot, as: .visited, in: [visited]) == .alreadySaved)
        #expect(ScheduleSpotPlaces.outcome(spot, as: .wish, in: [visited]) == .alreadySaved)
    }

    @Test("「行った」は予定の日を訪問日に、「行きたい」は訪問日なし。旅行とつなぐ")
    func makePlace() throws {
        let spot = try #require(item("美ら海水族館", hour: 3).scheduleSpot)
        let visited = ScheduleSpotPlaces.makePlace(spot, as: .visited, categoryIds: categories, travelPlanId: "t")
        #expect(visited.visitedAt == Self.start.addingTimeInterval(3 * 3600))
        #expect(visited.travelPlanId == "t")
        #expect(ScheduleSpotPlaces.makePlace(spot, as: .wish, categoryIds: categories, travelPlanId: nil).visitedAt == nil)
    }

    @Test("カテゴリーは名前から。無いカテゴリーなら先頭")
    func category() throws {
        func cat(_ name: String, _ ids: [String] = ["hotel", "restaurant", "sightseeing"]) throws -> String {
            ScheduleSpotPlaces.category(for: try #require(item(name).scheduleSpot), among: ids)
        }
        #expect(try cat("ホテル日航那覇") == "hotel")
        #expect(try cat("首里そば") == "restaurant")
        #expect(try cat("Blue Seal Cafe") == "restaurant")
        #expect(try cat("美ら海水族館") == "sightseeing")
        #expect(try cat("美ら海水族館", ["mine"]) == "mine")
    }

    @Test("知らせる一言")
    func messages() {
        typealias S = ScheduleSpotSaver.Summary
        #expect(S(added: 1).message(kind: .wish) == "場所保存の「行きたい」に入れました")
        #expect(S(markedVisited: 1).message(kind: .visited) == "場所保存で「行った」に変えました")
        #expect(S(alreadySaved: 2).message(kind: .wish) == "もう場所保存に入っています")
        #expect(S(added: 3, alreadySaved: 1).message(kind: .visited) == "3件を場所保存の「行った」に入れました（1件は入っていました）")
    }
}
