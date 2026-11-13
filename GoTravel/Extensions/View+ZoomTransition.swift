import SwiftUI

/// カードを押すと、そのカードから次の画面が広がって開く遷移（3.6）。
///
/// 押したものと開いた画面のつながりが見えるので、戻るときも「どこへ戻るか」が分かる。
/// 名前空間を渡さなければ何もしないので、同じカードを遷移なしの場所でも使える
extension View {
    /// 広がる元になるカードに付ける
    @ViewBuilder
    func zoomSource(id: some Hashable, in namespace: Namespace.ID?) -> some View {
        if let namespace {
            matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }

    /// 開く側の画面に付ける
    @ViewBuilder
    func zoomDestination(id: some Hashable, in namespace: Namespace.ID?) -> some View {
        if let namespace {
            navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self
        }
    }
}

/// 横に流すカードが、端へ行くほど少し小さく薄くなる（3.6）。
/// 真ん中のカードが主役に見え、流している手ごたえが出る。
/// 「視差効果を減らす」がオンのときは動かさない
private struct EdgeScrollTransition: ViewModifier {
    let axis: Axis
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.scrollTransition(.interactive, axis: axis) { view, phase in
                view
                    .scaleEffect(phase.isIdentity ? 1 : 0.94)
                    .opacity(phase.isIdentity ? 1 : 0.75)
            }
        }
    }
}

extension View {
    func edgeScrollTransition(axis: Axis) -> some View {
        modifier(EdgeScrollTransition(axis: axis))
    }
}
