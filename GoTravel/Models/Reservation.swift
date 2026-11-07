import Foundation

/// 旅行中の予約（飛行機・宿・レストランなど）。
///
/// 価値の中心は**予約番号をすぐ出せること**。
/// 旅行先で予約確認メールを探し直すのが手間なので、ここにまとめて持たせる。
struct Reservation: Identifiable, Codable, Equatable {

    enum Kind: String, Codable, CaseIterable, Identifiable {
        case flight
        case train
        /// バス（3.4。高速バス・空港バスなど）。**保存では「電車」として書き、`kindDetail` に "bus" と添える。**
        /// 古い版は知らない種類を「その他」として読み、出発地・到着地が出なくなる。「電車」なら発着地まで出る
        case bus
        /// 船・フェリー（3.4）。保存はバスと同じく「電車」＋ "ferry"
        case ferry
        case hotel
        case rentalCar
        /// 駐車場（2.9）。**保存では「その他」として書き、`kindDetail` に "parking" と添える。**
        /// 古いバージョンは知らない種類を読めず、予約の一覧をまるごと失うため（`Reservation.CodingKeys`）
        case parking
        case restaurant
        case ticket
        case other

        var id: String { rawValue }

        /// 知らない種類（新しいバージョンで足されたもの）は「その他」として読む。
        /// 読めずに失敗すると、予約の一覧がまるごと空になる
        init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = Kind(rawValue: raw) ?? .other
        }

        var label: String {
            switch self {
            case .flight: return "飛行機"
            case .train: return "新幹線・電車"
            case .bus: return "バス"
            case .ferry: return "船・フェリー"
            case .hotel: return "宿泊"
            case .rentalCar: return "レンタカー"
            case .parking: return "駐車場"
            case .restaurant: return "レストラン"
            case .ticket: return "チケット"
            case .other: return "その他"
            }
        }

        var icon: String {
            switch self {
            case .flight: return "airplane"
            case .train: return "tram.fill"
            case .bus: return "bus.fill"
            case .ferry: return "ferry.fill"
            case .hotel: return "bed.double.fill"
            case .rentalCar: return "car.fill"
            case .parking: return "parkingsign.circle.fill"
            case .restaurant: return "fork.knife"
            case .ticket: return "ticket.fill"
            case .other: return "checkmark.seal.fill"
            }
        }

