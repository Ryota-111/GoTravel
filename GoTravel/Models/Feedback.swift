import Foundation

/// アプリ内から送ってもらう意見の種別
enum FeedbackKind: String, CaseIterable, Identifiable {
    case request
    case bug
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .request: return "欲しい機能"
        case .bug: return "不具合の報告"
        case .other: return "その他"
        }
    }

    var icon: String {
        switch self {
        case .request: return "lightbulb.fill"
        case .bug: return "ladybug.fill"
        case .other: return "bubble.left.fill"
        }
    }

    /// 何を書けばいいか分からずに送信をやめてしまうのを防ぐための例文
    var placeholder: String {
        switch self {
        case .request:
            return "例）旅行の予定をカレンダーアプリにも入れたい\n\nどんな場面で使いたいかも書いていただけると、優先して検討できます。"
        case .bug:
            return "例）予定を保存しても一覧に出てこないことがある\n\nどの画面で、どんな操作をしたときに起きるかを書いていただけると助かります。"
        case .other:
            return "ご自由にお書きください。"
        }
    }
}
