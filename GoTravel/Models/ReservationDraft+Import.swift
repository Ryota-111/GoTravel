import Foundation

// MARK: - 下書きを予約にする

/// 下書きから作った予約と、編集画面で確かめてほしいこと
struct ImportedReservation: Identifiable, Equatable {
    var reservation: Reservation
    /// 「年を補った」「時刻が書いていなかった」など。編集画面の上に出す
    var notes: [String]

    var id: String { reservation.id }
}

extension ReservationDraft {

    /// 予約確認メールには時間帯が書かれていないので、ここで決める。
    ///
    /// - 空港が分かれば、その空港の時計（パリの空港ならパリ時間）
    /// - 新幹線・電車と国内の空港は日本時間
    /// - それ以外（宿・レストランなど）は、目的地が海外なら現地の時計、国内なら日本時間
    ///
    /// 時刻が書いていない日付には仮の時刻を入れ、そのことを `notes` に残す
    /// - Parameter destinationTimeZone: 旅行の目的地の時間帯。日本と時差があるときだけ渡す
    func makeReservation(destinationTimeZone: TimeZone?) -> ImportedReservation {
        let japan = ScheduleClock.legacyTimeZone
        let local = destinationTimeZone ?? japan
        var notes: [String] = []

        var reservation = Reservation(kind: kind)
        reservation.confirmationNumber = confirmationNumber
        reservation.cost = cost
        if kind.usesRoute {
            reservation.transportNumber = transportNumber
            reservation.departurePlace = departurePlace
            reservation.arrivalPlace = arrivalPlace
        } else {
            reservation.title = title
        }

        let startZone: TimeZone
        let arrivalZone: TimeZone
        if kind.usesRoute {
            // 出発地が分からなければ日本から出る便とみなす（編集画面の既定と同じ）
            startZone = Self.placeTimeZone(departurePlace, kind: kind) ?? japan
            arrivalZone = Self.placeTimeZone(arrivalPlace, kind: kind) ?? local
        } else {
            startZone = local
            arrivalZone = local
        }

        var missingTime: [String] = []
        if let start {
            if start.hour == nil { missingTime.append(kind.startLabel) }
            reservation.date = Self.date(from: start, defaultHour: Self.defaultStartHour(for: kind), in: startZone)
            reservation.timeZoneIdentifier = startZone.identifier
        }
        if kind.usesRoute, let arrival, reservation.date != nil {
            if arrival.hour == nil { missingTime.append("到着") }
            reservation.arrivalDate = Self.date(from: arrival, defaultHour: 12, in: arrivalZone)
            reservation.arrivalTimeZoneIdentifier = arrivalZone.identifier
        }
        if kind.usesPeriod, let end, reservation.date != nil {
            if end.hour == nil { missingTime.append(kind.endLabel) }
            reservation.endDate = Self.date(from: end, defaultHour: Self.defaultEndHour(for: kind), in: startZone)
        }

        if start == nil {
            notes.append("日時が読み取れませんでした。分かれば入れてください")
        }
        if !missingTime.isEmpty {
            notes.append("\(missingTime.joined(separator: "・"))の時刻がメールに無かったので、仮の時刻を入れています")
        }
        if guessedYear {
            notes.append("メールに年が無かったので、年を補っています")
        }
        if confirmationNumber == nil {
            notes.append("予約番号が見つかりませんでした")
        }
        return ImportedReservation(reservation: reservation, notes: notes)
    }

    // MARK: - 時刻の補い

    private static func defaultStartHour(for kind: Reservation.Kind) -> Int {
        switch kind {
        case .hotel: return 15
        case .rentalCar: return 9
        default: return 12
        }
    }

    private static func defaultEndHour(for kind: Reservation.Kind) -> Int {
        switch kind {
        case .hotel: return 10
        case .rentalCar: return 18
        default: return 12
        }
    }

    private static func date(from components: DateComponents, defaultHour: Int, in timeZone: TimeZone) -> Date? {
        var parts = DateComponents()
        parts.year = components.year
        parts.month = components.month
        parts.day = components.day
        parts.hour = components.hour ?? defaultHour
        parts.minute = components.hour == nil ? 0 : (components.minute ?? 0)
        return ScheduleClock.calendar(in: timeZone).date(from: parts)
    }

    // MARK: - 場所の時計

    /// 読み取りで出てくる海外の空港（`ReservationEmailParser` の空港の一覧と揃える）
    private static let foreignAirportZones: [String: String] = [
        "ホノルル空港": "Pacific/Honolulu",
        "仁川空港": "Asia/Seoul", "金浦空港": "Asia/Seoul",
        "台北桃園空港": "Asia/Taipei", "台北松山空港": "Asia/Taipei",
        "香港空港": "Asia/Hong_Kong",
        "シンガポール空港": "Asia/Singapore",
        "バンコク空港": "Asia/Bangkok",
        "パリ空港": "Europe/Paris",
        "ロンドン空港": "Europe/London",
        "ロサンゼルス空港": "America/Los_Angeles", "サンフランシスコ空港": "America/Los_Angeles",
        "ニューヨーク空港": "America/New_York",
        "グアム空港": "Pacific/Guam"
    ]

    /// 場所から時計が決まるなら返す。分からなければ nil
    static func placeTimeZone(_ place: String?, kind: Reservation.Kind) -> TimeZone? {
        guard let place, !place.isEmpty else { return nil }
        if let identifier = foreignAirportZones[place] { return TimeZone(identifier: identifier) }
        // 読み取りで出てくる空港は、海外の一覧に無ければ国内。新幹線・電車の駅も国内
        return ScheduleClock.legacyTimeZone
    }
}
