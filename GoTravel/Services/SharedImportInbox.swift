import Foundation

/// 共有メニューから Travory に送られた、予約の確認メールや画像の受け取り箱。
///
/// 共有メニューの拡張（TravoryShare）は、ここに置くだけで予約は作らない。
/// どの旅行の予約なのかは拡張からは分からず、読み取った内容も保存前に
/// 確かめてもらいたいので、次にアプリを開いたときに続きをしてもらう。
///
/// **置き方の決まり（拡張の `ShareInboxWriter` と揃えること）**
/// - App Group の `SharedImportInbox/` フォルダに、1件1ファイルで置く
/// - 本文は `.txt`（UTF-8）、画像は `.jpg`
/// - ファイル名は `<送った時刻のミリ秒>-<UUID>.<拡張子>`。古い順に並べるのに使う
enum SharedImportInbox {

    static let folderName = "SharedImportInbox"

    /// 1週間たっても取り込まれなかったものは捨てる（送ったことを忘れた予約が、いつまでも出続けないように）
    static let expiry: TimeInterval = 7 * 24 * 60 * 60

    struct Item: Identifiable, Equatable {
        enum Content: Equatable {
            case text(String)
            case image(URL)
        }

        let url: URL
        let sentAt: Date
        let content: Content

        var id: URL { url }
    }

    static var folder: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: WidgetDataStore.appGroupId)?
            .appendingPathComponent(folderName, isDirectory: true)
    }

    /// まだ取り込んでいないもの（古い順）。期限の切れたものはここで捨てる
    static func pendingItems(now: Date = Date()) -> [Item] {
        guard let folder,
              let urls = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { return [] }

        var items: [Item] = []
        for url in urls {
            guard let sentAt = sentDate(of: url) else { continue }
            if now.timeIntervalSince(sentAt) > expiry {
                remove(url)
                continue
            }
            switch url.pathExtension.lowercased() {
            case "txt":
                guard let text = try? String(contentsOf: url, encoding: .utf8),
                      !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                items.append(Item(url: url, sentAt: sentAt, content: .text(text)))
            case "jpg", "jpeg", "png":
                items.append(Item(url: url, sentAt: sentAt, content: .image(url)))
            default:
                continue
            }
        }
        return items.sorted { $0.sentAt < $1.sentAt }
    }

    static func remove(_ item: Item) {
        remove(item.url)
    }

    private static func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    /// ファイル名の頭のミリ秒から、送った時刻を読む
    static func sentDate(of url: URL) -> Date? {
        let name = url.deletingPathExtension().lastPathComponent
        guard let millis = name.split(separator: "-").first.flatMap({ Double($0) }) else { return nil }
        return Date(timeIntervalSince1970: millis / 1000)
    }
}
