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

    /// ホームの予定行の面。
    /// 一覧で最初に目に入る形なので、`radiusLarge` とは別に持たせる。
    /// 既定は今までの 20 なので、値を書かないテーマは何も変わらない
    var rowRadius: CGFloat = 20

    /// ホームの旅行計画カード（200×200）の面。既定は今までの 25
    var cardRadius: CGFloat = 25

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

    /// 日付や英字ラベル用の同梱フォント名。未同梱なら等幅のシステムフォントに落ちる
    var monoFontName: String? = nil

    // MARK: - 意匠
    //
    // 「レトロのときだけ切符の形」のような差は、ビュー側で
    // `if theme == .retroTravel` と書くと、テーマが増えるたびに分岐が増える。
    // どう描くかをここに持たせて、ビューはトークンを読むだけにする。
    // 既定値は今までの見た目なので、値を足さないテーマは何も変わらない。

    enum Decor {
        /// これまでどおりのカード
        case plain
        /// 切り取り線と半円の切り欠きを持つ切符仕立て
        case ticket
    }

    var decor: Decor = .plain

    /// 紙の粒子を乗算で重ねる濃さ。0 で重ねない
    var paperGrain: Double = 0

    /// ぼかさず、ずらすだけの影の量。印刷物の版ズレの表現。0 で使わない
    var offsetShadow: CGFloat = 0

    /// 予定行の左に立てる、種別を示す帯の幅。0 で描かない
    var typeSpineWidth: CGFloat = 0

    /// 予定行の右に置く、日付の半券の幅。0 で描かない
    var dateStubWidth: CGFloat = 0

    /// 予定行に落とす影。
    ///
    /// 行の影だけは、他の面より一回り広く敷いてある（既定テーマで半径13）。
    /// `shadowRadius` は既定テーマで10なので、その比率を保ったまま
    /// テーマごとの濃さ・広さを反映させる。
    /// 影を持たないテーマは `shadowStrength` が 0 なので、ここも 0 になる
    var rowShadowRadius: CGFloat { shadowRadius * 1.3 }

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

        // 和のテーマは明朝と、かなの表情が出る書体に。墨は影を捨てて罫線で区切る
        case .aiKinari:
            // 藍染の布。角はわずかに丸く、影は薄い
            return ThemeStyle(
                radiusSmall: 7, radiusMedium: 11, radiusLarge: 15,
                rowRadius: 14, cardRadius: 18,
                borderWidth: 1,
                shadowStrength: 0.7, shadowRadius: 12, shadowY: 5,
                fontDesign: .serif,
                displayFontName: "ZenAntique-Regular",
                bodyFontName: "ZenKakuGothicNew-Regular"
            )

        case .sumi:
            // 墨。角を落とし、影を捨て、種別は左の帯だけで示す
            return ThemeStyle(
                radiusSmall: 4, radiusMedium: 6, radiusLarge: 8,
                rowRadius: 4, cardRadius: 6,
                borderWidth: 1,
                shadowStrength: 0, shadowRadius: 0, shadowY: 0,
                fontDesign: .serif,
                displayFontName: "ZenAntique-Regular",
                bodyFontName: "ZenKakuGothicNew-Regular",
                typeSpineWidth: 5
            )

        case .momiji:
            return ThemeStyle(
                radiusSmall: 8, radiusMedium: 12, radiusLarge: 16,
                rowRadius: 16, cardRadius: 20,
                borderWidth: 1,
                shadowStrength: 0.8, shadowRadius: 12, shadowY: 5,
                fontDesign: .serif,
                displayFontName: "ZenAntique-Regular",
                bodyFontName: "ZenKakuGothicNew-Regular"
            )

        // やわらかいものは丸く
        case .sakura:
            return ThemeStyle(
                radiusSmall: 11, radiusMedium: 16, radiusLarge: 22,
                rowRadius: 26, cardRadius: 30,
                borderWidth: 0,
                shadowStrength: 0.8, shadowRadius: 14, shadowY: 6,
                fontDesign: .rounded,
                displayFontName: nil,
                bodyFontName: "ZenKakuGothicNew-Regular"
            )

        case .setouchi:
            return ThemeStyle(
                radiusSmall: 10, radiusMedium: 15, radiusLarge: 20,
                rowRadius: 24, cardRadius: 28,
                borderWidth: 0,
                shadowStrength: 0.6, shadowRadius: 14, shadowY: 6,
                fontDesign: .rounded,
                displayFontName: nil,
                bodyFontName: "ZenKakuGothicNew-Regular"
            )

        // 雪国は影をほとんど消して、余白で区切る
        case .yukiguni:
            return ThemeStyle(
                radiusSmall: 9, radiusMedium: 14, radiusLarge: 18,
                rowRadius: 18, cardRadius: 22,
                borderWidth: 1,
                shadowStrength: 0.25, shadowRadius: 8, shadowY: 3,
                fontDesign: .default,
                displayFontName: nil,
                bodyFontName: "ZenKakuGothicNew-Regular"
            )

        case .yakouRessha:
            // 夜行の時刻表。日付と時刻は等幅で桁を揃える
            return ThemeStyle(
                radiusSmall: 7, radiusMedium: 11, radiusLarge: 14,
                rowRadius: 12, cardRadius: 15,
                borderWidth: 1,
                shadowStrength: 1, shadowRadius: 14, shadowY: 6,
                fontDesign: .default,
                displayFontName: "ZenAntique-Regular",
                bodyFontName: "ZenKakuGothicNew-Regular",
                monoFontName: "SpaceMono-Bold",
                typeSpineWidth: 5
            )

        // ここから下は形と書体で個性を出すテーマ。
        // 同梱フォント名を指定してあるが、未同梱なら fontDesign に落ちる。

        case .retroTravel:
            // 切符と印刷物。デザイン案の実測値をそのまま入れている。
            //
            // ぼかした影は使わない。階層は破線・罫・版ズレのずらし影だけで作る。
            // 角丸もカード6／行5／チップ3まで下げて、切符らしい直線的な輪郭にする
            return ThemeStyle(
                radiusSmall: 3, radiusMedium: 5, radiusLarge: 6,
                rowRadius: 5, cardRadius: 6,
                borderWidth: 1.5,
                shadowStrength: 0, shadowRadius: 0, shadowY: 0,
                fontDesign: .serif,
                displayFontName: "ZenAntique-Regular",
                bodyFontName: "ZenKakuGothicNew-Regular",
                monoFontName: "SpaceMono-Bold",
                decor: .ticket,
                paperGrain: 0.06,
                offsetShadow: 2,
                typeSpineWidth: 6,
                dateStubWidth: 68
            )

        case .guidebook:
            // 紙の地図。罫線で区切る印刷物の作り。
            // 縮尺や距離の数字が揃うように等幅を当てる
            return ThemeStyle(
                radiusSmall: 5, radiusMedium: 8, radiusLarge: 11,
                rowRadius: 8, cardRadius: 11,
                borderWidth: 1,
                shadowStrength: 0.4, shadowRadius: 8, shadowY: 3,
                fontDesign: .default,
                displayFontName: nil,
                bodyFontName: "ZenKakuGothicNew-Regular",
                monoFontName: "SpaceMono-Bold",
                typeSpineWidth: 4
            )

        case .passport:
            // 旅券。角ばって、箔押しの縁。
            // 旅券の機械読取部と同じく、英数字は等幅で並べる
            return ThemeStyle(
                radiusSmall: 3, radiusMedium: 5, radiusLarge: 8,
                rowRadius: 5, cardRadius: 8,
                borderWidth: 1.5,
                shadowStrength: 0.3, shadowRadius: 8, shadowY: 3,
                fontDesign: .serif,
                displayFontName: "ZenAntique-Regular",
                bodyFontName: "ZenKakuGothicNew-Regular",
                monoFontName: "SpaceMono-Bold",
                typeSpineWidth: 6
            )

        case .film:
            // 写真の角。縁は無く、影はやわらかく広い。
            // 日付はフィルムに写し込まれた数字のつもりで等幅にする
            return ThemeStyle(
                radiusSmall: 2, radiusMedium: 4, radiusLarge: 6,
                rowRadius: 3, cardRadius: 5,
                borderWidth: 0,
                shadowStrength: 0.55, shadowRadius: 18, shadowY: 7,
                fontDesign: .serif,
                displayFontName: nil, bodyFontName: nil,
                monoFontName: "SpaceMono-Bold"
            )

        case .morningAirport:
            // ガラスと光。影を持たず、細い罫線だけで区切る。
            // 時刻は出発案内板の書体に寄せる
            return ThemeStyle(
                radiusSmall: 10, radiusMedium: 14, radiusLarge: 18,
                rowRadius: 16, cardRadius: 20,
                borderWidth: 1,
                shadowStrength: 0, shadowRadius: 0, shadowY: 0,
                fontDesign: .default,
                displayFontName: nil, bodyFontName: nil,
                monoFontName: "SpaceMono-Bold"
            )

        case .mountainHut:
            // 地形図と木。太めの縁で図面らしく。標高の数字は等幅で
            return ThemeStyle(
                radiusSmall: 6, radiusMedium: 10, radiusLarge: 14,
                rowRadius: 10, cardRadius: 14,
                borderWidth: 1.5,
                shadowStrength: 0.4, shadowRadius: 10, shadowY: 4,
                fontDesign: .default,
                displayFontName: nil, bodyFontName: nil,
                monoFontName: "SpaceMono-Bold",
                typeSpineWidth: 5
            )

        case .neonNight:
            // 発光。縁を光らせ、影を広く強く
            return ThemeStyle(
                radiusSmall: 8, radiusMedium: 12, radiusLarge: 16,
                rowRadius: 14, cardRadius: 18,
                borderWidth: 1.5,
                shadowStrength: 1, shadowRadius: 20, shadowY: 0,
                fontDesign: .monospaced,
                displayFontName: nil, bodyFontName: nil,
                monoFontName: "SpaceMono-Bold",
                typeSpineWidth: 3
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

    /// 見出しに使う書体。
    /// 同梱フォントには weight を当てない。Zen Antique は単一ウェイトで、
    /// 太らせると和文の字面が潰れる。あの書体はその太さで完成している。
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

    /// 日付や英字ラベルに使う等幅の書体。
    /// 桁の揃った数字が、そのまま切符や時刻表の表情になる。
    /// 同梱フォントが無いときは等幅のシステムフォントに落ちる
    func monoFont(_ style: Font.TextStyle, weight: Font.Weight = .bold) -> Font {
        if let name = monoFontName, Self.isBundled(name) {
            return .custom(name, size: Self.pointSize(for: style), relativeTo: style)
        }
        return .system(style, design: .monospaced).weight(weight)
    }

    // MARK: - 実寸の指定
    //
    // 意匠のある画面は、デザイン案が px で決まっている。
    // TextStyle 経由だと端末の文字サイズ設定で崩れる箇所があるので、
    // そこだけ実寸で指定できるようにしておく

    func monoFont(size: CGFloat, weight: Font.Weight = .bold) -> Font {
        if let name = monoFontName, Self.isBundled(name) {
            return .custom(name, size: size)
        }
        return .system(size: size, weight: weight, design: .monospaced)
    }

    /// 数字の桁だけ揃えたい箇所で使う。
    ///
    /// `monoFont` との違いは、同梱の等幅を持たないテーマの落とし先。
    /// あちらは等幅のシステムフォントに落ちるので、字面まで変わってしまう。
    /// こちらは既定のシステムフォントのまま数字だけ等幅にするので、
    /// 書体を指定していないテーマの見た目は今までと変わらない
    func tabularFont(size: CGFloat, weight: Font.Weight = .bold) -> Font {
        if let name = monoFontName, Self.isBundled(name) {
            return .custom(name, size: size)
        }
        return .system(size: size, weight: weight).monospacedDigit()
    }

    /// 見出し用の同梱フォントが実際に使えるか。
    /// 「書体を持つテーマかどうか」でビューを分けるための入口。
    /// テーマ名で分岐しないための判定なので、`if theme == ...` の代わりに使う
    var hasDisplayFont: Bool {
        guard let name = displayFontName else { return false }
        return Self.isBundled(name)
    }

    func displayFont(size: CGFloat, weight: Font.Weight = .bold) -> Font {
        if let name = displayFontName, Self.isBundled(name) {
            return .custom(name, size: size)
        }
        return .system(size: size, weight: weight, design: fontDesign)
    }

    func bodyFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if let name = bodyFontName, Self.isBundled(name) {
            return .custom(name, size: size)
        }
        return .system(size: size, weight: weight, design: fontDesign)
    }
}

// MARK: - ThemePreset から引く
extension ThemePreset {
    var style: ThemeStyle { ThemeStyle.forType(type) }

    func radius(_ r: ThemeStyle.Radius) -> CGFloat { style.radius(r) }

    func monoFont(_ textStyle: Font.TextStyle, weight: Font.Weight = .bold) -> Font {
        style.monoFont(textStyle, weight: weight)
    }

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
