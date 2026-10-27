import Foundation

// MARK: - 割り勘（3.1）
//
// 費用ごとに「誰が払ったか」「誰と割り勘するか」を持ち、最後に「さくら → 自分 ¥3,200」のような
// 受け渡しを出す（2026-10-16 のご要望から。`docs/設計_割り勘.md`）。
//
// - 予定の費用と予約の費用は、それぞれの JSON の中に `paidBy` / `splitWith` を持つ
// - アプリを使っていない同行者・予定にしない支出・済ませた精算は、旅行の `split`（`splitJSON`）に持つ
// - 計算（`TripSplitLedger`）は外の世界に触らない。入れた値だけで答えを返すので、テストで確かめられる

/// 旅行ごとの割り勘の情報
struct TripSplit: Codable, Equatable {
    /// アプリを使っていない同行者（名前だけ）。共有していない旅行でも割り勘できるように
    var companions: [TripCompanion] = []
    /// 予定にしない支出（水を買った、など）と、済ませた精算の受け渡し
    var expenses: [TripExpense] = []
    /// この旅行の金額を何の通貨で計算するか（3.1、`TripCurrency.swift`）。**nil なら円。**
    ///
    /// 割り勘と同じ旅行の JSON に入れる。旅行に欄を足すと CloudKit の Production 反映が要るため。
    /// 3.0 以前はこの項目を読まないので、円として出る（数字はそのまま）
    var currencyCode: String?

    var isEmpty: Bool { companions.isEmpty && expenses.isEmpty && currencyCode == nil }

    init(companions: [TripCompanion] = [], expenses: [TripExpense] = [], currencyCode: String? = nil) {
        self.companions = companions
        self.expenses = expenses
        self.currencyCode = currencyCode
    }

    enum CodingKeys: String, CodingKey { case companions, expenses, currencyCode }

    // 通貨だけ決めた旅行では、同行者・支出の欄が無いこともある
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        companions = try container.decodeIfPresent([TripCompanion].self, forKey: .companions) ?? []
        expenses = try container.decodeIfPresent([TripExpense].self, forKey: .expenses) ?? []
        currencyCode = try container.decodeIfPresent(String.self, forKey: .currencyCode)
    }

    static func decode(_ json: String?) -> TripSplit {
        guard let data = json?.data(using: .utf8) else { return TripSplit() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(TripSplit.self, from: data)) ?? TripSplit()
    }

    /// 何も無ければ nil（保存する欄を空のままにする）
    static func encode(_ split: TripSplit) -> String? {
        guard !split.isEmpty else { return nil }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys
        return (try? encoder.encode(split)).flatMap { String(data: $0, encoding: .utf8) }
    }
}

/// アプリを使っていない同行者
struct TripCompanion: Codable, Equatable, Identifiable {
    /// "companion-<UUID>"。共有メンバーのユーザーIDと混ざらないように
    var id: String = "companion-\(UUID().uuidString)"
    var name: String
}

/// 予定にしない支出か、済ませた精算の受け渡し
struct TripExpense: Codable, Equatable, Identifiable {
    var id: String = UUID().uuidString
    var title: String
    /// 円
    var amount: Double
    var date: Date
    /// 払った人。nil なら決まっていない（精算に入れない）
    var paidBy: String?
    /// 割り勘する人。nil なら全員
    var splitWith: [String]?
    /// 人ごとに決めた金額。決めていない人は、残りを同じ額ずつ分ける。nil なら均等
    var splitAmounts: [String: Double]?
    /// 精算の受け渡し（`paidBy` が `splitWith` の1人に払った）。費用の合計には入れない
    var isSettlement: Bool?

    var settles: Bool { isSettlement == true }

    /// 精算の受け渡しを済ませた記録
    static func settlement(from: String, to: String, amount: Double, date: Date) -> TripExpense {
        TripExpense(title: "精算", amount: amount, date: date, paidBy: from, splitWith: [to], isSettlement: true)
    }
}

// MARK: - 計算

/// 割り勘の計算。だれがいくら払い、いくら分を使ったかから、なるべく少ない受け渡しを出す
enum TripSplitLedger {

