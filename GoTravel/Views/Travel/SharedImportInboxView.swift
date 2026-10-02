import SwiftUI

/// 共有メニューから送られた予約確認メールや画像を、どの旅行に入れるか選ぶ画面。
///
/// アプリを開いたときに、受け取り箱（`SharedImportInbox`）に残っていれば出す。
/// 旅行を選ぶと読み取り、予約の編集画面で確かめてから保存してもらう。
/// 取り込みは Travory Pro。買っていない人には説明だけ出し、送ったものは捨てられるようにする
struct SharedImportInboxView: View {
    @State var items: [SharedImportInbox.Item]

    @EnvironmentObject var viewModel: TravelPlanViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject private var proStore = ProStore.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    /// 読み取りの画面を開く旅行
    @State private var importTarget: TravelPlan?
    /// 選んだ旅行。シートが閉じると importTarget は空になるので、別に覚えておく
    @State private var chosenPlan: TravelPlan?
    /// 読み取った結果。読み取りの画面が閉じてから編集画面を開く（シートを2枚同時には出せない）
    @State private var readResults: [ImportedReservation] = []
    @State private var editing: EditingTarget?
    /// 編集画面を開いたときの予約の数。閉じたあとに増えていれば保存されたとみなす
    @State private var reservationCountBeforeEditing = 0
    @State private var showsProSheet = false

    private struct EditingTarget: Identifiable {
        let plan: TravelPlan
        let imports: [ImportedReservation]
        var id: String { plan.id ?? "" }
    }

    private var current: SharedImportInbox.Item? { items.first }

    private var cardFill: Color {
        colorScheme == .dark
            ? themeManager.currentTheme.secondaryBackgroundDark
            : themeManager.currentTheme.secondaryBackgroundLight
    }

    private var textColor: Color { ThemePreset.readableText(on: cardFill) }
    private var accent: Color { themeManager.currentTheme.actionFill }

    /// これからの旅行（終わっていないもの）を出発の近い順に、そのあと過去の旅行を新しい順に
    private var sortedPlans: (upcoming: [TravelPlan], past: [TravelPlan]) {
        let today = Calendar.current.startOfDay(for: Date())
        let upcoming = viewModel.travelPlans
            .filter { $0.endDate >= today }
            .sorted { $0.startDate < $1.startDate }
        let past = viewModel.travelPlans
            .filter { $0.endDate < today }
            .sorted { $0.startDate > $1.startDate }
        return (upcoming, past)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark
                    ? themeManager.currentTheme.backgroundDark
                    : themeManager.currentTheme.backgroundLight)
                    .ignoresSafeArea()