        var placeholder: String {
            switch self {
            case .flight: return "例：ANA123便 羽田→那覇"
            case .train: return "例：のぞみ21号 東京→新大阪"
            case .bus: return "例：〇〇高速バス 梅田→新宿"
            case .ferry: return "例：〇〇フェリー 神戸→大分"
            case .hotel: return "例：〇〇ホテル"
            case .rentalCar: return "例：〇〇レンタカー 那覇空港店"
            case .parking: return "例：〇〇駐車場"
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
        if has(["高速バス", "夜行バス", "空港バス", "リムジンバス", "バス"]) { return .bus }
        if has(["フェリー", "高速船", "汽船"]) { return .ferry }
        if has(["新幹線", "電車", "列車", "のぞみ", "ひかり", "こだま", "はやぶさ", "特急", "駅"]) { return .train }
        if has(["ホテル", "宿", "旅館", "チェックイン", "泊", "ゲストハウス", "リゾート", "イン"]) { return .hotel }
        if has(["駐車場", "パーキング", "駐車"]) { return .parking }
        if has(["レンタカー", "レンタル", "車の受け取り", "car"]) { return .rentalCar }
        if has(["レストラン", "ランチ", "ディナー", "昼食", "夕食", "朝食", "食事", "居酒屋", "カフェ", "寿司", "焼肉", "ラーメン"]) { return .restaurant }
        if has(["チケット", "入場", "水族館", "美術館", "博物館", "動物園", "遊園地", "テーマパーク", "ツアー", "体験"]) { return .ticket }
        return .other
    }

    var id: String

    /// 種類。駐車場・バス・船は保存の形が違う（下の `storedKind` と `kindDetail`）
    var kind: Kind {
        get { Self.kind(stored: storedKind, detail: kindDetail) }
        set { (storedKind, kindDetail) = Self.storage(of: newValue) }
    }

    /// 古い版が読める形で書く。駐車場は「その他」、バス・船は「電車」に印を添える
    private static func storage(of kind: Kind) -> (Kind, String?) {
        switch kind {
        case .parking: return (.other, parkingDetail)
        case .bus: return (.train, busDetail)
        case .ferry: return (.train, ferryDetail)
        default: return (kind, nil)
        }
    }

    private static func kind(stored: Kind, detail: String?) -> Kind {
        switch detail {
        case parkingDetail: return .parking
        case busDetail: return .bus
        case ferryDetail: return .ferry
        default: return stored
        }
    }

    /// 保存する種類。駐車場は "other" として書く（古いバージョンが読めるように）
    private var storedKind: Kind
    /// 種類の詳しい印。駐車場なら "parking"。古いバージョンは読み飛ばす
    private var kindDetail: String?
    private static let parkingDetail = "parking"
    private static let busDetail = "bus"
    private static let ferryDetail = "ferry"

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
    /// ターミナル（例: 第2ターミナル）。電車・バス・船では、のりば・番線（例: 14番線。3.4〜）
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

    /// 費用（円）。
    ///
    /// 行程にも追加した予約では、**行程の予定の金額と同じもの**として扱う
    /// （作った予定の1件目に入れ、予定の側で直したらこちらも直す）。
    /// 予算の画面には、行程に出ていない予約の分もまとめて出す。
    /// JSON の中の項目なので、CloudKit のスキーマ変更は要らない
    var cost: Double?

    /// 外貨で入れたときの元の金額とレート。`cost` はこれを円に直したもの（`ForeignCost.swift`）
    var foreignCost: ForeignCost?

    // MARK: - 場所（地図で選んだもの）
    //
    // 予約の時点で地図の場所を入れておけば、「行程にも追加する」で作った予定にそのまま入り、
    // 日程タブで場所を入れ直さずに済む（ご要望から）。どれも JSON の中なのでスキーマ変更は要らない

    /// 宿・レストラン・チケットなどの場所。飛行機・新幹線では使わない
    var location: ReservationLocation?
    /// 飛行機・新幹線の出発地の位置。名前は `departurePlace`
    var departureLocation: ReservationLocation?
    /// 飛行機・新幹線の到着地の位置。名前は `arrivalPlace`
    var arrivalLocation: ReservationLocation?

    /// 割り勘（3.1）：払った人と割り勘する人（`ScheduleItem.paidBy` と同じ）。
    /// 行程に出ている予約では、予定の側のものを使う
    var paidBy: String?
    var splitWith: [String]?
    var splitAmounts: [String: Double]?

    /// 保存のときの項目名。**項目を足したら、ここにも必ず足すこと**（足さないと保存されない）。
    /// `storedKind` は "kind" として書く（駐車場以外は今までと同じ形）
    enum CodingKeys: String, CodingKey {
        case id
        case storedKind = "kind"
        case kindDetail
        case title, date, confirmationNumber, note, linkURL
        case transportNumber, departurePlace, arrivalPlace, arrivalDate, seat, terminal
        case timeZoneIdentifier, arrivalTimeZoneIdentifier, endDate, pinsDuringPeriod
        case cost, foreignCost, location, departureLocation, arrivalLocation
        case paidBy, splitWith, splitAmounts
    }

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
         pinsDuringPeriod: Bool? = nil,
         cost: Double? = nil,
         foreignCost: ForeignCost? = nil) {
        self.id = id
        (self.storedKind, self.kindDetail) = Self.storage(of: kind)
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
        self.cost = cost
        self.foreignCost = foreignCost
    }
}

extension Reservation.Kind {
    /// 出発地・到着地・座席を入力させる種類かどうか
    var usesRoute: Bool {
        self == .flight || self == .train || self == .bus || self == .ferry
    }

    /// 行程の「移動」の乗り物（3.4）。経路の無い種類は電車にしておく（使わない）
    var transportMode: TransportMode {
        switch self {
        case .flight: return .plane
        case .bus: return .bus
        case .ferry: return .ship
        default: return .train
        }
    }

    /// 行程の「移動」の乗り物から、予約の種類を決める。予約の無い乗り物（車・タクシー・徒歩）は nil
    init?(transportMode: TransportMode) {
        switch transportMode {
        case .plane: self = .flight
        case .train: self = .train
        case .bus: self = .bus
        case .ship: self = .ferry
        case .car, .taxi, .walk: return nil
        }
    }

