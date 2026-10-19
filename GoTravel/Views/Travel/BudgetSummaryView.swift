import SwiftUI

/// 旅行の費用（費用のタブ）。
///
/// 3.1 で家計簿のような作りにした。色のグラデーションや影のカード、見出しごとのアイコンをやめ、
/// 1枚の紙に「合計 → 精算 → 日ごとの明細」を細い線で区切って並べる。主役は数字で、
/// 誰が払ったか・誰と割り勘するかは金額の下に小さく添えるだけにする（`docs/設計_割り勘.md`）
struct BudgetSummaryView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var themeManager = ThemeManager.shared
    @EnvironmentObject var travelPlanViewModel: TravelPlanViewModel
    @EnvironmentObject var authVM: AuthViewModel

    let plan: TravelPlan
    /// タブに埋め込むときは true。独自のヘッダーを出さない
    var isEmbedded: Bool = false

    /// 明細を閉じている日
    @State private var collapsedDays: Set<Int> = []
    /// 払った人・割り勘する人を直している費用（支出なら中身ごと直す）
    @State private var editing: CostEditTarget?
    @State private var showsCompanionPrompt = false
    @State private var companionName = ""
    @State private var renamingCompanion: TripCompanion?

    /// ViewModelから最新のプランを見る。直した結果を即座に反映するため
    private var currentPlan: TravelPlan {
        travelPlanViewModel.travelPlans.first(where: { $0.id == plan.id }) ?? plan
    }

    private var myUserId: String? { authVM.userId }

    // MARK: - 色（1枚の紙の上に置く）

    private var paper: Color {
        colorScheme == .dark
            ? themeManager.currentTheme.secondaryBackgroundDark
            : themeManager.currentTheme.secondaryBackgroundLight
    }
    private var ink: Color { ThemePreset.readableText(on: paper) }
    private var faint: Color { ink.opacity(0.58) }
    private var rule: Color { ink.opacity(0.1) }
    /// 押せる文字（「済みにする」「＋ 支出を足す」など）
    private var tint: Color {
        ThemePreset.readableTintEitherWay(themeManager.currentTheme.primary, on: paper, minimum: 4.0)
    }
    private var warning: Color { ThemePreset.readableTint(themeManager.currentTheme.error, on: paper) }

    // MARK: - 金額

    private var allItems: [ScheduleItem] { currentPlan.daySchedulesInRange.flatMap(\.scheduleItems) }

    /// 行程に出ていない予約の費用（宿の予約番号と金額だけ控えた人の分も入れる）
    private var outsideReservations: [Reservation] {
        currentPlan.reservations.filter { (($0.cost ?? 0) > 0 || $0.foreignCost != nil)
            && !currentPlan.hasScheduleItems(forReservation: $0.id) }
    }

    /// 予定に使わない支出（精算の受け渡しは除く）
    private var expenses: [TripExpense] { currentPlan.split.expenses.filter { !$0.settles } }
    private var settlements: [TripExpense] { currentPlan.split.expenses.filter(\.settles) }

    private var plannedTotal: Double {
        allItems.compactMap(\.cost).reduce(0, +) + outsideReservations.compactMap(\.cost).reduce(0, +)
    }

    /// 実際に使った金額。支出は使ったものなので、ここに入れる
    private var actualTotal: Double {
        allItems.compactMap(\.actualCost).reduce(0, +) + expenses.map(\.amount).reduce(0, +)
    }

    private var hasActual: Bool { allItems.contains { $0.actualCost != nil } || !expenses.isEmpty }

    private var hasAnyCost: Bool { plannedTotal > 0 || hasActual }

    // MARK: - 割り勘

    private var memberNames: [String: String] { travelPlanViewModel.memberNames(for: currentPlan.id) }
    private var members: [String] { TripSplitLedger.members(of: currentPlan, myUserId: myUserId) }
    private var entries: [TripSplitLedger.Entry] { TripSplitLedger.entries(of: currentPlan, myUserId: myUserId) }

    private func name(_ id: String) -> String {
        currentPlan.splitMemberName(id, names: memberNames, myUserId: myUserId)
    }

    private var tripDays: Int {
        Calendar.current.dayDifference(from: currentPlan.startDate, to: currentPlan.endDate) + 1
    }

    // MARK: - Body

    var body: some View {
        Group {
            if isEmbedded {
                // 親がスクロールを持つので、ここでは入れ子にしない
                content
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 30)
            } else {
                VStack(spacing: 0) {
                    header
                    ScrollView(showsIndicators: false) {
                        content
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, 40)
                    }
                }
                .background(Color(.systemGroupedBackground).ignoresSafeArea())
                .navigationBarHidden(true)
            }
        }
        .sheet(item: $editing) { target in
            CostSplitEditor(target: target, plan: currentPlan, members: members, myUserId: myUserId, name: name,
                            onSave: save, onDelete: delete)
        }
        .alert("一緒に行く人", isPresented: $showsCompanionPrompt) {
            TextField("名前（父・さくら など）", text: $companionName)
            Button("足す") { addCompanion() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("アプリを使っていない人も、名前だけで割り勘に入れられます。")
        }
        .alert("名前を変える", isPresented: Binding(get: { renamingCompanion != nil },
                                                set: { if !$0 { renamingCompanion = nil } })) {
            TextField("名前", text: $companionName)
            Button("変える") { renameCompanion() }
            Button("キャンセル", role: .cancel) {}
        }
    }

    private var header: some View {
        HStack {
            Button { presentationMode.wrappedValue.dismiss() } label: {
                Image(systemName: "xmark").font(.body.weight(.semibold)).foregroundColor(.primary)
                    .frame(width: 36, height: 36)
            }
            Spacer()
            VStack(spacing: 1) {
                Text("費用").font(.headline)
                Text(currentPlan.title).font(.caption).foregroundColor(.secondary).lineLimit(1)
            }
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var content: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                totalSection
                splitSection
                if hasAnyCost || !currentPlan.split.expenses.isEmpty {
                    ledgerSection
                }
                if !foreignRates.isEmpty {
                    exchangeRateSection
                }
            }
            .padding(.horizontal, 18)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(paper))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(rule, lineWidth: 1))

            Button { editing = .newExpense } label: {
                Label("支出を足す", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(tint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(rule, lineWidth: 1))
            }
            .buttonStyle(.plain)

            if !hasAnyCost {
                Text("予定や予約に金額を入れるか、「支出を足す」から入れると、ここに出ます。")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - 合計

    private var totalSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(hasActual ? "使った金額" : "予算")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(faint)
                Spacer()
                Text("\(tripDays)日間").font(.footnote).foregroundColor(faint)
            }
            Text(yen(hasActual ? actualTotal : plannedTotal))
                .font(.system(size: 36, weight: .semibold))
                .monospacedDigit()
                .foregroundColor(ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if hasActual && plannedTotal > 0 {
                budgetLine
                HStack {
                    Text("予算 \(yen(plannedTotal))")
                    Spacer()
                    Text(remainingText)
                        .foregroundColor(actualTotal > plannedTotal ? warning : faint)
                }
                .font(.caption)
                .monospacedDigit()
                .foregroundColor(faint)
            } else if !hasActual && plannedTotal > 0 {
                Text("予定を押して「実際に使った金額」を入れると、予算との差が分かります。")
                    .font(.caption)
                    .foregroundColor(faint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 18)
    }

    /// 予算に対してどこまで使ったか（細い線1本）
    private var budgetLine: some View {
        GeometryReader { geo in
            let ratio = min(actualTotal / max(plannedTotal, 1), 1)
            ZStack(alignment: .leading) {
                Capsule().fill(rule)
                Capsule().fill(actualTotal > plannedTotal ? warning : ink.opacity(0.75))
                    .frame(width: max(geo.size.width * CGFloat(ratio), 3))
            }
        }
        .frame(height: 3)
    }

    private var remainingText: String {
        let difference = actualTotal - plannedTotal
        if difference > 0 { return "\(yen(difference)) 超えています" }
        if difference < 0 { return "あと \(yen(-difference))" }
        return "予算どおり"
    }

    // MARK: - 精算

    @ViewBuilder
    private var splitSection: some View {
        thinRule
        if members.count < 2 {
            VStack(alignment: .leading, spacing: 8) {
                sectionTitle("割り勘")
                Text("一緒に行く人を足すと、誰が誰にいくら払えばよいかを出します。")
                    .font(.caption)
                    .foregroundColor(faint)
                    .fixedSize(horizontal: false, vertical: true)
                addCompanionButton
            }
            .padding(.vertical, 16)
        } else {
            settlementBody
        }
    }

    private var settlementBody: some View {
        let balances = TripSplitLedger.balances(entries: entries, settlements: settlements, members: members)
        let transfers = TripSplitLedger.transfers(from: balances)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                sectionTitle("精算")
                Spacer()
                if !transfers.isEmpty {
                    Text("\(transfers.count)回").font(.footnote).foregroundColor(faint)
                }
                // 受け渡しを文字にして、LINE などで同行者に送る
                if !entries.isEmpty {
                    ShareLink(item: settlementText(transfers: transfers, balances: balances)) {
                        Label("送る", systemImage: "square.and.arrow.up")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(tint)
                    }
                    .padding(.leading, 8)
                }
            }
            if transfers.isEmpty {
                Text(entries.isEmpty ? "費用を入れると、ここに受け渡しが出ます。" : "精算はいりません。")
                    .font(.subheadline)
                    .foregroundColor(faint)
            } else {
                VStack(spacing: 10) {
                    ForEach(transfers) { transfer in transferRow(transfer) }
                }
            }
            if !settlements.isEmpty { settledList }
            perPerson(balances)
            membersRow
        }
        .padding(.vertical, 16)
    }

    private func transferRow(_ transfer: TripSplitLedger.Transfer) -> some View {
        HStack(spacing: 8) {
            Text(name(transfer.from)).lineLimit(1)
            Image(systemName: "arrow.right").font(.caption.weight(.semibold)).foregroundColor(faint)
            Text(name(transfer.to)).lineLimit(1)
            Spacer(minLength: 8)
            Text(yen(transfer.amount)).fontWeight(.semibold).monospacedDigit()
            Button("済み") { settle(transfer) }
                .font(.caption.weight(.semibold))
                .foregroundColor(tint)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .overlay(Capsule().stroke(tint.opacity(0.5), lineWidth: 1))
                .buttonStyle(.plain)
                .accessibilityLabel("\(name(transfer.from))から\(name(transfer.to))への\(yen(transfer.amount))を済みにする")
        }
        .font(.subheadline)
        .foregroundColor(ink)
    }

    /// 送る精算の文：
    /// 「沖縄（9月21日(月)〜9月23日(水)）の精算」、受け渡し、ひとりずつの払った額と負担する額
    private func settlementText(transfers: [TripSplitLedger.Transfer], balances: [TripSplitLedger.Balance]) -> String {
        var lines = ["\(currentPlan.title)（\(TravelPlanTextExporter.dateString(currentPlan.startDate))〜\(TravelPlanTextExporter.dateString(currentPlan.endDate))）の精算", ""]
        if transfers.isEmpty {
            lines.append("精算はいりません。")
        } else {
            lines += transfers.map { "\(name($0.from)) → \(name($0.to))　\(yen($0.amount))" }
        }
        if !settlements.isEmpty {
            lines += ["", "済み"]
            lines += settlements.map {
                "\(name($0.paidBy ?? "")) → \(name($0.splitWith?.first ?? ""))　\(yen($0.amount))"
            }
        }
        lines += ["", "ひとりずつ（払った額／負担する額）"]
        lines += balances.map { "\(name($0.member))　\(yen($0.paid))／\(yen($0.share))" }
        lines += ["", "割り勘した金額の合計 \(yen(entries.map(\.amount).reduce(0, +)))"]
        return lines.joined(separator: "\n")
    }

    /// 済ませた受け渡し。「取り消す」で、まだ済んでいないことに戻す
    private var settledList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("済み").font(.caption.weight(.semibold)).foregroundColor(faint)
            ForEach(settlements) { settlement in
                HStack(spacing: 6) {
                    Image(systemName: "checkmark").font(.caption2.weight(.bold))
                    Text("\(name(settlement.paidBy ?? "")) → \(name(settlement.splitWith?.first ?? ""))")
                    Spacer()
                    Text(yen(settlement.amount)).monospacedDigit()
                    Button("取り消す") {
                        withAnimation { delete(expenseId: settlement.id) }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(tint)
                    .padding(.leading, 6)
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(name(settlement.paidBy ?? ""))から\(name(settlement.splitWith?.first ?? ""))への精算の「済み」を取り消す")
                }
                .font(.caption)
                .foregroundColor(faint)
            }
        }
        .padding(.top, 2)
    }

    /// ひとりずつ：払った額と、その人が負担する額
    private func perPerson(_ balances: [TripSplitLedger.Balance]) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text("ひとりずつ")
                Spacer()
                Text("払った").frame(width: 84, alignment: .trailing)
                Text("負担する額").frame(width: 84, alignment: .trailing)
            }
            .font(.caption2.weight(.semibold))
            .foregroundColor(faint)
            ForEach(balances, id: \.member) { balance in
                HStack {
                    Text(name(balance.member)).lineLimit(1)
                    Spacer()
                    Text(yen(balance.paid)).frame(width: 84, alignment: .trailing)
                    Text(yen(balance.share)).frame(width: 84, alignment: .trailing)
                }
                .font(.caption)
                .monospacedDigit()
                .foregroundColor(ink)
            }
        }
        .padding(.top, 6)
    }

    /// 割り勘に入る人。同行者は長押しで名前を変えたり外したりできる
    private var membersRow: some View {
        ChipFlowLayout(spacing: 6) {
            ForEach(members, id: \.self) { member in
                let companion = currentPlan.split.companions.first { $0.id == member }
                Text(name(member))
                    .font(.caption)
                    .foregroundColor(ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(rule))
                    .contextMenu {
                        if let companion {
                            Button("名前を変える", systemImage: "pencil") {
                                companionName = companion.name
                                renamingCompanion = companion
                            }
                            Button("割り勘から外す", systemImage: "person.badge.minus", role: .destructive) {
                                removeCompanion(companion)
                            }
                        }
                    }
            }
            addCompanionButton
        }
        .padding(.top, 4)
    }

    private var addCompanionButton: some View {
        Button {
            companionName = ""
            showsCompanionPrompt = true
        } label: {
            Label("一緒に行く人", systemImage: "plus")
                .font(.caption.weight(.semibold))
                .foregroundColor(tint)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .overlay(Capsule().stroke(tint.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 明細（日ごと）

    private struct LedgerRow: Identifiable {
        var id: String
        var target: CostEditTarget
        var title: String
        var amount: Double?
        var isActual: Bool
        /// 予算と実際の額が違うときの予算
        var budget: Double?
        var foreignText: String?
        var missingRate: Bool
        var note: String?
        var paidBy: String?
        var splitWith: [String]?
        var splitAmounts: [String: Double]? = nil
    }

    private struct LedgerGroup: Identifiable {
        var id: String
        var title: String
        var subtitle: String?
        var dayNumber: Int?
        var rows: [LedgerRow]
        var total: Double { rows.compactMap(\.amount).reduce(0, +) }
    }

    private var ledgerGroups: [LedgerGroup] {
        let fallback = TripSplitLedger.defaultPayer(of: currentPlan, myUserId: myUserId)
        var groups: [LedgerGroup] = currentPlan.daySchedulesInRange.compactMap { day in
            var rows = day.scheduleItems
                .filter { ($0.cost ?? 0) > 0 || ($0.actualCost ?? 0) > 0 || $0.foreignCost != nil }
                .map { item in
                    LedgerRow(id: item.id, target: .scheduleItem(item.id), title: item.title,
                              amount: item.actualCost ?? item.cost, isActual: item.actualCost != nil,
                              budget: item.actualCost != nil && item.cost != item.actualCost ? item.cost : nil,
                              foreignText: Self.foreignText(item.foreignCost),
                              missingRate: item.foreignCost != nil && item.foreignCost?.rate == nil,
                              note: item.costNote, paidBy: item.paidBy ?? fallback, splitWith: item.splitWith,
                              splitAmounts: item.splitAmounts)
                }
            rows += expenses.filter { currentPlan.dayNumber(of: $0.date) == day.dayNumber }.map(expenseRow)
            guard !rows.isEmpty else { return nil }
            return LedgerGroup(id: "day\(day.dayNumber)", title: formatDate(currentPlan.date(forDay: day.dayNumber)),
                               subtitle: "Day \(day.dayNumber)", dayNumber: day.dayNumber, rows: rows)
        }
        let reservations = outsideReservations.map { reservation in
            LedgerRow(id: reservation.id, target: .reservation(reservation.id),
                      title: reservation.title.isEmpty ? reservation.kind.label : reservation.title,
                      amount: reservation.cost, isActual: false, budget: nil,
                      foreignText: Self.foreignText(reservation.foreignCost),
                      missingRate: reservation.foreignCost != nil && reservation.foreignCost?.rate == nil,
                      note: nil, paidBy: reservation.paidBy ?? fallback, splitWith: reservation.splitWith,
                      splitAmounts: reservation.splitAmounts)
        }
        if !reservations.isEmpty {
            groups.append(LedgerGroup(id: "reservations", title: "予約", subtitle: "行程に無いもの",
                                      dayNumber: nil, rows: reservations))
        }
        let others = expenses.filter { currentPlan.dayNumber(of: $0.date) == nil }.map(expenseRow)
        if !others.isEmpty {
            groups.append(LedgerGroup(id: "others", title: "旅行の前後", subtitle: nil, dayNumber: nil, rows: others))
        }
        return groups
    }

    private func expenseRow(_ expense: TripExpense) -> LedgerRow {
        LedgerRow(id: expense.id, target: .expense(expense), title: expense.title.isEmpty ? "支出" : expense.title,
                  amount: expense.amount, isActual: true, budget: nil, foreignText: nil, missingRate: false,
                  note: nil,
                  paidBy: expense.paidBy ?? TripSplitLedger.defaultPayer(of: currentPlan, myUserId: myUserId),
                  splitWith: expense.splitWith, splitAmounts: expense.splitAmounts)
    }

    private var ledgerSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if members.count >= 2 {
                thinRule
                Label("費用を押すと、払った人と割り勘する人を変えられます", systemImage: "hand.tap")
                    .font(.caption)
                    .foregroundColor(faint)
                    .padding(.vertical, 10)
            }
            ForEach(ledgerGroups) { group in
                thinRule
                groupHeader(group)
                if !(group.dayNumber.map(collapsedDays.contains) ?? false) {
                    VStack(spacing: 0) {
                        ForEach(group.rows) { row in ledgerRow(row) }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
    }

    private func groupHeader(_ group: LedgerGroup) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(group.title).font(.subheadline.weight(.semibold)).foregroundColor(ink)
            if let subtitle = group.subtitle {
                Text(subtitle).font(.caption).foregroundColor(faint)
            }
            Spacer(minLength: 4)
            Text(yen(group.total)).font(.subheadline.weight(.semibold)).monospacedDigit().foregroundColor(ink)
            if let day = group.dayNumber {
                Image(systemName: collapsedDays.contains(day) ? "chevron.right" : "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(faint)
                    .frame(width: 12)
            }
        }
        .padding(.top, 14)
        .padding(.bottom, 6)
        // Button にすると横スワイプでも反応してしまうため onTapGesture を使う
        .contentShape(Rectangle())
        .onTapGesture {
            guard let day = group.dayNumber else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                if collapsedDays.contains(day) { collapsedDays.remove(day) } else { collapsedDays.insert(day) }
            }
        }
    }

    private func ledgerRow(_ row: LedgerRow) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title).font(.subheadline).foregroundColor(ink).lineLimit(1)
                if let detail = detailText(row) {
                    Text(detail).font(.caption).foregroundColor(faint).lineLimit(2)
                }
                if row.missingRate {
                    Text("レートが入っていないので、合計に入っていません")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(warning)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(row.amount.map(yen) ?? "－")
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundColor(row.isActual ? ink : faint)
                if let budget = row.budget {
                    Text("予算 \(yen(budget))").font(.caption2).monospacedDigit().foregroundColor(faint)
                } else if !row.isActual, row.amount != nil, hasActual {
                    Text("予定").font(.caption2).foregroundColor(faint)
                }
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(faint.opacity(0.7))
        }
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .onTapGesture { editing = row.target }
        .accessibilityElement(children: .combine)
        .accessibilityHint("押すと、払った人と割り勘する人を選べます")
    }

    /// 「自分払い・父をのぞく ・ 2人分 ・ $120」
    private func detailText(_ row: LedgerRow) -> String? {
        var parts: [String] = []
        if members.count >= 2 {
            parts.append(splitText(paidBy: row.paidBy, splitWith: row.splitWith, splitAmounts: row.splitAmounts))
        }
        if let note = row.note, !note.isEmpty { parts.append(note) }
        if let foreign = row.foreignText { parts.append(foreign) }
        return parts.isEmpty ? nil : parts.joined(separator: " ・ ")
    }

    private func splitText(paidBy: String?, splitWith: [String]?, splitAmounts: [String: Double]? = nil) -> String {
        let payer = paidBy.flatMap { members.contains($0) ? "\(name($0))払い" : nil } ?? "払った人が未定"
        if let splitAmounts, !splitAmounts.isEmpty { return "\(payer)・金額を決めて割り勘" }
        let sharers = TripSplitLedger.sharers(of: splitWith, members: members)
        if sharers.count == members.count { return "\(payer)・全員" }
        let excluded = members.filter { !sharers.contains($0) }
        if excluded.count < sharers.count {
            return "\(payer)・\(excluded.map(name).joined(separator: "・"))をのぞく"
        }
        return "\(payer)・\(sharers.map(name).joined(separator: "・"))で割り勘"
    }

    private var thinRule: some View {
        Rectangle().fill(rule).frame(height: 1)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(.footnote.weight(.semibold)).foregroundColor(faint)
    }

    // MARK: - 外貨のレート

    /// この旅行で使っている外貨（円は除く）。通貨コード順
    private var foreignRates: [(code: String, rate: Double?)] {
        currentPlan.exchangeRates
            .filter { $0.key != CurrencyCatalog.yen }
            .map { (code: $0.key, rate: $0.value) }
            .sorted { $0.code < $1.code }
    }

    /// 旅行ごとのレート。ここで直すと、その通貨の費用がすべて円に直し直される
    private var exchangeRateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            thinRule
            sectionTitle("為替レート").padding(.top, 14)
            ForEach(foreignRates, id: \.code) { entry in
                ExchangeRateRow(code: entry.code, rate: entry.rate, textColor: ink, secondaryText: faint,
                                errorColor: warning) { newRate in
                    updatePlan { $0.setExchangeRate(newRate, for: entry.code) }
                }
            }
            Text("両替したときのレートを入れてください。その通貨の費用は、すべてこのレートで円に直して合計します。")
                .font(.caption2)
                .foregroundColor(faint)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 16)
        }
    }

    // MARK: - 保存

    private func updatePlan(_ change: (inout TravelPlan) -> Void) {
        guard let userId = myUserId else { return }
        var updated = currentPlan
        change(&updated)
        travelPlanViewModel.update(updated, userId: userId)
    }

    private func save(_ result: CostSplitEditor.Result) {
        updatePlan { plan in
            switch result {
            case .assignment(let target, let paidBy, let splitWith, let splitAmounts):
                switch target {
                case .scheduleItem(let id):
                    for d in plan.daySchedules.indices {
                        if let i = plan.daySchedules[d].scheduleItems.firstIndex(where: { $0.id == id }) {
                            plan.daySchedules[d].scheduleItems[i].paidBy = paidBy
                            plan.daySchedules[d].scheduleItems[i].splitWith = splitWith
                            plan.daySchedules[d].scheduleItems[i].splitAmounts = splitAmounts
                        }
                    }
                case .reservation(let id):
                    if let i = plan.reservations.firstIndex(where: { $0.id == id }) {
                        plan.reservations[i].paidBy = paidBy
                        plan.reservations[i].splitWith = splitWith
                        plan.reservations[i].splitAmounts = splitAmounts
                    }
                case .expense, .newExpense:
                    break
                }
            case .expense(let expense):
                if let i = plan.split.expenses.firstIndex(where: { $0.id == expense.id }) {
                    plan.split.expenses[i] = expense
                } else {
                    plan.split.expenses.append(expense)
                }
            }
        }
    }

    private func delete(expenseId: String) {
        updatePlan { $0.split.expenses.removeAll { $0.id == expenseId } }
    }

    private func settle(_ transfer: TripSplitLedger.Transfer) {
        updatePlan {
            $0.split.expenses.append(.settlement(from: transfer.from, to: transfer.to, amount: transfer.amount,
                                                 date: Date()))
        }
    }

    private func addCompanion() {
        let trimmed = companionName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        updatePlan { $0.split.companions.append(TripCompanion(name: trimmed)) }
    }

    private func renameCompanion() {
        let trimmed = companionName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let companion = renamingCompanion, !trimmed.isEmpty else { return }
        updatePlan { plan in
            if let i = plan.split.companions.firstIndex(where: { $0.id == companion.id }) {
                plan.split.companions[i].name = trimmed
            }
        }
        renamingCompanion = nil
    }

    /// 同行者を外す。その人が払った費用は「払った人が未定」に、その人が負担していた分は残りの人で分ける
    private func removeCompanion(_ companion: TripCompanion) {
        updatePlan { $0.split.companions.removeAll { $0.id == companion.id } }
    }

    // MARK: - Helpers

    /// 外貨の元の金額の書き方。実績があれば実績、無ければ予算
    private static func foreignText(_ foreign: ForeignCost?) -> String? {
        guard let foreign, let amount = foreign.actualAmount ?? foreign.amount else { return nil }
        return CurrencyCatalog.format(amount, code: foreign.currencyCode)
    }

    private func yen(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return "¥\(formatter.string(from: NSNumber(value: amount.rounded())) ?? "0")"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter.japanese
        formatter.dateFormat = "M月d日(E)"
        return formatter.string(from: date)
    }
}

