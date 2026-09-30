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
    /// 搭乗・チェックインなどの日時。決まっていない予約もあるので任意。
    /// 飛行機では出発時刻として扱う
    var date: Date?
    /// 予約番号・確認番号。この機能の主役
    var confirmationNumber: String?
    var note: String?
    var linkURL: String?

    // MARK: - 移動の予約で使う項目
    //
    // 空港で必要になるのは、便名・座席・予約番号・出発時刻・ターミナル。
    // メモに書いてもらう形だと探しにくいので、独立した項目にする。
    // 新幹線でもそのまま使えるように、飛行機だけの名前は避けている
    // （terminal だけは飛行機用）。
    //
    // これらは JSON にまとめて保存されるため、増やしても
    // CloudKit のスキーマ変更は要らない。古いデータでは nil になる。

    /// 便名・列車名（例: ANA123 / のぞみ21号）
    var transportNumber: String?
    /// 出発地（例: 羽田空港 / 東京駅）
    var departurePlace: String?
    /// 到着地（例: 那覇空港 / 新大阪駅）
    var arrivalPlace: String?
    /// 到着時刻。出発時刻は `date` を使う
    var arrivalDate: Date?
    /// 座席（例: 12A / 7号車 3D）
    var seat: String?
    /// ターミナル（例: 第2ターミナル）。飛行機のみ
    var terminal: String?

    // MARK: - 時刻をどこの時計で読むか
    //
    // 飛行機は出発と到着で時間帯が違う（羽田 10:00 発 → パリ 16:00 着）。
    // 端末の時計で読んでいたため、現地に着くと時刻がずれ、所要時間も
    // 時差の分だけ狂っていた。無い予約（2.7 より前）は日本時間とみなす。
    // JSON の中の項目なので、CloudKit のスキーマ変更は要らない

    /// `date`（出発・チェックインなど）の時間帯。"Europe/Paris" など
    var timeZoneIdentifier: String?
    /// `arrivalDate` の時間帯
    var arrivalTimeZoneIdentifier: String?

    /// 期間のある予約の終わり（宿泊ならチェックアウト、レンタカーなら返却）。始まりは `date`。
    ///
    /// これが無いと何日にまたがるのか分からず、期間中の各日に出せない
    /// （「滞在先を毎日の一番上に出したい」という要望）。
    /// 場所は1か所なので、時間帯は始まりと同じ `timeZoneIdentifier` を使う。
    /// 飛行機・新幹線は `arrivalDate` を使うので、これは使わない
    var endDate: Date?

    /// 日程の一番上に出すか。**選んだものだけ出す**（無い・false なら出さない）。
    /// 終わりがあれば期間中の毎日、無ければ始まりの日だけに出る
    var pinsDuringPeriod: Bool?

    /// 経路を表示するかどうか。
    /// 片方しか入っていなくても出す。入れた情報が画面に出ないほうが困る
    var hasRoute: Bool {
        !(departurePlace ?? "").isEmpty || !(arrivalPlace ?? "").isEmpty
    }

    init(id: String = UUID().uuidString,
         kind: Kind = .hotel,
         title: String = "",
         date: Date? = nil,
         confirmationNumber: String? = nil,
         note: String? = nil,
         linkURL: String? = nil,
         transportNumber: String? = nil,
         departurePlace: String? = nil,
         arrivalPlace: String? = nil,
         arrivalDate: Date? = nil,
         seat: String? = nil,
         terminal: String? = nil,
         timeZoneIdentifier: String? = nil,
         arrivalTimeZoneIdentifier: String? = nil,
         endDate: Date? = nil,
         pinsDuringPeriod: Bool? = nil) {
        self.id = id
        self.kind = kind
        self.title = title
        self.date = date
        self.confirmationNumber = confirmationNumber
        self.note = note
        self.linkURL = linkURL
        self.transportNumber = transportNumber
        self.departurePlace = departurePlace
        self.arrivalPlace = arrivalPlace
        self.arrivalDate = arrivalDate
        self.seat = seat
        self.terminal = terminal
        self.timeZoneIdentifier = timeZoneIdentifier
        self.arrivalTimeZoneIdentifier = arrivalTimeZoneIdentifier
        self.endDate = endDate
        self.pinsDuringPeriod = pinsDuringPeriod
    }
}

extension Reservation.Kind {
    /// 出発地・到着地・座席を入力させる種類かどうか
    var usesRoute: Bool {
        self == .flight || self == .train
    }

    /// 始まりと終わりの日時を持てる種類（経路のあるもの以外）
    var usesPeriod: Bool { !usesRoute }

    /// 始まりの呼び方
    var startLabel: String {
        switch self {
        case .hotel: return "チェックイン"
        case .rentalCar: return "受け取り"
        default: return "開始"
        }
    }

    /// 終わりの呼び方
    var endLabel: String {
        switch self {
        case .hotel: return "チェックアウト"
        case .rentalCar: return "返却"
        default: return "終了"
        }
    }

}

// MARK: - 行程へ持っていく

extension Reservation {

    /// 行程（タイムスケジュール）に並べる形にする。
    ///
    /// 予約から先に登録した人が、同じ内容を行程にもう一度打ち直さずに済むようにする。
    /// 逆向き（行程 → 予約）は `ScheduleItemPickerView` が既に担っている。
    ///
    /// **飛行機と新幹線で到着時刻もあるときは、出発と到着の2件に分ける。**
    /// 1件にすると、行程の上では「羽田10:00」としか出ず、
    /// 何時に着くのかが分からなくなる。
    ///
    /// 時刻が決まっていない予約（宿の予約番号だけ控えた場合など）は空を返す。
    /// 置く場所が決められないため
    func itineraryItems() -> [ScheduleItem] {
        guard let date else { return [] }

        let note = confirmationNumber
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .flatMap { $0.isEmpty ? nil : "予約番号 \($0)" }

        guard kind.usesRoute else {
            return [ScheduleItem(time: date,
                                 title: title,
                                 location: nil,
                                 notes: note,
                                 reservationId: id,
                                 timeZoneIdentifier: timeZoneIdentifier)]
        }

        // 経路のある予約は、便名を見出しにしたほうが行程で読みやすい。
        // タイトルは「ANA123 羽田空港 → 那覇空港」のように長い
        let label = transportNumber?.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = (label?.isEmpty == false ? label! : title)

        var items = [
            ScheduleItem(time: date,
                         title: "\(name) 出発",
                         location: departurePlace,
                         notes: note,
                         reservationId: id,
                         timeZoneIdentifier: timeZoneIdentifier)
        ]

        if let arrivalDate {
            items.append(
                ScheduleItem(time: arrivalDate,
                             title: "\(name) 到着",
                             location: arrivalPlace,
                             notes: nil,
                             reservationId: id,
                             timeZoneIdentifier: arrivalTimeZoneIdentifier)
            )
        }
        return items
    }
}
