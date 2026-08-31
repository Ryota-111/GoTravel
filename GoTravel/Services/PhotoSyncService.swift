import Foundation
import Combine
import CoreData
import UIKit

/// 写真を iCloud に預けて、別の端末でも見られるようにする。
///
/// これまで写真の実体は端末の Documents にしか無く、**機種変更で消えていた。**
/// 旅行計画も予定も場所も CloudKit で同期されるのに、写真だけが端末に残る。
/// 買い替えたときに「記録は残っているのに写真が全部無い」という壊れ方をしていた。
///
/// ## 仕組み
///
/// 実体を `PhotoAssetEntity` に入れて、他のデータと同じ Core Data + CloudKit の
/// 自動同期に相乗りさせる。CKAsset を自前で読み書きはしない。
///
/// **表示は今までどおりローカルのファイルを見る。** 一覧のスクロールで毎回
/// Core Data を触ると重いので、ファイルが無いときだけ書き戻す。
/// つまり同期は「保存したら預ける」「読めなかったら取り戻す」の2つだけで動く。
///
/// ## 有効になる条件
///
/// 追加テーマの買い切り（Pro）を持っているときだけ動く。`ProStore` が
/// 所有状態を確かめたあとに `setEnabled(_:)` で伝えてくる。
/// 無効のあいだは何もしないので、呼び出し側に分岐は要らない。
final class PhotoSyncService: ObservableObject {

    static let shared = PhotoSyncService()

    private init() {}


    // MARK: - 有効・無効

    /// Pro を持っているか。`ProStore` から伝えられる
    private(set) var isEnabled = false

    /// 預けられる状態か。
    /// 空データモードでは実データに触らないので、ここも止めておく
    private var isActive: Bool {
        isEnabled && !CoreDataManager.isEmptyDataMode && userId != nil
    }

    /// `ProStore` から所有状態を受け取る。
    /// 買った直後は、それまでに撮りためた写真がまだ預けられていないので追いつかせる
    func setEnabled(_ enabled: Bool) {
        guard isEnabled != enabled else { return }
        isEnabled = enabled
        log(enabled ? "有効になりました" : "無効になりました")
        if enabled { backfill() }
    }

    /// なぜ預けられないのかを一言で返す。動かないときの切り分け用
    private var inactiveReason: String? {
        if CoreDataManager.isEmptyDataMode { return "空データモードのため止めています" }
        if !isEnabled { return "Pro を購入していないため止めています" }
        if userId == nil { return "サインインしていないため止めています" }
        return nil
    }

    /// 開発中に動きを追うためのログ。リリースビルドには残らない
    private func log(_ message: String) {
        #if DEBUG
        print("[PhotoSync] \(message)")
        #endif
    }

    /// 写真を持ち主に紐づけるためのユーザーID。
    /// `AuthViewModel` が復元に使っているものと同じ保存先を見る
    private var userId: String? {
        UserDefaults.standard.string(forKey: "appleSignInUserId")
    }

    /// 一度取り戻せなかったファイル名。
    /// 消えた写真を一覧に出すたびに Core Data を引き直さないための覚え書き
    private var knownMissing = Set<String>()
    private let lock = NSLock()

    // MARK: - 預ける

    /// 保存した写真を預ける。ローカルへの書き込みが済んだあとに呼ぶ。
    ///
    /// 失敗しても画面には出さない。ローカルには保存できているので写真は見えるし、
    /// 預け直す機会は `backfill()` で次の起動にもある
    func store(data: Data, fileName: String, folder: PhotoFolder) {
        if let inactiveReason {
            log("\(fileName) を預けませんでした（\(inactiveReason)）")
            return
        }
        guard let userId else { return }

        CoreDataManager.shared.performBackgroundTask { [weak self] context in
            do {
                let existing = try PhotoAssetEntity.fetch(
                    fileName: fileName, folder: folder, userId: userId, context: context
                )
                let asset = existing ?? PhotoAssetEntity(context: context)

                if existing == nil {
                    asset.id = UUID().uuidString
                    asset.fileName = fileName
                    asset.folder = folder.rawValue
                    asset.userId = userId
                    asset.createdAt = Date()
                }
                asset.imageData = data

                try context.save()
                self?.log("\(fileName) を預けました（\(data.count / 1024)KB）")
            } catch {
                // 預けられなくてもローカルの写真は無事なので、画面には出さない。
                // ただし黙って消えると原因が追えないので、開発中は必ず残す
                self?.log("\(fileName) を預けられませんでした: \(error)")
            }
        }

        lock.lock()
        knownMissing.remove(Self.key(fileName, folder))
        lock.unlock()
    }