// MARK: - 直す費用

/// 費用の画面で押したもの
enum CostEditTarget: Identifiable, Hashable {
    case scheduleItem(String)
    case reservation(String)
    case expense(TripExpense)
    case newExpense

    var id: String {
        switch self {
        case .scheduleItem(let id): return "item-\(id)"
        case .reservation(let id): return "reservation-\(id)"
        case .expense(let expense): return "expense-\(expense.id)"
        case .newExpense: return "new-expense"
        }
    }
}

extension TripExpense: Hashable {
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// 払った人と割り勘する人を選ぶ。支出なら、何に・いくら・いつも直せる
private struct CostSplitEditor: View {
    enum Result {
        case assignment(CostEditTarget, paidBy: String?, splitWith: [String]?, splitAmounts: [String: Double]?)
        case expense(TripExpense)
    }

    let target: CostEditTarget
    let plan: TravelPlan
    let members: [String]
    let myUserId: String?
    let name: (String) -> String
    let onSave: (Result) -> Void
    let onDelete: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var amountText = ""
    @State private var date = Date()
    @State private var payer: String?
    @State private var sharers: Set<String> = []
    /// 人ごとに金額を決めるか（決めなければ均等）
    @State private var byAmount = false
    /// 人ごとの金額の入力（空なら、残りを同じ額ずつ）
    @State private var amountTexts: [String: String] = [:]
    @FocusState private var amountFocused: Bool