    /// 費用1つ
    struct Entry: Identifiable, Equatable {
        enum Source: Equatable {
            case scheduleItem
            case reservation
            case expense
        }
        var id: String
        var source: Source
        var title: String
        var amount: Double
        /// 何日目か。予約・旅行の外の日の支出は nil
        var dayNumber: Int?
        var paidBy: String?
        var splitWith: [String]?
        var splitAmounts: [String: Double]? = nil
    }

    /// 1人ぶん
    struct Balance: Equatable {
        var member: String
        /// 払った額
        var paid: Double
        /// その人が負担する額
        var share: Double
        /// 受け取る額（マイナスなら払う額）。精算の受け渡しを済ませた分も入る
        var net: Double
    }

    /// 受け渡し1つ
    struct Transfer: Equatable, Identifiable {
        var from: String
        var to: String
        var amount: Double
        var id: String { "\(from)>\(to)" }
    }

    /// 割り勘に入る人（ユーザーID か同行者の id）。
    /// 共有していればメンバー、していなければ自分。どちらにも同行者を足す
    static func members(of plan: TravelPlan, myUserId: String?) -> [String] {
        var ids: [String]
        if plan.isShared, !plan.sharedWith.isEmpty {
            ids = plan.sharedWith
        } else {
            ids = [myUserId ?? plan.ownerId ?? plan.userId ?? "me"]
        }
        for companion in plan.split.companions where !ids.contains(companion.id) {
            ids.append(companion.id)
        }
        return ids
    }

    /// 払った人が入っていない費用の持ち主。
    /// **共有していない旅行では自分が払ったことにする**（今までの費用をそのまま割り勘にできる）。
    /// 共有している旅行では誰か分からないので、決まっていないものとして精算に入れない
    static func defaultPayer(of plan: TravelPlan, myUserId: String?) -> String? {
        plan.isShared ? nil : members(of: plan, myUserId: myUserId).first
    }

    /// 旅行の費用を並べる（日の順）。金額は実際に使った額を優先し、無ければ予定の額
    static func entries(of plan: TravelPlan, myUserId: String?) -> [Entry] {
        let fallback = defaultPayer(of: plan, myUserId: myUserId)
        var result: [Entry] = []
        for day in plan.daySchedulesInRange {
            for item in day.scheduleItems {
                guard let amount = item.actualCost ?? item.cost, amount > 0 else { continue }
                result.append(Entry(id: item.id, source: .scheduleItem, title: item.title, amount: amount,
                                    dayNumber: day.dayNumber, paidBy: item.paidBy ?? fallback,
                                    splitWith: item.splitWith, splitAmounts: item.splitAmounts))
            }
        }
        for reservation in plan.reservationsWithCostOutsideItinerary {
            guard let amount = reservation.cost, amount > 0 else { continue }
            result.append(Entry(id: reservation.id, source: .reservation,
                                title: reservation.title.isEmpty ? reservation.kind.label : reservation.title,
                                amount: amount, dayNumber: nil, paidBy: reservation.paidBy ?? fallback,
                                splitWith: reservation.splitWith, splitAmounts: reservation.splitAmounts))
        }
        for expense in plan.split.expenses where !expense.settles {
            result.append(Entry(id: expense.id, source: .expense, title: expense.title, amount: expense.amount,
                                dayNumber: plan.dayNumber(of: expense.date), paidBy: expense.paidBy ?? fallback,
                                splitWith: expense.splitWith, splitAmounts: expense.splitAmounts))
        }
        return result
    }

    /// その費用を分ける人。決まっていない・知らない人しかいなければ全員
    static func sharers(of splitWith: [String]?, members: [String]) -> [String] {
        let chosen = (splitWith ?? []).filter(members.contains)
        return chosen.isEmpty ? members : chosen
    }

