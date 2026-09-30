import Foundation

/// 日本全国フォトマップの写真の並び（アルバムの `photoFileNames`）の読み書き。
///
/// フォトマップはアルバムの入れ物をそのまま使い、写真のファイル名に県を含めて
/// どの県の写真かを表す（`docs/設計_フォトマップ.md`）。
/// **県ごとの並びの先頭が代表写真**で、地図の県の形に切り抜いて出すのはこれ。
///
/// 画面にも Core Data にも触らない。並びを受け取って、新しい並びを返すだけ
enum PhotoMapFiles {

    /// 1つの県に置ける枚数。端末の容量と同期の量を抑えるため
    static let maxPhotosPerPrefecture = 30

    /// 新しく足す写真のファイル名（`tokyo__<UUID>.jpg`）
    static func newFileName(for prefecture: Prefecture) -> String {
        "\(prefecture.rawValue)__\(UUID().uuidString).jpg"
    }

    /// ファイル名から県を読む。2.7 までの `tokyo.jpg` もそのまま読める
    static func prefecture(of fileName: String) -> Prefecture? {
        let base = fileName.hasSuffix(".jpg") ? String(fileName.dropLast(4)) : fileName
        let key = base.components(separatedBy: "__").first ?? base
        return Prefecture(rawValue: key)
    }

    /// 県ごとに、並びの順のまま分ける
    static func grouped(_ fileNames: [String]) -> [Prefecture: [String]] {
        var result: [Prefecture: [String]] = [:]
        for fileName in fileNames {
            guard let prefecture = prefecture(of: fileName) else { continue }
            result[prefecture, default: []].append(fileName)
        }
        return result
    }

    /// その県の写真（先頭が代表）
    static func photos(of prefecture: Prefecture, in fileNames: [String]) -> [String] {
        fileNames.filter { self.prefecture(of: $0) == prefecture }
    }

    /// その県の代表写真
    static func cover(of prefecture: Prefecture, in fileNames: [String]) -> String? {
        fileNames.first { self.prefecture(of: $0) == prefecture }
    }

    /// 写真のある県の数
    static func prefectureCount(in fileNames: [String]) -> Int {
        Set(fileNames.compactMap { prefecture(of: $0) }).count
    }

    /// その県にあと何枚足せるか
    static func remainingSlots(for prefecture: Prefecture, in fileNames: [String]) -> Int {
        max(0, maxPhotosPerPrefecture - photos(of: prefecture, in: fileNames).count)
    }

    /// 代表にする。同じ県の写真の中で先頭へ動かす（他の県の並びは変えない）
    static func makingCover(_ fileName: String, in fileNames: [String]) -> [String] {
        guard let prefecture = prefecture(of: fileName),
              let firstIndex = fileNames.firstIndex(where: { self.prefecture(of: $0) == prefecture }),
              fileNames.contains(fileName) else { return fileNames }

        var result = fileNames
        result.removeAll { $0 == fileName }
        result.insert(fileName, at: min(firstIndex, result.count))
        return result
    }

    /// 2.7 までの `UserDefaults` の県の一覧を、既存の並びに足し合わせる。
    ///
    /// 片方で上書きしない。別の端末で移し替え済みの並びが同期されてきていると、
    /// 上書きした側の端末にしか無い写真が消えるため。重複は除く
    static func mergingLegacy(prefectures legacy: [String], into fileNames: [String]) -> [String] {
        var result = fileNames
        for key in legacy {
            let fileName = "\(key).jpg"
            guard Prefecture(rawValue: key) != nil, !result.contains(fileName) else { continue }
            result.append(fileName)
        }
        return result
    }
}
