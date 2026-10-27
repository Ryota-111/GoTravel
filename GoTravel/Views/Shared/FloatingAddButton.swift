import SwiftUI

/// 画面の右下に浮かせる「＋」ボタンの見た目。思い出・場所保存で、大きさと位置をそろえる
/// （以前は 58pt と 56pt、下の余白も 24pt と 20pt で、タブを切り替えるとずれて見えた）
struct FloatingAddButtonLabel: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    static let size: CGFloat = 56
    /// 画面の右と下からの余白
    static let margin: CGFloat = 20

    var body: some View {
        let fill = themeManager.currentTheme.xprimary
        Image(systemName: "plus")
            .font(.system(size: 24, weight: .bold))
            .foregroundColor(ThemePreset.readableText(on: fill))
            .frame(width: Self.size, height: Self.size)
            .background(Circle().fill(fill))
            .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
    }
}
