import Foundation
import MapKit
import Combine

/// 旅行の目的地の文字列から座標を引く。
///
/// 新規作成と編集の両方で使う。同じ処理を2か所に置いていたので、
/// 片方だけ直す事故を防ぐためにここへまとめた。
enum DestinationGeocoder {

    /// 見つかった行き先。`label` は「パリ（フランス）」「愛媛県 八幡浜市（日本）」のような、どこかが分かる名前
    struct Match: Equatable {
        var coordinate: CLLocationCoordinate2D
        var label: String

        static func == (lhs: Match, rhs: Match) -> Bool {
            lhs.label == rhs.label
                && lhs.coordinate.latitude == rhs.coordinate.latitude
                && lhs.coordinate.longitude == rhs.coordinate.longitude
        }
    }

    /// 入力が止まってから1回だけ検索する。
    ///
    /// 1文字ごとに投げると、Apple の検索の利用制限に当たって途中から
    /// 応答が返らなくなる。さらに「北」の結果が「北海道」の後に返ると
    /// 古いほうで上書きされ、打つ速さで結果が変わってしまう。
    ///
    /// 見つからなければ nil を返す。呼ぶ側はこれで座標を消すこと。
    /// 前の目的地の座標を残すと「位置情報を取得しました」と出たまま
    /// 中身が別の場所になる
    static func coordinate(for query: String, debounce: UInt64 = 500_000_000) async -> CLLocationCoordinate2D? {
        await match(for: query, debounce: debounce)?.coordinate
    }

    /// 行き先を探す。見つかった場所の名前も返す（3.4。合っているか確かめられるように出す）。
    ///
    /// Apple の検索は今いる場所の近くを優先するので、外れることがある（日本で「ロンドン」と打つと、
    /// 愛媛県の同じ名前のお店になった）。地名だけに絞ると「USJ」が京都府宇治市になるなど、かえって外れた。
    /// なので、ここは今までどおり1つ探して名前を出し、確かな行き先は候補から選んでもらう（`DestinationSuggestions`）
    static func match(for query: String, debounce: UInt64 = 500_000_000) async -> Match? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        try? await Task.sleep(nanoseconds: debounce)
        guard !Task.isCancelled else { return nil }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        guard let item = try? await MKLocalSearch(request: request).start().mapItems.first else { return nil }
        return Match(coordinate: item.placemark.coordinate, label: label(of: item.placemark, name: item.name))
    }

    /// 候補から選んだ行き先の座標と名前
    static func match(for completion: MKLocalSearchCompletion) async -> Match? {
        let request = MKLocalSearch.Request(completion: completion)
        guard let item = try? await MKLocalSearch(request: request).start().mapItems.first else { return nil }
        return Match(coordinate: item.placemark.coordinate, label: label(of: item.placemark, name: item.name))
    }

    /// 保存してある座標が、どこを指しているか（編集の画面で、合っているか確かめられるように）
    static func label(of coordinate: CLLocationCoordinate2D) async -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first else { return nil }
        return label(of: placemark, name: nil)
    }

    /// 世界全体。行き先は海外のことも多いので、今いる場所の近くに寄せない
    static let worldRegion = MKCoordinateRegion(MKMapRect.world)

    /// 「パリ（フランス）」「愛媛県 八幡浜市（日本）」「ホノルル（アメリカ合衆国 HI）」
    static func label(of placemark: CLPlacemark, name: String?) -> String {
        label(name: name, locality: placemark.locality, area: placemark.administrativeArea, country: placemark.country)
    }

    static func label(name: String?, locality: String?, area: String?, country: String?) -> String {
        // 県と市が同じ名前（「ソウル特別市 ソウル特別市」）は1つにする
        var parts: [String] = []
        for part in [area, locality].compactMap({ $0 }) where !part.isEmpty && !parts.contains(part) {
            parts.append(part)
        }
        var place = parts.joined(separator: " ")
        // 施設なら、その名前を先に出す（「ロンドン（愛媛県 八幡浜市・日本）」）
        if let name, !name.isEmpty, !parts.contains(name), name != country {
            place = place.isEmpty ? name : "\(name)・\(place)"
        }
        guard let country, !country.isEmpty else { return place }
        if place.isEmpty { return country }
        return "\(place)（\(country)）"
    }
}

/// 行き先を打っているあいだの候補（3.4）。
///
/// 自動で1つ選ぶだけでは、本当に合っているか分からない（「ロンドン」が愛媛県のお店になっていた）。
/// 国や地域の添え書き付きで並べ、自分で選べるようにする
@MainActor
final class DestinationSuggestions: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published private(set) var results: [MKLocalSearchCompletion] = []

    /// 地名（国・都市・県）と施設を別々に探し、地名を先に並べる。
    /// 1つにまとめて探すと、近くのお店（大阪の「ソウル」という店など）ばかりが並び、都市が出なかった
    private let places = MKLocalSearchCompleter()
    private let spots = MKLocalSearchCompleter()
    private var placeResults: [MKLocalSearchCompletion] = []
    private var spotResults: [MKLocalSearchCompletion] = []
    /// 候補から選んだあと、入った名前のままなら候補を出し直さない
    private var pickedTitle: String?

    /// 一度に出す候補の数。多いと日付の入力などが画面の下へ押し出される
    nonisolated static let limit = 6
    /// そのうち施設に使う数（地名が少ないときは、そのぶん施設を足す）
    nonisolated static let spotLimit = 2

    override init() {
        super.init()
        for (completer, types) in [(places, MKLocalSearchCompleter.ResultType.address), (spots, .pointOfInterest)] {
            completer.delegate = self
            completer.resultTypes = types
            completer.region = DestinationGeocoder.worldRegion
        }
    }

    /// 打った文字が変わったとき
    func update(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == pickedTitle {
            clear()
            if trimmed.isEmpty { places.cancel(); spots.cancel() }
            return
        }
        pickedTitle = nil
        places.queryFragment = trimmed
        spots.queryFragment = trimmed
    }

    /// 候補を選んだ。入る名前（`completion.title`）では候補を出し直さない
    func didPick(_ completion: MKLocalSearchCompletion) {
        pickedTitle = completion.title
        clear()
        places.cancel()
        spots.cancel()
    }

    /// 候補を閉じる（次へ進むときなど）
    func clear() {
        placeResults = []
        spotResults = []
        results = []
    }

    /// 地名を先に、施設を後ろに。同じ名前・添え書きは1つにする
    static func merged(places: [MKLocalSearchCompletion], spots: [MKLocalSearchCompletion]) -> [MKLocalSearchCompletion] {
        var seen = Set<String>()
        func unique(_ list: [MKLocalSearchCompletion]) -> [MKLocalSearchCompletion] {
            list.filter { seen.insert("\($0.title)|\($0.subtitle)").inserted }
        }
        let placePart = unique(places)
        let spotRoom = max(spotLimit, limit - placePart.count)
        let spotPart = Array(unique(spots).prefix(spotRoom))
        return Array((Array(placePart.prefix(limit - min(spotPart.count, spotLimit))) + spotPart).prefix(limit))
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let latest = completer.results
        Task { @MainActor in
            // 選んだあとに遅れて届いた候補は出さない
            guard self.pickedTitle == nil else { return }
            if completer === self.places { self.placeResults = latest } else { self.spotResults = latest }
            self.results = Self.merged(places: self.placeResults, spots: self.spotResults)
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            if completer === self.places { self.placeResults = [] } else { self.spotResults = [] }
            self.results = Self.merged(places: self.placeResults, spots: self.spotResults)
        }
    }
}