    private var isExpense: Bool {
        switch target {
        case .expense, .newExpense: return true
        default: return false
        }
    }

    private var existingExpense: TripExpense? {
        if case .expense(let expense) = target { return expense }
        return nil
    }

    /// 選んでいる費用の名前と金額（予定・予約のとき）
    private var summary: (title: String, amount: Double?) {
        switch target {
        case .scheduleItem(let id):
            let item = plan.daySchedules.flatMap(\.scheduleItems).first { $0.id == id }
            return (item?.title ?? "", item.flatMap { $0.actualCost ?? $0.cost })
        case .reservation(let id):
            let reservation = plan.reservations.first { $0.id == id }
            return (reservation?.title ?? "", reservation?.cost)
        default:
            return ("", nil)
        }
    }

    private var amount: Double? { CurrencyCatalog.parse(amountText).flatMap { $0 > 0 ? $0 : nil } }

    /// 分ける元の金額
    private var total: Double? { isExpense ? amount : summary.amount }

    /// 金額を決めた人の額（チェックの付いた人だけ）
    private var fixedAmounts: [String: Double] {
        var result: [String: Double] = [:]
        for member in chosenSharers {
            if let value = amountTexts[member].flatMap(CurrencyCatalog.parse) { result[member] = value }
        }
        return result
    }

