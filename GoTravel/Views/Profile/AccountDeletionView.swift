import SwiftUI

// MARK: - アカウント削除
//
// 2.9 までは「サインアウト」の隣に「アカウント削除」があり、確認も1回だけだった。
// 「旅行計画が全部消えた」お問い合わせ（2026年10月）で、iCloud に残っていたのが
// アカウント削除で消えない持ち物の候補だけだったことから、押し間違えのおそれがあると分かった。
// 別の画面に分け、消えるものを並べ、控えを残してもらい、「削除」と打たないと進めないようにする

/// アカウント削除の前に残す控え（文字だけ）。旅行計画は予約番号も入れる（本人が見返すためのもの）
enum AccountDeletionBackup {

    static func text(travelPlans: [TravelPlan], plans: [Plan], places: [VisitedPlace], now: Date = Date()) -> String {
        var sections: [String] = ["Travory の控え（\(TravelPlanTextExporter.dateString(now))）"]

        if !travelPlans.isEmpty {
            sections.append("■ 旅行計画（\(travelPlans.count)件）")
            for plan in travelPlans.sorted(by: { $0.startDate > $1.startDate }) {
                sections.append(TravelPlanTextExporter.fullItinerary(for: plan, includesConfirmationNumbers: true))
            }
        }

        if !plans.isEmpty {
            var lines = ["■ 予定（\(plans.count)件）"]
            for plan in plans.sorted(by: { $0.startDate > $1.startDate }) {
                var line = "・\(TravelPlanTextExporter.dateString(plan.startDate))"
                if let time = plan.timeRangeText { line += " \(time)" }
                line += "  \(plan.title)"
                lines.append(line)
                if let description = plan.description, !description.isEmpty { lines.append("  \(description)") }
            }
            sections.append(lines.joined(separator: "\n"))
        }

        if !places.isEmpty {
            var lines = ["■ 保存した場所（\(places.count)件）"]
            for place in places.sorted(by: { ($0.visitedAt ?? $0.createdAt) > ($1.visitedAt ?? $1.createdAt) }) {
                var line = "・\(place.title)"
                if let address = place.address, !address.isEmpty { line += "（\(address)）" }
                lines.append(line)
                if let notes = place.notes, !notes.isEmpty { lines.append("  \(notes)") }
            }
            sections.append(lines.joined(separator: "\n"))
        }

        return sections.joined(separator: "\n\n")
    }

    static func writeFile(_ text: String, now: Date = Date()) -> URL? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Travory_控え_\(formatter.string(from: now)).txt")
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }
}

/// アカウントを削除する画面
struct AccountDeletionView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var travelPlanViewModel: TravelPlanViewModel
    @EnvironmentObject private var plansViewModel: PlansViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) private var colorScheme

    @State private var confirmation = ""
    /// 共有シートで渡す控えのファイル。押したときに作る
    @State private var backupShare: BackupShare?
    /// 控えを保存（共有）し終えたか
    @State private var didSaveBackup = false
    @State private var backupError = false
    @State private var showsFinalConfirm = false
    @State private var showsDiagnostics = false

    private static let confirmationWord = "削除"

    private var canDelete: Bool {
        confirmation.trimmingCharacters(in: .whitespacesAndNewlines) == Self.confirmationWord
    }

    var body: some View {
        Form {
            Section {
                Label("サインアウトとは違い、元に戻せません", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundColor(.red)
                Text("アカウントを削除すると、この iPhone と iCloud から、次のデータがすべて消えます。ほかの iPhone や iPad からも消えます。")
                    .font(.subheadline)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(["旅行計画（最近削除した旅行計画も）", "予定・記念日・予定のカテゴリ（カレンダー）", "保存した場所・カテゴリー",
                             "アルバム・写真", "持ち物の候補・やることリスト"], id: \.self) { item in
                        Label(item, systemImage: "minus.circle")
                            .font(.subheadline)
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                Button {
                    showsDiagnostics = true
                } label: {
                    Label("データの診断を開く", systemImage: "stethoscope")
                }
            } header: {
                Text("旅行計画が見えなくなって困っている場合")
            } footer: {
                Text("削除しないでください。削除すると、iCloud に残っているかもしれないデータまで消えます。データの診断で、どこに残っているかを確かめられます。")
            }

            Section {
                // いつでも押せるようにし、押したときに控えを作る（開いたときに作れなかったら
                // ボタンごと出ない、ということが無いように）
                Button {
                    makeBackup()
                } label: {
                    Label(didSaveBackup ? "控えを保存しました（もう一度保存する）" : "控えを保存する（テキスト）",
                          systemImage: didSaveBackup ? "checkmark.circle.fill" : "square.and.arrow.down")
                }
            } header: {
                Text("1. 控えを残す")
            } footer: {
                Text("旅行計画（予約番号を含む）・予定・保存した場所を文字で書き出します。「ファイルに保存」やメモに残しておくと、削除したあとも見返せます。写真は含まれません。")
            }

            Section {
                TextField("「\(Self.confirmationWord)」と入力", text: $confirmation)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("アカウントを削除する", role: .destructive) {
                    showsFinalConfirm = true
                }
                .disabled(!canDelete)
            } header: {
                Text("2. 確かめる")
            } footer: {
                Text("消してよければ「\(Self.confirmationWord)」と入力してください。")
            }
        }
        .navigationTitle("アカウントを削除")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $backupShare) { share in
            ShareSheet(items: [share.url]) { _, completed in
                if completed { didSaveBackup = true }
            }
        }
        .alert("控えを作れませんでした", isPresented: $backupError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("もう一度お試しください。")
        }
        .confirmationDialog("本当にアカウントを削除しますか？", isPresented: $showsFinalConfirm, titleVisibility: .visible) {
            Button("削除する（元に戻せません）", role: .destructive) {
                authVM.deleteAccount()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text(didSaveBackup
                 ? "iCloud のデータも含めて、すべて消えます。"
                 : "控えをまだ保存していません。iCloud のデータも含めて、すべて消えます。")
        }
        .sheet(isPresented: $showsDiagnostics) {
            DataDiagnosticsView()
                .environmentObject(authVM)
        }
    }

    private struct BackupShare: Identifiable {
        let url: URL
        var id: URL { url }
    }

    private func makeBackup() {
        let places = authVM.userId.map { userId in
            ((try? VisitedPlaceEntity.fetchByUser(userId: userId, context: CoreDataManager.shared.viewContext)) ?? [])
                .map { $0.toVisitedPlace() }
        } ?? []
        let text = AccountDeletionBackup.text(travelPlans: travelPlanViewModel.travelPlans,
                                              plans: plansViewModel.plans, places: places)
        if let url = AccountDeletionBackup.writeFile(text) {
            backupShare = BackupShare(url: url)
        } else {
            backupError = true
        }
    }
}
