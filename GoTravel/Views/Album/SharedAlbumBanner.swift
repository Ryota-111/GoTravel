import SwiftUI

/// 共有した旅行のアルバムで、自分の写真も見せるかを1度だけ尋ねる帯（3.8）。
///
/// いつも出ていると写真の邪魔になるので、まだ決めていないあいだだけ出す。
/// 「共有する」を押すか × で閉じたら、もう出さない（切り替えは右上の「…」から）。
/// 今までに入れた写真を勝手に載せないよう、オンにするのは自分で押したときだけ（`SharedAlbumPhotos` のルール1）
struct SharedAlbumBanner: View {
    let tint: Color
    let onShare: () -> Void
    let onDismiss: () -> Void

    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "person.2.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(tint)
                .frame(width: 34, height: 34)
                .background(Circle().fill(tint.opacity(0.14)))

            VStack(alignment: .leading, spacing: 2) {
                Text("同行者と写真を見せ合えます")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(themeManager.currentTheme.text)
                Text("同行者が共有した写真はここに入ります")
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

            Button(action: onShare) {
                Text("共有する")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(tint))
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(themeManager.currentTheme.secondaryText)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("閉じる")
        }
        .buttonStyle(.plain)
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                .fill(tint.opacity(0.08))
        )
    }
}