    /// 消した写真を預け先からも消す。
    /// 残したままだと、消したはずの写真が別の端末で復活する
    func remove(fileName: String, folder: PhotoFolder) {
        guard !CoreDataManager.isEmptyDataMode, let userId else { return }

        CoreDataManager.shared.performBackgroundTask { context in
            do {
                if let asset = try PhotoAssetEntity.fetch(
                    fileName: fileName, folder: folder, userId: userId, context: context
                ) {
                    context.delete(asset)
                    try context.save()
                }
            } catch {
                // 消し損ねても実害は小さい（別端末で復活するだけ）ので、握りつぶす
            }
        }
    }

    // MARK: - 取り戻す

    /// ローカルにファイルが無ければ、預けてあるものから書き戻す。
    ///
    /// 戻り値は「呼んだあとにローカルのファイルが在るか」。
    /// 機種変更の直後にしか通らない道なので、同期的に書いてよい。
    /// 一度失敗したファイルは覚えておき、次からは即座に false を返す
    @discardableResult
    func restoreIfMissing(fileName: String, folder: PhotoFolder) -> Bool {
        let url = folder.url().appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: url.path) { return true }

        guard isActive, let userId else { return false }

        let key = Self.key(fileName, folder)
        lock.lock()
        let alreadyGaveUp = knownMissing.contains(key)
        lock.unlock()
        if alreadyGaveUp { return false }

        let context = CoreDataManager.shared.viewContext
        var restored = false

        context.performAndWait {
            guard
                let asset = try? PhotoAssetEntity.fetch(
                    fileName: fileName, folder: folder, userId: userId, context: context
                ),
                let data = asset.imageData
            else { return }

            restored = (try? data.write(to: url, options: .atomic)) != nil
        }

        if !restored {
            lock.lock()
            knownMissing.insert(key)
            lock.unlock()
        }
        return restored
    }

    // MARK: - 追いつかせる

    /// まだ預けていない写真を順に預ける。
    ///
    /// 買った直後と、起動のたびに1回だけ走らせる。すでに預けてあるものは
    /// ファイル名の一覧を1回引いて弾くので、2回目以降はほとんど何もしない
    func backfill() {
        if let inactiveReason {
            log("追いつかせませんでした（\(inactiveReason)）")
            return
        }
        guard let userId else { return }

        CoreDataManager.shared.performBackgroundTask { [weak self] context in
            var added = 0

            for folder in [PhotoFolder.documents, .albums, .japanPhotos] {
                guard
                    let stored = try? PhotoAssetEntity.fetchStoredFileNames(
                        folder: folder, userId: userId, context: context
                    )
                else { continue }

                for fileName in Self.localFileNames(in: folder) where !stored.contains(fileName) {
                    let url = folder.url().appendingPathComponent(fileName)
                    guard let data = try? Data(contentsOf: url) else { continue }

                    let asset = PhotoAssetEntity(context: context)
                    asset.id = UUID().uuidString
                    asset.fileName = fileName
                    asset.folder = folder.rawValue
                    asset.userId = userId
                    asset.createdAt = Date()
                    asset.imageData = data
                    added += 1
                }

                // フォルダごとに保存する。まとめて保存すると、途中で落ちたときに
                // 何も預けられていない状態に戻ってしまう
                if context.hasChanges {
                    do {
                        try context.save()
                    } catch {
                        self?.log("\(folder.rawValue) の追いつかせに失敗: \(error)")
                    }
                }
            }

            self?.log(added > 0 ? "\(added)枚を新たに預けました" : "預けていない写真はありませんでした")
        }
    }

    // MARK: - Helpers

    private static func key(_ fileName: String, _ folder: PhotoFolder) -> String {
        "\(folder.rawValue)/\(fileName)"
    }

    /// フォルダ直下の画像ファイル名。サブフォルダは見ない
    private static func localFileNames(in folder: PhotoFolder) -> [String] {
        let contents = try? FileManager.default.contentsOfDirectory(
            at: folder.url(),
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        )

        return (contents ?? [])
            .filter { ["jpg", "jpeg", "png", "heic"].contains($0.pathExtension.lowercased()) }
            .map { $0.lastPathComponent }
    }
}

// MARK: - 保存先

extension PhotoFolder {
    func url() -> URL {
        let documents = FileManager.documentsDirectory()
        switch self {
        case .documents:
            return documents
        case .albums:
            return subdirectory(of: documents, named: "Albums")
        case .japanPhotos:
            return subdirectory(of: documents, named: "JapanPhotos")
        }
    }

    private func subdirectory(of parent: URL, named name: String) -> URL {
        let url = parent.appendingPathComponent(name)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }
}
