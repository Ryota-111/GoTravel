import Foundation

// MARK: - 下書き

/// 予約確認メールから読み取った、予約の下書き。
///
/// **そのまま保存しない。** 予約の編集画面に入れた状態で開き、確かめてから保存してもらう。
/// 読み違えても「直す手間」で済むようにするため。
///
/// 日時は年月日と時分のまま持ち、どこの時間帯かは決めない。予約確認メールには
/// 時間帯が書かれていないことが多いので、取り込むときに時差対応の仕組みで決める
struct ReservationDraft: Equatable {
    var kind: Reservation.Kind
    var title: String = ""
    var confirmationNumber: String?
    var transportNumber: String?
    var departurePlace: String?
    var arrivalPlace: String?
    /// 始まり（出発・チェックイン・受け取り）
    var start: DateComponents?
    /// 到着（飛行機・新幹線）
    var arrival: DateComponents?
    /// 終わり（チェックアウト・返却）
    var end: DateComponents?
    /// 年が書いていなかったので補った。画面で確かめてもらう
    var guessedYear = false
    /// 支払った金額（円）。1通に複数の予約があるときは、1件目にだけ入れる（合計なので）
    var cost: Double?
}

// MARK: - 読み取り

/// 予約確認メールの本文から、予約の下書きを作る（決まった形の読み取り）。
///
/// 便名・列車名・予約番号・日付と時刻・空港や駅の名前のように、書き方の決まったものを拾う。
/// 航空会社や予約サイトごとの文面の違いは、なるべく言葉の手がかり（「チェックイン」
/// 「予約番号」など）で吸収する。
///
/// 精度は `~/Developer/travory-reservation-emails/` の実際のメールで測る
/// （`ReservationEmailSampleTests`）
enum ReservationEmailParser {

    /// - Parameters:
    ///   - kind: 利用者が選んだ種類。選んでいれば、文面から当てずにこれで読む
    ///   - referenceDate: 年が書いていない日付を補う基準（ふつうは今日）
    static func parse(_ rawText: String, kind chosenKind: Reservation.Kind? = nil,
                      referenceDate: Date = Date()) -> [ReservationDraft] {
        let text = tableToLabelValues(normalized(rawText))
        let kind = chosenKind ?? detectKind(text)
        // 受付・支払いの日時や、キャンセル・有効の期限は、予約の日時として使わない
        let allEvents = dateTimeEvents(in: text, referenceDate: referenceDate)
        let reservationEvents = allEvents.filter { !$0.isAdministrative }
        let events = reservationEvents.isEmpty ? allEvents : reservationEvents
        let confirmation = confirmationNumber(in: text)

        var drafts: [ReservationDraft]
        switch kind {
        case .flight:
            drafts = flightDrafts(in: text, events: events)
        case .train:
            drafts = trainDrafts(in: text, events: events)
        case .hotel:
            drafts = [periodDraft(kind: .hotel, in: text, events: events,
                                  startWords: ["チェックイン", "宿泊日", "到着日", "check-in", "check in", "arrival", "arrive"],
                                  endWords: ["チェックアウト", "出発日", "check-out", "check out", "departure", "depart"])]
        case .parking:
            drafts = [periodDraft(kind: .parking, in: text, events: events,
                                  startWords: ["入庫", "利用開始", "駐車開始", "利用日時"],
                                  endWords: ["出庫", "利用終了", "駐車終了"])]
        case .rentalCar:
            drafts = [periodDraft(kind: .rentalCar, in: text, events: events,
                                  startWords: ["貸出", "貸渡", "出発", "受取", "受け取り", "pick-up", "pickup", "pick up"],
                                  endWords: ["返却", "return", "drop-off", "drop off"])]
        default:
            drafts = [singleDateDraft(kind: kind, in: text, events: events)]
        }

        if drafts.isEmpty {
            drafts = [ReservationDraft(kind: kind)]
        }
        for index in drafts.indices where drafts[index].confirmationNumber == nil {
            drafts[index].confirmationNumber = confirmation
        }
        drafts[0].cost = paidAmount(in: text)
        return drafts
    }

    // MARK: - 金額

    /// 支払いの合計を探すラベル。前にあるものほど確か
    /// （「お支払い金額」「割引後」はクーポンやポイントを引いた後、「合計」は引く前のことがある）。
    /// 合計が書いていない航空券のために、運賃や領収額も最後に探す
    private static let amountLabels = ["割引後料金合計", "割引後合計", "割引後の合計", "お支払い金額", "お支払金額", "お支払額",
                                       "支払い金額", "支払金額", "ご請求額", "お支払い総額", "支払総額", "合計金額", "料金合計",
                                       "総額", "合計", "total", "領収額", "発売額", "運賃額", "航空券代金", "運賃"]

    /// 支払った金額（円）。ラベルの後ろ（改行1つまで）にある最初の円の金額を使う。
    /// 小計や1枚あたりの値段を拾わないよう、ラベルの無い金額は使わない。
    /// 円以外（ドル・ユーロ）は、予算が円なので読まない
    static func paidAmount(in text: String) -> Double? {
        let ns = text as NSString
        let amount = #"^[^\n]{0,30}?(?:\n[^\n]{0,30}?)?(?:[¥￥]\s?([\d,]+)|([\d,]+)\s?円|JPY\s?([\d,]+))"#
        guard let amountRegex = try? NSRegularExpression(pattern: amount, options: [.caseInsensitive]) else { return nil }

        for label in amountLabels {
            var searchStart = 0
            while searchStart < ns.length {
                let found = ns.range(of: label, options: [.caseInsensitive],
                                     range: NSRange(location: searchStart, length: ns.length - searchStart))
                guard found.location != NSNotFound else { break }
                searchStart = found.location + found.length

                // 「小計」「subtotal」のような別の言葉の一部は飛ばす
                if found.location > 0,
                   let before = ns.substring(with: NSRange(location: found.location - 1, length: 1)).first,
                   before == "小" || before.isLetter && before.isASCII { continue }

                let rest = ns.substring(from: searchStart)
                let restNS = rest as NSString
                guard let match = amountRegex.firstMatch(in: rest, range: NSRange(location: 0, length: restNS.length)) else { continue }
                for group in 1...3 {
                    let range = match.range(at: group)
                    guard range.location != NSNotFound else { continue }
                    let digits = restNS.substring(with: range).replacingOccurrences(of: ",", with: "")
                    if let value = Double(digits), value > 0 { return value }
                }
            }
        }
        return nil
    }

