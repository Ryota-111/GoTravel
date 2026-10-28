import SwiftUI

/// 予定と予定の間に出す移動手段（3.2）。押すと手段を選べる。
///
/// 旅行の日程とおでかけの予定の両方で使う。レールは呼ぶ側の行に合わせて描くので、ここは右側の札だけ
struct TransportGapMenu: View {
    let mode: TransportMode?
    let tint: Color
    let placeholderColor: Color
    let onSelect: (TransportMode?) -> Void

    var body: some View {
        Menu {
            ForEach(TransportMode.allCases) { candidate in
                Button {
                    onSelect(candidate)
                } label: {
                    if candidate == mode {
                        Label(candidate.title, systemImage: "checkmark")
                    } else {
                        Label(candidate.title, systemImage: candidate.systemImage)
                    }
                }
            }
            if mode != nil {
                Divider()
                Button(role: .destructive) {
                    onSelect(nil)
                } label: {
                    Label("外す", systemImage: "xmark")
                }
            }
        } label: {
            if let mode {
                HStack(spacing: 4) {
                    Image(systemName: mode.systemImage)
                        .font(.system(size: 11, weight: .semibold))
                    Text(mode.title)
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(tint)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(tint.opacity(0.12), in: Capsule())
            } else {
                // 決めていない間は目立たせない。予定の間に毎回出るので、強いと行程が読みにくくなる
                HStack(spacing: 3) {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .bold))
                    Text("移動手段")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(placeholderColor)
                .padding(.vertical, 4)
            }
        }
        .accessibilityLabel(Text(mode.map { "次の予定まで\($0.title)" } ?? "次の予定までの移動手段を選ぶ"))
    }
}
