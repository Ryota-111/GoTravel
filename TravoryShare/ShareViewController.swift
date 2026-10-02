import UIKit
import SwiftUI
import UniformTypeIdentifiers
import ImageIO
import Combine

/// 共有メニューの「Travory」。
///
/// 予約確認メールの本文や、確認画面のスクリーンショットを受け取り、
/// アプリとの共有フォルダ（App Group）に置くだけにする。
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

    private func receive() async {
        let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        var saved = false

        for item in items {
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier),
                   let data = await loadImageData(provider),
                   ShareInboxWriter.save(imageData: data) {
                    saved = true
                } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                          let text = await loadText(provider),
                          ShareInboxWriter.save(text: text) {
                    saved = true
                }
            }
            // メールで選んだ文字は、添付ではなく本文として届くことがある
            if !saved, let text = item.attributedContentText?.string, ShareInboxWriter.save(text: text) {
                saved = true
            }
        }
        state.result = saved ? .saved : .nothing
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
/// - 本文は `.txt`（UTF-8）、画像は `.jpg`
/// - ファイル名は `<送った時刻のミリ秒>-<UUID>.<拡張子>`
enum ShareInboxWriter {
    static let appGroupId = "group.com.gmail.taismryotasis.Travory"
    static let folderName = "SharedImportInbox"

    static func save(text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return false }
        return write(data, extension: "txt")
    }

    static func save(imageData: Data) -> Bool {
        write(imageData, extension: "jpg")
    }

    private static func write(_ data: Data, extension ext: String) -> Bool {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else { return false }
        let folder = container.appendingPathComponent(folderName, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let millis = Int64(Date().timeIntervalSince1970 * 1000)
            try data.write(to: folder.appendingPathComponent("\(millis)-\(UUID().uuidString).\(ext)"), options: .atomic)
            return true
        } catch {
            return false
        }
    }
}

// MARK: - 画面

@MainActor
final class ShareState: ObservableObject {
    enum Result { case saving, saved, nothing }
    @Published var result: Result = .saving
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
            case .saved:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.green)
                Text("Travory に送りました")
                    .font(.headline)
                Text("Travory を開くと、どの旅行の予約か選んで取り込めます。保存する前に内容を確かめられます。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            case .nothing:
                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)
                Text("送れる本文や画像がありませんでした")
                    .font(.headline)
                Text("予約確認メールの本文を選んで共有するか、確認画面のスクリーンショットを共有してください。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            Button(action: close) {
                Text(state.result == .saving ? "キャンセル" : "閉じる")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .background(Color(.systemBackground))
    }
}
