import Foundation
import UIKit
import Combine
import os

/// 共有した旅行のアルバムの写真を、同行者と見せ合う（3.8・無料）。ルールは `SharedAlbumPhotos`。
///
/// 思い出タブを開いたとき・アルバムを開いたとき・写真を足したときに、旅行ごとに突き合わせる。
/// 端末に覚えておくもの（UserDefaults。旅行ごと）
/// - `SharedAlbumUpload_<planId>`：自分の写真を載せる（共有をオンにした）
/// - `SharedAlbumKnown_<planId>`：前回載っていた写真（キー → 載せた人）
/// - `SharedAlbumDismissed_<planId>`：自分のアルバムから消した、ほかの人の写真
/// - `SharedAlbumNoAutoCreate_<planId>`：アルバムごと消したので、もう作り直さない
@MainActor
final class SharedAlbumSync: ObservableObject {
    static let shared = SharedAlbumSync()

    /// いま突き合わせている旅行
    @Published private(set) var syncingPlanIds: Set<String> = []
    /// 通信できなかった旅行（画面に「もう一度」を出す）
    @Published private(set) var failedPlanIds: Set<String> = []
    /// 共有のオン・オフが変わったことを画面に知らせる
    @Published private(set) var settingsVersion = 0

    private var userId: String?
    private let defaults = UserDefaults.standard
    private let logger = Logger(subsystem: "com.gmail.taismryotasis.Travory", category: "sharing")
    private var albums: AlbumManager { AlbumManager.shared }
    private var cloud: CloudKitService { CloudKitService.shared }

    private init() {}

    // MARK: - 設定

    func isUploading(planId: String) -> Bool {
        defaults.bool(forKey: "SharedAlbumUpload_\(planId)")
    }

    /// 「同行者と写真を見せ合えます」の帯を閉じたか（共有するか、× を押した）
    func isBannerDismissed(planId: String) -> Bool {
        _ = settingsVersion
        return defaults.bool(forKey: "SharedAlbumBannerDismissed_\(planId)") || isUploading(planId: planId)
    }

    func dismissBanner(planId: String) {
        defaults.set(true, forKey: "SharedAlbumBannerDismissed_\(planId)")
        settingsVersion += 1
    }

    /// 自分の写真を載せるかを切り替える。オフにしたら、自分が載せた写真をみんなのアルバムから消す
    func setUploading(_ enabled: Bool, plan: TravelPlan, userId: String) async {
        guard let planId = plan.id else { return }
        defaults.set(enabled, forKey: "SharedAlbumUpload_\(planId)")
        defaults.set(true, forKey: "SharedAlbumBannerDismissed_\(planId)")
        settingsVersion += 1
        if !enabled {
            let mine = known(planId).filter { $0.value == userId }.map(\.key)
            do {
                try await cloud.deleteSharedAlbumPhotos(keys: mine)
                var updated = known(planId)
                for key in mine { updated[key] = nil }
                setKnown(updated, planId: planId)
            } catch {
                logger.error("アルバムの共有をやめるときに写真を消せなかった error=\(String(describing: error), privacy: .public)")
                failedPlanIds.insert(planId)
                return
            }
        }
        await sync(plan: plan, userId: userId)
    }

    // MARK: - 突き合わせ

    /// 共有している旅行をすべて突き合わせる（思い出タブを開いたとき）
    func syncAll(plans: [TravelPlan], userId: String) async {
        for plan in plans where plan.isShared {
            await sync(plan: plan, userId: userId)
        }
    }

    /// 1つの旅行を突き合わせる。アルバムが無ければ、同行者の写真が載っているときだけ作る
    func sync(plan: TravelPlan, userId: String) async {
        self.userId = userId
        guard plan.isShared, let planId = plan.id, !syncingPlanIds.contains(planId) else { return }
        syncingPlanIds.insert(planId)
        defer { syncingPlanIds.remove(planId) }

        do {
            let remote = try await cloud.fetchSharedAlbumPhotos(planId: planId)
            let dismissed = Set(defaults.stringArray(forKey: "SharedAlbumDismissed_\(planId)") ?? [])

            var album = albums.albums.first { $0.travelPlanId == planId && !$0.isJapanPhotoMap }
            if album == nil {
                let hasOthers = remote.contains { $0.addedBy != userId && !dismissed.contains($0.key) }
                guard hasOthers, !defaults.bool(forKey: "SharedAlbumNoAutoCreate_\(planId)"),
                      let albumId = albums.createTravelPlanAlbum(from: plan) else {
                    setKnown(Dictionary(remote.map { ($0.key, $0.addedBy) }, uniquingKeysWith: { a, _ in a }), planId: planId)
                    failedPlanIds.remove(planId)
                    return
                }
                album = albums.albums.first { $0.id == albumId }
                    ?? Album(id: albumId, title: plan.title, travelPlanId: planId, type: .travel, userId: userId)
            }
            guard let album else { return }

            var fileNameByKey: [String: String] = [:]
            for name in album.photoFileNames { fileNameByKey[SharedAlbumPhotos.key(fileName: name)] = name }
            let localKeys = album.photoFileNames.map(SharedAlbumPhotos.key(fileName:))
            let missing = Set(localKeys.filter { key in
                fileNameByKey[key].map { !albums.hasPhotoFile(fileName: $0) } ?? false
            })

            let decision = SharedAlbumPhotos.plan(localKeys: localKeys, missingFileKeys: missing,
                                                  remote: remote, known: known(planId), dismissed: dismissed,
                                                  uploadsEnabled: isUploading(planId: planId), userId: userId)

            // 載せた人が共有から消した写真を、手元から外す
            let removals = decision.removeLocal.compactMap { fileNameByKey[$0] }
            if !removals.isEmpty {
                albums.removePhotos(fileNames: removals, from: album.id, propagatesToSharing: false)
            }

            // 同行者の写真を取り込む・無いファイルを取り直す
            let images = try await cloud.fetchSharedAlbumImages(keys: decision.download + decision.refetch)
            albums.addReceivedPhotos(decision.download.compactMap { key in
                images[key].map { (SharedAlbumPhotos.fileName(key: key, albumId: album.id), $0) }
            }, to: album.id)
            for key in decision.refetch {
                if let data = images[key], let name = fileNameByKey[key] {
                    albums.writeReceivedPhoto(data, fileName: name)
                }
            }

            // 自分の写真を載せる
            var uploaded: [String] = []
            if !decision.upload.isEmpty {
                let files = decision.upload.compactMap { key -> (key: String, file: URL)? in
                    guard let name = fileNameByKey[key], let file = Self.uploadFile(fileName: name) else { return nil }
                    return (key, file)
                }
                defer { files.forEach { try? FileManager.default.removeItem(at: $0.file) } }
                uploaded = try await cloud.uploadSharedAlbumPhotos(files, planId: planId, userId: userId)
            }

            var newKnown = Dictionary(remote.map { ($0.key, $0.addedBy) }, uniquingKeysWith: { a, _ in a })
            for key in uploaded { newKnown[key] = userId }
            setKnown(newKnown, planId: planId)
            failedPlanIds.remove(planId)
        } catch {
            logger.error("アルバムの突き合わせに失敗 planId=\(planId, privacy: .public) error=\(String(describing: error), privacy: .public)")
            failedPlanIds.insert(planId)
        }
    }

