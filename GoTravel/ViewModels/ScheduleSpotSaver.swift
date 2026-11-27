import Foundation
import CoreData

/// 日程のスポットを「場所保存」に入れる（3.9）。旅行とおでかけの両方から使う。
///
/// 重なりを確かめるためだけに `PlacesViewModel` の一覧（写真まで読む）を持つと重いので、
/// 保存済みの場所はここで Core Data から位置だけ読む
@MainActor
enum ScheduleSpotSaver {

    struct Summary: Equatable {
        var added = 0
        var markedVisited = 0
        var alreadySaved = 0

        /// 知らせる一言
        func message(kind: ScheduleSpotSaveKind) -> String {
            let place = kind == .wish ? "「行きたい」" : "「行った」"
            if added + markedVisited == 0 { return "もう場所保存に入っています" }
            if added + markedVisited + alreadySaved == 1 {
                return markedVisited == 1 ? "場所保存で「行った」に変えました" : "場所保存の\(place)に入れました"
            }
            var text = "\(added + markedVisited)件を場所保存の\(place)に入れました"
            if alreadySaved > 0 { text += "（\(alreadySaved)件は入っていました）" }
            return text
        }
    }

    /// 入れる。同じ場所が場所保存にあれば足さない。「行きたい」の場所を「行った」で入れたときは訪問日を付ける
    @discardableResult
    static func save(_ spots: [ScheduleSpot], as kind: ScheduleSpotSaveKind,
                     userId: String, travelPlanId: String?) -> Summary {
        var known = savedPlaces(userId: userId)
        let categoryIds = PlaceCategoryManager.shared.categories.map(\.id)
        let placesVM = PlacesViewModel()
        var summary = Summary()

        for spot in spots {
            switch ScheduleSpotPlaces.outcome(spot, as: kind, in: known) {
            case .added:
                let place = ScheduleSpotPlaces.makePlace(spot, as: kind, categoryIds: categoryIds,
                                                         travelPlanId: travelPlanId)
                placesVM.add(place, userId: userId)
                known.append(place)
                summary.added += 1
            case .markedVisited:
                guard var place = ScheduleSpotPlaces.existing(spot, in: known),
                      let index = known.firstIndex(where: { $0.id == place.id }) else { continue }
                place.visitedAt = spot.date
                placesVM.update(place, userId: userId)
                known[index] = place
                summary.markedVisited += 1
            case .alreadySaved:
                summary.alreadySaved += 1
            }
        }
        return summary
    }

    /// 保存してある場所（写真は読まない）
    static func savedPlaces(userId: String) -> [VisitedPlace] {
        let request: NSFetchRequest<VisitedPlaceEntity> = VisitedPlaceEntity.fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@", userId)
        let context = CoreDataManager.shared.viewContext
        return ((try? context.fetch(request)) ?? []).map { $0.toVisitedPlace() }
    }
}
