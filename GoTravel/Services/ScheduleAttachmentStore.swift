import Foundation
import UIKit
import Combine

// MARK: - 予定の添付（3.5、ご要望から）
//
// 「予定や移動に、メモのほかに画像や PDF を添付できると便利」というご意見から。
// eチケット・地図のスクリーンショット・予約の控えなどを、その予定のところで開けるようにする。
//
// ## 置き場所
//
// **旅行の JSON（`ScheduleItem`）には入れない。** ファイルは端末の
// `Documents/ScheduleAttachments` に「予定の id + 足した時刻 + 名前」の名前で置き、
// その予定の添付はファイル名の頭で探す。
//
// - 共有した旅行でも、**添付は足した人にしか見えない**。チケットや予約の控えは個人のものが多く、
//   共有レコード（パブリックDB）に載せると、誰でも読める場所に置くことになるため
// - 旅行の JSON を変えないので、共有の突き合わせ・古い版・CloudKit のスキーマに影響しない
// - ほかの端末へは、写真と同じく `PhotoSyncService`（Pro）で預けて取り戻す
// - 予定を別の日へ移しても id は変わらないので、添付はついてくる

/// 予定に添付した1つのファイル
struct ScheduleAttachment: Identifiable, Hashable {
    /// 置いてあるファイル名。`<予定の id>__<足した時刻>__<名前>.<拡張子>`
    let fileName: String

    var id: String { fileName }

    var isPDF: Bool { (fileName as NSString).pathExtension.lowercased() == "pdf" }

    /// 画面に出す名前（足したときのファイル名。写真は「写真」）
    var displayName: String {
        let parts = fileName.components(separatedBy: ScheduleAttachmentStore.separator)
        let name = parts.count >= 3 ? parts.dropFirst(2).joined(separator: ScheduleAttachmentStore.separator) : fileName
        return name.isEmpty ? (isPDF ? "PDF" : "写真") : name
    }

    /// 端末に置いてある場所（まだ取り戻していなければ、ファイルは無い）
    var localURL: URL { PhotoFolder.scheduleAttachments.url().appendingPathComponent(fileName) }
}

@MainActor
final class ScheduleAttachmentStore: ObservableObject {

    static let shared = ScheduleAttachmentStore()

    /// 1つの予定に付けられる数
    static let maxPerItem = 10
    /// 1つのファイルの大きさの上限（PDF）。写真は小さくしてから置く
    static let maxFileBytes = 20 * 1024 * 1024
    /// 写真の長いほうの辺。読める大きさを保ちつつ、iCloud の容量を食わない
    static let maxImageSide: CGFloat = 2400

    nonisolated static let separator = "__"

    /// 予定の id ごとの添付（足した順）
    @Published private(set) var byItem: [String: [ScheduleAttachment]] = [:]

    private var observers: [NSObjectProtocol] = []

