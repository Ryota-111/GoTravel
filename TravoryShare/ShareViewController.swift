import UIKit
import SwiftUI
import UniformTypeIdentifiers
import ImageIO
import Combine

/// 共有メニューの「Travory」。
///
/// 予約確認メールの本文や、確認画面のスクリーンショットを受け取り、
/// アプリとの共有フォルダ（App Group）に置くだけにする。
/// 3.5 から、地図や店のリンク・Instagram などのスクリーンショットを「行きたい場所」としても送れる。
/// どちらとして送るかは、ここで選んでもらう（予約と場所は、アプリで続ける画面が違うため）
/// 3.6 から PDF も受け取る。Gmail アプリはメール1通を「印刷 → 共有」で PDF にしか出せないため。
/// PDF は予約としてだけ送る（選ぶ画面は出さない）。中の文字はアプリで読む（拡張は使えるメモリが少ない）
/// どの旅行の予約なのかはここでは分からず、読み取った内容も保存前に確かめて
/// もらいたいので、続きは次にアプリを開いたときに聞く（アプリの `SharedImportInbox`）
final class ShareViewController: UIViewController {

    private let state = ShareState()

    override func viewDidLoad() {
        super.viewDidLoad()
        let host = UIHostingController(rootView: ShareView(state: state) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        })
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)

        Task { await receive() }
    }

    /// 受け取ったもの。どちらとして送るか選ばれるまで持っておく
    private var texts: [String] = []
    private var images: [Data] = []
    /// 受け取った PDF を、この拡張の一時フォルダに写したもの（元のファイルは受け取りが終わると消える）
    private var pdfs: [URL] = []

    private func receive() async {
        let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []

        for item in items {
            var textsOfItem: [String] = []
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
                    if let url = await loadPDF(provider) { pdfs.append(url) }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier),
                   let data = await loadImageData(provider) {
                    images.append(data)
                } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
                          let url = await loadURL(provider) {
                    // 「ファイル」アプリなどからは、PDF がファイルの場所として届くことがある
                    if url.isFileURL {
                        if url.pathExtension.lowercased() == "pdf", let copy = Self.copyToTemporary(url) { pdfs.append(copy) }
                    } else {
                        textsOfItem.append(url.absoluteString)
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                          let text = await loadText(provider) {
                    textsOfItem.append(text)
                }
            }
            // メールで選んだ文字や、地図アプリの場所の名前は、添付ではなく本文として届くことがある
            if let text = item.attributedContentText?.string, !text.isEmpty,
               !textsOfItem.contains(where: { $0.contains(text) || text.contains($0) }) {
                textsOfItem.insert(text, at: 0)
            }
            if !textsOfItem.isEmpty { texts.append(textsOfItem.joined(separator: "\n")) }
        }

        guard !texts.isEmpty || !images.isEmpty || !pdfs.isEmpty else {
            state.result = .nothing
            return
        }
        // PDF だけなら、予約として送る（場所として送る使い方は無い）
        if texts.isEmpty && images.isEmpty {
            save(as: .reservation)
            return
        }
        state.suggestsPlace = Self.looksLikePlace(texts)
        state.result = .choosing
        state.onChoose = { [weak self] kind in self?.save(as: kind) }
    }

    /// 地図・店のリンクなら、場所として送るほうを先に出す
    private static func looksLikePlace(_ texts: [String]) -> Bool {
        let joined = texts.joined(separator: " ").lowercased()
        return ["maps.app.goo.gl", "google.com/maps", "goo.gl/maps", "maps.apple", "tabelog.com", "retty.me",
                "hotpepper.jp", "instagram.com", "tiktok.com"].contains { joined.contains($0) }
    }

    private func save(as kind: ShareInboxWriter.Kind) {
        var saved = false
        for text in texts where ShareInboxWriter.save(text: text, kind: kind) { saved = true }
        for data in images where ShareInboxWriter.save(imageData: data, kind: kind) { saved = true }
        // PDF はいつも予約の箱へ
        for url in pdfs where ShareInboxWriter.save(pdfAt: url) { saved = true }
        state.savedKind = kind
        state.result = saved ? .saved : .nothing
        if saved { openApp() }
    }

    /// 送ったあと、そのまま Travory に切り替える（アプリは開いたときに受け取り箱を見て、続きの画面を出す）。
    /// 共有の拡張からアプリを開く決まった方法は無いので、拡張を載せているアプリ（UIApplication）を探して開いてもらう。
    /// 開けなかったときは「Travory に送りました」の画面のまま残る
    private func openApp() {
        guard let url = URL(string: "travory://shared") else { return }
        var responder: UIResponder? = self
        while let current = responder {
            if let application = current as? UIApplication {
                application.open(url, options: [:]) { [weak self] opened in
                    if opened { self?.extensionContext?.completeRequest(returningItems: nil) }
                }
                return
            }
            responder = current.next
        }
    }

    /// PDF を一時フォルダに写す。大きすぎる PDF（20MB より大きい）は受け取らない
    private func loadPDF(_ provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: UTType.pdf.identifier) { url, _ in
                // 渡された場所は、この中を抜けると消されるので、ここで写す
                continuation.resume(returning: url.flatMap { Self.copyToTemporary($0) })
            }
        }
    }

    private static func copyToTemporary(_ url: URL) -> URL? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size <= ShareInboxWriter.maxPDFBytes else { return nil }
        let copy = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).pdf")
        do {
            try FileManager.default.copyItem(at: url, to: copy)
            return copy
        } catch {
            return nil
        }
    }

    private func loadURL(_ provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.url.identifier) { item, _ in
                if let url = item as? URL {
                    continuation.resume(returning: url)
                } else if let data = item as? Data {
                    continuation.resume(returning: URL(dataRepresentation: data, relativeTo: nil))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func loadText(_ provider: NSItemProvider) async -> String? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { item, _ in
                if let text = item as? String {
                    continuation.resume(returning: text)
                } else if let data = item as? Data {
                    continuation.resume(returning: String(data: data, encoding: .utf8))
                } else if let url = item as? URL {
                    continuation.resume(returning: try? String(contentsOf: url, encoding: .utf8))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// 画像は文字が読める大きさに縮めて JPEG にする。
    /// 共有メニューの拡張は使えるメモリが少なく、元の大きさのまま扱うと落ちることがある
    private func loadImageData(_ provider: NSItemProvider) async -> Data? {
        let raw: Data? = await withCheckedContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                continuation.resume(returning: data)
            }
        }
        guard let raw, let source = CGImageSourceCreateWithData(raw as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,   // 写真の向きを直してから縮める
            kCGImageSourceThumbnailMaxPixelSize: 3000
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: image).jpegData(compressionQuality: 0.9)
    }
}

// MARK: - アプリとの受け渡し

/// アプリの `SharedImportInbox` と同じ決まりで置く。**どちらかを変えたら、もう片方も揃えること**
/// - App Group の `SharedImportInbox/` フォルダに、1件1ファイル
/// - 本文は `.txt`（UTF-8）、画像は `.jpg`、PDF は `.pdf`（3.6。予約の箱にだけ置く）
/// - ファイル名は `<送った時刻のミリ秒>-<UUID>.<拡張子>`
enum ShareInboxWriter {
    static let appGroupId = "group.com.gmail.taismryotasis.Travory"
    static let maxPDFBytes = 20 * 1024 * 1024

    /// 予約として送るか、行きたい場所として送るか（3.5）。箱を分ける
    enum Kind {
        case reservation
        case place

        var folderName: String {
            switch self {
            case .reservation: return "SharedImportInbox"
            case .place: return "SharedPlaceInbox"
            }
        }
    }

    static func save(text: String, kind: Kind = .reservation) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return false }
        return write(data, extension: "txt", kind: kind)
    }

    static func save(imageData: Data, kind: Kind = .reservation) -> Bool {
        write(imageData, extension: "jpg", kind: kind)
    }

    /// 一時フォルダに写した PDF を、受け取り箱へ移す
    static func save(pdfAt url: URL) -> Bool {
        guard let folder = folder(for: .reservation) else { return false }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try FileManager.default.moveItem(at: url, to: folder.appendingPathComponent(newFileName(extension: "pdf")))
            return true
        } catch {
            return false
        }
    }

    private static func folder(for kind: Kind) -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId)?
            .appendingPathComponent(kind.folderName, isDirectory: true)
    }

    private static func newFileName(extension ext: String) -> String {
        "\(Int64(Date().timeIntervalSince1970 * 1000))-\(UUID().uuidString).\(ext)"
    }

    private static func write(_ data: Data, extension ext: String, kind: Kind) -> Bool {
        guard let folder = folder(for: kind) else { return false }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try data.write(to: folder.appendingPathComponent(newFileName(extension: ext)), options: .atomic)
            return true
        } catch {
            return false
        }
    }
}

