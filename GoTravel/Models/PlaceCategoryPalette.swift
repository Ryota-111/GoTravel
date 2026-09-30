import SwiftUI

/// 場所カテゴリーの色。
///
/// 以前は予定の種別色（おでかけ=青／日常=オレンジ）と旅行の緑を借りていた。
/// 別の意味の色を流用すると、増やしたときに割り当てる色が尽きるうえ、
/// 白黒テーマではテーマ側のカテゴリ色が全部黒で、
/// **自分で追加したカテゴリーだけ見分けがつかなくなっていた。**
///
/// ここで場所専用の色を決め、テーマに関係なく同じ色を使う。
/// 種別のタグと同じく、色を出すのは小さな面（タイル・タグ・ピン）だけ
enum PlaceCategoryPalette {

    struct Swatch: Identifiable, Equatable {
        let id: String
        let name: String
        let hex: String

        var color: Color { Color(hex: hex) ?? .gray }
    }

    /// 既定カテゴリーの色。ユーザーは変えられない
    static func defaultHex(forCategoryId id: String) -> String? {
        switch id {
        case "hotel":       return "#2F6FE0"   // ブルー
        case "restaurant":  return "#EE8A21"   // オレンジ
        case "sightseeing": return "#2E9E52"   // グリーン
        default:            return nil
        }
    }

    /// カスタムカテゴリーで選べる色。並び順がそのまま選択画面の並びになる。
    ///
    /// **既定の3色（ブルー・オレンジ・グリーン）は入れていない。**
    /// 同じ色を選べると、一覧や地図のピンで
    /// 自分で作ったカテゴリーがホテル・レストラン・風景に見えてしまう。
    /// 抜いた3つのぶんは、色数が減らないよう別の色を足してある
    static let swatches: [Swatch] = [
        Swatch(id: "teal",   name: "ティール", hex: "#14A3A3"),
        Swatch(id: "lime",   name: "ライム",   hex: "#7DA82B"),
        Swatch(id: "yellow", name: "イエロー", hex: "#C9A227"),
        Swatch(id: "red",    name: "レッド",   hex: "#DE4B4B"),
        Swatch(id: "wine",   name: "ワイン",   hex: "#8E3A5A"),
        Swatch(id: "pink",   name: "ピンク",   hex: "#DD5397"),
        Swatch(id: "purple", name: "パープル", hex: "#8558D6"),
        Swatch(id: "brown",  name: "ブラウン", hex: "#96684C"),
        Swatch(id: "gray",   name: "グレー",   hex: "#767E88")
    ]

    /// 色を選ばずに作られたカテゴリーの色。
    /// IDから決めるので、増やしても消しても既存の色が動かない
    static func fallbackHex(forCategoryId id: String) -> String {
        let stable = id.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        return swatches[stable % swatches.count].hex
    }
}