    // MARK: - 手元で消したとき

    /// アルバムから写真を消した。自分が載せた写真は共有からも消し、ほかの人の写真はもう取り込まない
    func didRemovePhotos(fileNames: [String], planId: String) {
        guard let userId else { return }
        let keys = fileNames.map(SharedAlbumPhotos.key(fileName:))
        let current = known(planId)
        // 一度も突き合わせていない旅行（共有していない旅行など）は何もしない
        guard !current.isEmpty || isUploading(planId: planId) else { return }
        let removal = SharedAlbumPhotos.removal(keys: keys, known: current, userId: userId)

        var dismissed = defaults.stringArray(forKey: "SharedAlbumDismissed_\(planId)") ?? []
        dismissed.append(contentsOf: removal.dismiss.filter { !dismissed.contains($0) })
        defaults.set(dismissed, forKey: "SharedAlbumDismissed_\(planId)")

        var updated = current
        for key in keys { updated[key] = nil }
        setKnown(updated, planId: planId)

        let mine = removal.deleteRemote.filter { current[$0] != nil }
        guard !mine.isEmpty else { return }
        Task {
            do {
                try await cloud.deleteSharedAlbumPhotos(keys: mine)
            } catch {
                logger.error("消した写真を共有から消せなかった error=\(String(describing: error), privacy: .public)")
            }
        }
    }

    /// 旅行のアルバムごと消した。自分の写真を共有から消し、もうアルバムを作り直さない
    func didDeleteAlbum(planId: String) {
        defaults.set(true, forKey: "SharedAlbumNoAutoCreate_\(planId)")
        defaults.set(false, forKey: "SharedAlbumUpload_\(planId)")
        guard let userId else { return }
        let mine = known(planId).filter { $0.value == userId }.map(\.key)
        setKnown([:], planId: planId)
        guard !mine.isEmpty else { return }
        Task { try? await cloud.deleteSharedAlbumPhotos(keys: mine) }
    }

    /// 持ち主が共有をやめた・旅行を消した。載っている写真をすべて消し、端末の覚えも捨てる
    func didStopSharing(planId: String) {
        forget(planId: planId)
        Task { try? await cloud.deleteAllSharedAlbumPhotos(planId: planId) }
    }

    /// 旅行から抜けた。自分の写真だけ共有から消す（ほかの人の写真は手元に残る）
    func didLeave(planId: String, userId: String) {
        let mine = known(planId).filter { $0.value == userId }.map(\.key)
        forget(planId: planId)
        guard !mine.isEmpty else { return }
        Task { try? await cloud.deleteSharedAlbumPhotos(keys: mine) }
    }

    private func forget(planId: String) {
        for prefix in ["SharedAlbumUpload_", "SharedAlbumKnown_", "SharedAlbumDismissed_", "SharedAlbumNoAutoCreate_",
                       "SharedAlbumBannerDismissed_"] {
            defaults.removeObject(forKey: prefix + planId)
        }
        settingsVersion += 1
    }

    // MARK: - 覚え

    private func known(_ planId: String) -> [String: String] {
        defaults.dictionary(forKey: "SharedAlbumKnown_\(planId)") as? [String: String] ?? [:]
    }

    private func setKnown(_ value: [String: String], planId: String) {
        defaults.set(value, forKey: "SharedAlbumKnown_\(planId)")
    }

    /// 載せる写真を縮めて一時ファイルに書く。CKAsset はファイルの場所で渡すため
    private static func uploadFile(fileName: String) -> URL? {
        guard let image = AlbumManager.shared.loadPhoto(fileName: fileName),
              let data = image.downscaled(maxPixel: SharedAlbumPhotos.uploadMaxPixel)
                .jpegData(compressionQuality: 0.8) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("tripphoto_\(UUID().uuidString).jpg")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
