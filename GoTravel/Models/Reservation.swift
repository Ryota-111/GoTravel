import Foundation

/// 旅行中の予約（飛行機・宿・レストランなど）。
///
/// 価値の中心は**予約番号をすぐ出せること**。
/// 旅行先で予約確認メールを探し直すのが手間なので、ここにまとめて持たせる。
struct Reservation: Identifiable, Codable, Equatable {

    enum Kind: String, Codable, CaseIterable, Identifiable {
        case flight
        case train
        case hotel
        case rentalCar
        case restaurant
        case ticket
        case other

        var id: String { rawValue }

        var label: String {
            switch self {
            case .flight: return "飛行機"
            case .train: return "新幹線・電車"
            case .hotel: return "宿泊"
            case .rentalCar: return "レンタカー"
            case .restaurant: return "レストラン"
            case .ticket: return "チケット"
            case .other: return "その他"
            }
        }

        var icon: String {
            switch self {
            case .flight: return "airplane"
            case .train: return "tram.fill"
            case .hotel: return "bed.double.fill"
            case .rentalCar: return "car.fill"
            case .restaurant: return "fork.knife"
            case .ticket: return "ticket.fill"
            case .other: return "checkmark.seal.fill"
            }
        }

        var placeholder: String {
            switch self {
            case .flight: return "例：ANA123便 羽田→那覇"
            case .train: return "例：のぞみ21号 東京→新大阪"
            case .hotel: return "例：〇〇ホテル"
            case .rentalCar: return "例：〇〇レンタカー 那覇空港店"
            case .restaurant: return "例：〇〇亭 ディナー"
            case .ticket: return "例：〇〇水族館 入場チケット"
            case .other: return "例：予約の名前"
            }
        }
    }

    /// タイムスケジュールから取り込むとき、予定の名前と場所から種類を当てる。
    /// 外れても選び直せるので、迷ったら other にせず素直に寄せる
    static func guessedKind(title: String, location: String?) -> Kind {
        let text = (title + " " + (location ?? "")).lowercased()
        func has(_ words: [String]) -> Bool { words.contains { text.contains($0) } }

        if has(["空港", "飛行機", "フライト", "搭乗", "便", "ana", "jal", "peach", "スカイマーク"]) { return .flight }
        if has(["新幹線", "電車", "列車", "のぞみ", "ひかり", "こだま", "はやぶさ", "特急", "駅"]) { return .train }
        if has(["ホテル", "宿", "旅館", "チェックイン", "泊", "ゲストハウス", "リゾート", "イン"]) { return .hotel }
        if has(["レンタカー", "レンタル", "車の受け取り", "car"]) { return .rentalCar }
        if has(["レストラン", "ランチ", "ディナー", "昼食", "夕食", "朝食", "食事", "居酒屋", "カフェ", "寿司", "焼肉", "ラーメン"]) { return .restaurant }
        if has(["チケット", "入場", "水族館", "美術館", "博物館", "動物園", "遊園地", "テーマパーク", "ツアー", "体験"]) { return .ticket }
        return .other
    }

    var id: String
    var kind: Kind
    var title: String
    /// 搭乗・チェックインなどの日時。決まっていない予約もあるので任意
    var date: Date?
    /// 予約番号・確認番号。この機能の主役
    var confirmationNumber: String?
    var note: String?
    var linkURL: String?

    init(id: String = UUID().uuidString,
         kind: Kind = .hotel,
         title: String = "",
         date: Date? = nil,
         confirmationNumber: String? = nil,
         note: String? = nil,
         linkURL: String? = nil) {
        self.id = id
        self.kind = kind
        self.title = title
        self.date = date
        self.confirmationNumber = confirmationNumber
        self.note = note
        self.linkURL = linkURL
    }
}
