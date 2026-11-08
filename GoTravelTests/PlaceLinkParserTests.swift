import Testing
import Foundation
@testable import GoTravel

/// 共有・スクリーンショットから場所を読む（3.5）
struct PlaceLinkParserTests {

    @Test("Google マップの場所のリンクから、名前と場所そのものの位置を読む")
    func googlePlace() throws {
        let url = try #require(URL(string: "https://www.google.com/maps/place/%E6%9D%B1%E4%BA%AC%E3%82%BF%E3%83%AF%E3%83%BC/@35.6585805,139.7454329,17z/data=!3m1!4b1!4m6!3m5!1s0x0:0x0!8m2!3d35.6585769!4d139.7454506"))
        let hint = try #require(PlaceLinkParser.hint(from: url))
        #expect(hint.name == "東京タワー")
        #expect(hint.latitude == 35.6585769)
        #expect(hint.longitude == 139.7454506)
    }

    @Test("Google マップの検索のリンク（?q=）は名前、位置なら位置")
    func googleQuery() throws {
        let named = try #require(PlaceLinkParser.hint(from: URL(string: "https://maps.google.com/?q=Blue+Bottle+Coffee+Kiyosumi")!))
        #expect(named.name == "Blue Bottle Coffee Kiyosumi")
        let point = try #require(PlaceLinkParser.hint(from: URL(string: "https://www.google.com/maps?q=34.9671,135.7727")!))
        #expect(point.name == nil)
        #expect(point.latitude == 34.9671)
    }

    @Test("住所は名前にしない。「店名, 住所」は分け、住所だけなら名前は空にする")
    func addressIsNotName() throws {
        let both = try #require(PlaceLinkParser.hint(from: URL(string: "https://maps.google.com/maps?q=%E3%81%B2%E3%82%87%E3%81%86%E3%81%9F%E3%82%93%E4%BA%AD,+%E6%97%A5%E6%9C%AC%E3%80%81%E3%80%92150-0002+%E6%9D%B1%E4%BA%AC%E9%83%BD%E6%B8%8B%E8%B0%B7%E5%8C%BA%E6%B8%8B%E8%B0%B72%E4%B8%81%E7%9B%AE24-12&ftid=0x0:0x1")!))
        #expect(both.name == "ひょうたん亭")
        #expect(both.address == "東京都渋谷区渋谷2丁目24-12")

        let onlyAddress = try #require(PlaceLinkParser.hint(from: URL(string: "https://www.google.com/maps/place/%E6%97%A5%E6%9C%AC%E3%80%81%E3%80%92430-0933+%E9%9D%99%E5%B2%A1%E7%9C%8C%E6%B5%9C%E6%9D%BE%E5%B8%82%E4%B8%AD%E5%A4%AE%E5%8C%BA%E9%8D%9B%E5%86%B6%E7%94%BA100/@34.7,137.7,17z")!))
        #expect(onlyAddress.name == nil)
        #expect(onlyAddress.address == "静岡県浜松市中央区鍛冶町100")

        #expect(PlaceLinkParser.isAddressLike("東京都渋谷区渋谷2-24-12"))
        #expect(PlaceLinkParser.isAddressLike("〒150-0002 東京都渋谷区"))
        #expect(PlaceLinkParser.isAddressLike("渋谷区渋谷2丁目24-12"))
        // Google マップが実際に返したリンク（住所・建物・階のあとに名前）
        let museum = try #require(PlaceLinkParser.hint(from: URL(string: "https://www.google.com/maps?q=%E3%80%92104-0031+%E6%9D%B1%E4%BA%AC%E9%83%BD%E4%B8%AD%E5%A4%AE%E5%8C%BA%E4%BA%AC%E6%A9%8B%EF%BC%91%E4%B8%81%E7%9B%AE%EF%BC%97%E2%88%92%EF%BC%91+TODA+BUILDING+6%E9%9A%8E+CREATIVE+MUSEUM+TOKYO&ftid=0x60188bbf166ac4a1:0xbdd0d2b518555899&entry=gps")!))
        #expect(museum.name == "CREATIVE MUSEUM TOKYO")
        #expect(museum.address == "東京都中央区京橋１丁目７−１ TODA BUILDING 6階")
        #expect(PlaceLinkParser.streetAddress("東京都中央区京橋１丁目７−１ TODA BUILDING 6階") == "東京都中央区京橋１丁目７−１")
        #expect(PlaceLinkParser.splitNameAndAddress("〒100-0005 東京都千代田区丸の内１丁目９−１ 東京駅").name == "東京駅")
        #expect(PlaceLinkParser.splitNameAndAddress("〒100-0005 東京都千代田区丸の内１丁目９−１").name == nil)
        #expect(PlaceLinkParser.isAddressLike("京橋１丁目7−１"))
        #expect(PlaceLinkParser.isAddressLike("銀座4-6-16"))
        #expect(PlaceLinkParser.splitNameAndAddress("CREATIVE MUSEUM TOKYO, 京橋１丁目7−１").name == "CREATIVE MUSEUM TOKYO")
        #expect(PlaceLinkParser.splitNameAndAddress("京橋１丁目7−１").name == nil)
        #expect(!PlaceLinkParser.isAddressLike("CREATIVE MUSEUM TOKYO"))
        #expect(!PlaceLinkParser.isAddressLike("21_21 DESIGN SIGHT"))
        #expect(!PlaceLinkParser.isAddressLike("スターバックス コーヒー 渋谷スクランブルスクエア店"))
        #expect(!PlaceLinkParser.isAddressLike("道の駅 南伊豆町"))
        #expect(!PlaceLinkParser.isAddressLike("東京タワー"))
        #expect(PlaceLinkParser.splitNameAndAddress("東京タワー").name == "東京タワー")
    }

