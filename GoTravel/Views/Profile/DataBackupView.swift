import SwiftUI
import CoreData
import UniformTypeIdentifiers

/// データの書き出し・読み込み（3.0、プロフィールから）。
///
/// iCloud だけに頼らず、自分の手でデータを保存しておき、いつでも戻せるようにする
struct DataBackupView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @ObservedObject private var themeManager = ThemeManager.shared

    @State private var includesImages = true
    @State private var imagesSizeText: String?
    @State private var isWorking = false
    @State private var shareItem: ShareFile?
    @State private var showsImporter = false
    @State private var opened: DataExportService.OpenedFile?
    @State private var showsConfirm = false
    /// 毎日の控え（開いたときに1回だけ読む。ファイルを読むので、描くたびには読まない）
    @State private var snapshotSummary: (savedAt: Date, summary: String)?
    @State private var message: String?
    @AppStorage(Self.lastExportKey) private var lastExportAt: Double = 0

    static let lastExportKey = "DataBackup.lastExportAt"
    /// 前の書き出しからこれだけたったら、プロフィールで知らせる
    static let reminderInterval: TimeInterval = 90 * 24 * 60 * 60

    private struct ShareFile: Identifiable {
        let url: URL
        var id: URL { url }
    }

    var body: some View {
        Form {
            Section {
                Text("旅行計画・予定・保存した場所・アルバムなどを1つのファイルにして、「ファイル」アプリなどに保存できます。iCloud のデータが失われても、このファイルから戻せます。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Section {
                Toggle("写真も入れる", isOn: $includesImages)
                if includesImages, let imagesSizeText {
                    Text("写真の分：約\(imagesSizeText)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Button {
                    Task { await export() }
                } label: {
                    Label("書き出す", systemImage: "square.and.arrow.up")
                        .fontWeight(.semibold)
                }
                .disabled(isWorking)
            } header: {
                Text("書き出す")
            } footer: {
                Text((lastExportAt > 0
                      ? "前回の書き出し：\(Date(timeIntervalSince1970: lastExportAt).formatted(.dateTime.year().month().day()))。"
                      : "まだ書き出していません。")
                     + "ファイルには予約番号なども入ります。人に送らず、ご自身で保管してください。")
            }

            Section {
                Button {
                    showsImporter = true
                } label: {
                    Label("ファイルから読み込む", systemImage: "square.and.arrow.down")
                }
                .disabled(isWorking)
            } header: {
                Text("読み込む")
            } footer: {
                Text("この iPhone に無いものだけを足します。すでにあるものは、そのままにします（読み込みで消えることはありません）。iCloud から読み込んでいる途中のときは、終わってから読み込んでください。")
            }

            if let snapshot = snapshotSummary {
                Section {
                    Text("この iPhone の中にも、毎日の控え（直近\(LocalSnapshotStore.keepDays)日分）を自動で残しています。最新：\(snapshot.savedAt.formatted(.dateTime.month().day().hour().minute()))（\(snapshot.summary)）")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } header: {
                    Text("自動の控え")
                } footer: {
                    Text("iCloud にデータが無いときは、「データの診断」から、この控えで戻せます。")
                }
            }
        }
        .tint(themeManager.currentTheme.actionFill)
        .navigationTitle("データの書き出し・読み込み")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isWorking {
                ProgressView()
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .task {
            if let userId = authVM.userId, let latest = LocalSnapshotStore.latest(userId: userId) {
                snapshotSummary = (latest.savedAt, latest.export.summary)
            }
            await measureImages()
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url]) { _, completed in
                if completed { lastExportAt = Date().timeIntervalSince1970 }
            }
        }
        .fileImporter(isPresented: $showsImporter, allowedContentTypes: [.item]) { result in
            guard case .success(let url) = result else { return }
            Task { await open(url) }
        }
        .confirmationDialog(confirmTitle, isPresented: $showsConfirm, titleVisibility: .visible) {
            Button("読み込む") {
                Task { await apply() }
            }
            Button("キャンセル", role: .cancel) { discardOpened() }
        } message: {
            Text("この iPhone に無いものだけを足します。")
        }
        .alert(message ?? "", isPresented: messageBinding) {
            Button("OK", role: .cancel) { message = nil }
        }
    }

    // MARK: - 動作

    private func measureImages() async {
        guard let userId = authVM.userId else { return }
        let size = await Task.detached(priority: .utility) { () -> Int64 in
            let context = CoreDataManager.shared.persistentContainer.newBackgroundContext()
            let export = DataExportService.collect(userId: userId, context: context)
            return DataExportService.imagesSize(DataExportService.imagePaths(for: export))
        }.value
        imagesSizeText = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    private func export() async {
        guard let userId = authVM.userId else { return }
        isWorking = true
        let includesImages = includesImages
        let result = await Task.detached(priority: .userInitiated) { () -> Result<URL, Error> in
            let context = CoreDataManager.shared.persistentContainer.newBackgroundContext()
            let export = DataExportService.collect(userId: userId, context: context)
            return Result { try DataExportService.writeFile(export, includesImages: includesImages) }
        }.value
        isWorking = false
        switch result {
        case .success(let url): shareItem = ShareFile(url: url)
        case .failure: message = DataExportService.ExportError.failed.localizedDescription
        }
    }

    private func open(_ url: URL) async {
        isWorking = true
        let result = await Task.detached(priority: .userInitiated) { Result { try DataExportService.open(url) } }.value
        isWorking = false
        switch result {
        case .success(let file):
            opened = file
            showsConfirm = true
        case .failure(let error): message = error.localizedDescription
        }
    }

    private func apply() async {
        guard let file = opened, let userId = authVM.userId else { return }
        isWorking = true
        let result = await Task.detached(priority: .userInitiated) { () -> DataExportService.ImportResult in
            let context = CoreDataManager.shared.persistentContainer.newBackgroundContext()
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            return DataExportService.apply(file.export, userId: userId, context: context, imagesFolder: file.folder)
        }.value
        isWorking = false
        discardOpened()
        message = result.message
    }

    private func discardOpened() {
        if let folder = opened?.folder { try? FileManager.default.removeItem(at: folder) }
        opened = nil
    }

    private var confirmTitle: String {
        guard let file = opened else { return "" }
        let date = file.export.exportedAt.formatted(.dateTime.year().month().day())
        return "\(date)に書き出したファイルです（\(file.export.summary)）。読み込みますか？"
    }

    private var messageBinding: Binding<Bool> {
        Binding(get: { message != nil }, set: { if !$0 { message = nil } })
    }
}