    // MARK: - 下ごしらえ

    /// 全角の英数字・記号と全角スペースを半角にする。
    /// カタカナは触らない（`fullwidthToHalfwidth` はカタカナまで半角にしてしまう）
    static func normalized(_ text: String) -> String {
        var scalars = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0xFF01...0xFF5E:
                scalars.append(Unicode.Scalar(scalar.value - 0xFEE0)!)
            case 0x3000:
                scalars.append(" ")
            default:
                // アラビア語やタイ語などの数字（٢٠٢٦、๒๐๒๖）も半角にする。
                // 正規表現の `\d` はこれらにも一致するが、`Int()` は半角しか読めないので、
                // そのまま進むと日付を数に直すところで落ちる
                if !scalar.isASCII, scalar.properties.numericType == .decimal,
                   let value = scalar.properties.numericValue, (0...9).contains(value) {
                    scalars.append(Unicode.Scalar(UInt8(0x30 + Int(value))))
                } else {
                    scalars.append(scalar)
                }
            }
        }
        return String(scalars)
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    /// 表の形（ラベルだけの行の次に、値だけの行が並ぶ）を「ラベル：値」の行に直す。
    ///
    /// 「予約ID • チェックイン日 • チェックアウト日」の次の行に「1234567890 2025/09/17 2025/09/18」
    /// のように並ぶ書き方（agoda など）。直さないと、どの日付がどのラベルのものか分からない
    static func tableToLabelValues(_ text: String) -> String {
        var lines = text.components(separatedBy: "\n")
        var index = 0
        while index + 1 < lines.count {
            let header = tableCells(lines[index])
            let values = tableCells(lines[index + 1])
            // 見出しの行は3つ以上に分かれていて、数字を含まない
            if header.count >= 3, header.count == values.count,
               !header.contains(where: { $0.contains(where: \.isNumber) }) {
                let merged = zip(header, values).map { "\($0)：\($1)" }
                lines.replaceSubrange(index...(index + 1), with: merged)
                index += merged.count
            } else {
                index += 1
            }
        }
        return lines.joined(separator: "\n")
    }

    private static func tableCells(_ line: String) -> [String] {
        line.components(separatedBy: "\t")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && $0 != "•" && $0 != "・" }
    }

    // MARK: - 種類

    static func detectKind(_ text: String) -> Reservation.Kind {
        let lower = text.lowercased()
        func score(_ words: [String]) -> Int {
            words.reduce(0) { $0 + lower.components(separatedBy: $1.lowercased()).count - 1 }
        }

        // 便名や列車名そのものが見つかれば、いちばん強い手がかりにする。
        // 「往路 JL915 羽田 → 那覇」のように、言葉の手がかりが無い文面もあるため
        let flightCount = flightNumbers(in: text).count
        let trainCount = trainNames(in: text).count

        let scores: [(Reservation.Kind, Int)] = [
            (.flight, flightCount * 3 + score(["便名", "搭乗", "フライト", "航空", "空港", "flight", "boarding", "airline", "airport"])),
            (.train, trainCount * 3 + score(["新幹線", "号車", "乗車", "列車", "えきねっと", "スマートex", "ex予約"])),
            (.hotel, score(["チェックイン", "チェックアウト", "宿泊", "ご宿泊", "泊", "check-in", "check-out", "check in", "hotel", "night", "accommodation", "airbnb"])),
            (.rentalCar, score(["レンタカー", "貸出", "貸渡", "返却", "車種", "rent a car", "rental car", "car rental", "pick-up", "drop-off", "vehicle"])),
            // 「駐車場」だけでは決めない。宿やレストランの案内にも駐車場のことが書いてあるため
            (.parking, score(["入庫", "出庫", "駐車予約", "駐車場の予約", "駐車場予約", "akippa", "特p", "軒先パーキング", "タイムズのb"]) * 2),
            // 「来店」だけでは決めない。体験や来店予約、店頭での受け取りでも使う言葉のため
            (.restaurant, score(["レストラン", "ご来店日時", "ディナー", "ランチ", "お席", "コース料理", "restaurant", "dinner", "lunch", "table for", "party of", "opentable"])),
            // 来店予約・入場予約・体験・施設の予約はチケットとして扱う
            (.ticket, score(["入場", "チケット", "公演", "開演", "体験", "ツアー", "アクティビティ", "開始時間",
                             "整理番号", "当選", "先着", "入場券", "eチケット", "パスポート", "入園", "利用人数", "ticket", "admission", "tour", "activity", "klook", "viator", "getyourguide"])),
            // 注文の受け取り（ケーキなど）は、どの種類にも当てはまらないので「その他」
            (.other, score(["ご注文", "受取り", "受け取り", "テイクアウト", "オーダー"]))
        ]
        guard let best = scores.max(by: { $0.1 < $1.1 }), best.1 > 0 else { return .other }
        return best.0
    }

    // MARK: - 予約番号

    private static let confirmationLabel = #"(?:予約番号|予約コード|予約確認番号|確認番号|確認コード|予約ID|予約No\.?|受付番号|予約依頼番号|依頼番号|予約申込番号|受付ID|整理番号|お預かり番号|お申込番号|申込番号|confirmation (?:number|code|no\.?)|booking (?:reference|number|id|no\.?)|reservation (?:number|code|no\.?)|itinerary number|booking code|record locator|pnr|예약\s?번호|예약\s?코드|확인\s?번호|訂位代號|訂位代号|訂位編號|預訂編號|预订编号|訂單編號|订单编号|訂單號碼|订单号|確認號碼|确认号码)"#

    static func confirmationNumber(in text: String) -> String? {
        // ラベルと同じ行、またはすぐ次の行に書かれていることが多い
        // 「【確認番号】」のように閉じ括弧が挟まる書き方もある
        let pattern = confirmationLabel + #"\s*[】\])）]?\s*[:：]?\s*\n?\s*([A-Za-z0-9][A-Za-z0-9-]{3,})"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let valueRange = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[valueRange])
    }

    // MARK: - 日時

    struct DateTimeEvent {
        let position: Int
        let components: DateComponents
        let guessedYear: Bool
        /// 受付・支払いの日時や、キャンセル・有効の期限。予約の日時としては使わない
        var isAdministrative = false
    }

    /// 日付の直前（同じ行、または日付だけの行ならその前の行）にこれがあれば、予約の日時ではない
    private static let administrativeWords = ["受付日", "予約受付", "お支払い日", "お支払日", "支払日", "支払期限",
                                              "お支払期限", "購入日", "申込日", "お申込日", "注文日", "送信日",
                                              "発行日", "発送日", "キャンセル", "期限"]

    /// 英語の文面での同じ手がかり。大文字・小文字を区別せずに見る
    private static let englishAdministrativeWords = ["booked on", "booking date", "booking made", "order date", "ordered on",
                                                     "issued", "payment", "paid on", "purchase", "cancel", "deadline"]

    private static let reservationLabelWords = ["チェックイン", "チェックアウト", "来店", "出発", "到着", "返却",
                                                "貸出", "乗車", "搭乗", "開催", "入園", "受取", "受け取り", "宿泊",
                                                "check-in", "check in", "check-out", "check out", "arrival", "arrive",
                                                "departure", "depart", "pick-up", "pickup", "pick up", "drop-off", "return"]

    private static func isAdministrative(_ range: NSRange, in ns: NSString) -> Bool {
        let lineRange = ns.lineRange(for: range)
        var prefix = ns.substring(with: NSRange(location: lineRange.location, length: range.location - lineRange.location))
        // 「予約受付日」の次の行に日付だけ、という書き方もあるので、そのときは前の行を見る
        if prefix.trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.whitespaces).union(.symbols)).isEmpty,
           lineRange.location > 0 {
            let previous = ns.lineRange(for: NSRange(location: lineRange.location - 1, length: 0))
            prefix = ns.substring(with: previous)
        }
        let lowerPrefix = prefix.lowercased()
        // 転送したメールの頭の「Date:」は送信日時。英語の予約では「Date: Fri, Oct 9」が
        // 予約の日付の見出しでもあるので、「From:」「Subject:」と並ぶときだけ送信日時とみなす
        if prefix.trimmingCharacters(in: .whitespaces).hasPrefix("Date:"),
           ns.range(of: "From:").location != NSNotFound || ns.range(of: "Subject:").location != NSNotFound {
            return true
        }
        if administrativeWords.contains(where: prefix.contains)
            || englishAdministrativeWords.contains(where: lowerPrefix.contains) { return true }
        // 直前が予約のラベルなら、後ろに「まで」があっても予約の日時。
        // 「チェックアウト 2026年10月8日 （11:00まで）」は期限ではなく、チェックアウトの時刻
        if reservationLabelWords.contains(where: lowerPrefix.contains) { return false }

        let end = range.location + range.length
        let suffix = ns.substring(with: NSRange(location: end, length: min(20, lineRange.location + lineRange.length - end)))
        // 「2026年9月28日 23:59まで」「2026年5月19日以降」は期限の話
        if suffix.contains("まで") || suffix.contains("以降") { return true }
        // 「［2026/03/13 22:50:55］」のように秒まである時刻は、送信や決済の記録
        if suffix.range(of: #"^[\s(（)）\p{Han}]*\d{1,2}:\d{2}:\d{2}"#, options: .regularExpression) != nil { return true }
        return false
    }

    /// 本文の中の「日付（＋近くの時刻）」を、出てくる順に拾う
    static func dateTimeEvents(in text: String, referenceDate: Date) -> [DateTimeEvent] {
        let ns = text as NSString
        let monthFirst = numericDatesAreMonthFirst(in: text, referenceDate: referenceDate)
        let patterns: [(String, (NSTextCheckingResult) -> (y: Int?, m: Int, d: Int)?)] = [
            // 2026年10月6日 / 2026/10/06 / 2026-10-06 / 2026.10.6
            (#"(20\d{2})\s*[年/\-.]\s*(\d{1,2})\s*[月/\-.]\s*(\d{1,2})\s*日?"#, { m in
                (Int(ns.substring(with: m.range(at: 1))), Int(ns.substring(with: m.range(at: 2)))!, Int(ns.substring(with: m.range(at: 3)))!)
            }),
            // 10/06/2026（アメリカ式）/ 06.10.2026（ヨーロッパ式）。どちらかは本文全体で決める
            (numericDatePattern, { m in
                let first = Int(ns.substring(with: m.range(at: 1)))!
                let second = Int(ns.substring(with: m.range(at: 2)))!
                let year = Int(ns.substring(with: m.range(at: 3)))
                return monthFirst ? (year, first, second) : (year, second, first)
            }),
            // 26/4/16（年が2桁）
            (#"(?<![\d/])(\d{2})/(\d{1,2})/(\d{1,2})(?![\d/])"#, { m in
                (2000 + Int(ns.substring(with: m.range(at: 1)))!, Int(ns.substring(with: m.range(at: 2)))!, Int(ns.substring(with: m.range(at: 3)))!)
            }),
            // 10月6日（年なし）
            (#"(?<![\d/])(\d{1,2})月\s*(\d{1,2})日"#, { m in
                (nil, Int(ns.substring(with: m.range(at: 1)))!, Int(ns.substring(with: m.range(at: 2)))!)
            }),
            // Oct 6, 2026 / October 6th 2026
            (monthName + #"\s+(\d{1,2})(?:st|nd|rd|th)?,?\s+(20\d{2})"#, { m in
                (Int(ns.substring(with: m.range(at: 3))), monthNumber(ns.substring(with: m.range(at: 1))), Int(ns.substring(with: m.range(at: 2)))!)
            }),
            // 6 Oct 2026 / 6th October, 2026
            (#"(\d{1,2})(?:st|nd|rd|th)?\s+"# + monthName + #",?\s+(20\d{2})"#, { m in
                (Int(ns.substring(with: m.range(at: 3))), monthNumber(ns.substring(with: m.range(at: 2))), Int(ns.substring(with: m.range(at: 1)))!)
            }),
            // Oct 6 / Mon, Oct 6（年なし）
            (monthName + #"\s+(\d{1,2})(?:st|nd|rd|th)?(?![\d:])"#, { m in
                (nil, monthNumber(ns.substring(with: m.range(at: 1))), Int(ns.substring(with: m.range(at: 2)))!)
            }),
            // 6 Oct / Sat 6th October（年なし）
            (#"(?<![\d:])(\d{1,2})(?:st|nd|rd|th)?\s+"# + monthName, { m in
                (nil, monthNumber(ns.substring(with: m.range(at: 2))), Int(ns.substring(with: m.range(at: 1)))!)
            })
        ]

        var found: [(range: NSRange, y: Int?, m: Int, d: Int)] = []
        for (pattern, extract) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
                // 先に拾った長い形（年つき）と重なるものは捨てる
                guard !found.contains(where: { NSIntersectionRange($0.range, match.range).length > 0 }),
                      let value = extract(match), (1...12).contains(value.m), (1...31).contains(value.d) else { continue }
                found.append((match.range, value.y, value.m, value.d))
            }
        }
        found.sort { $0.range.location < $1.range.location }

        let times = timeMatches(in: text)

        return found.map { date in
            var components = DateComponents()
            var guessed = false
            if let year = date.y {
                components.year = year
            } else {
                components.year = inferredYear(month: date.m, day: date.d, referenceDate: referenceDate)
                guessed = true
            }
            components.month = date.m
            components.day = date.d

            // 日付のすぐ後ろ（40文字以内）の時刻を、その日の時刻とみなす。
            // ただし空行や「■」「【」の見出しをまたがない。別の欄の時刻を付けてしまうため
            let dateEnd = date.range.location + date.range.length
            if let time = times.first(where: { $0.position >= dateEnd && $0.position - dateEnd <= 40 }),
               !{ () -> Bool in
                   let between = ns.substring(with: NSRange(location: dateEnd, length: time.position - dateEnd))
                   return between.contains("\n\n") || between.contains("■") || between.contains("【")
               }() {
                components.hour = time.hour
                components.minute = time.minute
            }
            return DateTimeEvent(position: date.range.location, components: components, guessedYear: guessed,
                                 isAdministrative: isAdministrative(date.range, in: ns))
        }
    }

    struct TimeMatch {
        let position: Int
        let hour: Int
        let minute: Int
    }

    static func timeMatches(in text: String) -> [TimeMatch] {
        let ns = text as NSString
        var result: [TimeMatch] = []
        // 「時半」は「時」より先に探す（同じ場所は先に拾ったほうを使う）。
        // 最後の形は「6pm」「7 PM」のように、分の無い12時間制
        let patterns = [#"(?<!\d)(\d{1,2}):(\d{2})(?!\d)"#, #"(\d{1,2})時(\d{1,2})分"#, #"(\d{1,2})時半"#,
                        #"(\d{1,2})時(?!\d|間)"#, #"(?<![\d:])(\d{1,2})\s?(?=[ap]\.?m\.?(?![a-z]))"#]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
                guard !result.contains(where: { abs($0.position - match.range.location) < 3 }) else { continue }
                var hour = Int(ns.substring(with: match.range(at: 1))) ?? -1
                let minute = match.numberOfRanges > 2 && match.range(at: 2).location != NSNotFound
                    ? Int(ns.substring(with: match.range(at: 2))) ?? 0
                    : (pattern.contains("時半") ? 30 : 0)

                // 「午後6時」「3:00 PM」は12時間制。直さないと、夕方6時が朝6時になる
                if let meridiem = meridiem(around: match.range, in: ns) {
                    guard (0...12).contains(hour) else { continue }
                    if meridiem == .pm, hour < 12 { hour += 12 }
                    if meridiem == .am, hour == 12 { hour = 0 }
                }
                guard (0...23).contains(hour), (0...59).contains(minute) else { continue }
                result.append(TimeMatch(position: match.range.location, hour: hour, minute: minute))
            }
        }
        return result.sorted { $0.position < $1.position }
    }

    private enum Meridiem { case am, pm }

    /// 時刻の前の「午前」「午後」、または後ろの「AM」「PM」「a.m.」
    private static func meridiem(around range: NSRange, in ns: NSString) -> Meridiem? {
        let beforeLength = min(3, range.location)
        let before = ns.substring(with: NSRange(location: range.location - beforeLength, length: beforeLength))
            .trimmingCharacters(in: .whitespaces)
        if before.hasSuffix("午後") { return .pm }
        if before.hasSuffix("午前") { return .am }

        let end = range.location + range.length
        let after = ns.substring(with: NSRange(location: end, length: min(8, ns.length - end)))
        guard let found = after.range(of: #"^\s?([ap])\.?m\.?(?![a-z])"#,
                                      options: [.regularExpression, .caseInsensitive]) else { return nil }
        return after[found].lowercased().contains("p") ? .pm : .am
    }

    /// 英語の月の名前。「Mark」「Decor」のような別の単語の頭は月としない
    private static let monthName = #"(?<![A-Za-z])(Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|June?|July?|Aug(?:ust)?|Sep(?:t(?:ember)?)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\.?(?![A-Za-z])"#

    private static let numericDatePattern = #"(?<![\d/.\-])(\d{1,2})[/.\-](\d{1,2})[/.\-](20\d{2})(?![\d/.\-])"#

    /// 「10/06/2026」が10月6日（アメリカ式）か6月10日（ヨーロッパ式）か。
    ///
    /// 13以上の数があればそれが日なので、そこで決まる。どの日付でも決まらないときは、
    /// 予約はこれからのことなので、今日に近い先の日付になるほうを選ぶ
    static func numericDatesAreMonthFirst(in text: String, referenceDate: Date) -> Bool {
        let ns = text as NSString
        guard let regex = try? NSRegularExpression(pattern: numericDatePattern) else { return true }
        let pairs = regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { m in
            (Int(ns.substring(with: m.range(at: 1)))!, Int(ns.substring(with: m.range(at: 2)))!, Int(ns.substring(with: m.range(at: 3)))!)
        }
        if pairs.contains(where: { $0.0 > 12 }) { return false }
        if pairs.contains(where: { $0.1 > 12 }) { return true }
        guard let (first, second, year) = pairs.first else { return true }

        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(byAdding: .day, value: -30, to: referenceDate) ?? referenceDate
        func distance(month: Int, day: Int) -> TimeInterval {
            guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else { return .infinity }
            return date < start ? .infinity : date.timeIntervalSince(start)
        }
        return distance(month: first, day: second) <= distance(month: second, day: first)
    }

    private static func monthNumber(_ name: String) -> Int {
        let months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
        return (months.firstIndex(of: String(name.prefix(3)).lowercased()) ?? 0) + 1
    }

    /// 年が書いていない日付の年。今日より30日以上前になるなら来年とみなす
    /// （予約確認メールは、これからの予約について送られてくるため）
    static func inferredYear(month: Int, day: Int, referenceDate: Date) -> Int {
        let calendar = Calendar(identifier: .gregorian)
        let year = calendar.component(.year, from: referenceDate)
        guard let candidate = calendar.date(from: DateComponents(year: year, month: month, day: day)),
              let threshold = calendar.date(byAdding: .day, value: -30, to: referenceDate) else { return year }
        return candidate < threshold ? year + 1 : year
    }

    // MARK: - 飛行機

    /// 国内線と、日本発着でよく使う航空会社のコード。どんな2文字でも拾うと、予約番号の一部などを誤って拾う
    private static let airlineCodes = ["NH", "JL", "MM", "GK", "BC", "6J", "7G", "HD", "NU", "IJ", "FW", "JH",
                                       "UA", "DL", "AA", "HA", "KE", "OZ", "LJ", "7C", "TW", "CI", "BR", "IT",
                                       "CX", "HX", "UO", "SQ", "TR", "TG", "VN", "PR", "5J", "QF", "AF", "LH",
                                       "BA", "AY", "KL", "EK", "QR", "AC", "ZG", "MU", "CA", "CZ",
                                       // 韓国・台湾・東南アジアへの旅行でよく使う会社（3.4）
                                       "BX", "ZE", "RS", "JX", "YP", "D7", "AK", "VJ", "3K", "Z2", "FD"]

    /// 「ANA123」「SKY111」のように、各社の呼び名で書かれることもある。
    /// 値は、カタカナで書かれたときに便名として使う書き方
    private static let airlineNames = ["ANA": "ANA", "JAL": "JAL", "SKY": "SKY", "ADO": "ADO", "SNJ": "SNJ", "SFJ": "SFJ",
                                       "Peach": "MM", "AIRDO": "ADO", "ジェットスター": "GK", "スカイマーク": "SKY",
                                       "エアドゥ": "ADO", "ソラシドエア": "SNJ", "スターフライヤー": "SFJ"]

    /// 便名。**メールに書かれたとおりの書き方で返す**（空白だけ詰める）。
    ///
    /// 公式の2文字コードに直すと、スカイマークの「SKY111」が「BC111」になり、
    /// 空港の案内表示や搭乗券の書き方と食い違って探せなくなる
    static func flightNumbers(in text: String) -> [(position: Int, number: String)] {
        let ns = text as NSString
        let codes = (airlineCodes + airlineNames.keys)
            .sorted { $0.count > $1.count }   // 「AIRDO」を「ADO」より先に
            .map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|")
        // 数字の直後に英数字が続くものは便名ではない（予約番号「JL7X9K2P」の頭を JL7 と読まないように）。
        // 写真から読んだ文字では、数字の 0 が英字の O に化けることがある（「SKY025」→「SKYO25」）。
        // 番号の中の O・o は 0 として読む（数字が1つも無いものは便名とみなさない）
        let pattern = #"(?<![A-Za-z0-9])("# + codes + #")\s?([0-9Oo]{1,4})(?![A-Za-z0-9])(?:\s?便)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        var result: [(Int, String)] = []
        var seen: Set<String> = []
        for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            let prefix = ns.substring(with: match.range(at: 1))
            let raw = ns.substring(with: match.range(at: 2))
            guard raw.contains(where: \.isNumber) else { continue }
            let digits = raw.replacingOccurrences(of: "O", with: "0").replacingOccurrences(of: "o", with: "0")
            // 英字はそのまま、カタカナの社名だけ便名の書き方にする
            let code = prefix.allSatisfy(\.isASCII) ? prefix : (airlineNames[prefix] ?? prefix)
            // 同じ便が何度も書かれているメールは多い。最初の1回だけ使う
            // （「ANA 027」と「ANA27」は同じ便）
            let key = "\(code)\(Int(digits) ?? 0)"
            guard seen.insert(key).inserted else { continue }
            result.append((match.range.location, "\(code)\(digits)"))
        }

        // 「ソラシドエア（SNA）021便」のように、社名のあとのかっこにコードを書き、番号と「便」が続く書き方
        let parenPattern = #"[（(]([A-Z0-9]{2,3})[）)]\s?(\d{1,4})\s?便"#
        if let parenRegex = try? NSRegularExpression(pattern: parenPattern) {
            for match in parenRegex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
                let code = ns.substring(with: match.range(at: 1))
                let digits = ns.substring(with: match.range(at: 2))
                let key = "\(code)\(Int(digits) ?? 0)"
                guard seen.insert(key).inserted else { continue }
                result.append((match.range.location, "\(code)\(digits)"))
            }
            result.sort { $0.0 < $1.0 }
        }
        return result
    }

    /// よく使う空港。
    ///
    /// 同じ場所に複数の書き方が当たったときは、**いちばん長く当たったものを使う**（`airportMentions`）。
    /// 「台北松山空港」は「台北」（桃園）や「松山」（愛媛）にも当たるが、「台北松山」が勝つ。
    /// 愛媛の「松山空港」は、台北の行に入れない（以前は「松山空港」を台北松山として読んでいた）
    private static let airports: [(pattern: String, name: String)] = [
        ("羽田|東京国際|HANEDA|HND", "羽田空港"), ("成田|NARITA|NRT", "成田空港"), ("伊丹|大阪国際|ITAMI|ITM", "伊丹空港"),
        ("関西国際|関空|関西|KANSAI|KIX", "関西空港"), ("神戸|UKB", "神戸空港"), ("中部|セントレア|NGO", "中部空港"),
        ("新千歳|CHITOSE|CTS", "新千歳空港"), ("福岡|FUKUOKA|FUK", "福岡空港"), ("那覇|OKA|(?<=[→⇒]\\s?)沖縄|沖縄(?=\\s?[→⇒])", "那覇空港"),
        ("鹿児島|KOJ", "鹿児島空港"), ("仙台|SDJ", "仙台空港"), ("広島|HIJ", "広島空港"),
        ("石垣|ISG", "石垣空港"), ("宮古|MMY", "宮古空港"), ("長崎|NGS", "長崎空港"), ("熊本|KMJ", "熊本空港"),
        ("小松|KMQ", "小松空港"), ("松山|MYJ", "松山空港"), ("高松|TAK", "高松空港"), ("函館|HKD", "函館空港"),
        ("ホノルル|ダニエル・K・イノウエ|HNL", "ホノルル空港"),
        // 韓国（ハングルの書き方も）
        ("仁川|인천|ICN", "仁川空港"), ("金浦|김포|GMP", "金浦空港"), ("釜山|金海|김해|부산|PUS", "釜山空港"),
        ("済州|濟州|제주|CJU", "済州空港"), ("大邱|대구|TAE", "大邱空港"), ("清州|청주|CJJ", "清州空港"),
        // 台湾（繁体字の書き方も）。「台北」だけなら桃園
        ("台北桃園|臺北桃園|台湾桃園|桃園|台北|臺北|TPE", "台北桃園空港"), ("台北松山|臺北松山|TSA", "台北松山空港"),
        ("高雄|KHH", "高雄空港"), ("台中|臺中|RMQ", "台中空港"),
        ("香港|HKG", "香港空港"), ("上海浦東|浦東|PVG", "上海浦東空港"), ("北京首都|PEK", "北京空港"),
        ("シンガポール|チャンギ|SIN", "シンガポール空港"), ("バンコク|スワンナプーム|BKK", "バンコク空港"),
        ("マニラ|MNL", "マニラ空港"), ("セブ島|セブ空港|マクタン|CEB", "セブ空港"), ("ダナン|DAD", "ダナン空港"),
        ("ハノイ|ノイバイ|HAN", "ハノイ空港"), ("ホーチミン|タンソンニャット|SGN", "ホーチミン空港"),
        ("パリ|シャルル|CDG", "パリ空港"), ("ロンドン|ヒースロー|LHR", "ロンドン空港"),
        ("ロサンゼルス|LAX", "ロサンゼルス空港"), ("サンフランシスコ|SFO", "サンフランシスコ空港"),
        ("ニューヨーク|JFK", "ニューヨーク空港"), ("グアム|GUM", "グアム空港")
    ]

    static func airportMentions(in text: String) -> [(position: Int, name: String)] {
        let ns = text as NSString
        var found: [(range: NSRange, name: String)] = []
        for airport in airports {
            let pattern = #"(?<![A-Za-z])(?:"# + airport.pattern + #")(?![A-Za-z])"#
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
                found.append((match.range, airport.name))
            }
        }
        // 重なって当たったものは、長いほうだけ残す（「台北松山」が「台北」「松山」に勝つ）
        var claimed: [NSRange] = []
        var result: [(Int, String)] = []
        for hit in found.sorted(by: { $0.range.length > $1.range.length }) {
            guard !claimed.contains(where: { NSIntersectionRange($0, hit.range).length > 0 }) else { continue }
            claimed.append(hit.range)
            result.append((hit.range.location, hit.name))
        }
        return result.sorted { $0.0 < $1.0 }
    }

    /// 便ごとに1件。
    ///
    /// 便の範囲は「便名のある行の頭から、次の便名のある行の頭まで」。
    /// 「往路 2026年10月6日 JL915 羽田 08:00 → 那覇 10:45」のように、日付が便名より前に
    /// 同じ行で書かれることもあるため、行の頭から見る。範囲に日付が無ければ、すぐ前の日付を使う
    /// （日付の行の次に便名の行が来る書き方）。範囲の中の時刻の1つ目を出発、2つ目を到着とみなす
    private static func flightDrafts(in text: String, events: [DateTimeEvent]) -> [ReservationDraft] {
        let ns = text as NSString
        let flights = flightNumbers(in: text)
        let airports = airportMentions(in: text)
        let allTimes = timeMatches(in: text)
        let lineStarts = flights.map { ns.lineRange(for: NSRange(location: $0.position, length: 0)).location }

        return flights.enumerated().map { index, flight in
            let from = lineStarts[index]
            let limit = index + 1 < flights.count ? lineStarts[index + 1] : Int.max
            let previousLimit = index > 0 ? lineStarts[index - 1] : -1

            let myEvents = events.filter { $0.position >= from && $0.position < limit }
            let dateEvent = myEvents.first
                ?? events.last { $0.position < from && $0.position >= previousLimit }
            let times = allTimes.filter { $0.position >= from && $0.position < limit }

            var draft = ReservationDraft(kind: .flight)
            draft.transportNumber = flight.number

            if var start = dateEvent?.components {
                // 日付の近くに時刻が無い書き方（日付の行と時刻の行が離れている）なら、範囲の時刻を使う
                if start.hour == nil, let first = times.first {
                    start.hour = first.hour
                    start.minute = first.minute
                }
                draft.start = start
                draft.guessedYear = dateEvent?.guessedYear ?? false

                if myEvents.count >= 2, myEvents[1].components.hour != nil {
                    draft.arrival = myEvents[1].components
                } else if times.count >= 2 {
                    // 到着の日付が省かれているときは、出発と同じ日の時刻とみなす
                    var arrival = start
                    arrival.hour = times[1].hour
                    arrival.minute = times[1].minute
                    draft.arrival = arrival
                }
            }

            let myAirports = uniqueNames(airports.filter { $0.position >= from && $0.position < limit })
            let places = myAirports.isEmpty ? uniqueNames(airports) : myAirports
            draft.departurePlace = places.first
            draft.arrivalPlace = places.dropFirst().first
            return draft
        }
    }

    // MARK: - 新幹線

    private static let trainNamePattern = #"(のぞみ|ひかり|こだま|はやぶさ|はやて|やまびこ|なすの|つばさ|こまち|かがやき|はくたか|あさま|とき|たにがわ|みずほ|さくら|つばめ|かもめ)\s?(\d{1,3})\s?号"#

    static func trainNames(in text: String) -> [String] {
        let ns = text as NSString
        guard let regex = try? NSRegularExpression(pattern: trainNamePattern) else { return [] }
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { ns.substring(with: $0.range) }
    }

    /// 「名古屋(21:39)→のぞみ89号→新大阪(22:27)」（スマートEX など）。
    /// 駅・時刻・列車がそろった強い形なので、先にこれで読む
    private static let trainSegmentPattern = #"([\p{Han}\p{Katakana}ー]{1,10})\s*[(（](\d{1,2}):(\d{2})[)）]\s*(?:→|->|⇒)\s*"# + trainNamePattern + #"\s*(?:→|->|⇒)\s*([\p{Han}\p{Katakana}ー]{1,10})\s*[(（](\d{1,2}):(\d{2})[)）]"#

    private static func segmentTrainDrafts(in text: String, events: [DateTimeEvent]) -> [ReservationDraft] {
        let ns = text as NSString
        guard let regex = try? NSRegularExpression(pattern: trainSegmentPattern) else { return [] }
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap { match in
            func group(_ index: Int) -> String { ns.substring(with: match.range(at: index)) }
            // 乗車日は、この行より前に出てくる日付のうち一番近いもの
            guard let dateEvent = events.last(where: { $0.position < match.range.location }) ?? events.first else { return nil }

            var draft = ReservationDraft(kind: .train)
            draft.transportNumber = "\(group(4))\(group(5))号"
            draft.departurePlace = group(1)
            draft.arrivalPlace = group(6)
            var start = dateEvent.components
            start.hour = Int(group(2))
            start.minute = Int(group(3))
            var arrival = dateEvent.components
            arrival.hour = Int(group(7))
            arrival.minute = Int(group(8))
            draft.start = start
            draft.arrival = arrival
            draft.guessedYear = dateEvent.guessedYear
            return draft
        }
    }

    private static func trainDrafts(in text: String, events: [DateTimeEvent]) -> [ReservationDraft] {
        let segments = segmentTrainDrafts(in: text, events: events)
        if !segments.isEmpty { return segments }

        let ns = text as NSString
        guard let regex = try? NSRegularExpression(pattern: trainNamePattern) else { return [] }
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        var seen = Set<String>()
        var drafts: [ReservationDraft] = []

        for (index, match) in matches.enumerated() {
            let name = "\(ns.substring(with: match.range(at: 1)))\(ns.substring(with: match.range(at: 2)))号"
            guard seen.insert(name).inserted else { continue }
            let limit = index + 1 < matches.count ? matches[index + 1].range.location : Int.max

            var draft = ReservationDraft(kind: .train)
            draft.transportNumber = name
            let before = events.filter { $0.position < match.range.location }.last
            let after = events.first { $0.position >= match.range.location && $0.position < limit }
            if var start = (after ?? before)?.components {
                let times = timeMatches(in: text).filter { $0.position >= match.range.location && $0.position < limit }
                if let first = times.first {
                    start.hour = first.hour
                    start.minute = first.minute
                }
                draft.start = start
                draft.guessedYear = (after ?? before)?.guessedYear ?? false
                if times.count >= 2 {
                    var arrival = start
                    arrival.hour = times[1].hour
                    arrival.minute = times[1].minute
                    draft.arrival = arrival
                }
            }
            // 「東京 → 新大阪」
            if let route = firstRoute(in: text, from: match.range.location) {
                draft.departurePlace = route.from
                draft.arrivalPlace = route.to
            }
            drafts.append(draft)
        }
        return drafts
    }

    private static func firstRoute(in text: String, from position: Int) -> (from: String, to: String)? {
        let ns = text as NSString
        let pattern = #"([\p{Han}\p{Katakana}ー]{1,8}駅?)\s*(?:→|->|⇒|～|〜|-)\s*([\p{Han}\p{Katakana}ー]{1,8}駅?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        guard let match = matches.first(where: { $0.range.location >= position }) ?? matches.first else { return nil }
        return (ns.substring(with: match.range(at: 1)), ns.substring(with: match.range(at: 2)))
    }

    // MARK: - 宿・レンタカー（始まりと終わり）

    private static func periodDraft(kind: Reservation.Kind,
                                    in text: String,
                                    events: [DateTimeEvent],
                                    startWords: [String],
                                    endWords: [String]) -> ReservationDraft {
        var draft = ReservationDraft(kind: kind)
        draft.title = propertyName(in: text, kind: kind) ?? ""

        var endEvent = event(after: endWords, in: text, events: events)
        var startEvent = event(after: startWords, in: text, events: events)
        if startEvent?.position == endEvent?.position { startEvent = nil }

        // チェックアウトしか書いていない宿（Booking.com など）は、泊数から逆算する
        if startEvent == nil, kind == .hotel,
           let end = endEvent?.components, let nights = nights(in: text),
           let start = Self.shift(end, days: -nights) {
            draft.start = start
            draft.guessedYear = endEvent?.guessedYear ?? false
            if let time = time(after: startWords, in: text) {
                draft.start?.hour = time.hour
                draft.start?.minute = time.minute
            }
            var endComponents = end
            if endComponents.hour == nil, let time = time(after: endWords, in: text) {
                endComponents.hour = time.hour
                endComponents.minute = time.minute
            }
            draft.end = endComponents
            return draft
        }
        if startEvent == nil {
            startEvent = events.first { $0.position != endEvent?.position }
        }

        if var start = startEvent?.components {
            // 「チェックイン 15:00」のように、日付と時刻が別の行にあることが多い
            if start.hour == nil, let time = time(after: startWords, in: text) {
                start.hour = time.hour
                start.minute = time.minute
            }
            draft.start = start
            draft.guessedYear = startEvent?.guessedYear ?? false
        }

        // 「2026年12月5日～2026年12月6日」のように、期間で書かれていれば後ろの日付が終わり
        if endEvent == nil, let start = startEvent,
           let next = events.first(where: { $0.position > start.position }) {
            let ns = text as NSString
            let between = ns.substring(with: NSRange(location: start.position, length: next.position - start.position))
            if between.count <= 30, between.contains(where: { "～〜~".contains($0) }) {
                endEvent = next
            }
        }

        if var end = endEvent?.components {
            if end.hour == nil, let time = time(after: endWords, in: text) {
                end.hour = time.hour
                end.minute = time.minute
            }
            draft.end = end
        } else if kind == .hotel, let start = draft.start, let nights = nights(in: text) {
            // 「2泊」とだけ書いてあるなら、チェックインから数える
            if var end = Self.shift(start, days: nights) {
                if let time = time(after: endWords, in: text) {
                    end.hour = time.hour
                    end.minute = time.minute
                }
                draft.end = end
            }
        }
        return draft
    }

    /// 言葉のすぐ後ろ（80文字以内）に出てくる日付
    private static func event(after words: [String], in text: String, events: [DateTimeEvent]) -> DateTimeEvent? {
        for word in words {
            let lower = text.lowercased()
            guard let range = lower.range(of: word.lowercased()) else { continue }
            let position = lower.distance(from: lower.startIndex, to: range.lowerBound)
            if let event = events.first(where: { $0.position >= position && $0.position - position <= 80 }) {
                return event
            }
        }
        return nil
    }

    /// 言葉のすぐ後ろ（30文字以内）に出てくる時刻
    private static func time(after words: [String], in text: String) -> TimeMatch? {
        let times = timeMatches(in: text)
        for word in words {
            let lower = text.lowercased()
            var searchStart = lower.startIndex
            while let range = lower.range(of: word.lowercased(), range: searchStart..<lower.endIndex) {
                let position = lower.distance(from: lower.startIndex, to: range.upperBound)
                if let time = times.first(where: { $0.position >= position && $0.position - position <= 30 }) {
                    return time
                }
                searchStart = range.upperBound
            }
        }
        return nil
    }

    /// 日付を何日かずらす（時刻は落とす）
    static func shift(_ components: DateComponents, days: Int) -> DateComponents? {
        let calendar = Calendar(identifier: .gregorian)
        guard let date = calendar.date(from: DateComponents(year: components.year, month: components.month, day: components.day)),
              let shifted = calendar.date(byAdding: .day, value: days, to: date) else { return nil }
        return calendar.dateComponents([.year, .month, .day], from: shifted)
    }

    /// レストラン・体験・チケットなど、日時が1つの予約。
    ///
    /// メールの冒頭の送信日時（「［2026/03/13 22:50:55］」）を取り違えないよう、
    /// 「ご来店日時」「予約日」などのラベルの後ろの日付を優先する
    private static func singleDateDraft(kind: Reservation.Kind, in text: String, events: [DateTimeEvent]) -> ReservationDraft {
        var draft = ReservationDraft(kind: kind)
        draft.title = propertyName(in: text, kind: kind) ?? ""

        let dateWords = ["ご来店日時", "来店日時", "予約日時", "ご利用日時", "利用日", "予約日", "受取り日", "受取日",
                         "受け取り日", "イベント開催日", "開催日", "公演日", "入園日", "来場日", "日時", "日程",
                         "reservation date", "date of visit", "visit date", "event date", "date & time", "date and time",
                         "when:", "date:"]
        // 「時間」だけでは探さない。「受付時間 10:00AM」のような営業時間まで拾うため
        let timeWords = ["入店目安時間", "入場時間", "入店時間", "開始時間", "開始時刻", "予約時間", "受取り時間",
                         "受取時間", "受け取り時間", "来店時間", "集合時間", "開演",
                         "start time", "reservation time", "arrival time", "entry time", "time slot", "meeting time", "time:"]
        let dateEvent = event(after: dateWords, in: text, events: events) ?? events.first
        if var start = dateEvent?.components {
            // 時刻のラベルがあれば、日付の近くの時刻より優先する
            // （「開催日 6月5日 [開店時間]11:00」より「入店目安時間 12:00」が自分の時刻）
            if let time = time(after: timeWords, in: text) {
                start.hour = time.hour
                start.minute = time.minute
            }
            draft.start = start
            draft.guessedYear = dateEvent?.guessedYear ?? false
        }
        return draft
    }

    private static func nights(in text: String) -> Int? {
        let ns = text as NSString
        // 「2泊」「2 nights」。「1 night」は単数
        guard let regex = try? NSRegularExpression(pattern: #"(\d{1,2})\s?(?:泊|nights?(?![a-z]))"#, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return Int(ns.substring(with: match.range(at: 1)))
    }

    /// 宿やレンタカー店の名前。ラベルの付いた行を優先し、無ければ名前らしい行を探す
    private static func propertyName(in text: String, kind: Reservation.Kind) -> String? {
        let labels: [String]
        switch kind {
        case .hotel:
            labels = ["宿泊施設名", "宿泊施設", "施設名", "ホテル名", "宿名", "宿泊先", "施設", "ホテル", "property name", "property", "hotel name"]
        case .rentalCar:
            labels = ["貸出店舗", "貸渡店舗", "出発店舗", "出発場所名", "店舗名", "営業所", "pick-up location", "pickup location", "pick up location"]
        case .parking:
            labels = ["駐車場名", "駐車場", "利用駐車場", "パーキング名", "施設名"]
        default:
            labels = ["レストラン名", "店舗名", "店舗", "店名", "施設名", "会場", "イベント名", "公演名", "restaurant name", "venue", "event name"]
        }
        let lines = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }

        for (index, line) in lines.enumerated() {
            // 行の頭（「【」「■」などの飾りは除く）がラベルで始まるものだけ見る
            let head = line.trimmingCharacters(in: CharacterSet(charactersIn: "【■●◆・[-−― "))
            // ラベルの直後が区切りのときだけラベルとみなす。
            // 「宿泊施設のポリシーや…」を「宿泊施設」のラベルと取り違えないように
            guard let label = labels.first(where: { label in
                      guard head.lowercased().hasPrefix(label.lowercased()) else { return false }
                      let rest = head.dropFirst(label.count)
                      return rest.isEmpty || rest.first.map { ":：】] \t".contains($0) } == true
                  }),
                  let range = head.range(of: label, options: .caseInsensitive) else { continue }
            var value = String(head[range.upperBound...])
            value = value.trimmingCharacters(in: CharacterSet(charactersIn: " :：】]"))
            if value.isEmpty, index + 1 < lines.count {
                value = lines[index + 1]
            }
            // 「Bella Dining Cafe(TEL:050-…)」のような電話番号の添え書きは外す
            if let paren = value.range(of: #"[(（]\s*(TEL|tel|電話)"#, options: .regularExpression) {
                value = String(value[..<paren.lowerBound]).trimmingCharacters(in: .whitespaces)
            }
            if !value.isEmpty { return String(value.prefix(40)) }
        }

        if kind == .hotel {
            // 「イン」は「ツインルーム」にも入っているので手がかりにしない。部屋やプランの行も除く
            let keywords = ["ホテル", "旅館", "リゾート", "ゲストハウス", "hotel", "resort", "hostel"]
            let excluded = ["予約", "楽天", "じゃらん", "ルーム", "部屋", "プラン", "㎡", "マイル", "キャンペーン"]
            // 「■ホテル」のような見出しの行は名前にしない
            let headings: [Character] = ["■", "【", "[", "●", "◆"]
            return lines.first { line in
                line.count <= 40 && keywords.contains { line.lowercased().contains($0) }
                    && !excluded.contains { line.contains($0) }
                    && !(line.first.map(headings.contains) ?? false)
            }
        }
        return nil
    }

    private static func uniqueNames(_ mentions: [(position: Int, name: String)]) -> [String] {
        var seen = Set<String>()
        return mentions.map(\.name).filter { seen.insert($0).inserted }
    }
}
