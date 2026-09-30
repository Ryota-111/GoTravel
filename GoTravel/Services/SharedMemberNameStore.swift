import Foundation

/// 共有メンバーの表示名の、端末の控え。
///
/// 名前は共有レコード（パブリックDBの `memberNamesJSON`）が正。取り込むたびにここへ写し、
/// 通信しなくても画面に名前を出せるようにする。Core Data には載せない
/// （載せると Core Data のスキーマ変更と Production への反映が要るため）
enum SharedMemberNameStore {

    private static func key(planId: String) -> String {
        "SharedMemberNames_\(planId)"
    }

    static func names(planId: String) -> [String: String] {
        UserDefaults.standard.dictionary(forKey: key(planId: planId)) as? [String: String] ?? [:]
    }

    static func save(_ names: [String: String], planId: String) {
        UserDefaults.standard.set(names, forKey: key(planId: planId))
    }

    /// プロフィールの名前。旅行で呼び方を決めていなければ、これを使う。
    /// `AuthViewModel` が同じ鍵で保存している
    static func profileName(userId: String) -> String? {
        let name = UserDefaults.standard.string(forKey: "appleSignInUserFullName_\(userId)")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (name?.isEmpty ?? true) ? nil : name
    }
}
