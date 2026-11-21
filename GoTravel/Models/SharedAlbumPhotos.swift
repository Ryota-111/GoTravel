import Foundation

/// 共有した旅行のアルバムの写真を、同行者と見せ合う（3.8・無料。ご要望から）。
///
/// 写真は端末の中にしか無く、同じ旅行に参加していても、ほかの人のアルバムは見られなかった。
/// パブリックDBに1枚ずつ `SharedTripPhoto` として載せ、旅行の id で引いて取り込む。
/// 詳しいルールは `docs/設計_アルバムの共有.md`。
///
/// ## ルール
/// 1. 自分の写真を載せるのは、アルバムで「同行者と共有する」をオンにした人だけ。
///    これまでに入れていた写真を、勝手に載せない
/// 2. ほかの人が載せた写真は、オンにしていなくても自分のアルバムに入る
/// 3. 自分が載せた写真を消すと、みんなのアルバムからも消える。
///    ほかの人の写真を消すと、自分のアルバムからだけ消える（もう入ってこない）
/// 4. 共有をオフにすると、自分が載せた写真をみんなのアルバムから消す（自分の手元には残る）
///
/// 写真は「キー」で見分ける。アルバムのファイル名は `<アルバムの id>_<UUID>.jpg` で、
/// アルバムの id は人によって違うので、`_` の後ろの UUID をキーにする。
/// 取り込んだ写真も、自分のアルバムの id と同じキーで保存する
enum SharedAlbumPhotos {

    static let recordType = "SharedTripPhoto"
    /// 載せる写真の長辺。アルバムで見るのに足りる大きさに縮める（1枚 300〜600KB）
    static let uploadMaxPixel: CGFloat = 2048
    /// 1つの旅行に載せられる写真の数。パブリックDBの容量を使い切らないように
    static let maxPhotosPerTrip = 500

    static func recordName(key: String) -> String { "tripphoto_\(key)" }

    /// ファイル名からキー。`_` が無い古い名前はファイル名（拡張子なし）をそのまま使う
    static func key(fileName: String) -> String {
        let stem = (fileName as NSString).deletingPathExtension
        guard let index = stem.lastIndex(of: "_") else { return stem }
        return String(stem[stem.index(after: index)...])
    }

    /// 取り込んだ写真を、自分のアルバムに置くときのファイル名
    static func fileName(key: String, albumId: String) -> String { "\(albumId)_\(key).jpg" }

    /// 載っている写真1枚（中身の写真は除いた情報）
    struct RemotePhoto: Equatable {
        var key: String
        /// 載せた人（userId）
        var addedBy: String
        var createdAt: Date?
    }

    /// 突き合わせた結果
    struct Plan: Equatable {
        /// 取り込む（自分のアルバムに無い・消していない）。載った順
        var download: [String] = []
        /// 載せる（共有をオンにしていて、まだ載っていない自分の写真）
        var upload: [String] = []
        /// 自分のアルバムから外す（載せた人が共有から消した、ほかの人の写真）
        var removeLocal: [String] = []
        /// ファイルが無いので取り直す（別の端末で入れた写真など。アルバムには並んでいる）
        var refetch: [String] = []
    }

    /// 自分のアルバムと、載っている写真を突き合わせる
    /// - Parameters:
    ///   - localKeys: 自分のアルバムに並んでいる写真のキー（並び順）
    ///   - missingFileKeys: そのうち、この端末にファイルが無いもの
    ///   - remote: いま載っている写真
    ///   - known: 前回の突き合わせで載っていた写真（キー → 載せた人）
    ///   - dismissed: 自分のアルバムから消した、ほかの人の写真
    ///   - uploadsEnabled: 自分の写真を載せる（共有をオンにしている）
    ///   - userId: 自分
    static func plan(localKeys: [String], missingFileKeys: Set<String> = [],
                     remote: [RemotePhoto], known: [String: String], dismissed: Set<String>,
                     uploadsEnabled: Bool, userId: String) -> Plan {
        var result = Plan()
        let local = Set(localKeys)
        let remoteByKey = Dictionary(remote.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })

        let ordered = remote.sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
        result.download = ordered.map(\.key).filter { !local.contains($0) && !dismissed.contains($0) }

        for key in localKeys {
            if remoteByKey[key] != nil {
                if missingFileKeys.contains(key) { result.refetch.append(key) }
            } else if let addedBy = known[key] {
                // 前は載っていたのに、もう無い。ほかの人の写真なら、その人が共有から消した。
                // 自分の写真は、別の端末で共有をオフにしただけかもしれないので手元に残す
                if addedBy != userId { result.removeLocal.append(key) }
            } else if uploadsEnabled && !missingFileKeys.contains(key) {
                result.upload.append(key)
            }
        }

        // 上限を超える分は載せない
        let room = max(maxPhotosPerTrip - remote.count, 0)
        if result.upload.count > room { result.upload = Array(result.upload.prefix(room)) }
        return result
    }

    /// 自分のアルバムから写真を消したときに、共有から消すもの（自分が載せた写真）と、
    /// もう取り込まないもの（ほかの人の写真）に分ける
    static func removal(keys: [String], known: [String: String], userId: String)
        -> (deleteRemote: [String], dismiss: [String]) {
        var deleteRemote: [String] = [], dismiss: [String] = []
        for key in keys {
            if let addedBy = known[key], addedBy != userId {
                dismiss.append(key)
            } else {
                // 自分の写真。まだ載せていなければ消すものは無いが、消しに行っても困らない
                deleteRemote.append(key)
            }
        }
        return (deleteRemote, dismiss)
    }
}
