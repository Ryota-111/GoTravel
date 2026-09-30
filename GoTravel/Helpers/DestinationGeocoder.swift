import Foundation
import MapKit

/// 目的地の文字列から座標を引く。
///
/// 旅行計画の作成画面と基本情報の編集画面で同じことをするため、ここにまとめる。
/// 呼ぶ側は `Task` を持っておき、次の入力が来たら `cancel()` すること。
enum DestinationGeocoder {

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
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        try? await Task.sleep(nanoseconds: debounce)
        guard !Task.isCancelled else { return nil }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed

        let response = try? await MKLocalSearch(request: request).start()
        return response?.mapItems.first?.placemark.coordinate
    }
}
