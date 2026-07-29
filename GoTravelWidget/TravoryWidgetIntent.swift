import AppIntents
import WidgetKit

/// 小サイズとロック画面で、旅行と予定のどちらを表示するか
enum WidgetContentType: String, AppEnum {
    /// 先に来るほうを自動で選ぶ
    case automatic
    case travel
    case plan

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "表示する内容")
    }

    static var caseDisplayRepresentations: [WidgetContentType: DisplayRepresentation] {
        [
            .automatic: DisplayRepresentation(title: "自動", subtitle: "次に来るほうを表示"),
            .travel: DisplayRepresentation(title: "旅行", subtitle: "次の旅行までの日数や旅行中の予定"),
            .plan: DisplayRepresentation(title: "予定", subtitle: "おでかけ・日常の予定")
        ]
    }
}

/// ウィジェットを長押し →「ウィジェットを編集」で切り替えられる設定。
/// 小サイズとロック画面に効く。中サイズは常に旅行と予定の両方を並べる
struct TravoryWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "表示する内容" }

    static var description: IntentDescription {
        IntentDescription("旅行と予定のどちらを表示するか選びます。「自動」は次に来るほうを表示します。中サイズは常に両方表示されます。")
    }

    @Parameter(title: "表示する内容", default: .automatic)
    var contentType: WidgetContentType
}