    /// 金額を決めていない人の、1人あたり
    private var restShare: Double? {
        guard let total else { return nil }
        let rest = chosenSharers.filter { fixedAmounts[$0] == nil }
        guard !rest.isEmpty else { return nil }
        return max(total - fixedAmounts.values.reduce(0, +), 0) / Double(rest.count)
    }

    /// 決めた額が合っていない理由（合っていれば nil）
    private var amountProblem: String? {
        guard byAmount, let total else { return nil }
        let fixedTotal = fixedAmounts.values.reduce(0, +)
        if fixedTotal > total + 0.5 {
            return "決めた額が \(TravelPlanTextExporter.currency(fixedTotal - total)) 多すぎます"
        }
        if fixedAmounts.count == chosenSharers.count, abs(fixedTotal - total) >= 0.5 {
            return "全員の額の合計が \(TravelPlanTextExporter.currency(total - fixedTotal)) 足りません"
        }
        return nil
    }

    private var canSave: Bool { (!isExpense || amount != nil) && amountProblem == nil }

    var body: some View {
        NavigationStack {
            Form {
                if isExpense {
                    Section {
                        TextField("何に（水・お土産 など）", text: $title)
                        HStack {
                            Text("¥").foregroundColor(.secondary)
                            TextField("金額", text: $amountText)
                                .keyboardType(.numberPad)
                                .focused($amountFocused)
                        }
                        DatePicker("日", selection: $date, displayedComponents: .date)
                    } footer: {
                        Text("予定にしない買い物や立て替えを入れます。日程には出ません。")
                    }
                } else {
                    Section {
                        HStack {
                            Text(summary.title).lineLimit(1)
                            Spacer()
                            if let amount = summary.amount {
                                Text(TravelPlanTextExporter.currency(amount)).monospacedDigit().foregroundColor(.secondary)
                            }
                        }
                    } footer: {
                        Text("金額は、実際に使った金額があればそれを、無ければ予定の金額を使います。")
                    }
                }

                if members.count >= 2 {
                    Section {
                        ForEach(members, id: \.self) { member in
                            // もう一度押すと選択を外す
                            choiceRow(name(member), isOn: payer == member) { payer = payer == member ? nil : member }
                        }
                    } header: {
                        Text("払った人")
                    } footer: {
                        if payer == nil {
                            Text(plan.isShared ? "選ばなければ、精算には入りません。" : "選ばなければ、自分が払ったことにします。")
                        }
                    }
                    Section {
                        Picker("分け方", selection: $byAmount) {
                            Text("均等に分ける").tag(false)
                            Text("金額を決める").tag(true)
                        }
                        .pickerStyle(.segmented)
                        ForEach(members, id: \.self) { member in
                            sharerRow(member)
                        }
                    } header: {
                        Text("割り勘する人")
                    } footer: {
                        if byAmount {
                            VStack(alignment: .leading, spacing: 4) {
                                if let amountProblem {
                                    Text(amountProblem).foregroundColor(.red)
                                }
                                Text("空欄の人は、残りを同じ額ずつ分けます。チェックを外すと、その人は払いません。")
                            }
                        } else {
                            Text("チェックの付いた人で同じ額ずつ分けます。押すと外したり戻したりできます（運転した人を外す、など）。")
                        }
                    }
                }

                if members.count >= 2, payer != nil || !sharers.isEmpty || byAmount {
                    Section {
                        Button("選択を外して、はじめの状態に戻す") {
                            payer = nil
                            sharers = []
                            byAmount = false
                            amountTexts = [:]
                        }
                    } footer: {
                        Text("払った人を選ばず、全員で割り勘する状態に戻します。")
                    }
                }

                if let existingExpense {
                    Section {
                        Button("この支出を削除", role: .destructive) {
                            onDelete(existingExpense.id)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(isExpense ? (existingExpense == nil ? "支出を足す" : "支出") : "割り勘")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }.fontWeight(.semibold).disabled(!canSave)
                }
            }
            .onAppear(perform: load)
        }
        .presentationDetents(isExpense ? [.large] : [.medium, .large])
    }

    private func choiceRow(_ label: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label).foregroundColor(.primary)
                Spacer()
                if isOn { Image(systemName: "checkmark").foregroundColor(.accentColor).fontWeight(.semibold) }
            }
        }
    }

    /// 割り勘する人の1行。金額を決めるときは、右に金額の欄を出す（空欄なら残りの等分を薄く出す）
    @ViewBuilder
    private func sharerRow(_ member: String) -> some View {
        let isOn = chosenSharers.contains(member)
        if byAmount {
            HStack {
                Button { toggleSharer(member) } label: {
                    HStack(spacing: 10) {
                        Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isOn ? .accentColor : .secondary)
                        Text(name(member)).foregroundColor(.primary)
                    }
                }
                .buttonStyle(.borderless)
                Spacer()
                if isOn {
                    Text("¥").foregroundColor(.secondary)
                    TextField(restShare.map { CurrencyCatalog.editingText($0.rounded()) } ?? "0",
                              text: Binding(get: { amountTexts[member] ?? "" },
                                            set: { amountTexts[member] = $0 }))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .monospacedDigit()
                        .frame(maxWidth: 110)
                }
            }
        } else {
            choiceRow(name(member), isOn: isOn) { toggleSharer(member) }
        }
    }

    /// 今チェックが付いている人（何も選んでいなければ全員）
    private var chosenSharers: Set<String> { sharers.isEmpty ? Set(members) : sharers }

    /// 押した人を外す・戻す。全員に付いたら「全員」として持つ。最後の1人は外せない
    private func toggleSharer(_ member: String) {
        var chosen = chosenSharers
        if chosen.contains(member) {
            guard chosen.count > 1 else { return }
            chosen.remove(member)
        } else {
            chosen.insert(member)
        }
        sharers = chosen.count == members.count ? [] : chosen
    }

    /// 保存してある選択をそのまま出す（選んでいなければ何も付けない）
    private func load() {
        switch target {
        case .scheduleItem(let id):
            let item = plan.daySchedules.flatMap(\.scheduleItems).first { $0.id == id }
            payer = item?.paidBy
            sharers = Set(item?.splitWith ?? [])
            loadAmounts(item?.splitAmounts)
        case .reservation(let id):
            let reservation = plan.reservations.first { $0.id == id }
            payer = reservation?.paidBy
            sharers = Set(reservation?.splitWith ?? [])
            loadAmounts(reservation?.splitAmounts)
        case .expense(let expense):
            title = expense.title
            amountText = CurrencyCatalog.editingText(expense.amount)
            date = expense.date
            payer = expense.paidBy
            sharers = Set(expense.splitWith ?? [])
            loadAmounts(expense.splitAmounts)
        case .newExpense:
            // 旅行中なら今日、そうでなければ旅行の初日
            let today = Date()
            date = plan.dayNumber(of: today) != nil ? today : plan.startDate
            payer = members.first { $0 == myUserId } ?? members.first
            amountFocused = true
        }
    }

    private func loadAmounts(_ amounts: [String: Double]?) {
        guard let amounts, !amounts.isEmpty else { return }
        byAmount = true
        amountTexts = amounts.mapValues { CurrencyCatalog.editingText($0) }
    }

    private func save() {
        let splitWith = SharedMembers.normalizedParticipants(sharers, members: members)
        // 均等なら持たない。金額を決めた人がいなければ均等と同じ
        let splitAmounts: [String: Double]? = byAmount && !fixedAmounts.isEmpty ? fixedAmounts : nil
        switch target {
        case .scheduleItem, .reservation:
            onSave(.assignment(target, paidBy: payer, splitWith: splitWith, splitAmounts: splitAmounts))
        case .expense(let expense):
            var updated = expense
            updated.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            updated.amount = amount ?? expense.amount
            updated.date = date
            updated.paidBy = payer
            updated.splitWith = splitWith
            updated.splitAmounts = splitAmounts
            onSave(.expense(updated))
        case .newExpense:
            guard let amount else { return }
            onSave(.expense(TripExpense(title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                                        amount: amount, date: date, paidBy: payer, splitWith: splitWith,
                                        splitAmounts: splitAmounts)))
        }
        dismiss()
    }
}

