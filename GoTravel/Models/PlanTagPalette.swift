import SwiftUI

/// 予定タグの色。
///
/// 予定の分類はタグが主役で、種別（おでかけ／日常／記念日）は
/// 作るときに何を聞くかを決めるためだけのものになった。
/// そのため、以前まで一覧の見分けに使っていた種別色はここには関わらない。
///
/// 場所カテゴリー（`PlaceCategoryPalette`）とは別に持つ。
/// 予定と場所は同じ画面に並ばないので色が被っても混同しないし、
/// 片方の都合で色を足し引きしたときに、もう片方の既存の色が動くのを避けたい。
///
/// 色を出すのは小さな面（一覧のタグ・選択チップ）だけに限る。
/// カードの面や影に流すと、白黒テーマを選んだ人の一覧が色で埋まる
enum PlanTagPalette {

    struct Swatch: Identifiable, Equatable {
        let id: String
        let name: String
        let hex: String

        var color: Color { Color(hex: hex) ?? .gray }
    }

    /// 並び順がそのまま色を選ぶ画面の並びになる
    static let swatches: [Swatch] = [
        Swatch(id: "blue",   name: "ブルー",   hex: "#2F6FE0"),
        Swatch(id: "orange", name: "オレンジ", hex: "#EE8A21"),
        Swatch(id: "green",  name: "グリーン", hex: "#2E9E52"),
        Swatch(id: "purple", name: "パープル", hex: "#8558D6"),
        Swatch(id: "pink",   name: "ピンク",   hex: "#DD5397"),
        Swatch(id: "teal",   name: "ティール", hex: "#14A3A3"),
        Swatch(id: "red",    name: "レッド",   hex: "#DE4B4B"),
        Swatch(id: "yellow", name: "イエロー", hex: "#C9A227"),
        Swatch(id: "brown",  name: "ブラウン", hex: "#96684C"),
        Swatch(id: "gray",   name: "グレー",   hex: "#767E88")
    ]

    /// 作った順に頭から配る。最初の数個が全部同じ色になるのを避けるだけの用途
    static func hex(forIndex index: Int) -> String {
        swatches[abs(index) % swatches.count].hex
    }

    /// 色が決まっていないタグの色。
    /// IDから決めるので、タグを増やしても消しても既存の色が動かない
    static func fallbackHex(forTagId id: String) -> String {
        let stable = id.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        return swatches[stable % swatches.count].hex
    }
}