    /// 乗り場の欄の呼び方と例。飛行機はターミナル、ほかはのりば・番線（`terminal` に入れる）
    var terminalLabel: String { self == .flight ? "ターミナル" : "のりば・番線" }
    var terminalPlaceholder: String {
        switch self {
        case .flight: return "例：第2"
        case .bus: return "例：D2のりば"
        case .ferry: return "例：第3乗り場"
        default: return "例：14番線"
        }
    }

    /// 便名の欄の呼び方と例（経路のある種類）
    var numberLabel: String {
        switch self {
        case .flight: return "便名"
        case .train: return "列車名"
        default: return "便・系統"
        }
    }
    var numberPlaceholder: String {
        switch self {
        case .flight: return "例：ANA123"
        case .bus: return "例：〇〇高速バス 3便"
        case .ferry: return "例：さんふらわあ"
        default: return "例：のぞみ21号"
        }
    }
    var departurePlaceholder: String {
        switch self {
        case .flight: return "例：羽田空港"
        case .bus: return "例：大阪梅田（阪急三番街）"
        case .ferry: return "例：神戸港"
        default: return "例：東京駅"
        }
    }
    var arrivalPlaceholder: String {
        switch self {
        case .flight: return "例：那覇空港"
        case .bus: return "例：バスタ新宿"
        case .ferry: return "例：大分港"
        default: return "例：新大阪駅"
        }
    }
    var seatPlaceholder: String {
        switch self {
        case .flight: return "例：12A"
        case .bus: return "例：5A"
        case .ferry: return "例：2等洋室 205"
        default: return "例：7号車 3D"
        }
    }

    /// 始まりと終わりの日時を持てる種類（経路のあるもの以外）
    var usesPeriod: Bool { !usesRoute }

    /// 始まりの呼び方
    var startLabel: String {
        switch self {
        case .hotel: return "チェックイン"
        case .rentalCar: return "受け取り"
        case .parking: return "入庫"
        default: return "開始"
        }
    }

    /// 終わりの呼び方
    var endLabel: String {
        switch self {
        case .hotel: return "チェックアウト"
        case .rentalCar: return "返却"
        case .parking: return "出庫"
        default: return "終了"
        }
    }

}

/// 予約の場所。地図で選んだときは座標を持つ
struct ReservationLocation: Codable, Equatable {
    var name: String
    var address: String?
    var latitude: Double?
    var longitude: Double?
}

// MARK: - 行程へ持っていく

extension Reservation {

    /// 行程（タイムスケジュール）に並べる形にする。
    ///
    /// 予約から先に登録した人が、同じ内容を行程にもう一度打ち直さずに済むようにする。
    /// 逆向き（行程 → 予約）は `ScheduleItemPickerView` が既に担っている。
    ///
    /// **飛行機・電車・バス・船で到着時刻もあるときは、出発と到着の2件に分ける。**
    /// それぞれの時刻・場所（地図のピン）で並ぶので、何時にどこへ着くかが日程で分かる。
    /// 出発の予定には乗り物・便・のりば・座席（`ScheduleItem.move`）を持たせ、
    /// 行程に「✈︎ NH991 · 座席 12A」と出す（3.4）。到着は時刻と場所だけ
    ///
    /// **宿やレンタカーで終わりの日時もあるときは、始まりと終わりの2件に分ける。**
    /// 2泊以上の宿で、チェックアウトの日の行程に何も出ないと、その日の動きが組めない
    /// （ご報告から）。泊まっている間の毎日に出したいときは「日程の一番上に表示」を使う。
    ///
    /// 時刻が決まっていない予約（宿の予約番号だけ控えた場合など）は空を返す。
    /// 置く場所が決められないため
    func itineraryItems() -> [ScheduleItem] {
        // 住所は、どの部分の予定かに合わせて付ける（宿などは場所、飛行機は出発地・到着地）
        itineraryItemsWithoutAddress().map { item in
            var item = item
            switch item.reservationPart.flatMap(ReservationPart.init(rawValue:)) {
            case .departure, .move: item.address = departureLocation?.address
            case .arrival: item.address = arrivalLocation?.address
            default: item.address = location?.address
            }
            return item
        }
    }

