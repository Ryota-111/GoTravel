import SwiftUI

/// 実際に使った金額だけを入力する画面。
///
/// 実績は旅行が終わってから記録するものなので、
/// 予定を作るときの入力欄だけでは記録できない。
/// 項目全体の編集はまだ用意していないため、金額に絞った導線を置く。
struct ActualCostEditorView: View {
    let item: ScheduleItem
    let onSave: (Double?) -> Void

    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var amount: String = ""
    @FocusState private var amountFocused: Bool

    private var accent: Color { themeManager.currentTheme.actionFill }
    private var titleColor: Color { themeManager.currentTheme.adaptiveText(for: colorScheme) }

    private var cardFill: Color {
        colorScheme == .dark
            ? themeManager.currentTheme.secondaryBackgroundDark
            : themeManager.currentTheme.secondaryBackgroundLight
    }

    var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark
                    ? themeManager.currentTheme.backgroundDark
                    : themeManager.currentTheme.backgroundLight)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    header
                    amountField

                    if let budget = item.cost {
                        comparisonRow(budget: budget)
                    }

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("実際に使った金額")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                        .foregroundColor(accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        onSave(amount.isEmpty ? nil : Double(amount))
                        dismiss()
                    }
                    .foregroundColor(accent)
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            if let actual = item.actualCost {
                amount = String(format: "%.0f", actual)
            }
            amountFocused = true
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text(item.title)
                .font(.headline)
                .foregroundColor(titleColor)
                .multilineTextAlignment(.center)

            if let location = item.location {
                Text(location)
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.secondaryText)
            }
        }
    }

    private var amountField: some View {
        HStack {
            Image(systemName: "yensign.circle.fill")
                .foregroundColor(accent)

            TextField("未入力", text: $amount)
                .font(.title2.weight(.bold))
                .keyboardType(.decimalPad)
                .focused($amountFocused)
                .foregroundColor(titleColor)

            Text("円")
                .foregroundColor(themeManager.currentTheme.secondaryText)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 14).fill(cardFill))
    }

    private func comparisonRow(budget: Double) -> some View {
        let actual = Double(amount) ?? 0
        let diff = actual - budget

        return VStack(spacing: 8) {
            HStack {
                Text("予算")
                    .font(.subheadline)
                    .foregroundColor(themeManager.currentTheme.secondaryText)
                Spacer()
                Text(formatCurrency(budget))
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(titleColor)
            }

            if !amount.isEmpty {
                Divider()
                HStack {
                    Text(diff > 0 ? "超過" : "節約")
                        .font(.subheadline)
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                    Spacer()
                    Text(formatCurrency(abs(diff)))
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(diff > 0
                            ? themeManager.currentTheme.error
                            : themeManager.currentTheme.success)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 14).fill(cardFill))
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return "¥\(formatter.string(from: NSNumber(value: value)) ?? "0")"
    }
}
