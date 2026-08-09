import SwiftUI

/// 1項目分の行。式が複雑になると型チェックが通らなくなるため切り出す
private struct WhatsNewRow: View {
    let item: WhatsNew.Item
    let accent: Color
    let titleColor: Color
    let bodyColor: Color

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: item.icon)
                .font(.system(size: 20))
                .foregroundColor(accent)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.bold())
                    .foregroundColor(titleColor)
                    .fixedSize(horizontal: false, vertical: true)

                Text(item.detail)
                    .font(.caption)
                    .foregroundColor(bodyColor)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}

/// アップデート後に一度だけ出る「新機能のお知らせ」。
/// 併せて、要望をいつでも送れることを伝える
struct WhatsNewView: View {
    let content: WhatsNew

    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var showFeedbackForm = false

    private var accent: Color { themeManager.currentTheme.actionFill }
    private var titleColor: Color { themeManager.currentTheme.adaptiveText(for: colorScheme) }
    private var bodyColor: Color { themeManager.currentTheme.secondaryText }

    private var cardFill: Color {
        colorScheme == .dark
            ? themeManager.currentTheme.secondaryBackgroundDark
            : themeManager.currentTheme.secondaryBackgroundLight
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        header
                        itemList
                        messageCard
                        buttons
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { dismiss() }
                        .foregroundColor(accent)
                }
            }
        }
        .sheet(isPresented: $showFeedbackForm) {
            FeedbackFormView()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 44))
                .foregroundColor(accent)
                .padding(.top, 10)

            Text("Version \(content.version) の新機能")
                .font(.title3.bold())
                .foregroundColor(titleColor)

            Text("いつもTravoryをご利用いただきありがとうございます")
                .font(.caption)
                .foregroundColor(bodyColor)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Items

    private var itemList: some View {
        VStack(spacing: 18) {
            ForEach(content.items) { item in
                WhatsNewRow(
                    item: item,
                    accent: accent,
                    titleColor: titleColor,
                    bodyColor: bodyColor
                )
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 16).fill(cardFill))
    }

    // MARK: - Message

    private var messageCard: some View {
        VStack(spacing: 10) {
            Text("みなさんと一緒に作っていきたいです")
                .font(.subheadline.bold())
                .foregroundColor(titleColor)
                .multilineTextAlignment(.center)

            Text("Travoryは一人で開発しています。「こんな機能が欲しい」「ここが使いにくい」など、どんなことでもお気軽にお寄せください。いただいた声をもとに改善を続けています。")
                .font(.caption)
                .foregroundColor(bodyColor)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(accent.opacity(0.1)))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(accent.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Buttons

    private var buttons: some View {
        VStack(spacing: 12) {
            Button(action: { showFeedbackForm = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                    Text("ご意見・ご要望を送る")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(RoundedRectangle(cornerRadius: 14).fill(accent))
            }

            Button(action: { dismiss() }) {
                Text("あとで")
                    .font(.subheadline)
                    .foregroundColor(bodyColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }

            Text("「ヘルプ・サポート」からいつでも送れます")
                .font(.caption2)
                .foregroundColor(bodyColor)
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                themeManager.currentTheme.gradientDark,
                themeManager.currentTheme.dark
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}
