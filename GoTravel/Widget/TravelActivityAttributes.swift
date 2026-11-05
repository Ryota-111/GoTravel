import Foundation
import ActivityKit
import AppIntents

/// 旅行中のライブアクティビティ（ロック画面・Dynamic Island・Apple Watch のスマートスタック）に出す中身。
///
/// アプリとウィジェットの両方で使う（ウィジェット側は project.pbxproj の membershipExceptions で取り込んでいる）。
///
/// ## 時刻が来たら次の予定に進める仕組み（サーバーなし）
///
/// ライブアクティビティは、ウィジェットのように時刻ごとの表示を前もって用意できず、
/// 書き換えにはアプリが動くかプッシュ通知（サーバー）が要る。Travory にはサーバーが無いので、
/// 1. 今日このあとの予定を**まとめて**渡しておき、表示する側がその時点の時刻で「次の予定」を選ぶ
/// 2. 次の予定に切り替える時刻を `staleDate` にして、その時刻にシステムに描き直させる
/// 3. それでも追いつかないときのために「更新」ボタン（`RefreshTravelActivityIntent`）を置く
///
/// システムが描き直すのは古くなった時点の1回だけなので、アプリが動かないまま予定が2つ以上進むと
/// 1つ遅れることがある。そのときは「更新」で直る
struct TravelActivityAttributes: ActivityAttributes, Equatable {

    struct ContentState: Codable, Hashable {
        /// 旅行の何日目か（1始まり）と、全部で何日か
        var dayNumber: Int
        var dayCount: Int
        /// 今日このあとの予定（時刻順、最大 `maxItems` 件）
        var items: [Entry]

        static let maxItems = 6

        /// 予定1件分
        struct Entry: Codable, Hashable {
            var title: String
            /// 場所など（予定の名前と同じなら入れない）
            var subtitle: String?
            /// 表示する時刻（"08:00"）。旅先の時計で組み立て済み。時刻の無い予定は nil
            var timeText: String?
            /// 起きる瞬間（時刻の無い予定は nil）
            var startsAt: Date?
            /// 「次の予定」として見せ終える瞬間。ここを過ぎたら次の予定に譲る
            var endsAt: Date?
        }

        /// `date` の時点で「次の予定」として見せるものの位置（無ければ nil）
        func currentIndex(at date: Date) -> Int? {
            items.firstIndex { ($0.endsAt ?? .distantFuture) > date }
        }
    }

    /// 旅行の名前と行き先。旅行が変わったら、ライブアクティビティを作り直す
    var travelTitle: String
    var destination: String?
}

// MARK: - 「更新」ボタン

/// ライブアクティビティの「更新」ボタン。押すとアプリが裏で起きて、いまの時刻で書き換える。
///
/// `LiveActivityIntent` の `perform` はアプリの中で動く（ウィジェットの中では動かない）。
/// ウィジェットにも型が要るので、中身はアプリが起動時に `TravelActivityRefresher.handler` に入れる
struct RefreshTravelActivityIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "旅行の予定を更新"
    static let description = IntentDescription("ライブアクティビティの「次の予定」を、いまの時刻に合わせて書き換えます。")
    static let isDiscoverable = false

    init() {}

    func perform() async throws -> some IntentResult {
        await TravelActivityRefresher.handler?()
        return .result()
    }
}

/// 「更新」ボタンで呼ぶ処理の差し込み口。アプリだけが中身を入れる（ウィジェットでは空のまま）
@MainActor
enum TravelActivityRefresher {
    static var handler: (@MainActor () async -> Void)?
}
