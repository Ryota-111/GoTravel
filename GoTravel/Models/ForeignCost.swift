import Foundation

// MARK: - 外貨の費用
//
// 海外旅行で「ドルで払った」「ウォンで払った」金額をそのまま入れ、円に直して予算に入れる。
//
// **円の金額（`cost` / `actualCost`）は今までどおり持ち、外貨はその元として横に持つ。**
// 予算・割り勘・書き出しなど、円で計算している所は何も変えずに済む。
//
// レートは旅行そのものではなく、費用を入れた予定・予約の中に持たせる。
// 旅行の項目を増やすと Core Data と共有レコードのスキーマ変更（Production への反映）が要るため。
// 「旅行ごとのレート」は、同じ旅行の同じ通貨はいつも同じレートに揃えることで実現する
// （`TravelPlan.setExchangeRate`）。無料の機能（`docs/設計_外貨の費用.md`）

/// 外貨で入れた金額
struct ForeignCost: Codable, Equatable {
    /// 通貨（"USD" など ISO 4217）
    var currencyCode: String
    /// 1単位あたりの円。まだ入れていなければ nil（そのあいだ円の金額は空で、予算に入らない）
    var rate: Double?
    /// 予算（外貨）
    var amount: Double?
    /// 実際に使った金額（外貨）。予約では使わない
    var actualAmount: Double?

    /// 外貨を円に直す。端数は四捨五入（予算の画面は円単位で出すため）
    static func yen(_ amount: Double?, rate: Double?) -> Double? {
        guard let amount, let rate, rate > 0 else { return nil }
        return (amount * rate).rounded()
    }

    var yenAmount: Double? { Self.yen(amount, rate: rate) }
    var yenActualAmount: Double? { Self.yen(actualAmount, rate: rate) }
}

// MARK: - 通貨

enum CurrencyCatalog {
    static let yen = "JPY"

    /// 選びやすいよう先に並べる通貨（日本からの旅行先で多いもの）
    static let common = ["JPY", "USD", "EUR", "KRW", "TWD", "CNY", "HKD", "THB", "SGD", "VND",
                         "PHP", "IDR", "MYR", "AUD", "NZD", "GBP", "CAD", "CHF"]

    private static let locale = Locale(identifier: "ja_JP")

    /// 「米ドル」「ユーロ」
    static func name(of code: String) -> String {
        locale.localizedString(forCurrencyCode: code) ?? code
    }

    /// 「$120」「₩15,000」「€9.50」。小数は通貨の決まりに合わせる（ウォンや円は小数なし）
    static func format(_ amount: Double, code: String) -> String {
        amount.formatted(.currency(code: code).locale(locale))
    }

    /// 入力欄の文字を数にする。全角・カンマ・通貨記号が混ざっていても読む
    static func parse(_ text: String) -> Double? {
        var cleaned = ""
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0xFF10...0xFF19: cleaned.unicodeScalars.append(Unicode.Scalar(scalar.value - 0xFEE0)!)
            case 0xFF0E: cleaned.append(".")
            default: cleaned.unicodeScalars.append(scalar)
            }
        }
        let digits = cleaned.filter { $0.isNumber || $0 == "." }
        guard let value = Double(digits), value >= 0 else { return nil }
        return value
    }

    /// 入力欄に戻すときの書き方（120 / 9.5 / 15000）。余計な 0 は付けない
    static func editingText(_ value: Double?) -> String {
        guard let value else { return "" }
        return value == value.rounded() ? String(Int(value)) : String(value)
    }
}

// MARK: - 旅行のレート

extension TravelPlan {

    /// この旅行で使っている外貨と、そのレート（レート未入力なら nil）
    var exchangeRates: [String: Double?] {
        var result: [String: Double?] = [:]
        for foreign in allForeignCosts {
            if let rate = foreign.rate {
                result[foreign.currencyCode] = rate
            } else if result[foreign.currencyCode] == nil {
                result[foreign.currencyCode] = .some(nil)
            }
        }
        return result
    }

    /// その通貨の、この旅行でのレート。入力の初期値に使う
    func exchangeRate(for code: String) -> Double? {
        exchangeRates[code] ?? nil
    }

    /// 同じ通貨の費用を、全部このレートで円に直し直す。
    ///
    /// 「旅行ごとのレート」はここで揃える。1件の予定でレートを直したときも、
    /// 予算の画面でレートを直したときも、同じ旅行の同じ通貨はすべて同じレートになる
    mutating func setExchangeRate(_ rate: Double?, for code: String) {
        for day in daySchedules.indices {
            for index in daySchedules[day].scheduleItems.indices {
                guard var foreign = daySchedules[day].scheduleItems[index].foreignCost,
                      foreign.currencyCode == code else { continue }
                foreign.rate = rate
                daySchedules[day].scheduleItems[index].foreignCost = foreign
                daySchedules[day].scheduleItems[index].cost = foreign.yenAmount
                daySchedules[day].scheduleItems[index].actualCost = foreign.yenActualAmount
            }
        }
        for index in reservations.indices {
            guard var foreign = reservations[index].foreignCost, foreign.currencyCode == code else { continue }
            foreign.rate = rate
            reservations[index].foreignCost = foreign
            reservations[index].cost = foreign.yenAmount
        }
    }

    private var allForeignCosts: [ForeignCost] {
        daySchedules.flatMap(\.scheduleItems).compactMap(\.foreignCost)
            + reservations.compactMap(\.foreignCost)
    }
}
