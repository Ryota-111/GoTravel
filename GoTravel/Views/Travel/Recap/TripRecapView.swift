import SwiftUI
import CoreData


/// 旅行が終わったあと、ホームに1回だけ出す案内
struct TripRecapBanner: View {
    let plan: TravelPlan
    let onOpen: () -> Void
    let onDismiss: () -> Void

    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = themeManager.currentTheme
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.title3)
                .foregroundColor(theme.actionFill)
            VStack(alignment: .leading, spacing: 2) {
                Text("「\(plan.title)」おかえりなさい")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(theme.textOnCardBackground2(for: colorScheme))
                    .lineLimit(1)
                Text("撮った写真と動画から、旅のダイジェスト動画を作れます")
                    .font(.caption)
                    .foregroundColor(theme.secondaryTextOnCardBackground2(for: colorScheme))
            }
            Spacer(minLength: 0)
            Button("作る", action: onOpen)
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .tint(theme.actionFill)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundColor(theme.secondaryTextOnCardBackground2(for: colorScheme))
            }
            .accessibilityLabel("閉じる")
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(theme.cardBackground2))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.cardBorder, lineWidth: 1))
    }
}
