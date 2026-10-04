import SwiftUI

/// 旅行のメモ帳（自由な文章1枚）。リストのタブの「メモ」で出す。
///
/// 1文字ごとに保存すると、そのたびに旅行全体を書き直して共有にも送ってしまう。
/// 書き終えたとき（キーボードを閉じたとき・画面を離れたとき）にまとめて保存する
struct TripMemoView: View {
    let plan: TravelPlan

    @EnvironmentObject var viewModel: TravelPlanViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) private var colorScheme

    @State private var text = ""
    @FocusState private var isFocused: Bool

    private var currentPlan: TravelPlan {
        viewModel.travelPlans.first(where: { $0.id == plan.id }) ?? plan
    }

    private var cardFill: Color {
        colorScheme == .dark
            ? themeManager.currentTheme.secondaryBackgroundDark
            : themeManager.currentTheme.secondaryBackgroundLight
    }

    private var textColor: Color { ThemePreset.readableText(on: cardFill) }
    private var accent: Color { themeManager.currentTheme.actionFill }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if currentPlan.isShared {
                Label("このメモは、共有している全員が見て書けます", systemImage: "person.2.fill")
                    .font(.system(size: 12))
                    .foregroundColor(themeManager.currentTheme.secondaryText)
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .focused($isFocused)
                    .scrollContentBackground(.hidden)
                    .foregroundColor(textColor)
                    .font(.system(size: 15))
                    .frame(minHeight: 260)
                    .padding(8)
                if text.isEmpty {
                    Text("旅行のメモを自由に書けます（例：集合場所、駐車場、気をつけること）")
                        .font(.system(size: 15))
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(cardFill)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(textColor.opacity(0.12), lineWidth: 1))
            )

            if isFocused {
                HStack {
                    Spacer()
                    Button("完了") { isFocused = false }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(accent)
                }
            }
        }
        .onAppear { text = currentPlan.memo ?? "" }
        // 書いていない間に同行者の変更が届いたら、表示を新しくする
        .onChange(of: currentPlan.memo) { _, newValue in
            if !isFocused { text = newValue ?? "" }
        }
        .onChange(of: isFocused) { _, focused in
            if !focused { save() }
        }
        .onDisappear { save() }
    }

    private func save() {
        guard let userId = authVM.userId else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let newMemo = trimmed.isEmpty ? nil : text
        guard newMemo != currentPlan.memo else { return }
        var updated = currentPlan
        updated.memo = newMemo
        viewModel.update(updated, userId: userId)
    }
}