    @Test("Apple マップのリンクから、名前・位置・住所を読む")
    func appleMaps() throws {
        let url = try #require(URL(string: "https://maps.apple.com/?address=%E4%BA%AC%E9%83%BD%E5%BA%9C%E4%BA%AC%E9%83%BD%E5%B8%82&ll=34.9671,135.7727&q=%E4%BC%8F%E8%A6%8B%E7%A8%B2%E8%8D%B7%E5%A4%A7%E7%A4%BE"))
        let hint = try #require(PlaceLinkParser.hint(from: url))
        #expect(hint.name == "伏見稲荷大社")
        #expect(hint.address == "京都府京都市")
        #expect(hint.latitude == 34.9671)
        #expect(hint.longitude == 135.7727)
    }

    @Test("地図ではないリンクは手がかりにしない。短いリンクは開いてから読む。投稿のリンクは見分ける")
    func otherLinks() {
        #expect(PlaceLinkParser.hint(from: URL(string: "https://tabelog.com/tokyo/A1303/A130301/13000001/")!) == nil)
        #expect(PlaceLinkParser.needsExpansion(URL(string: "https://maps.app.goo.gl/AbCdEf123")!))
        #expect(!PlaceLinkParser.needsExpansion(URL(string: "https://www.google.com/maps/place/x")!))
        #expect(PlaceLinkParser.isSocialPost(URL(string: "https://www.instagram.com/p/Cxyz/")!))
        #expect(PlaceLinkParser.isSocialPost(URL(string: "https://vt.tiktok.com/ZS123/")!))
        #expect(!PlaceLinkParser.isSocialPost(URL(string: "https://tabelog.com/")!))
    }

    @Test("Google マップの共有の文章は「名前／住所／リンク」。リンクを除いた行を返す")
    func sharedText() {
        let text = "スターバックス コーヒー 渋谷スクランブルスクエア店\n東京都渋谷区渋谷2-24-12\nhttps://maps.app.goo.gl/AbCdEf123"
        #expect(PlaceLinkParser.urls(in: text).map(\.absoluteString) == ["https://maps.app.goo.gl/AbCdEf123"])
        #expect(PlaceLinkParser.lines(in: text) == ["スターバックス コーヒー 渋谷スクランブルスクエア店", "東京都渋谷区渋谷2-24-12"])
    }

    @Test("ページの題名から店の名前だけを取り出す")
    func pageTitle() {
        #expect(PlaceLinkParser.name(fromPageTitle: "ブルーボトルコーヒー 清澄白河 (清澄白河/カフェ) - 食べログ") == "ブルーボトルコーヒー 清澄白河")
        #expect(PlaceLinkParser.name(fromPageTitle: "【公式】ホテル雅叙園東京 | 目黒") == "ホテル雅叙園東京")
        #expect(PlaceLinkParser.name(fromPageTitle: "a") == nil)
        #expect(PlaceImportReader.title(fromHTML: #"<html><head><meta property="og:title" content="喫茶 &amp; バー ソワレ"><title>x</title>"#) == "喫茶 & バー ソワレ")
        #expect(PlaceImportReader.title(fromHTML: "<title>\n 鎌倉大仏 </title>") == "鎌倉大仏")
    }

    @Test("スクリーンショットの文字から、場所の名前らしい行を先に選ぶ（画面の部品の言葉や時刻は外す）")
    func screenshotQueries() {
        let recognized = """
        travory_trip
        フォロー
        週末は京都でのんびりしてきました！最高の一日でした。
        📍 % ARABICA Kyoto 東山
        いいね！
        1.2万
        12:30
        #京都カフェ
        京都府京都市東山区星野町87-5
        """
        let queries = PlaceLinkParser.queries(fromRecognized: recognized)
        #expect(queries.first == "% ARABICA Kyoto 東山")
        #expect(queries.contains("京都府京都市東山区星野町87-5"))
        #expect(queries.contains("京都カフェ"))
        #expect(!queries.contains("フォロー"))
        #expect(!queries.contains("1.2万"))
        #expect(!queries.contains("12:30"))
    }

    @Test("「店名：」「【】」の後ろを名前にする")
    func markers() {
        let queries = PlaceLinkParser.queries(fromRecognized: "店名：喫茶ソワレ\n【伏見稲荷大社】千本鳥居がすごい")
        #expect(queries.contains("喫茶ソワレ"))
        #expect(queries.contains("伏見稲荷大社"))
    }
}
