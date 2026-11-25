import Foundation
import Photos
import CoreLocation

/// 旅行計画なしで作る思い出（3.8）。
///
/// 写真コラージュ・旅行ポスター・旅行日記・旅のダイジェストは、どれも「旅行の期間に撮った写真」から作る。
/// 計画を立てずに出かけた人も使えるように、名前と期間（または自分で選んだ写真）だけを持つものを作り、
/// 作る画面には旅行の形（`plan`）にして渡す。作る画面のほうは、ふつうの旅行と同じに扱える。
///
/// 端末の中だけに持つ（作ったもの自体も端末の中に保存しているため。`MemoryStore`・`TripDigestLibrary`）
struct FreeMemory: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    /// 場所（任意）。ポスターの題などに使う
    var place: String
    var startDate: Date
    var endDate: Date
    /// 自分で選んだ写真・動画（カメラロールの id）。空なら、期間に撮ったものすべてから選ぶ
    var assetIds: [String]
    /// 写真の撮った場所（あれば。ポスターの緯度経度と英語の地名に使う）
    var latitude: Double?
    var longitude: Double?
    var createdAt: Date

    /// 選べる期間の長さの上限（日記のページとダイジェストのカードが、日数ぶんできるため）
    static let maxDays = 31
    /// id の頭。旅行の id と分けるため
    static let idPrefix = "free-"

    /// 作る画面に渡す旅行の形
    var plan: TravelPlan {
        TravelPlan(id: id, title: title, startDate: startDate, endDate: endDate, destination: place,
                   latitude: latitude, longitude: longitude, createdAt: createdAt)
    }
}

/// 旅行計画なしで作った思い出の一覧（UserDefaults に JSON で持つ）
enum FreeMemoryStore {
    private static let key = "FreeMemories"

    /// 新しい順
    static func all(defaults: UserDefaults = .standard) -> [FreeMemory] {
        guard let data = defaults.data(forKey: key),
              let items = try? JSONDecoder().decode([FreeMemory].self, from: data) else { return [] }
        return items.sorted { $0.createdAt > $1.createdAt }
    }

    static func save(_ memory: FreeMemory, defaults: UserDefaults = .standard) {
        var items = all(defaults: defaults).filter { $0.id != memory.id }
        items.append(memory)
        write(items, defaults: defaults)
    }

    /// 消す。作ったもの（コラージュ・ポスター・日記・ダイジェストの動画）も一緒に消す
    static func delete(id: String, defaults: UserDefaults = .standard) {
        write(all(defaults: defaults).filter { $0.id != id }, defaults: defaults)
        for kind in MemoryKind.allCases { MemoryStore.delete(planId: id, kind: kind) }
        for entry in TripDigestLibrary.entries(planId: id) { TripDigestLibrary.remove(entry) }
    }

    /// 旅行計画なしで作ったものか
    static func isFree(planId: String?) -> Bool {
        planId?.hasPrefix(FreeMemory.idPrefix) == true
    }

    /// 自分で選んだ写真だけで作るときの、その写真の id。期間で作るもの・ふつうの旅行は nil
    static func pickedAssetIds(planId: String?, defaults: UserDefaults = .standard) -> Set<String>? {
        guard isFree(planId: planId),
              let memory = all(defaults: defaults).first(where: { $0.id == planId }),
              !memory.assetIds.isEmpty else { return nil }
        return Set(memory.assetIds)
    }

    private static func write(_ items: [FreeMemory], defaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(items) { defaults.set(data, forKey: key) }
    }

    // MARK: カメラロール

    /// 選んだ写真の撮った日の範囲と、最初に見つかった撮った場所
    static func summary(of assetIds: [String]) -> (start: Date, end: Date, latitude: Double?, longitude: Double?)? {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: assetIds, options: nil)
        var dates: [Date] = []
        var location: CLLocationCoordinate2D?
        assets.enumerateObjects { asset, _, _ in
            if let date = asset.creationDate { dates.append(date) }
            if location == nil, let coordinate = asset.location?.coordinate { location = coordinate }
        }
        guard let start = dates.min(), let end = dates.max() else { return nil }
        return (start, end, location?.latitude, location?.longitude)
    }

    /// 期間に撮った写真・動画の数（スクリーンショットは除く）、見本に出す最初の数枚、最初に見つかった撮った場所
    static func photos(from start: Date, to end: Date, previewLimit: Int = 12,
                       calendar: Calendar = .current) -> (count: Int, previewIds: [String], latitude: Double?, longitude: Double?) {
        let from = calendar.startOfDay(for: start)
        guard let to = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: end)) else { return (0, [], nil, nil) }
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate < %@", from as NSDate, to as NSDate)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        var count = 0
        var previewIds: [String] = []
        var location: CLLocationCoordinate2D?
        PHAsset.fetchAssets(with: options).enumerateObjects { asset, _, _ in
            guard asset.mediaType == .image || asset.mediaType == .video,
                  !asset.mediaSubtypes.contains(.photoScreenshot) else { return }
            count += 1
            if previewIds.count < previewLimit, asset.mediaType == .image { previewIds.append(asset.localIdentifier) }
            if location == nil, let coordinate = asset.location?.coordinate { location = coordinate }
        }
        return (count, previewIds, location?.latitude, location?.longitude)
    }

    /// 表紙にする写真（選んだ写真の最初の1枚か、期間に撮った最初の写真）
    static func coverAssetId(for memory: FreeMemory, calendar: Calendar = .current) -> String? {
        if let first = memory.assetIds.first { return first }
        guard let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: memory.endDate)) else { return nil }
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate < %@ AND mediaType == %d",
                                        calendar.startOfDay(for: memory.startDate) as NSDate, end as NSDate,
                                        PHAssetMediaType.image.rawValue)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        options.fetchLimit = 1
        return PHAsset.fetchAssets(with: options).firstObject?.localIdentifier
    }

    /// 期間の日数（始まりと終わりの日を含む）
    static func dayCount(from start: Date, to end: Date, calendar: Calendar = .current) -> Int {
        (calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: end)).day ?? 0) + 1
    }
}
