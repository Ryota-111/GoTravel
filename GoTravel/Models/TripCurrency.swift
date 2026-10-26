import Foundation

// MARK: - 旅行ごとの「計算する通貨」（3.1）
//
// 予算・合計・割り勘・精算・書き出しを、旅行ごとに選んだ通貨で出す（海外在住の方のご要望から）。
// ふだんは円で、今までの旅行も使い方も変わらない。
//
// **費用の金額（`cost` / `actualCost` / 予約の `cost` / 支出の `amount` / `splitAmounts`）は、
// この通貨での金額として持つ。** 外貨で入れた費用（`ForeignCost`）は、この通貨に直したものを `cost` に入れる。
// 通貨は割り勘の JSON（`TripSplit.currencyCode`）に入るので、CloudKit のスキーマは変わらない

extension TravelPlan {
    /// この旅行の金額の通貨（"JPY" / "EUR" など）
    var currencyCode: String {
        get { split.currencyCode ?? CurrencyCatalog.yen }
        set { split.currencyCode = newValue == CurrencyCatalog.yen ? nil : newValue }
    }

    /// 円で計算している旅行か
    var usesYen: Bool { currencyCode == CurrencyCatalog.yen }

    /// この旅行の通貨での金額の書き方（"¥12,000" / "€95.50"）
    func money(_ amount: Double) -> String {
        CurrencyCatalog.money(amount, code: currencyCode)
    }

    /// 金額が1つでも入っているか。入っていれば、通貨を変えるときにレートを聞く
    var hasAnyAmount: Bool {
        daySchedules.flatMap(\.scheduleItems).contains { $0.cost != nil || $0.actualCost != nil || $0.foreignCost != nil }
            || reservations.contains { $0.cost != nil || $0.foreignCost != nil }
            || !split.expenses.isEmpty
    }

    /// 計算する通貨を変える。
    ///
    /// - Parameter rate: 新しい通貨 1 単位が、今の通貨でいくらか（「1 EUR = 160 円」の 160）。
    ///   金額が入っていなければ要らない（nil でよい）。
    ///
    /// 今の通貨で入れていた金額は、**入れた数字を「今の通貨の外貨」として残し**、新しい通貨に直す
    /// （あとでレートを直せば、元の数字から計算し直せる）。外貨で入れていた費用はレートを付け替え、
    /// 新しい通貨で入れていたものはそのままの金額にする。予定にしない支出と、人ごとに決めた金額は直す
    mutating func changeCurrency(to newCode: String, rate: Double?) {
        let oldCode = currencyCode
        guard newCode != oldCode else { return }
        let factor = rate.flatMap { $0 > 0 ? $0 : nil }
        currencyCode = newCode

        /// 今の通貨の金額を、新しい通貨に（レートが無ければ nil）
        func convert(_ amount: Double?) -> Double? {
            guard let amount, let factor else { return nil }
            return CurrencyCatalog.round(amount / factor, code: newCode)
        }
        func convertShares(_ shares: [String: Double]?) -> [String: Double]? {
            guard let shares else { return nil }
            guard factor != nil else { return nil }  // レートが分からなければ、均等に戻す
            return shares.compactMapValues { convert($0) }
        }
        /// 外貨のレートを付け替える。新しい通貨そのものなら外貨でなくなる
        func refit(_ foreign: ForeignCost) -> ForeignCost? {
            guard foreign.currencyCode != newCode else { return nil }
            var refitted = foreign
            // レートは小数6桁まで残す（1 円 = 0.006250 EUR のように小さくなるため）
            refitted.rate = foreign.rate.flatMap { old in factor.map { (old / $0 * 1_000_000).rounded() / 1_000_000 } }
            return refitted
        }

        for day in daySchedules.indices {
            for index in daySchedules[day].scheduleItems.indices {
                var item = daySchedules[day].scheduleItems[index]
                if let foreign = item.foreignCost {
                    if let refitted = refit(foreign) {
                        item.foreignCost = refitted
                        item.cost = refitted.baseAmount(in: newCode)
                        item.actualCost = refitted.baseActualAmount(in: newCode)
                    } else {
                        item.foreignCost = nil
                        item.cost = foreign.amount
                        item.actualCost = foreign.actualAmount
                    }
                } else if item.cost != nil || item.actualCost != nil {
                    // 今の通貨で入れた金額は、今の通貨の外貨として残す
                    let kept = ForeignCost(currencyCode: oldCode, rate: factor.map { 1 / $0 },
                                           amount: item.cost, actualAmount: item.actualCost)
                    item.foreignCost = kept
                    item.cost = kept.baseAmount(in: newCode)
                    item.actualCost = kept.baseActualAmount(in: newCode)
                }
                item.splitAmounts = convertShares(item.splitAmounts)
                daySchedules[day].scheduleItems[index] = item
            }
        }

        for index in reservations.indices {
            var reservation = reservations[index]
            if let foreign = reservation.foreignCost {
                if let refitted = refit(foreign) {
                    reservation.foreignCost = refitted
                    reservation.cost = refitted.baseAmount(in: newCode)
                } else {
                    reservation.foreignCost = nil
                    reservation.cost = foreign.amount
                }
            } else if let cost = reservation.cost {
                let kept = ForeignCost(currencyCode: oldCode, rate: factor.map { 1 / $0 }, amount: cost)
                reservation.foreignCost = kept
                reservation.cost = kept.baseAmount(in: newCode)
            }
            reservation.splitAmounts = convertShares(reservation.splitAmounts)
            reservations[index] = reservation
        }

        // 予定にしない支出と済ませた精算は外貨を持てないので、そのまま直す。
        // レートが無いときは数字を残す（消すより、あとで見て直せるほうがよい）
        for index in split.expenses.indices {
            if let converted = convert(split.expenses[index].amount) {
                split.expenses[index].amount = converted
            }
            split.expenses[index].splitAmounts = convertShares(split.expenses[index].splitAmounts)
        }
    }
}

extension CurrencyCatalog {
    /// 文の中での呼び名。円は「円」、ほかは「ユーロ」「米ドル」
    static func shortName(of code: String) -> String {
        code == yen ? "円" : name(of: code)
    }

    /// 新しい旅行の通貨。前に作った旅行で円以外を選んでいれば、それを引き継ぐ
    /// （海外に住んでいる人が、毎回選び直さなくて済むように）
    static var preferredTripCurrency: String {
        get { UserDefaults.standard.string(forKey: "tripCurrency.preferred") ?? yen }
        set { UserDefaults.standard.set(newValue, forKey: "tripCurrency.preferred") }
    }
}
