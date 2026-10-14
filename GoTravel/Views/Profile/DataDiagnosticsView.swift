import SwiftUI
import CoreData
import CloudKit

// MARK: - データの診断
//
// 旅行計画が見当たらないときに、端末と iCloud のどちらにあるのか（どちらにも無いのか）を
// 確かめ、戻し方を案内する画面（`DataDiagnostics`）。
// 結果はそのまま「ご意見・ご要望」に添えて開発者に送れる

struct DataDiagnosticsView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var report: DataDiagnostics.Report?
    @State private var isRunning = false
    @State private var showsFeedback = false
    @State private var showsBackup = false
    @State private var backup: TravelPlanBackupStore.Backup?
    @State private var showsAdoptConfirmation = false
    @State private var adoptedCount: Int?
    /// 端末の中の毎日の控え（3.0）
    @State private var snapshot: LocalSnapshotStore.Snapshot?
    @State private var showsRestoreConfirmation = false
    @State private var restoreMessage: String?

    private var theme: ThemePreset { themeManager.currentTheme }
    private var textColor: Color { theme.adaptiveText(for: colorScheme) }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("旅行計画が見当たらないときに、端末とiCloudのどちらに残っているかを確かめます。旅行計画の中身は読みません。")
                            .font(.footnote)
                            .foregroundColor(theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        if let report, !isRunning {
                            verdictCard(report)
                            actions(report)
                            details(report)
                        } else {
                            runningCard
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("データの診断")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                        .foregroundColor(theme.actionFill)
                }
            }
            .task { await run() }
            .sheet(isPresented: $showsFeedback) {
                if let report {
                    FeedbackFormView(kind: .bug, diagnostics: DataDiagnostics.text(for: report))
                }
            }
            .sheet(isPresented: $showsBackup) {
                if let backup {
                    TravelPlanBackupView(backup: backup)
                }
            }
            .alert("今のアカウントで表示しますか？", isPresented: $showsAdoptConfirmation) {
                Button("表示する") { adopt() }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("前に別のApple アカウントでサインインしたときの旅行計画・予定・保存した場所を、今のアカウントの一覧に出します。")
            }
            .alert("控えから戻しますか？", isPresented: $showsRestoreConfirmation) {
                Button("戻す") { restoreFromSnapshot() }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text(snapshot.map { "\($0.savedAt.formatted(.dateTime.month().day().hour().minute()))の控え（\($0.export.summary)）から戻します。写真は戻りません。" } ?? "")
            }
            .alert("戻しました", isPresented: restoreBinding) {
                Button("OK", role: .cancel) { restoreMessage = nil }
            } message: {
                Text(restoreMessage ?? "")
            }
            .alert("表示しました", isPresented: adoptedBinding) {
                Button("OK", role: .cancel) { adoptedCount = nil }
            } message: {
                Text("旅行計画\(adoptedCount ?? 0)件を、今のアカウントで表示しました。")
            }
        }
    }

    // MARK: - 中身

    private var runningCard: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("端末とiCloudを確かめています…")
                .font(.subheadline)
                .foregroundColor(textColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(RoundedRectangle(cornerRadius: theme.style.radiusMedium).fill(cardFill))
    }

    private func verdictCard(_ report: DataDiagnostics.Report) -> some View {
        let verdict = report.verdict
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: verdict.icon)
                    .font(.title3)
                    .foregroundColor(verdict.isGood ? theme.success : theme.actionFill)
                Text(verdict.title)
                    .font(.headline)
                    .foregroundColor(textColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(verdict.message)
                .font(.subheadline)
                .foregroundColor(textColor.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(RoundedRectangle(cornerRadius: theme.style.radiusMedium).fill(cardFill))
    }

    @ViewBuilder
    private func actions(_ report: DataDiagnostics.Report) -> some View {
        VStack(spacing: 10) {
            if case .otherUser = report.verdict {
                actionButton("今のアカウントで表示する", icon: "person.crop.circle.badge.checkmark", primary: true) {
                    showsAdoptConfirmation = true
                }
            }
            // iCloud にデータが無いと確かめられたときだけ、毎日の控えから戻せる
            if let snapshot, DataDiagnostics.canRestoreFromSnapshot(report.verdict) {
                actionButton("控えから戻す（\(snapshot.savedAt.formatted(.dateTime.month().day()))の控え）",
                             icon: "arrow.uturn.backward.circle.fill", primary: true) {
                    showsRestoreConfirmation = true
                }
            }
            if backup != nil, !report.verdict.isGood {
                actionButton("前回の控えを見る（日程・予約番号・持ち物）", icon: "doc.text.magnifyingglass", primary: false) {
                    showsBackup = true
                }
            }
            actionButton("この結果を開発者に送る", icon: "paperplane.fill", primary: !report.verdict.isGood) {
                showsFeedback = true
            }
            actionButton("もう一度確かめる", icon: "arrow.clockwise", primary: false) {
                Task { await run() }
            }
        }
    }

    private func actionButton(_ title: String, icon: String, primary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundColor(primary ? .white : theme.actionFill)
                .background(
                    RoundedRectangle(cornerRadius: theme.style.radiusMedium)
                        .fill(primary ? theme.actionFill : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: theme.style.radiusMedium)
                        .stroke(theme.actionFill.opacity(primary ? 0 : 0.5), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    /// 数えた中身。お問い合わせのときに読み上げてもらえるよう、そのまま出す
    private func details(_ report: DataDiagnostics.Report) -> some View {
        let local = report.local
        return VStack(alignment: .leading, spacing: 12) {
            Text("くわしい結果")
                .font(.subheadline.bold())
                .foregroundColor(textColor)

            detailGroup("この端末", rows: [
                ("旅行計画", "\(local.travelPlans)件"),
                ("最近削除した旅行計画", "\(local.trashedTravelPlans)件"),
                ("予定", "\(local.plans)件"),
                ("保存した場所", "\(local.places)件")
            ] + (local.otherUserTravelPlanCount > 0
                 ? [("別のアカウントの旅行計画", "\(local.otherUserTravelPlanCount)件")] : []))

            detailGroup("iCloud", rows: cloudRows(report))

            if let count = report.backupCount, let savedAt = report.backupSavedAt {
                detailGroup("前回の控え", rows: [
                    ("旅行計画", "\(count)件"),
                    ("保存した日時", savedAt.formatted(.dateTime.month().day().hour().minute()))
                ])
            }
        }
    }

    private func cloudRows(_ report: DataDiagnostics.Report) -> [(String, String)] {
        let account = ("状態", report.accountStatus == .available ? "使えます" : "使えません")
        switch report.cloud {
        case .counted(let counts):
            return [account,
                    ("旅行計画", "\(counts.travelPlans)件"),
                    ("最近削除した旅行計画", "\(counts.trashedTravelPlans)件"),
                    ("予定", "\(counts.plans)件"),
                    ("保存した場所", "\(counts.places)件")]
        case .zoneMissing:
            return [account, ("Travoryのデータ", "ありません")]
        case .zoneDeleted:
            return [account, ("Travoryのデータ", "削除されています")]
        case .skipped:
            return [account]
        case .failed:
            return [account, ("Travoryのデータ", "確かめられませんでした")]
        }
    }

    private func detailGroup(_ title: String, rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(theme.secondaryText)
            ForEach(rows, id: \.0) { row in
                HStack {
                    Text(row.0)
                    Spacer()
                    Text(row.1).monospacedDigit()
                }
                .font(.subheadline)
                .foregroundColor(textColor)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: theme.style.radiusMedium).fill(cardFill))
    }

    // MARK: - 動作

    private func run() async {
        guard let userId = authVM.userId, !isRunning else { return }
        isRunning = true
        let result = await DataDiagnostics.run(userId: userId)
        backup = TravelPlanBackupStore.load(userId: userId)
        snapshot = LocalSnapshotStore.latest(userId: userId)
        report = result
        isRunning = false
    }

    /// 毎日の控えから戻す。ID で突き合わせ、無いものだけを足す（`DataExportService.apply`）
    private func restoreFromSnapshot() {
        guard let snapshot, let userId = authVM.userId else { return }
        Task {
            let result = await Task.detached(priority: .userInitiated) { () -> DataExportService.ImportResult in
                let context = CoreDataManager.shared.persistentContainer.newBackgroundContext()
                return DataExportService.apply(snapshot.export, userId: userId, context: context)
            }.value
            restoreMessage = result.message
            await run()
        }
    }

    private func adopt() {
        guard let userId = authVM.userId else { return }
        adoptedCount = DataDiagnostics.adoptOtherUserData(into: userId, context: CoreDataManager.shared.viewContext)
        Task { await run() }
    }

    private var restoreBinding: Binding<Bool> {
        Binding(get: { restoreMessage != nil }, set: { if !$0 { restoreMessage = nil } })
    }

    private var adoptedBinding: Binding<Bool> {
        Binding(get: { adoptedCount != nil }, set: { if !$0 { adoptedCount = nil } })
    }

    // MARK: - 部品

    private var cardFill: Color {
        colorScheme == .dark ? theme.secondaryBackgroundDark : theme.secondaryBackgroundLight
    }

    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: colorScheme == .dark
                ? [theme.backgroundDark, theme.secondaryBackgroundDark]
                : [theme.backgroundLight, theme.secondaryBackgroundLight]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

// MARK: - 判定の見せ方

extension DataDiagnostics.Verdict {

    /// 心配の要らない結果か
    var isGood: Bool {
        if case .fine = self { return true }
        return false
    }

    var icon: String {
        switch self {
        case .fine: return "checkmark.circle.fill"
        case .partiallyLoaded, .cloudHasData: return "icloud.and.arrow.down.fill"
        case .inTrash: return "trash.fill"
        case .otherUser: return "person.2.fill"
        case .iCloudUnavailable: return "exclamationmark.icloud.fill"
        case .cloudDeleted, .cloudEmpty: return "icloud.slash.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }

    var title: String {
        switch self {
        case .fine(let count): return "旅行計画はこの端末にあります（\(count)件）"
        case .partiallyLoaded: return "iCloudから読み込んでいる途中です"
        case .inTrash(let count): return "最近削除した旅行計画に\(count)件あります"
        case .otherUser(let count): return "別のアカウントの旅行計画が\(count)件あります"
        case .iCloudUnavailable: return "iCloudにつながっていません"
        case .cloudHasData(let count): return "iCloudに旅行計画が\(count)件残っています"
        case .cloudDeleted: return "iCloudのTravoryのデータが削除されています"
        case .cloudEmpty: return "iCloudに旅行計画が見つかりません"
        case .unknown: return "iCloudの中を確かめられませんでした"
        }
    }

    var message: String {
        switch self {
        case .fine:
            return "一覧に出ていないときは、旅行計画の上の絞り込み（すべて・進行中など）をお確かめください。"
        case .partiallyLoaded(let local, let cloud):
            return "この端末に\(local)件、iCloudに\(cloud)件あります。通信できる場所で Travory を開いたまま、数分お待ちください。しばらくしても増えないときは、この結果を開発者に送ってください。"
        case .inTrash:
            return "削除した旅行計画は、30日間は「プロフィール」→「最近削除した旅行計画」から戻せます。"
        case .otherUser:
            return "この端末には、前に別のApple アカウントでサインインしたときの旅行計画があります。下の「今のアカウントで表示する」で、一覧に出せます。"
        case .iCloudUnavailable:
            return ICloudGuidanceText.dataUnavailable
        case .cloudHasData:
            return """
            データはiCloudに残っていますが、この端末に読み込まれていません。次の順にお試しください。

            1. 通信できる場所で Travory を開いたまま、数分待つ
            2. 設定アプリの一番上のお名前を開き、パスワードの入力や規約への同意が出ていれば済ませる
            3. それでも戻らないときは、この結果を開発者に送ってください。戻し方をご案内します
            """
        case .cloudDeleted:
            return "設定の「iCloud」→「ストレージを管理」などから、Travory のデータが削除されています。iCloudから戻すことはできません。共有していた旅行計画は、同行者に共有コードを教えてもらうと参加し直せます。"
        case .cloudEmpty:
            return "iCloudに Travory の旅行計画が保存されていませんでした。iCloudの容量がいっぱいだった、または Travory の iCloud がオフになっていたおそれがあります。共有していた旅行計画は、同行者に共有コードを教えてもらうと参加し直せます。この結果を開発者に送っていただければ、詳しくお調べします。"
        case .unknown:
            return "通信できる場所で「もう一度確かめる」をお試しください。続くときは、この結果を開発者に送ってください。"
        }
    }
}
