import SwiftUI
import UIKit

/// テーマの「色以外」。書体・角丸・影・罫線。
///
/// 色だけではテーマの違いが出しきれないので、形と書体もトークンにする。
/// これを一度足しておけば、以降のテーマは1組の値を書くだけで増やせる。
struct ThemeStyle {

    // MARK: - 角丸
    enum Radius {
        case small     // チップ、小さなボタン
        case medium    // 行、入力欄
        case large     // カード
    }

    var radiusSmall: CGFloat
    var radiusMedium: CGFloat
    var radiusLarge: CGFloat

    // MARK: - 罫線
    /// 0 にすると縁を描かない
    var borderWidth: CGFloat

    // MARK: - 影
    /// 0 で影なし、1 で標準の濃さ。色は ThemePreset.shadow を使う
    var shadowStrength: CGFloat
    var shadowRadius: CGFloat
    var shadowY: CGFloat

    // MARK: - 書体
    /// システムフォントの表情。同梱フォントが無くても違いを出せる
    var fontDesign: Font.Design
    /// 見出し用の同梱フォント名。未同梱なら nil のままにする
    var displayFontName: String?
    /// 本文用の同梱フォント名。未同梱なら nil のままにする
    var bodyFontName: String?

    func radius(_ r: Radius) -> CGFloat {
        switch r {
        case .small: return radiusSmall
        case .medium: return radiusMedium
        case .large: return radiusLarge
        }
    }

    // MARK: - 既定値
    /// 既存テーマの見た目を変えないための基準値
    static let standard = ThemeStyle(
        radiusSmall: 8, radiusMedium: 12, radiusLarge: 16,
        borderWidth: 1,
        shadowStrength: 1, shadowRadius: 10, shadowY: 5,
        fontDesign: .default,
        displayFontName: nil, bodyFontName: nil
    )

    static func forType(_ type: ThemePreset.ThemeType) -> ThemeStyle {
        switch type {
        // 既存の3つは今の見た目のまま据え置く
        case .originalColor, .whiteBlack, .pastelPink:
            return .standard

        // 和のテーマは明朝寄りに。墨は影を捨てて罫線で区切る
        case .aiKinari:
            return ThemeStyle(
                radiusSmall: 7, radiusMedium: 11, radiusLarge: 15,
                borderWidth: 1,
                shadowStrength: 0.7, shadowRadius: 12, shadowY: 5,
                fontDesign: .serif,
                displayFontName: nil, bodyFontName: nil
            )

        case .sumi:
            return ThemeStyle(
                radiusSmall: 4, radiusMedium: 6, radiusLarge: 8,
                borderWidth: 1,
                shadowStrength: 0, shadowRadius: 0, shadowY: 0,
                fontDesign: .serif,
                displayFontName: nil, bodyFontName: nil
            )

        case .momiji:
            return ThemeStyle(
                radiusSmall: 8, radiusMedium: 12, radiusLarge: 16,
                borderWidth: 1,
                shadowStrength: 0.8, shadowRadius: 12, shadowY: 5,
                fontDesign: .serif,
                displayFontName: nil, bodyFontName: nil
            )

        // やわらかいものは丸く
        case .sakura:
            return ThemeStyle(
                radiusSmall: 11, radiusMedium: 16, radiusLarge: 22,
                borderWidth: 0,
                shadowStrength: 0.8, shadowRadius: 14, shadowY: 6,
                fontDesign: .rounded,
                displayFontName: nil, bodyFontName: nil
            )

        case .setouchi:
            return ThemeStyle(
                radiusSmall: 10, radiusMedium: 15, radiusLarge: 20,
                borderWidth: 0,
                shadowStrength: 0.6, shadowRadius: 14, shadowY: 6,
                fontDesign: .rounded,
                displayFontName: nil, bodyFontName: nil
            )

        // 雪国は影をほとんど消して、余白で区切る
        case .yukiguni:
            return ThemeStyle(
                radiusSmall: 9, radiusMedium: 14, radiusLarge: 18,
                borderWidth: 1,
                shadowStrength: 0.25, shadowRadius: 8, shadowY: 3,
                fontDesign: .default,
                displayFontName: nil, bodyFontName: nil
            )

        case .yakouRessha:
            return ThemeStyle(
                radiusSmall: 7, radiusMedium: 11, radiusLarge: 14,
                borderWidth: 1,
                shadowStrength: 1, shadowRadius: 14, shadowY: 6,
                fontDesign: .default,
                displayFontName: nil, bodyFontName: nil
            )

        // ここから下は形と書体で個性を出すテーマ。
        // 同梱フォント名を指定してあるが、未同梱なら fontDesign に落ちる。

        case .retroTravel:
            // 切符と印刷物。角は控えめ、縁は太く、影は薄く
            return ThemeStyle(
                radiusSmall: 5, radiusMedium: 8, radiusLarge: 11,
                borderWidth: 1.5,
                shadowStrength: 0.35, shadowRadius: 8, shadowY: 3,
                fontDesign: .serif,
                displayFontName: "ZenAntique-Regular",
                bodyFontName: "ZenKakuGothicNew-Regular"
            )

        case .guidebook:
            // 紙の地図。罫線で区切る印刷物の作り
            return ThemeStyle(
                radiusSmall: 5, radiusMedium: 8, radiusLarge: 11,
                borderWidth: 1,
                shadowStrength: 0.4, shadowRadius: 8, shadowY: 3,
                fontDesign: .default,
                displayFontName: nil,
                bodyFontName: "ZenKakuGothicNew-Medium"
            )

        case .passport:
            // 旅券。角ばって、箔押しの縁
            return ThemeStyle(
                radiusSmall: 3, radiusMedium: 5, radiusLarge: 8,
                borderWidth: 1.5,
                shadowStrength: 0.3, shadowRadius: 8, shadowY: 3,
                fontDesign: .serif,
                displayFontName: "ZenOldMincho-Bold",
                bodyFontName: nil
            )

        case .film:
            // 写真の角。縁は無く、影はやわらかく広い
            return ThemeStyle(
                radiusSmall: 2, radiusMedium: 4, radiusLarge: 6,
                borderWidth: 0,
                shadowStrength: 0.55, shadowRadius: 18, shadowY: 7,
                fontDesign: .serif,
                displayFontName: nil, bodyFontName: nil
            )

        case .morningAirport:
            // ガラスと光。影を持たず、細い罫線だけで区切る
            return ThemeStyle(
                radiusSmall: 10, radiusMedium: 14, radiusLarge: 18,
                borderWidth: 1,
                shadowStrength: 0, shadowRadius: 0, shadowY: 0,
                fontDesign: .default,
                displayFontName: nil, bodyFontName: nil
            )

        case .mountainHut:
            // 地形図と木。太めの縁で図面らしく
            return ThemeStyle(
                radiusSmall: 6, radiusMedium: 10, radiusLarge: 14,
                borderWidth: 1.5,
                shadowStrength: 0.4, shadowRadius: 10, shadowY: 4,
                fontDesign: .default,
                displayFontName: nil, bodyFontName: nil
            )

        case .neonNight:
            // 発光。縁を光らせ、影を広く強く
            return ThemeStyle(
                radiusSmall: 8, radiusMedium: 12, radiusLarge: 16,
                borderWidth: 1.5,
                shadowStrength: 1, shadowRadius: 20, shadowY: 0,
                fontDesign: .monospaced,
                displayFontName: nil, bodyFontName: nil
            )
        }
    }
}

