import Foundation
import Combine

// MARK: - 自分で足した「行った県」（3.1）
//
// 旅の記録は Travory で作った旅行から数えるので、アプリを使う前に行った県が入らなかった。
// 旅の記録の「＋ 行った県を足す」と、フォトマップの「カメラロールから自動追加」で足した県と、行った年を持つ。
// 小さなデータなので iCloud のキー・バリューの保存に置く（端末どうしで同期。CloudKit のスキーマは使わない）

/// 県（`Prefecture.rawValue`）→ 行った年。年が空なら「年は分からない」（「これまで全部」にだけ入る）
struct VisitedPrefectureRecords: Codable, Equatable {
    var years: [String: [Int]] = [:]

    var asDictionary: [Prefecture: Set<Int>] {
        var result: [Prefecture: Set<Int>] = [:]
        for (key, list) in years {
            if let prefecture = Prefecture(rawValue: key) { result[prefecture] = Set(list) }
        }
        return result
    }
}

@MainActor
final class VisitedPrefectureStore: ObservableObject {
    static let shared = VisitedPrefectureStore()

    /// 足した県と、行った年
    @Published private(set) var records: [Prefecture: Set<Int>] = [:]

    private static let key = "visitedPrefectures.v1"
    private let cloud = NSUbiquitousKeyValueStore.default
    private var observer: AnyCancellable?

    private init() {
        records = Self.load(from: cloud.data(forKey: Self.key) ?? UserDefaults.standard.data(forKey: Self.key))
        // ほかの端末で足した・外したら読み直す
        observer = NotificationCenter.default
            .publisher(for: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: cloud)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.records = Self.load(from: self.cloud.data(forKey: Self.key))
                UserDefaults.standard.set(self.cloud.data(forKey: Self.key), forKey: Self.key)
            }
        cloud.synchronize()
    }

    private static func load(from data: Data?) -> [Prefecture: Set<Int>] {
        guard let data, let decoded = try? JSONDecoder().decode(VisitedPrefectureRecords.self, from: data)
        else { return [:] }
        return decoded.asDictionary
    }

    private func save() {
        let encoded = VisitedPrefectureRecords(years: Dictionary(uniqueKeysWithValues: records.map {
            ($0.key.rawValue, $0.value.sorted())
        }))
        let data = try? JSONEncoder().encode(encoded)
        cloud.set(data, forKey: Self.key)
        // iCloud が使えないときのために、端末の中にも残す
        UserDefaults.standard.set(data, forKey: Self.key)
    }

    func contains(_ prefecture: Prefecture) -> Bool { records[prefecture] != nil }

    /// 行った県として足す。年は今までの年に足す（年が分からなければ空でよい）
    func add(_ prefecture: Prefecture, years: Set<Int> = []) {
        records[prefecture, default: []].formUnion(years)
        save()
    }

    /// 年を外す（県は残す。年がすべて無くなれば「年は分からない」）
    func removeYear(_ year: Int, from prefecture: Prefecture) {
        guard records[prefecture] != nil else { return }
        records[prefecture]?.remove(year)
        save()
    }

    /// 「行ったことにする」を取り消す。その年を外し、年が1つも残らなければ県ごと外す
    func undo(_ prefecture: Prefecture, years: Set<Int>) {
        guard var current = records[prefecture] else { return }
        current.subtract(years)
        records[prefecture] = current.isEmpty ? nil : current
        save()
    }

    /// フォトマップに写真がある県を、年は分からない行った県として足す（初めの1回だけ）。
    /// 外した県が、開くたびに戻ってこないようにする
    func importPhotoMapOnce(_ prefectures: Set<Prefecture>) {
        let key = "visitedPrefectures.importedPhotoMap.v1"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        for prefecture in prefectures where records[prefecture] == nil { records[prefecture] = [] }
        save()
    }

    /// 行った県から外す
    func remove(_ prefecture: Prefecture) {
        records[prefecture] = nil
        save()
    }
}
