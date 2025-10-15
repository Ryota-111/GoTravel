import Foundation

struct MapURLParser {

    static func extractAddress(from urlString: String) -> String? {
        guard URL(string: urlString) != nil else {
            return nil
        }

        var urlStr = urlString

        if urlStr.contains("maps.app.goo.gl") || urlStr.contains("goo.gl") {
            print("短縮URLを検出（住所抽出）: \(urlStr)")
            if let expandedURL = expandShortenedURLCompletely(urlStr) {
                print("URL展開成功: \(expandedURL)")
                urlStr = expandedURL
            } else {
                print("URL展開失敗")
                return nil
            }
        }

        if let range = urlStr.range(of: #"\?q=([^&]+)"#, options: .regularExpression) {
            let qParam = String(urlStr[range])
            let addressEncoded = qParam.replacingOccurrences(of: "?q=", with: "")
            if let address = addressEncoded.removingPercentEncoding {
                let simplified = simplifyAddress(address)
                print("住所を抽出: \(simplified)")
                return simplified
            }
        }

        return nil
    }

    private static func expandShortenedURLCompletely(_ urlString: String) -> String? {
        guard let url = URL(string: urlString) else {
            return nil
        }

        var expandedURL: String?
        let semaphore = DispatchSemaphore(value: 0)

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10.0

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse {
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

    private static func simplifyAddress(_ address: String) -> String {

        var simplified = address

        simplified = simplified.replacingOccurrences(of: "+", with: " ")
        simplified = simplified.replacingOccurrences(of: #"〒\d{3}-\d{4}\s*"#, with: "", options: .regularExpression)
        simplified = simplified.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)

        let prefectures = ["北海道", "青森県", "岩手県", "宮城県", "秋田県", "山形県", "福島県",
                          "茨城県", "栃木県", "群馬県", "埼玉県", "千葉県", "東京都", "神奈川県",
                          "新潟県", "富山県", "石川県", "福井県", "山梨県", "長野県", "岐阜県",
                          "静岡県", "愛知県", "三重県", "滋賀県", "京都府", "大阪府", "兵庫県",
                          "奈良県", "和歌山県", "鳥取県", "島根県", "岡山県", "広島県", "山口県",
                          "徳島県", "香川県", "愛媛県", "高知県", "福岡県", "佐賀県", "長崎県",
                          "熊本県", "大分県", "宮崎県", "鹿児島県", "沖縄県"]

        for prefecture in prefectures {
            if let range = simplified.range(of: prefecture) {
                let fromPrefecture = String(simplified[range.lowerBound...])
                let components = fromPrefecture.split(separator: " ")
                if components.count >= 1 {
                    let mainAddress = components.prefix(3).joined(separator: " ")
                    simplified = mainAddress
                    break
                }
            }
        }

        return simplified.trimmingCharacters(in: .whitespaces)
    }

}