// MARK: - Font
extension ThemeStyle {
    /// TextStyle ごとの標準サイズ。同梱フォントを使うときだけ必要になる
    static func pointSize(for style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: return 34
        case .title: return 28
        case .title2: return 22
        case .title3: return 20
        case .headline: return 17
        case .body: return 17
        case .callout: return 16
        case .subheadline: return 15
        case .footnote: return 13
        case .caption: return 12
        case .caption2: return 11
        @unknown default: return 17
        }
    }

    /// フォントが実際に同梱されているか。
    /// Font.custom は見つからないと黙ってシステムフォントに落ちるので、
    /// 先に確かめて fontDesign の側へ倒す。毎回の照会は重いので結果を覚えておく。
    private static var availability: [String: Bool] = [:]

    static func isBundled(_ name: String) -> Bool {
        if let known = availability[name] { return known }
        let found = UIFont(name: name, size: 12) != nil
        availability[name] = found
        return found
    }

    /// 見出しに使う書体
    func displayFont(_ style: Font.TextStyle, weight: Font.Weight = .bold) -> Font {
        if let name = displayFontName, Self.isBundled(name) {
            return .custom(name, size: Self.pointSize(for: style), relativeTo: style)
        }
        return .system(style, design: fontDesign).weight(weight)
    }

    /// 本文に使う書体
    func bodyFont(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        if let name = bodyFontName, Self.isBundled(name) {
            return .custom(name, size: Self.pointSize(for: style), relativeTo: style)
        }
        return .system(style, design: fontDesign).weight(weight)
    }
}

// MARK: - ThemePreset から引く
extension ThemePreset {
    var style: ThemeStyle { ThemeStyle.forType(type) }

    func radius(_ r: ThemeStyle.Radius) -> CGFloat { style.radius(r) }

    func displayFont(_ textStyle: Font.TextStyle, weight: Font.Weight = .bold) -> Font {
        style.displayFont(textStyle, weight: weight)
    }

    func bodyFont(_ textStyle: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        style.bodyFont(textStyle, weight: weight)
    }

    /// 影の色。shadowStrength が 0 のテーマでは透明を返すので、そのまま .shadow に渡せる
    var effectiveShadow: Color {
        style.shadowStrength <= 0 ? .clear : shadow.opacity(style.shadowStrength)
    }

    /// 罫線の色。borderWidth が 0 のテーマでは透明を返す
    var effectiveBorder: Color {
        style.borderWidth <= 0 ? .clear : cardBorder
    }
}