/// 名前の札を、幅に合わせて折り返して並べる
private struct ChipFlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: proposal.width ?? maxX, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// 為替レートの1行。打ち終わったとき（確定・フォーカスが外れたとき）だけ保存する。
/// 1文字ごとに保存すると、そのたびに旅行全体を書き直して共有にも送ってしまう
private struct ExchangeRateRow: View {
    let code: String
    let rate: Double?
    let textColor: Color
    let secondaryText: Color
    let errorColor: Color
    let onCommit: (Double?) -> Void

    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text("1 \(code) =")
                .font(.subheadline)
                .foregroundColor(textColor)
            TextField("未入力", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .focused($isFocused)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundColor(textColor)
                .frame(maxWidth: 100)
            Text("円")
                .font(.subheadline)
                .foregroundColor(secondaryText)
            Spacer(minLength: 4)
            Text(CurrencyCatalog.name(of: code))
                .font(.caption)
                .foregroundColor(rate == nil ? errorColor : secondaryText)
                .lineLimit(1)
        }
        .onAppear { text = CurrencyCatalog.editingText(rate) }
        .onChange(of: rate) { _, newValue in
            if !isFocused { text = CurrencyCatalog.editingText(newValue) }
        }
        .onChange(of: isFocused) { _, focused in
            guard !focused else { return }
            let newRate = CurrencyCatalog.parse(text).flatMap { $0 > 0 ? $0 : nil }
            if newRate != rate { onCommit(newRate) }
        }
        // 数字のキーボードには確定のキーが無いので、上に「完了」を出す
        .toolbar {
            if isFocused {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完了") { isFocused = false }
                }
            }
        }
    }
}
