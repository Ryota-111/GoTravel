import Foundation
import CoreData

/// 端末の中のデータ（Core Data）を開けなかったこと（3.8）。
///
/// 3.6 までは開けないと `fatalError` で落としていて、起動した瞬間に落ちる報告が続いていた
/// （3.5・3.6 で同じ場所、同じ端末から何度も）。落とさずに「開けませんでした」の画面を出し、
/// 開けなかった理由（エラーの番号）を開発者に送る。
///
/// **個人の情報は送らない。** 送るのはエラーの種類と番号、空き容量の目安だけ。
/// エラーの説明文にはファイルの場所などが入るので送らない
struct StoreLoadFailure: Equatable {
    var domain: String
    var code: Int
    /// 元になったエラー（SQLite の番号など）。「種類 番号」の形で、外側から順に
    var underlying: [String]
    /// 空き容量（バイト）。分からなければ nil
    var availableCapacity: Int64?

    init(domain: String, code: Int, underlying: [String] = [], availableCapacity: Int64? = nil) {
        self.domain = domain
        self.code = code
        self.underlying = underlying
        self.availableCapacity = availableCapacity
    }

    init(_ error: NSError, availableCapacity: Int64?) {
        var chain: [String] = []
        var next = error.userInfo[NSUnderlyingErrorKey] as? NSError
        while let current = next, chain.count < 4 {
            chain.append("\(current.domain) \(current.code)")
            next = current.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        // SQLite の番号は、元のエラーではなく userInfo に入ってくることがある
        if let sqlite = error.userInfo[NSSQLiteErrorDomain] as? NSNumber {
            chain.append("\(NSSQLiteErrorDomain) \(sqlite.intValue)")
        }
        self.init(domain: error.domain, code: error.code, underlying: chain, availableCapacity: availableCapacity)
    }

    /// 空き容量が少なくて開けなかったと思われるか（SQLite の「いっぱい」、または 200MB を切っている）
    var looksLikeLowStorage: Bool {
        if underlying.contains("\(NSSQLiteErrorDomain) 13") { return true }
        guard let availableCapacity else { return false }
        return availableCapacity < 200 * 1_000_000
    }

    /// 端末のロックで読めなかったか（SQLite の 23）。
    ///
    /// 再起動したあと一度もロックを解いていないうちに、アプリが裏で起こされたとき（iCloud の知らせなど）に起きる。
    /// データの入れ物はロックを解くまで読めない決まりなので、壊れたわけではない。ロックが解けたら開き直せる。
    /// 3.7 で届いた「データを開けなかった」の報告はほとんどこれだった（3.8）
    var isDeviceLocked: Bool {
        underlying.contains("\(NSSQLiteErrorDomain) 23")
    }

    /// 画面に出す短い番号（問い合わせのときに伝えてもらう）
    var shortCode: String {
        ([ "\(domain) \(code)" ] + underlying).joined(separator: " / ")
    }

    /// 開発者に送る文。版・OS・機種はご意見の記録の側に入るので、ここには入れない
    var diagnosticText: String {
        var lines = ["■ データを開けなかった（落とさずに知らせる画面を出した）",
                     "エラー: \(domain) \(code)"]
        lines += underlying.map { "元のエラー: \($0)" }
        if let availableCapacity {
            lines.append("空き容量: \(Self.capacityLabel(availableCapacity))")
        }
        return lines.joined(separator: "\n")
    }

    /// 空き容量の目安。細かい数字は要らないので、だいたいの大きさにする
    static func capacityLabel(_ bytes: Int64) -> String {
        let megabytes = Double(bytes) / 1_000_000
        if megabytes < 100 { return "100MB 未満" }
        if megabytes < 1_000 { return "約 \(Int(megabytes / 100) * 100)MB" }
        return String(format: "約 %.1fGB", megabytes / 1_000)
    }
}