    private func itineraryItemsWithoutAddress() -> [ScheduleItem] {
        guard let date else { return [] }

        let note = itineraryNotes

        guard kind.usesRoute else {
            var items = [ScheduleItem(time: date,
                                      title: title,
                                      location: location?.name,
                                      notes: note,
                                      latitude: location?.latitude,
                                      longitude: location?.longitude,
                                      cost: cost,
                                      reservationId: id,
                                      timeZoneIdentifier: timeZoneIdentifier,
                                      foreignCost: foreignCost,
                                      reservationPart: ReservationPart.main.rawValue)]
            // 終わり（チェックアウト・返却）。費用は始まりにだけ入れる（2重に数えない）
            if kind.usesPeriod, let endDate, endDate > date {
                items.append(ScheduleItem(time: endDate,
                                          title: "\(title) \(kind.endLabel)",
                                          location: location?.name,
                                          latitude: location?.latitude,
                                          longitude: location?.longitude,
                                          reservationId: id,
                                          timeZoneIdentifier: timeZoneIdentifier,
                                          reservationPart: ReservationPart.end.rawValue))
            }
            return items
        }

        return routeItems()
    }

    /// 乗り物の予約の、行程での「移動」の中身
    var scheduleMove: ScheduleMove {
        ScheduleMove(mode: kind.transportMode, line: transportNumber, platform: terminal, seat: seat,
                     from: departurePlace.map { MovePlace(name: $0, address: departureLocation?.address,
                                                         latitude: departureLocation?.latitude,
                                                         longitude: departureLocation?.longitude) },
                     to: arrivalPlace.map { MovePlace(name: $0, address: arrivalLocation?.address,
                                                     latitude: arrivalLocation?.latitude,
                                                     longitude: arrivalLocation?.longitude) })
    }

    /// 行程の見出し（便名、無ければ予約の名前）
    private var legacyName: String {
        let label = transportNumber?.trimmingCharacters(in: .whitespacesAndNewlines)
        return label?.isEmpty == false ? label! : title
    }

    /// 乗り物の予約の「出発」「到着」の2件。出発にだけ乗り物・便・のりば・座席を持たせる（3.4）
    private func routeItems() -> [ScheduleItem] {
        guard kind.usesRoute, let date else { return [] }
        let name = legacyName
        let move = scheduleMove
        var items = [
            // 費用は1件目（出発）にだけ入れる。到着にも入れると予算で2重に数える
            ScheduleItem(time: date,
                         title: "\(name) 出発",
                         location: departurePlace,
                         notes: itineraryNotes,
                         latitude: departureLocation?.latitude,
                         longitude: departureLocation?.longitude,
                         cost: cost,
                         reservationId: id,
                         timeZoneIdentifier: timeZoneIdentifier,
                         foreignCost: foreignCost,
                         reservationPart: ReservationPart.departure.rawValue)
        ]

        if let arrivalDate {
            items.append(
                ScheduleItem(time: arrivalDate,
                             title: "\(name) 到着",
                             location: arrivalPlace,
                             notes: nil,
                             latitude: arrivalLocation?.latitude,
                             longitude: arrivalLocation?.longitude,
                             reservationId: id,
                             timeZoneIdentifier: arrivalTimeZoneIdentifier,
                             reservationPart: ReservationPart.arrival.rawValue)
            )
        }
        // 便・座席は乗る前に要るもの。到着は時刻と場所だけにする（2つに同じ行が並ぶと読みにくい）
        items[0].move = move
        return items
    }
}

extension Reservation {
    /// 行程の予定に入れるメモ。予約番号の行の下に、予約のメモを続ける
    var itineraryNotes: String? {
        let number = confirmationNumber?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let memo = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let lines = [number.isEmpty ? nil : Self.confirmationLine(number), memo.isEmpty ? nil : memo].compactMap { $0 }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    static func confirmationLine(_ number: String) -> String { "予約番号 \(number)" }

    /// 行程の予定のメモから、予約のメモの部分を取り出す（先頭の予約番号の行は除く）
    func memo(fromItineraryNotes notes: String?) -> String? {
        var lines = (notes ?? "").components(separatedBy: "\n")
        if let number = confirmationNumber?.trimmingCharacters(in: .whitespacesAndNewlines), !number.isEmpty,
           lines.first?.trimmingCharacters(in: .whitespaces) == Self.confirmationLine(number) {
            lines.removeFirst()
        }
        let memo = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return memo.isEmpty ? nil : memo
    }
}
