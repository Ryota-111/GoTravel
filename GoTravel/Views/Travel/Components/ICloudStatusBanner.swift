import SwiftUI

/// iCloud が使えない・保存できていないときに、ホームの旅行計画の上に出す帯（`ICloudSyncMonitor`）。
///
/// 一覧が空に見えても、データは iCloud に残っていることを伝え、確認の手順を案内する
struct ICloudStatusBanner: View {
    let problem: ICloudSyncMonitor.Problem

    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var showsGuide = false

    private var cardFill: Color {
        colorScheme == .dark
            ? themeManager.currentTheme.secondaryBackgroundDark
            : themeManager.currentTheme.secondaryBackgroundLight
    }

    private var textColor: Color { ThemePreset.readableText(on: cardFill) }
    private var warning: Color { ThemePreset.readableTint(themeManager.currentTheme.error, on: cardFill) }

    private var title: String {
        switch problem {
        case .notSignedIn: return "iCloudにサインインしていません"
        case .temporarilyUnavailable: return "iCloudの確認が必要です"
        case .restricted: return "iCloudが使えない設定になっています"
        case .quotaExceeded: return "iCloudの容量がいっぱいです"
        }
    }

    private var detail: String {
        switch problem {
        case .quotaExceeded:
            return "新しく入れた内容がiCloudに保存できていません。"
        default:
            return "旅行計画が表示されなかったり、保存されなかったりします。データはiCloudに残っています。"
        }
    }

    private var guide: String {
        problem == .quotaExceeded ? ICloudGuidanceText.quotaExceeded : ICloudGuidanceText.dataUnavailable
    }

    var body: some View {
        Button {
            showsGuide = true
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: problem == .quotaExceeded ? "externaldrive.badge.exclamationmark" : "exclamationmark.icloud.fill")
                    .font(.system(size: 18))
                    .foregroundColor(warning)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(textColor)
                    Text(detail)
                        .font(.caption)
                        .foregroundColor(textColor.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("確認のしかた")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(warning)
                        .padding(.top, 2)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: themeManager.currentTheme.style.radiusMedium)
                    .fill(cardFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: themeManager.currentTheme.style.radiusMedium)
                            .stroke(warning.opacity(0.5), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .alert(title, isPresented: $showsGuide) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(guide)
        }
    }
}
