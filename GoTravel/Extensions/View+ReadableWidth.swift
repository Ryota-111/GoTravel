import SwiftUI
import UIKit

// MARK: - 広い画面で、中身を読みやすい幅にそろえる
//
// iPhone 向けに作った画面は、iPad の横向きや Mac（iPhone・iPad 向けアプリとして動かしたとき）では
// 窓いっぱいに引き伸ばされ、左の文字と右の金額・ボタンが2,000pt近く離れて読みにくかった。
//
// **iPhone には一切効かない。** 大きい iPhone を横にすると幅は regular になるが、
// 端末の種類（idiom）が .phone なので何もしない。iPad でも、Split View などで幅が狭いときは何もしない。
// Mac の「Designed for iPad」は idiom が .pad になるので効く。

enum WideLayout {
    /// 文章や一覧を読ませる画面の最大幅
    static let readableWidth: CGFloat = 960
    /// 写真の一覧など、横に並べたい画面の最大幅
    static let galleryWidth: CGFloat = 1280
    /// 追加・作成・編集の画面（入力欄が並ぶ画面）の最大幅
    static let formWidth: CGFloat = 720

    /// iPad・Mac で動いているか（iPhone では常に false）
    static var isPadOrMac: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
}

private struct ReadableWidthModifier: ViewModifier {
    let maxWidth: CGFloat
    let alignment: Alignment
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isWide: Bool {
        WideLayout.isPadOrMac && horizontalSizeClass == .regular
    }

    func body(content: Content) -> some View {
        if isWide {
            content
                .frame(maxWidth: maxWidth, alignment: alignment)
                .frame(maxWidth: .infinity, alignment: .center)
        } else {
            content
        }
    }
}

extension View {
    /// iPad・Mac の広い画面でだけ、中身を `maxWidth` までに抑えて真ん中に置く。iPhone では何もしない
    func readableWidth(_ maxWidth: CGFloat = WideLayout.readableWidth, alignment: Alignment = .topLeading) -> some View {
        modifier(ReadableWidthModifier(maxWidth: maxWidth, alignment: alignment))
    }
}

/// iPad・Mac の広い画面かどうか。列の数を変えるなど、幅を抑える以外の出し分けに使う
struct IsWideLayoutReader<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ViewBuilder let content: (Bool) -> Content

    var body: some View {
        content(WideLayout.isPadOrMac && horizontalSizeClass == .regular)
    }
}

// MARK: - 追加・作成・編集の画面

/// 入力欄が並ぶ画面を、iPad・Mac の広い画面でだけ `WideLayout.formWidth` までに抑える。
///
/// 幅を枠で縛るのではなく、スクロールする中身の左右の余白（contentMargins）を広げる。
/// こうすると Form・List・ScrollView のどれで組んだ画面にも同じように効き、
/// 背景の色や区切り線は窓いっぱいのまま、入力欄だけが真ん中に寄る。
/// iPhone（横向きを含む）と、iPad のシートのように幅が狭いときは何もしない
private struct ReadableFormWidthModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var containerWidth: CGFloat = 0

    func body(content: Content) -> some View {
        if WideLayout.isPadOrMac && horizontalSizeClass == .regular {
            content
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { containerWidth = $0 }
                .contentMargins(.horizontal,
                                max(0, (containerWidth - WideLayout.formWidth) / 2),
                                for: .scrollContent)
        } else {
            content
        }
    }
}

extension View {
    /// 追加・作成・編集の画面の一番外側に付ける。iPhone では何もしない
    func readableFormWidth() -> some View {
        modifier(ReadableFormWidthModifier())
    }
}

extension View {
    /// `readableFormWidth()` の余白を、この中では使わない。
    /// 余白はその中にあるスクロールするもの全部に効くので、メモ欄（TextEditor）や
    /// 横に流れる並びの中にまで大きな余白が入ってしまうのを打ち消す
    func resetFormMargins() -> some View {
        contentMargins(.horizontal, 0, for: .scrollContent)
    }
}

// MARK: - 表紙の写真の高さ

/// 窓いっぱいの幅で出す表紙の写真を、iPad・Mac の広い画面でだけ幅に合わせて高くする。
///
/// 高さを固定したまま幅だけ広がると、細長く切り抜かれて写真がひどく拡大されて見える。
/// 広い画面では「横 2.6：縦 1」くらいを目安に、`base`〜480pt のあいだで高くする。
/// iPhone（横向きを含む）では `base` のまま
private struct AdaptiveHeroHeightModifier: ViewModifier {
    let base: CGFloat
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var width: CGFloat = 0

    private var height: CGFloat {
        guard WideLayout.isPadOrMac, horizontalSizeClass == .regular, width > 0 else { return base }
        return min(max(width / 2.6, base), 480)
    }

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }
}

extension View {
    /// 表紙の写真の高さ。iPhone では `base`、iPad・Mac の広い画面では幅に合わせて高くする
    func adaptiveHeroHeight(_ base: CGFloat) -> some View {
        modifier(AdaptiveHeroHeightModifier(base: base))
    }
}
