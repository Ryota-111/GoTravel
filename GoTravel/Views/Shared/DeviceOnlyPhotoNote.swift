import SwiftUI

/// 写真を追加できる画面に置く1行。**未購入のときだけ出る。**
///
/// 写真を iCloud に預かるのは Travory Pro に含まれる。買っていない人の写真は
/// 端末の中だけにあり、**機種変更やアプリの削除で失われる。**
/// 黙って預からないでいると、実際に消えて初めて気づくことになるので、
/// 写真を入れる場所に事実として置いておく。
///
/// 保存の邪魔はしない。アラートもトーストも出さず、画面に静かに居るだけ。
/// タップすると Pro の説明が開く。
///
/// 購入済みのときは何も描かないので、置く側に分岐は要らない。
struct DeviceOnlyPhotoNote: View {
    @ObservedObject private var store = ProStore.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var showPro = false

    private var theme: ThemePreset { themeManager.currentTheme }

    var body: some View {
        if !store.isPurchased {
            Button {
                showPro = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "iphone.gen3")
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)

                    Text("写真はこの端末の中だけに保存されます。機種変更では引き継げません。")
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(theme.tertiaryText)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: theme.radius(.medium), style: .continuous)
                        .fill(theme.secondaryText.opacity(0.08))
                )
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showPro) {
                ProSheet(highlighted: nil)
            }
        }
    }
}
