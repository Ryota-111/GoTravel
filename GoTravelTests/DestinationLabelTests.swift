import Testing
import Foundation
@testable import GoTravel

/// 行き先として見つかった場所の名前（3.4）。
///
/// 「場所が見つかりました」だけでは、日本の同じ名前のお店になっていても気づけなかった
struct DestinationLabelTests {

    @Test("都市は「パリ（フランス）」。県と市が同じ名前なら1つにする")
    func city() {
        #expect(DestinationGeocoder.label(name: "パリ", locality: "パリ", area: nil, country: "フランス") == "パリ（フランス）")
        #expect(DestinationGeocoder.label(name: nil, locality: "ソウル特別市", area: "ソウル特別市", country: "大韓民国")
                == "ソウル特別市（大韓民国）")
    }

    @Test("お店や施設なら、その名前と場所を出す（外れていると分かる）")
    func spot() {
        #expect(DestinationGeocoder.label(name: "ロンドン", locality: "八幡浜市", area: "愛媛県", country: "日本")
                == "ロンドン・愛媛県 八幡浜市（日本）")
    }

    @Test("国だけのときは国の名前")
    func country() {
        #expect(DestinationGeocoder.label(name: "台湾", locality: nil, area: nil, country: "台湾") == "台湾")
        #expect(DestinationGeocoder.label(name: nil, locality: nil, area: "沖縄県", country: "日本") == "沖縄県（日本）")
    }
}