    /// 1つの費用を、人ごとにいくらずつ持つか。
    /// 金額を決めた人はその額、決めていない人は残りを同じ額ずつ。
    /// 全員の額を決めていて合計が合わなければ、差を全員で同じ額ずつ足し引きする（合計は必ず費用と同じ）
    static func shares(of amount: Double, splitWith: [String]?, splitAmounts: [String: Double]?,
                       members: [String]) -> [String: Double] {
        let sharers = sharers(of: splitWith, members: members)
        let fixed = (splitAmounts ?? [:]).filter { sharers.contains($0.key) }
        let rest = sharers.filter { fixed[$0] == nil }
        let remainder = amount - fixed.values.reduce(0, +)
        var result = fixed
        if rest.isEmpty {
            for member in sharers { result[member, default: 0] += remainder / Double(sharers.count) }
        } else {
            for member in rest { result[member] = max(remainder, 0) / Double(rest.count) }
        }
        return result
    }

    /// 払った人が決まっていない（か、もう居ない人の）費用。精算に入らない
    static func unassigned(_ entries: [Entry], members: [String]) -> [Entry] {
        entries.filter { entry in entry.paidBy.map { !members.contains($0) } ?? true }
    }

    static func balances(entries: [Entry], settlements: [TripExpense], members: [String]) -> [Balance] {
        var paid: [String: Double] = [:]
        var share: [String: Double] = [:]
        for entry in entries {
            guard let payer = entry.paidBy, members.contains(payer) else { continue }
            paid[payer, default: 0] += entry.amount
            for (member, value) in shares(of: entry.amount, splitWith: entry.splitWith,
                                          splitAmounts: entry.splitAmounts, members: members) {
                share[member, default: 0] += value
            }
        }
        // 済ませた受け渡し：払った人は受け取る側から「借り」が減る
        var settled: [String: Double] = [:]
        for settlement in settlements where settlement.settles {
            guard let from = settlement.paidBy, let to = settlement.splitWith?.first,
                  members.contains(from), members.contains(to) else { continue }
            settled[from, default: 0] += settlement.amount
            settled[to, default: 0] -= settlement.amount
        }
        return members.map { member in
            let p = paid[member] ?? 0, s = share[member] ?? 0
            return Balance(member: member, paid: p, share: s, net: p - s + (settled[member] ?? 0))
        }
    }

    /// 受け渡しを、なるべく少ない回数にする（払う額の大きい人から、受け取る額の大きい人へ）。
    /// 通貨のいちばん小さい単位（円なら1円、ユーロなら1セント）で四捨五入し、それに満たない差は出さない
    static func transfers(from balances: [Balance], unit: Double = 1) -> [Transfer] {
        let half = unit / 2
        var creditors = balances.filter { $0.net >= half }.map { ($0.member, $0.net) }
        var debtors = balances.filter { $0.net <= -half }.map { ($0.member, -$0.net) }
        creditors.sort { $0.1 > $1.1 }
        debtors.sort { $0.1 > $1.1 }
        var result: [Transfer] = []
        var c = 0, d = 0
        while c < creditors.count, d < debtors.count {
            let amount = min(creditors[c].1, debtors[d].1)
            let rounded = (amount / unit).rounded() * unit
            if rounded >= unit - unit / 1_000 {
                result.append(Transfer(from: debtors[d].0, to: creditors[c].0, amount: rounded))
            }
            creditors[c].1 -= amount
            debtors[d].1 -= amount
            if creditors[c].1 < half { c += 1 }
            if debtors[d].1 < half { d += 1 }
        }
        return result
    }
}

extension TravelPlan {
    /// その日付が何日目か。旅行の外なら nil
    func dayNumber(of date: Date, calendar: Calendar = .current) -> Int? {
        let offset = calendar.dateComponents([.day], from: calendar.startOfDay(for: startDate),
                                             to: calendar.startOfDay(for: date)).day ?? 0
        let lastDay = (calendar.dateComponents([.day], from: calendar.startOfDay(for: startDate),
                                               to: calendar.startOfDay(for: endDate)).day ?? 0) + 1
        let day = offset + 1
        return (1...max(lastDay, 1)).contains(day) ? day : nil
    }

    /// 割り勘に入る人の名前（共有メンバーの呼び方・同行者の名前）
    func splitMemberName(_ id: String, names: [String: String], myUserId: String?) -> String {
        if let companion = split.companions.first(where: { $0.id == id }) { return companion.name }
        if !isShared || sharedWith.isEmpty { return "自分" }
        return SharedMembers.displayName(of: id, names: names, members: sharedWith, myUserId: myUserId)
    }
}