                if let current {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 18) {
                            preview(current)
                            if proStore.isPurchased {
                                planChooser
                            } else {
                                proNotice
                            }
                            discardButton(current)
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle(items.count > 1 ? "共有された予約（あと\(items.count)件）" : "共有された予約")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    // 捨てずに閉じる。次に開いたときにまた出す
                    Button("あとで") { dismiss() }
                        .foregroundColor(accent)
                }
            }
            .sheet(item: $importTarget, onDismiss: openEditorIfRead) { plan in
                ReservationEmailImportView(plan: plan, kind: nil, initial: current?.content) { results in
                    readResults = results
                }
            }
            .sheet(item: $editing, onDismiss: finishEditing) { target in
                ReservationEditorView(planId: target.plan.id ?? "",
                                      reservation: Reservation(),
                                      initialImports: target.imports)
                    .environmentObject(viewModel)
                    .environmentObject(authVM)
            }
            .sheet(isPresented: $showsProSheet) {
                ProSheet(highlighted: nil, dismissesOnPurchase: true)
            }
        }
    }

    // MARK: - 送られたもの

    private func preview(_ item: SharedImportInbox.Item) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.sentAt.formatted(.dateTime.month().day().hour().minute()) + " に送った内容")
                .font(.caption.weight(.semibold))
                .foregroundColor(themeManager.currentTheme.secondaryText)

            Group {
                switch item.content {
                case .text(let text):
                    Text(text.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(.system(size: 12))
                        .foregroundColor(textColor)
                        .lineLimit(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                case .image(let url):
                    if let image = UIImage(contentsOfFile: url.path) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 220)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(cardFill))
        }
    }

    // MARK: - 旅行を選ぶ

    @ViewBuilder
    private var planChooser: some View {
        let plans = sortedPlans
        VStack(alignment: .leading, spacing: 10) {
            Text("どの旅行の予約ですか？")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(themeManager.currentTheme.adaptiveText(for: colorScheme))

            if plans.upcoming.isEmpty && plans.past.isEmpty {
                Text("旅行計画がまだありません。先に旅行計画を作ってから、もう一度アプリを開いてください。")
                    .font(.system(size: 13))
                    .foregroundColor(themeManager.currentTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(plans.upcoming) { plan in
                planRow(plan)
            }

            if !plans.past.isEmpty {
                Text("過去の旅行")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(themeManager.currentTheme.secondaryText)
                    .padding(.top, 6)
                ForEach(plans.past.prefix(10)) { plan in
                    planRow(plan)
                }
            }
        }
    }

    private func planRow(_ plan: TravelPlan) -> some View {
        Button {
            readResults = []
            chosenPlan = plan
            importTarget = plan
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(plan.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(textColor)
                        .lineLimit(1)
                    Text(dateRangeText(plan) + "・" + plan.destination)
                        .font(.system(size: 12))
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(themeManager.currentTheme.secondaryText)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(cardFill))
        }
        .buttonStyle(.plain)
    }

    private func dateRangeText(_ plan: TravelPlan) -> String {
        let start = plan.startDate.formatted(.dateTime.month().day())
        let end = plan.endDate.formatted(.dateTime.month().day())
        return start == end ? start : "\(start)〜\(end)"
    }

    // MARK: - 買っていない人

    private var proNotice: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("確認メールや画像からの取り込みは、Travory Pro の機能です。")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(themeManager.currentTheme.adaptiveText(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
            Text("買うと、このまま旅行を選んで取り込めます。予約は手で入れることもできます（無料）。")
                .font(.system(size: 12))
                .foregroundColor(themeManager.currentTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                showsProSheet = true
            } label: {
                Text("Travory Pro について")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ThemePreset.readableText(on: accent))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(accent))
            }
            .buttonStyle(.plain)
        }
    }

    private func discardButton(_ item: SharedImportInbox.Item) -> some View {
        Button(role: .destructive) {
            SharedImportInbox.remove(item)
            moveToNext()
        } label: {
            Text("取り込まずに捨てる")
                .font(.system(size: 14))
                .frame(maxWidth: .infinity)
        }
        .padding(.top, 4)
    }

    // MARK: - 流れ

    /// 読み取れたら、予約の編集画面で確かめてもらう
    private func openEditorIfRead() {
        guard let plan = chosenPlan, !readResults.isEmpty else { return }
        reservationCountBeforeEditing = reservationCount(of: plan)
        editing = EditingTarget(plan: plan, imports: readResults)
    }

    /// 1件でも保存されていれば、送られたものは取り込み済みとして受け取り箱から消す。
    /// 保存せずに閉じたときは残す（旅行を選び直せるように）
    private func finishEditing() {
        defer {
            chosenPlan = nil
            readResults = []
        }
        guard let plan = chosenPlan, let current,
              reservationCount(of: plan) > reservationCountBeforeEditing else { return }
        SharedImportInbox.remove(current)
        moveToNext()
    }

    private func reservationCount(of plan: TravelPlan) -> Int {
        viewModel.travelPlans.first(where: { $0.id == plan.id })?.reservations.count ?? 0
    }

    private func moveToNext() {
        items.removeFirst()
        if items.isEmpty { dismiss() }
    }
}