    private init() {
        byItem = Self.scan()
        // ほかの端末で足した添付（Pro）が届いたら、一覧を作り直す
        for name in [PhotoSyncService.photosMayHaveArrived, .coreDataDidUpdate] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
                Task { @MainActor in ScheduleAttachmentStore.shared.reload() }
            })
        }
    }

    func attachments(for itemId: String) -> [ScheduleAttachment] {
        byItem[itemId] ?? []
    }

    func reload() {
        let fresh = Self.scan()
        if fresh != byItem { byItem = fresh }
    }

    // MARK: - 足す

    enum AddError: LocalizedError {
        case tooMany
        case tooLarge
        case unreadable

        var errorDescription: String? {
            switch self {
            case .tooMany: return "1つの予定に添付できるのは\(ScheduleAttachmentStore.maxPerItem)個までです"
            case .tooLarge: return "20MB より大きいファイルは添付できません"
            case .unreadable: return "ファイルを読み込めませんでした"
            }
        }
    }

    /// 写真を添付する。長いほうの辺を `maxImageSide` までに縮めて JPEG で置く
    func addImage(_ data: Data, to itemId: String) throws {
        guard let image = UIImage(data: data) else { throw AddError.unreadable }
        let resized = Self.resized(image, maxSide: Self.maxImageSide)
        guard let jpeg = resized.jpegData(compressionQuality: 0.8) else { throw AddError.unreadable }
        try add(jpeg, name: "写真", fileExtension: "jpg", to: itemId)
    }

    /// ファイル（PDF・画像）を添付する。画像は写真と同じく縮める
    func addFile(at url: URL, to itemId: String) throws {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { throw AddError.unreadable }
        let ext = url.pathExtension.lowercased()
        let name = url.deletingPathExtension().lastPathComponent
        if ext == "pdf" {
            try add(data, name: name, fileExtension: "pdf", to: itemId)
        } else {
            guard let image = UIImage(data: data) else { throw AddError.unreadable }
            let resized = Self.resized(image, maxSide: Self.maxImageSide)
            guard let jpeg = resized.jpegData(compressionQuality: 0.8) else { throw AddError.unreadable }
            try add(jpeg, name: name, fileExtension: "jpg", to: itemId)
        }
    }

    private func add(_ data: Data, name: String, fileExtension: String, to itemId: String) throws {
        guard attachments(for: itemId).count < Self.maxPerItem else { throw AddError.tooMany }
        guard data.count <= Self.maxFileBytes else { throw AddError.tooLarge }
        let fileName = Self.fileName(itemId: itemId, name: name, fileExtension: fileExtension, date: Date())
        let url = PhotoFolder.scheduleAttachments.url().appendingPathComponent(fileName)
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw AddError.unreadable
        }
        PhotoSyncService.shared.store(data: data, fileName: fileName, folder: .scheduleAttachments)
        reload()
    }

    // MARK: - 消す

    func remove(_ attachment: ScheduleAttachment) {
        try? FileManager.default.removeItem(at: attachment.localURL)
        PhotoSyncService.shared.remove(fileName: attachment.fileName, folder: .scheduleAttachments)
        reload()
    }

    /// 予定を消したときに、その予定の添付もまとめて消す
    func removeAll(for itemIds: some Sequence<String>) {
        var changed = false
        for itemId in itemIds {
            for attachment in attachments(for: itemId) {
                try? FileManager.default.removeItem(at: attachment.localURL)
                PhotoSyncService.shared.remove(fileName: attachment.fileName, folder: .scheduleAttachments)
                changed = true
            }
        }
        if changed { reload() }
    }

    // MARK: - 開く

    /// 開くためのファイルの場所。端末に無ければ預けてあるものから取り戻す。取り戻せなければ nil
    func openableURL(for attachment: ScheduleAttachment) -> URL? {
        let url = attachment.localURL
        if FileManager.default.fileExists(atPath: url.path) { return url }
        return PhotoSyncService.shared.restoreIfMissing(fileName: attachment.fileName, folder: .scheduleAttachments)
            ? url : nil
    }

    // MARK: - Helpers

    /// 端末にあるファイルと、預けてある（ほかの端末で足した）ファイルの名前から一覧を作る
    private static func scan() -> [String: [ScheduleAttachment]] {
        let folder = PhotoFolder.scheduleAttachments
        let local = (try? FileManager.default.contentsOfDirectory(atPath: folder.url().path)) ?? []
        let names = Set(local).union(PhotoSyncService.shared.storedFileNames(in: folder))
        return group(fileNames: names)
    }

    /// ファイル名を予定の id ごとに分ける。足した順（名前の2つ目が時刻なので、名前の順）
    nonisolated static func group(fileNames: some Sequence<String>) -> [String: [ScheduleAttachment]] {
        var result: [String: [ScheduleAttachment]] = [:]
        for name in fileNames {
            guard let itemId = itemId(of: name),
                  PhotoFolder.scheduleAttachments.fileExtensions.contains((name as NSString).pathExtension.lowercased())
            else { continue }
            result[itemId, default: []].append(ScheduleAttachment(fileName: name))
        }
        return result.mapValues { $0.sorted { $0.fileName < $1.fileName } }
    }

    nonisolated static func itemId(of fileName: String) -> String? {
        let parts = fileName.components(separatedBy: separator)
        guard parts.count >= 3, !parts[0].isEmpty else { return nil }
        return parts[0]
    }

    /// `<予定の id>__<足した時刻（並び順）と乱数>__<名前>.<拡張子>`。
    /// 名前に使えない文字は除き、長すぎる名前は切る
    nonisolated static func fileName(itemId: String, name: String, fileExtension: String, date: Date) -> String {
        let stamp = String(format: "%013.0f", date.timeIntervalSince1970 * 1000)
        let random = UUID().uuidString.prefix(6)
        var cleaned = name
            .replacingOccurrences(of: separator, with: "_")
            .components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>\n\r\t")).joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.count > 60 { cleaned = String(cleaned.prefix(60)) }
        return "\(itemId)\(separator)\(stamp)\(random)\(separator)\(cleaned).\(fileExtension)"
    }

    private static func resized(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxSide else { return image }
        let scale = maxSide / longest
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
