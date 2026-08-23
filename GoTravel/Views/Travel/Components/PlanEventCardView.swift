import SwiftUI

// MARK: - Plan Event Card View
//
// 骨格はどのカードも同じにして、今日の1枚だけを前に出す。
// 以前は全カードが同じ強さで色を敷いていたため、一覧が平坦で主役がいなかった。
//
// 色の受け持ちを2つに分けている。
// - カードの主役色（日付タイル・面の色味・影）は **テーマ色**。
//   白黒テーマを選んだ人の一覧が青やオレンジで埋まらないようにする
// - 種別（おでかけ／日常）の色は **小さなタグだけ**。
//   一覧を見分ける手がかりとしては、この大きさで足りる
struct PlanEventCardView: View {
    let plan: Plan
    var onDelete: (() -> Void)? = nil
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var themeManager = ThemeManager.shared

    // メインテーマ色（カード全体の主役。種別カラーはアクセントに限定）
    private var mainColor: Color {
        themeManager.currentTheme.xprimary
    }

    private var titleColor: Color {
        colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1
    }

    private var subTextColor: Color {
        titleColor.opacity(0.65)
    }

    private var surfaceColor: Color {
        colorScheme == .dark
            ? themeManager.currentTheme.secondaryBackgroundDark
            : themeManager.currentTheme.backgroundLight
    }

    /// 今日にかかっている予定。この1枚だけ日付タイルを塗る
    private var isToday: Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return calendar.startOfDay(for: plan.startDate) <= today
            && calendar.startOfDay(for: plan.endDate) >= today
    }

    private var isSingleDay: Bool {
        Calendar.current.isDate(plan.startDate, inSameDayAs: plan.endDate)
    }

    private var typeName: String {
        plan.planType == .daily ? "日常" : "おでかけ"
    }

    var body: some View {
        HStack(spacing: 14) {
            dateTile

            VStack(alignment: .leading, spacing: 8) {
                Text(plan.title)
                    .font(.system(size: isToday ? 18 : 17, weight: isToday ? .bold : .semibold))
                    .foregroundColor(titleColor)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    // 種別色を使うのはここだけ
                    Text(typeName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(typeColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(typeColor.opacity(colorScheme == .dark ? 0.24 : 0.14), in: RoundedRectangle(cornerRadius: 7))

                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(subTextColor)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            menuButton
        }
        .padding(.leading, 15)
        .padding(.vertical, 15)
        .padding(.trailing, 6)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(surfaceColor)

                // 今日の1枚だけ、面にも薄く色を流す
                if isToday {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [mainColor.opacity(colorScheme == .dark ? 0.18 : 0.10), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        // ダークでは影が沈んで効かないので、細い輪郭に置き換える
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    colorScheme == .dark
                        ? mainColor.opacity(isToday ? 0.48 : 0.10)
                        : .clear,
                    lineWidth: 1
                )
        )
        .shadow(
            color: colorScheme == .dark
                ? .clear
                : (isToday ? mainColor.opacity(0.16) : Color.black.opacity(0.07)),
            radius: 13,
            x: 0,
            y: 5
        )
    }

    // MARK: - 日付タイル
    //
    // アイコンだけの目印では日付が本文に埋もれ、一覧を流し読みできなかった。
    // 数字を大きく置いて、日付でたどれるようにする
    private var dateTile: some View {
        VStack(spacing: 3) {
            Text(isToday ? "今日" : monthText)
                .font(.system(size: 11, weight: .bold))
                .opacity(isToday ? 0.86 : 0.78)

            Text(dayText)
                .font(.system(size: 25, weight: .heavy))
                .monospacedDigit()

            Text(weekdayText)
                .font(.system(size: 10, weight: .bold))
                .opacity(isToday ? 0.86 : 0.72)
        }
        .foregroundColor(isToday ? ThemePreset.readableText(on: mainColor) : mainColor)
        .padding(.vertical, 9)
        .frame(width: 56)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(isToday ? AnyShapeStyle(mainColor) : AnyShapeStyle(mainColor.opacity(colorScheme == .dark ? 0.22 : 0.12)))
        )
    }

    /// むき出しの削除ボタンは、一覧をなぞるだけで押してしまう。
    /// 44pt の「⋯」にまとめて、押す気がないと届かないようにする
    @ViewBuilder
    private var menuButton: some View {
        if let onDelete = onDelete {
            Menu {
                Button("削除", systemImage: "trash", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(subTextColor)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("この予定の操作")
        }
    }

    // MARK: - 文言
    //
    // 単日でも「8月23日 〜 8月23日」と出していたのをやめる。
    // 日付はタイルが持つので、本文には期間と中身だけを残す
    private var subtitle: String {
        var parts: [String] = []

        if !isSingleDay {
            parts.append("\(DateFormatter.japaneseDate.string(from: plan.endDate))まで")
            let days = (Calendar.current.dateComponents([.day], from: plan.startDate, to: plan.endDate).day ?? 0) + 1
            parts.append("\(days)日間")
        }

        if let time = plan.time {
            parts.append(DateFormatter.japaneseTime.string(from: time))
        }

        if !plan.places.isEmpty {
            parts.append("\(plan.places.count)件の場所")
        }

        return parts.joined(separator: " · ")
    }

    private var typeColor: Color {
        plan.planType == .daily
            ? themeManager.currentTheme.dailyPlanColor
            : themeManager.currentTheme.outingPlanColor
    }

    /// タイルに出す日。今日にかかっている予定は今日を指す
    private var tileDate: Date {
        isToday ? Date() : plan.startDate
    }

    private var monthText: String {
        Self.monthFormatter.string(from: tileDate)
    }

    private var dayText: String {
        Self.dayFormatter.string(from: tileDate)
    }

    private var weekdayText: String {
        Self.weekdayFormatter.string(from: tileDate)
    }

    private static let monthFormatter = japaneseFormatter("M月")
    private static let dayFormatter = japaneseFormatter("d")
    private static let weekdayFormatter = japaneseFormatter("E")

    private static func japaneseFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = format
        return formatter
    }
}
