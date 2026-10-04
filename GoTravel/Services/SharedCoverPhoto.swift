import UIKit

/// 共有した旅行のヘッダー写真（無料）。
///
/// 写真は端末の中にしか無く、共有コードで参加した人には出なかった（ご要望から）。
/// 共有レコード（パブリックDB）に縮めた写真と「版」を載せ、全員で同じ写真を見る。
///
/// **ルール**（`docs/設計_ヘッダー写真の共有.md`）
/// 1. 1つの旅行に写真は1枚。2.9 以降に誰かが写真を変えたら、全員その写真になる（`set-` の版）
/// 2. 2.9 に上げた直後は、自分で入れていた写真を勝手に置き換えない。
///    まだ誰の写真も載っていない旅行では、最初に同期した人の写真を載せる（`init-` の版）。
///    `init-` の写真は、写真を入れていない人にだけ出す
enum SharedCoverPhoto {

    /// 共有レコードの項目
    static let imageKey = "coverImage"
    static let versionKey = "coverImageVersion"

    /// 載せる写真の長辺。ヘッダーに足りる大きさに縮め、取り込むたびの通信を軽くする
    static let uploadMaxPixel: CGFloat = 1000

    // MARK: - 版

    static func newVersion(explicit: Bool) -> String {
        (explicit ? "set-" : "init-") + UUID().uuidString
    }

    /// 誰かが写真を変えて載せた版か（最初の1枚を載せただけの版ではないか）
    static func isExplicit(_ version: String) -> Bool {
        version.hasPrefix("set-")
    }

    // MARK: - 判断（純粋関数。テストで確かめる）

    /// 送るときに写真を載せるか。載せるなら新しい版を返す
    /// - Parameters:
    ///   - changedLocally: この端末で写真を変えて、まだ載せていない
    ///   - remoteVersion: 共有レコードにいま載っている版
    ///   - hasLocalPhoto: この端末に写真がある
    static func uploadVersion(changedLocally: Bool, remoteVersion: String?, hasLocalPhoto: Bool) -> String? {
        guard hasLocalPhoto else { return nil }
        if changedLocally { return newVersion(explicit: true) }
        // まだ誰の写真も載っていなければ、最初の1枚として載せる
        if remoteVersion == nil { return newVersion(explicit: false) }
        return nil
    }

    enum Adoption: Equatable {
        /// 載っている写真をこの端末の写真にする
        case adopt
        /// 自分の写真のままにする（この版は見たことにする）
        case keepOwn
        /// 何もしない
        case none
    }

    /// 取り込むときに、載っている写真をこの端末の写真にするか
    /// - Parameter changedLocally: この端末で写真を変えて、まだ送れていない。
    ///   そのときは自分の写真のほうが新しいので取り込まない（次に送ったときに全員がこの写真になる）
    static func adoption(remoteVersion: String?, adoptedVersion: String?,
                         hasLocalPhoto: Bool, changedLocally: Bool = false) -> Adoption {
        guard let remoteVersion, remoteVersion != adoptedVersion, !changedLocally else { return .none }
        if isExplicit(remoteVersion) || !hasLocalPhoto { return .adopt }
        return .keepOwn
    }

    // MARK: - この端末の覚え書き

    private static let defaults = UserDefaults.standard

    /// この端末が使っている（または見た）版
    static func adoptedVersion(planId: String) -> String? {
        defaults.string(forKey: "SharedCoverVersion_\(planId)")
    }

    static func setAdopted(_ version: String, planId: String) {
        defaults.set(version, forKey: "SharedCoverVersion_\(planId)")
    }

    /// この端末で写真を変えた（次に送るときに載せる）
    static func markChanged(planId: String) {
        defaults.set(true, forKey: "SharedCoverPending_\(planId)")
    }

    static func isChanged(planId: String) -> Bool {
        defaults.bool(forKey: "SharedCoverPending_\(planId)")
    }

    static func clearChanged(planId: String) {
        defaults.removeObject(forKey: "SharedCoverPending_\(planId)")
    }

    // MARK: - 写真

    /// この端末の写真があるか
    static func hasLocalPhoto(_ plan: TravelPlan) -> Bool {
        guard let name = plan.localImageFileName else { return false }
        return FileManager.default.fileExists(
            atPath: FileManager.documentsDirectory().appendingPathComponent(name).path)
    }

    /// 載せる写真を、縮めて一時ファイルに書く。CKAsset はファイルの場所で渡すため
    static func uploadFile(for plan: TravelPlan) -> URL? {
        guard let name = plan.localImageFileName,
              let image = FileManager.documentsImage(named: name),
              let data = image.downscaled(maxPixel: uploadMaxPixel).jpegData(compressionQuality: 0.75) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("cover_\(UUID().uuidString).jpg")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
