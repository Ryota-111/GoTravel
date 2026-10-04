import SwiftUI

/// 費用の入力の中身。円でも外貨でも同じ形で持ち、保存のときに円の金額と外貨の元に分ける
struct CostInput: Equatable {
    var currencyCode = CurrencyCatalog.yen
    /// 「1 USD = 150 円」の 150
    var rateText = ""
    /// 予算（選んだ通貨で）
    var amountText = ""
    /// 実際に使った金額（選んだ通貨で）。予約では使わない
    var actualText = ""

    var isForeign: Bool { currencyCode != CurrencyCatalog.yen }

    init() {}

    /// 保存されている値から入力欄を作る。外貨で入れていれば外貨のまま出す
    init(cost: Double?, actualCost: Double? = nil, foreign: ForeignCost?) {
        if let foreign {
            currencyCode = foreign.currencyCode
            rateText = CurrencyCatalog.editingText(foreign.rate)
            amountText = CurrencyCatalog.editingText(foreign.amount)
            actualText = CurrencyCatalog.editingText(foreign.actualAmount)
        } else {
            amountText = CurrencyCatalog.editingText(cost)
            actualText = CurrencyCatalog.editingText(actualCost)
        }
    }

    var amount: Double? { CurrencyCatalog.parse(amountText) }
    var actualAmount: Double? { CurrencyCatalog.parse(actualText) }
    var rate: Double? { CurrencyCatalog.parse(rateText).flatMap { $0 > 0 ? $0 : nil } }

    /// 保存する値。円の金額は、外貨ならレートを掛けたもの（レートが無ければ空）
    var result: (cost: Double?, actualCost: Double?, foreign: ForeignCost?) {
        guard isForeign else { return (amount, actualAmount, nil) }
        guard amount != nil || actualAmount != nil else { return (nil, nil, nil) }
        let foreign = ForeignCost(currencyCode: currencyCode, rate: rate, amount: amount, actualAmount: actualAmount)
        return (foreign.yenAmount, foreign.yenActualAmount, foreign)
    }
}

/// 費用の入力欄（通貨の選択・金額・外貨ならレート）。
///
/// 外貨を選ぶと「1 USD = ○ 円」の欄が出る。同じ旅行で前に入れたレートがあれば最初から入れておく
/// （旅行ごとのレート。保存すると同じ旅行の同じ通貨はすべてこのレートに揃う）
struct CurrencyCostFields: View {
    @Binding var input: CostInput
    /// 実際に使った金額の欄も出すか（予定では出す、予約では出さない）
    var showsActual = false
    /// この旅行で使っている通貨とレート（`TravelPlan.exchangeRates`）
    var tripRates: [String: Double?] = [:]
    var accent: Color
    var textColor: Color
    var secondaryText: Color
    var successColor: Color = .green
    var fieldBackground: Color

    /// この旅行で使っている通貨を先に、そのあとよく使う通貨を並べる
    private var currencyChoices: [String] {
        let used = tripRates.keys.sorted()
        return [CurrencyCatalog.yen] + used.filter { $0 != CurrencyCatalog.yen }
            + CurrencyCatalog.common.filter { $0 != CurrencyCatalog.yen && !used.contains($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            amountRow(icon: "yensign.circle", placeholder: showsActual ? "予算" : "費用",
                      text: $input.amountText, iconColor: accent.opacity(0.7), showsPicker: true)

            if showsActual {
                // 旅行後に実際いくら使ったかを記録する欄
                amountRow(icon: "checkmark.circle", placeholder: "実際に使った金額",
                          text: $input.actualText, iconColor: successColor.opacity(0.8), showsPicker: false)
            }

            if input.isForeign {
                rateRow
            }
        }
    }

    private func amountRow(icon: String, placeholder: String, text: Binding<String>,
                           iconColor: Color, showsPicker: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 24)
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .foregroundColor(textColor)
            if showsPicker {
                currencyMenu
            } else {
                Text(unitLabel)
                    .foregroundColor(secondaryText)
            }
        }
        .padding(14)
        .background(fieldBackground)
        .cornerRadius(12)
    }

    /// 円は「円」、外貨は通貨コードで出す
    private var unitLabel: String {
        input.isForeign ? input.currencyCode : "円"
    }

    private var currencyMenu: some View {
        Menu {
            ForEach(currencyChoices, id: \.self) { code in
                Button {
                    select(code)
                } label: {
                    if code == input.currencyCode {
                        Label(menuTitle(code), systemImage: "checkmark")
                    } else {
                        Text(menuTitle(code))
                    }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Text(unitLabel)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(accent)
        }
        .accessibilityLabel(Text("通貨：\(CurrencyCatalog.name(of: input.currencyCode))"))
    }

    private func menuTitle(_ code: String) -> String {
        code == CurrencyCatalog.yen ? "円（JPY）" : "\(CurrencyCatalog.name(of: code))（\(code)）"
    }

    /// 通貨を変えたら、この旅行で前に使ったレートを入れておく
    private func select(_ code: String) {
        input.currencyCode = code
        if code != CurrencyCatalog.yen, let rate = tripRates[code] ?? nil {
            input.rateText = CurrencyCatalog.editingText(rate)
        } else if code == CurrencyCatalog.yen {
            input.rateText = ""
        }
    }

    private var rateRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("1 \(input.currencyCode) =")
                    .foregroundColor(textColor)
                TextField("レート", text: $input.rateText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(textColor)
                    .frame(maxWidth: 110)
                Text("円")
                    .foregroundColor(secondaryText)
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(fieldBackground)
            .cornerRadius(12)

            Text(conversionNote)
                .font(.caption)
                .foregroundColor(secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var conversionNote: String {
        let result = input.result
        guard input.rate != nil else {
            return "レートを入れると、円に直して予算の合計に入ります。両替したときのレートを入れてください。"
        }
        var parts: [String] = []
        if let yen = result.cost { parts.append("予算 約\(CurrencyCatalog.format(yen, code: CurrencyCatalog.yen))") }
        if showsActual, let yen = result.actualCost { parts.append("実績 約\(CurrencyCatalog.format(yen, code: CurrencyCatalog.yen))") }
        let converted = parts.isEmpty ? "" : parts.joined(separator: "・") + "。"
        return converted + "この旅行の \(input.currencyCode) は、すべてこのレートで円に直します。"
    }
}
