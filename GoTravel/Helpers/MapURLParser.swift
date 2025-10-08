import Foundation

struct MapURLParser {

    /// URLから住所を抽出
    static func extractAddress(from urlString: String) -> String? {
        guard URL(string: urlString) != nil else {
            return nil
        }

        var urlStr = urlString

        // 短縮URLの場合は展開を試みる
        if urlStr.contains("maps.app.goo.gl") || urlStr.contains("goo.gl") {
            print("🔗 短縮URLを検出（住所抽出）: \(urlStr)")
            if let expandedURL = expandShortenedURLCompletely(urlStr) {
                print("✅ URL展開成功: \(expandedURL)")
                urlStr = expandedURL
            } else {
                print("⚠️ URL展開失敗")
                return nil
            }
        }

        // ?q=パラメータから住所を抽出
        if let range = urlStr.range(of: #"\?q=([^&]+)"#, options: .regularExpression) {
            let qParam = String(urlStr[range])
            let addressEncoded = qParam.replacingOccurrences(of: "?q=", with: "")
            if let address = addressEncoded.removingPercentEncoding {
                let simplified = simplifyAddress(address)
                print("✅ 住所を抽出: \(simplified)")
                return simplified
            }
        }

        return nil
    }

    /// 短縮URLを完全に展開して最終的なURLを取得（GETリクエストで実際のコンテンツを取得）
    private static func expandShortenedURLCompletely(_ urlString: String) -> String? {
        guard let url = URL(string: urlString) else {
            return nil
        }

        var expandedURL: String?
        let semaphore = DispatchSemaphore(value: 0)

        var request = URLRequest(url: url)
        request.httpMethod = "GET"  // 実際のコンテンツを取得してリダイレクトを完全に追跡
        request.timeoutInterval = 10.0

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse {
                // 最終的なURLを取得
                if let finalURL = httpResponse.url?.absoluteString {
                    expandedURL = finalURL
                    print("📍 最終URL: \(finalURL)")
                }
            }
            semaphore.signal()
        }

        task.resume()
        _ = semaphore.wait(timeout: .now() + 10.0)

        return expandedURL
    }

    /// 住所を簡略化（ジオコーディングしやすい形式に）
    private static func simplifyAddress(_ address: String) -> String {
        // "〒100-0005 東京都千代田区丸の内１丁目９−１ 月島もんじゃ たまとや 東京駅 東京駅 黒塀横丁B1F"
        // → "東京都千代田区丸の内１丁目９−１"

        var simplified = address

        // "+" を空白に置き換え
        simplified = simplified.replacingOccurrences(of: "+", with: " ")

        // 郵便番号を削除
        simplified = simplified.replacingOccurrences(of: #"〒\d{3}-\d{4}\s*"#, with: "", options: .regularExpression)

        // 複数の空白を1つに
        simplified = simplified.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)

        // 最初の住所部分のみを抽出（都道府県から始まる）
        let prefectures = ["北海道", "青森県", "岩手県", "宮城県", "秋田県", "山形県", "福島県",
                          "茨城県", "栃木県", "群馬県", "埼玉県", "千葉県", "東京都", "神奈川県",
                          "新潟県", "富山県", "石川県", "福井県", "山梨県", "長野県", "岐阜県",
                          "静岡県", "愛知県", "三重県", "滋賀県", "京都府", "大阪府", "兵庫県",
                          "奈良県", "和歌山県", "鳥取県", "島根県", "岡山県", "広島県", "山口県",
                          "徳島県", "香川県", "愛媛県", "高知県", "福岡県", "佐賀県", "長崎県",
                          "熊本県", "大分県", "宮崎県", "鹿児島県", "沖縄県"]

        for prefecture in prefectures {
            if let range = simplified.range(of: prefecture) {
                // 都道府県から住所の主要部分を抽出（最初の3〜4セグメント）
                let fromPrefecture = String(simplified[range.lowerBound...])
                let components = fromPrefecture.split(separator: " ")
                if components.count >= 1 {
                    // 最初の数セグメントのみ使用（店名などを除外）
                    let mainAddress = components.prefix(3).joined(separator: " ")
                    simplified = mainAddress
                    break
                }
            }
        }

        return simplified.trimmingCharacters(in: .whitespaces)
    }

}