// MARK: - 画面

@MainActor
final class ShareState: ObservableObject {
    enum Result { case saving, choosing, saved, nothing }
    @Published var result: Result = .saving
    /// 地図・店のリンクなど、場所らしいものか（場所のボタンを先に出す）
    @Published var suggestsPlace = false
    @Published var savedKind: ShareInboxWriter.Kind = .reservation
    var onChoose: ((ShareInboxWriter.Kind) -> Void)?
}

private struct ShareView: View {
    @ObservedObject var state: ShareState
    let close: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            switch state.result {
            case .saving:
                ProgressView()
                Text("送っています…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            case .choosing:
                Text("Travory に送る")
                    .font(.headline)
                Text("何として送りますか？")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                VStack(spacing: 10) {
                    if state.suggestsPlace {
                        choice(.place)
                        choice(.reservation)
                    } else {
                        choice(.reservation)
                        choice(.place)
                    }
                }
                .padding(.top, 8)
            case .saved:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.green)
                Text("Travory に送りました")
                    .font(.headline)
                Text(state.savedKind == .place
                     ? "Travory を開くと、見つかった場所を選んで「行きたい場所」に保存できます。"
                     : "Travory を開くと、どの旅行の予約か選んで取り込めます。保存する前に内容を確かめられます。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            case .nothing:
                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)
                Text("送れる本文や画像がありませんでした")
                    .font(.headline)
                Text("地図や店のリンク、予約確認メールの本文、スクリーンショット、PDF（20MB まで）を共有してください。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            Button(action: close) {
                Text(state.result == .saving || state.result == .choosing ? "キャンセル" : "閉じる")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .background(Color(.systemBackground))
    }

    private func choice(_ kind: ShareInboxWriter.Kind) -> some View {
        Button {
            state.onChoose?(kind)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: kind == .place ? "mappin.and.ellipse" : "ticket")
                    .font(.title3)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(kind == .place ? "行きたい場所として送る" : "予約として送る")
                        .font(.headline)
                    Text(kind == .place ? "地図・お店のリンク、Instagram・TikTok のスクショ" : "予約確認メール、予約画面のスクショ、PDF")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
