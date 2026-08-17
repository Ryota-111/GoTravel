import SwiftUI

/// 提携先へ送る行。
///
/// 景品表示法（2023年10月施行のステマ規制）により、**広告であることの明示が必須**。
/// 「PR」バッジをタイトルと同じ行に置き、見落とされないようにしている。
/// 表記が漏れると行政指導の対象になるため、提携リンクは必ずこの部品を通すこと。
///
/// 検索結果が0件になりうるので、文言は「購入」ではなく「探す」に留める。
struct AffiliateLinkRow: View {
    let title: String
    /// 提携先の名前。どこへ移るのか分かるようにする
    let serviceName: String
    let icon: String
    let accentColor: Color
    let action: () -> Void

    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme

    private var cardFill: Color {
        colorScheme == .dark
            ? themeManager.currentTheme.secondaryBackgroundDark
            : themeManager.currentTheme.secondaryBackgroundLight
    }

    private var titleColor: Color {
        ThemePreset.readableText(on: cardFill)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(accentColor)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(accentColor.opacity(0.14)))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        // ステマ規制対応。省略不可
                        Text("PR")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(ThemePreset.readableText(on: accentColor))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 3).fill(accentColor))

                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(titleColor)
                            .lineLimit(1)
                    }

                    Text("レジャー・体験の予約（\(serviceName)）")
                        .font(.caption2)
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                }

                Spacer(minLength: 0)

                // 外部サイトへ移ることが分かるようにする
                Image(systemName: "arrow.up.forward.square")
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.secondaryText)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardFill)
                    .shadow(color: themeManager.currentTheme.shadow, radius: 6, x: 0, y: 2)
            )
        }
        .buttonStyle(.plain)
    }
}
