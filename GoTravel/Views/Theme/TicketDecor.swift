import SwiftUI

/// 切符仕立てのテーマで使う意匠の部品。
///
/// テーマ名では分岐しない。`ThemeStyle` のトークンが 0 や `.plain` なら
/// 何も描かないので、呼び出し側は常に同じコードのまま置いておける。
/// 意匠を持つテーマが増えても、増えるのは `ThemeStyle` の値だけ。

// MARK: - 紙の粒子

/// 紙の繊維に見せるための粒子。乗算で最前面に重ねる。
///
/// 画面いっぱいに毎フレーム描くと重いので、小さなタイルを一度だけ作って
/// 敷き詰める。生成結果は使い回す
struct PaperGrain: View {
    let opacity: Double

    /// ここでの分岐は overlay の中だけで完結する。
    /// overlay 自体は常に付いたままなので、外側のビューの同一性は変わらない。
    /// 粒子を使わないテーマで乗算合成を走らせないために、中身は空にしておく
    @ViewBuilder
    var body: some View {
        if opacity > 0, let tile = Self.tile {
            Image(uiImage: tile)
                .resizable(resizingMode: .tile)
                .opacity(opacity)
                .blendMode(.multiply)
                .allowsHitTesting(false)
                .ignoresSafeArea()
        } else {
            Color.clear
                .allowsHitTesting(false)
        }
    }

    private static let tile: UIImage? = makeTile(side: 160)

    private static func makeTile(side: Int) -> UIImage? {
        let count = side * side
        var pixels = [UInt8](repeating: 0, count: count)
        // 中間より明るめに散らす。暗い点が多いと乗算で全体が沈む
        for i in 0..<count {
            pixels[i] = UInt8.random(in: 150...255)
        }

        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let cg = CGImage(
                width: side, height: side,
                bitsPerComponent: 8, bitsPerPixel: 8,
                bytesPerRow: side,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGBitmapInfo(rawValue: 0),
                provider: provider, decode: nil,
                shouldInterpolate: false, intent: .defaultIntent
              )
        else { return nil }

        return UIImage(cgImage: cg)
    }
}

// MARK: - 破線

/// 切り取り線。縦にも横にも引ける
struct DashedRule: Shape {
    var vertical = false

    func path(in rect: CGRect) -> Path {
        var p = Path()
        if vertical {
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        } else {
            p.move(to: CGPoint(x: rect.minX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        }
        return p
    }
}

// MARK: - 切り欠き

/// 切り取り線の両端に置く半円。
///
/// 形をくり抜くのではなく、地色で塗った円を縁からはみ出させて重ねる。
/// デザイン案も同じ作りで、こちらのほうが背景の写真とずれない
struct TicketNotches: View {
    let y: CGFloat
    let diameter: CGFloat
    let fill: Color
    let border: Color
    let borderWidth: CGFloat

    var body: some View {
        GeometryReader { geo in
            let r = diameter / 2
            ForEach([-r, geo.size.width - r], id: \.self) { x in
                Circle()
                    .fill(fill)
                    .overlay(Circle().strokeBorder(border, lineWidth: borderWidth))
                    .frame(width: diameter, height: diameter)
                    .offset(x: x, y: y - r)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 版ズレの影

private struct OffsetShadow: ViewModifier {
    let amount: CGFloat
    let color: Color
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        // こちらも同じ理由で、付けたり外したりしない（`paperGrain` の注記を参照）
        content.background(
            // ぼかさず、ずらすだけ。印刷の版ズレに見せる
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(color)
                .opacity(amount > 0 ? 1 : 0)
                .offset(x: amount, y: amount)
        )
    }
}

extension View {
    /// ぼかしのない、ずらすだけの影。`offsetShadow` が 0 のテーマでは何もしない
    func offsetShadow(_ amount: CGFloat, color: Color, cornerRadius: CGFloat = 0) -> some View {
        modifier(OffsetShadow(amount: amount, color: color, cornerRadius: cornerRadius))
    }

    /// 紙の粒子を最前面に重ねる。`paperGrain` が 0 のテーマでは何も見えない。
    ///
    /// **付けるか付けないかを if で分けてはいけない。**
    /// 分岐が変わるとビューの同一性が変わり、SwiftUI がその部分木を作り直す。
    /// この修飾子は NavigationView の中身の根に付いているので、テーマを
    /// 変えた瞬間に開いていた画面が閉じてホームに戻ってしまう。
    /// 常に重ねたままにして、濃さ 0 で見えなくする
    func paperGrain(_ opacity: Double) -> some View {
        overlay(PaperGrain(opacity: opacity))
    }
}
