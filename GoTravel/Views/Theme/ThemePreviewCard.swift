import SwiftUI

/// テーマの見え方を、そのテーマ自身のトークンで縮小して描く。
///
/// 写真を同梱しない。画面を作り替えるたびに撮り直すことになり、
/// 古い写真が残ると「買ったら違った」になるため。
/// ここはトークンから描いているので、UI を変えれば見本も一緒に変わり、
/// テーマを足せば見本も自動で増える。
///
/// 設計上の寸法は `base` で、実際の大きさは `width` に合わせて拡大縮小する。
/// 中の比率を崩さずに、一覧では小さく、購入画面では大きく置ける。
struct ThemePreviewCard: View {
    let preset: ThemePreset
    var width: CGFloat = 96

    @Environment(\.colorScheme) private var colorScheme

    /// 設計上の幅。この幅で組んで、あとから縮める
    private let base: CGFloat = 120
    private var ratio: CGFloat { 1.34 }

    var body: some View {
        content
            .frame(width: base, height: base * ratio)
            .scaleEffect(width / base, anchor: .center)
            .frame(width: width, height: width * ratio)
            .clipShape(RoundedRectangle(cornerRadius: preset.radius(.medium)))
            .overlay(
                RoundedRectangle(cornerRadius: preset.radius(.medium))
                    .strokeBorder(ink.opacity(0.12), lineWidth: 1)
            )
            .accessibilityLabel("\(preset.type.rawValue)の見え方")
    }

    // MARK: - 明暗
    //
    // ダーク固定・ライト固定のテーマがあるので、端末の設定をそのまま使えない

    private var isDark: Bool {
        switch preset.type.preferredColorScheme {
        case .dark:  return true
        case .light: return false
        default:     return colorScheme == .dark
        }
    }

    private var bg: Color { isDark ? preset.backgroundDark : preset.backgroundLight }
    private var surface: Color { isDark ? preset.secondaryBackgroundDark : preset.cardBackground2 }
    private var ink: Color { preset.adaptiveText(for: isDark ? .dark : .light) }
    private var style: ThemeStyle { preset.style }

    // MARK: - 中身

    private var content: some View {
        VStack(alignment: .leading, spacing: 5) {
            heading
            mainCard
            planRow(preset.outingPlanColor)
            planRow(preset.dailyPlanColor)
            Spacer(minLength: 0)
        }
        .padding(7)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(bg)
        .paperGrain(style.paperGrain)
    }

    /// 見出し。書体の違いがいちばん出るところ
    private var heading: some View {
        HStack(spacing: 3) {
            Text("旅行")
                .font(style.displayFont(size: 11))
                .foregroundColor(ink)

            if style.decor == .ticket {
                Rectangle()
                    .fill(preset.cardBorder)
                    .frame(height: 0.5)

                Text("TRIPS")
                    .font(style.monoFont(size: 4))
                    .tracking(0.8)
                    .foregroundColor(ink.opacity(0.5))
            } else {
                Spacer(minLength: 0)
            }
        }
    }

    /// 主役のカード。切符仕立てなら切り取り線と切り欠きまで出す
    private var mainCard: some View {
        let radius = style.radiusLarge
        let artHeight: CGFloat = style.decor == .ticket ? 30 : 42

        return VStack(spacing: 0) {
            LinearGradient(
                colors: [preset.travelColor, preset.travelColor.opacity(0.55)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .frame(height: artHeight)
            .overlay(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(surface.opacity(0.85))
                    .frame(width: 40, height: 3)
                    .padding(4)
            }

            if style.decor == .ticket {
                // 半券。日付が入るところ
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(ink.opacity(0.55))
                        .frame(width: 26, height: 3)
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(ink.opacity(0.28))
                        .frame(width: 12, height: 3)
                }
                .padding(.horizontal, 5)
                .frame(maxHeight: .infinity)
                .overlay(alignment: .top) {
                    DashedRule()
                        .stroke(preset.cardBorder,
                                style: StrokeStyle(lineWidth: 0.8, dash: [2, 1.5]))
                        .frame(height: 0.8)
                        .padding(.horizontal, 5)
                }
            }
        }
        .frame(height: style.decor == .ticket ? 48 : 42)
        .background(surface)
        .clipShape(RoundedRectangle(cornerRadius: radius))
        .overlay(
            RoundedRectangle(cornerRadius: radius)
                .strokeBorder(preset.cardBorder, lineWidth: max(style.borderWidth, 0.5))
        )
        .overlay {
            if style.decor == .ticket {
                TicketNotches(y: 30, diameter: 6,
                              fill: bg, border: preset.cardBorder, borderWidth: 0.5)
            }
        }
        .shadow(color: preset.shadow.opacity(style.shadowStrength * 0.5),
                radius: style.shadowRadius * 0.4,
                x: 0, y: style.shadowY * 0.4)
    }

    /// 予定の行。種別の色と、半券の有無で作りが変わる
    private func planRow(_ accent: Color) -> some View {
        HStack(spacing: 0) {
            if style.typeSpineWidth > 0 {
                Rectangle()
                    .fill(accent)
                    .frame(width: 2.5)
            }

            HStack(spacing: 3) {
                if style.typeSpineWidth == 0 {
                    Circle()
                        .fill(accent)
                        .frame(width: 5, height: 5)
                }

                VStack(alignment: .leading, spacing: 2) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(ink.opacity(0.5))
                        .frame(width: 44, height: 3)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(ink.opacity(0.22))
                        .frame(width: 26, height: 2.5)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 4)

            if style.dateStubWidth > 0 {
                RoundedRectangle(cornerRadius: 1)
                    .fill(ink.opacity(0.45))
                    .frame(width: 10, height: 3)
                    .frame(width: 18)
                    .frame(maxHeight: .infinity)
                    .background(preset.cardBorder.opacity(0.13))
                    .overlay(alignment: .leading) {
                        DashedRule(vertical: true)
                            .stroke(preset.cardBorder,
                                    style: StrokeStyle(lineWidth: 0.8, dash: [2, 1.5]))
                            .frame(width: 0.8)
                    }
            }
        }
        .frame(height: 20)
        .background(surface)
        .clipShape(RoundedRectangle(cornerRadius: style.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: style.radiusMedium)
                .strokeBorder(preset.cardBorder, lineWidth: max(style.borderWidth, 0.5))
        )
    }
}
