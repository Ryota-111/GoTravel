import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - 予約の読み取り（ルール＋端末の中の AI）

/// 予約確認メール・スクリーンショットの文字から、予約の下書きを作る入口。
///
/// 1. まず決まった形の読み取り（`ReservationEmailParser`）で読む
/// 2. 端末の中の AI（Apple の Foundation Models）が使えるときは、**ルールで読めなかった項目だけ**を AI で埋める。
///    ルールで読めた値は変えない（AI が書かれていない値を作ることがあるため）
/// 3. AI の答えは**本文と照らし合わせてから**使う（`ReservationAIReader.validated`）
///
/// AI が使えない端末（Apple Intelligence に対応していない・オフ・iOS 26 より前）では 1 だけで読む。
/// どちらも端末の中だけで動き、文字も画像もどこにも送らない
enum ReservationReader {

    static func read(_ text: String, kind: Reservation.Kind? = nil,
                     referenceDate: Date = Date()) async -> [ReservationDraft] {
        let drafts = ReservationEmailParser.parse(text, kind: kind, referenceDate: referenceDate)
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), ReservationAIReader.isAvailable {
            let resolvedKind = kind ?? drafts.first?.kind ?? .other
            if let suggestions = await ReservationAIReader.suggest(text: text, kind: resolvedKind,
                                                                   referenceDate: referenceDate) {
                return ReservationAIReader.merge(rules: drafts, ai: suggestions)
            }
        }
        #endif
        return drafts
    }
}

#if canImport(FoundationModels)

/// 端末の中の AI で、ルールが読めなかった項目を埋める候補を作る。
///
/// ## 作りで気をつけていること（実際に試して分かったこと）
/// - **種類は先に決め、種類ごとに別の形で答えさせる。** 全部の種類を1つの形で答えさせると、
///   宿に便名や出発地を作ったり、予約を2件に増やしたりした
/// - **`@Guide` の説明に例の値を書かない。** 「例 ANA993」と書くと、関係のない予約の番号にそれが入った
/// - **便の数と答えの長さに上限をつける。** 同じ便を繰り返して、一度に読める量を超えて失敗することがあった
/// - **AI の値は本文と照らし合わせる。** 書かれていない時刻（07:00 発を 15:00 に）や年を作ることがある。
///   時刻は本文に同じ時:分があるとき、日付は本文に同じ月日があるときだけ使い、年は本文の日付から取る
@available(iOS 26.0, *)
enum ReservationAIReader {

    /// この端末で AI が使えるか
    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    // MARK: AI に返してもらう形（種類ごと）

    /// 飛行機・新幹線・電車
    @Generable
    struct Rides {
        @Guide(description: "予約番号・確認番号。文面に書かれている文字のまま。書かれていなければ空")
        var confirmationNumber: String?
        @Guide(description: "文面に書かれている便や列車。往復や乗り継ぎは1つずつ。同じものを繰り返さない", .maximumCount(4))
        var rides: [Ride]
    }

    @Generable
    struct Ride {
        @Guide(description: "便名または列車名。文面に書かれている文字のまま")
        var number: String?
        @Guide(description: "出発する空港または駅")
        var from: String?
        @Guide(description: "到着する空港または駅")
        var to: String?
        @Guide(description: "出発する日。yyyy-MM-dd の形。予約した日や支払いの期限ではない")
        var date: String?
        @Guide(description: "出発時刻。HH:mm（24時間）")
        var departureTime: String?
        @Guide(description: "到着時刻。HH:mm（24時間）")
        var arrivalTime: String?
    }

    /// 宿・レンタカー・駐車場（始まりと終わりがあるもの）
    @Generable
    struct Stay {
        @Guide(description: "予約番号・確認番号。文面に書かれている文字のまま。書かれていなければ空")
        var confirmationNumber: String?
        @Guide(description: "始まりの日（チェックイン・受け取り・入庫）。yyyy-MM-dd。予約した日ではない")
        var startDate: String?
        @Guide(description: "始まりの時刻。HH:mm（24時間）")
        var startTime: String?
        @Guide(description: "終わりの日（チェックアウト・返却・出庫）。yyyy-MM-dd")
        var endDate: String?
        @Guide(description: "終わりの時刻。HH:mm（24時間）")
        var endTime: String?
    }

    /// 飲食店・チケット・そのほか（1つの日時のもの）
    @Generable
    struct Visit {
        @Guide(description: "予約番号・確認番号。文面に書かれている文字のまま。書かれていなければ空")
        var confirmationNumber: String?
        @Guide(description: "予約した日（来店・開催・利用する日）。yyyy-MM-dd。メールや手紙を書いた日ではない")
        var date: String?
        @Guide(description: "予約した時刻。HH:mm（24時間）")
        var time: String?
    }

    /// 一度に渡す文字の上限。モデルが一度に読める量に、指示と答えの分の余裕を残す
    static let maxCharacters = 2_500

    // MARK: 読んでもらう

    /// 一度に読ませる回数の上限。端末の AI は1回に数秒かかるので、長い文面でも2回まで
    static let maxChunks = 2

    /// AI に渡す文。3.7 までは先頭の 2,500 文字だけを渡していて、長いメールの後ろにある
    /// 帰りの便やチェックアウトを読ませられなかった（3.8）。
    ///
    /// 予約の手がかりのある行（日付・時刻・便名・予約番号などのラベル）と、その前後1行を、本文の順のまま拾う。
    /// 拾った分が上限を超えるときは、行の切れ目で `maxChunks` 個までに分ける。
    /// 短い文面は、そのまま1つで渡す
    static func chunks(of text: String, limit: Int = maxCharacters) -> [String] {
        guard text.count > limit else { return [text] }
        let lines = text.components(separatedBy: "\n")
        let signal = #"\d{1,2}[:：]\d{2}|\d{1,4}\s*[年/.-]\s*\d{1,2}|\d{1,2}月\s*\d{1,2}日|予約|確認|番号|便|号車|出発|到着|発|着|チェックイン|チェックアウト|搭乗|乗車|乗船|入庫|出庫|貸出|返却|来店|宿泊|空港|駅|booking|reservation|confirmation|flight|depart|arriv|check|pick|drop|\b[A-Z0-9]{2}\s?\d{2,4}\b"#
        var keep = Set<Int>()
        for (index, line) in lines.enumerated()
        where line.range(of: signal, options: [.regularExpression, .caseInsensitive]) != nil {
            keep.formUnion([index - 1, index, index + 1].filter { lines.indices.contains($0) })
        }
        let picked = lines.indices.filter(keep.contains).map { lines[$0] }
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        var result: [String] = []
        var current = ""
        for line in picked {
            if current.count + line.count + 1 > limit, !current.isEmpty {
                result.append(current)
                guard result.count < maxChunks else { return result }
                current = ""
            }
            current += (current.isEmpty ? "" : "\n") + String(line.prefix(limit))
        }
        if !current.isEmpty, result.count < maxChunks { result.append(current) }
        return result.isEmpty ? [String(text.prefix(limit))] : result
    }

    /// AI に読んでもらい、本文と照らし合わせた下書きにする。使えない・失敗したときは nil。
    /// 長い文面は分けて読ませ、便は同じ便を重ねずにまとめる（3.8）
    static func suggest(text: String, kind: Reservation.Kind, referenceDate: Date) async -> [ReservationDraft]? {
        var collected: [ReservationDraft] = []
        var answered = false
        for chunk in chunks(of: text) {
            guard let drafts = await suggest(chunk: chunk, fullText: text, kind: kind, referenceDate: referenceDate) else { continue }
            answered = true
            for draft in drafts {
                if let index = collected.firstIndex(where: { sameReservation($0, draft) }) {
                    collected[index] = filled(collected[index], with: draft)
                } else {
                    collected.append(draft)
                }
            }
        }
        // 宿・レストランなど1件の予約は、分けて読んでも1件にまとめる
        if !kind.usesRoute, collected.count > 1 {
            collected = [collected.dropFirst().reduce(collected[0]) { filled($0, with: $1) }]
        }
        return answered ? collected : nil
    }

    /// 分けて読ませた答えどうしが同じ予約か（便名が同じ、または食い違いなく日付が同じ）
    private static func sameReservation(_ lhs: ReservationDraft, _ rhs: ReservationDraft) -> Bool {
        guard lhs.kind.usesRoute else { return true }
        guard let score = matchScore(lhs, rhs) else { return false }
        if let a = lhs.transportNumber, let b = rhs.transportNumber { return transportKey(a) == transportKey(b) }
        return score >= 2
    }

    private static func suggest(chunk prompt: String, fullText text: String, kind: Reservation.Kind,
                                referenceDate: Date) async -> [ReservationDraft]? {
        let instructions = """
        あなたは旅行の予約確認メールや予約画面の文字から、予約の内容を取り出す係です。
        文面に書かれていることだけを答えてください。書かれていない値は空にし、推測で作らないでください。
        """
        let options = GenerationOptions(sampling: .greedy, maximumResponseTokens: 400)
        let evidence = Evidence(text: text, referenceDate: referenceDate)
        do {
            let session = LanguageModelSession(instructions: instructions)
            switch kind {
            case .flight, .train, .bus, .ferry:
                let answer = try await session.respond(to: prompt, generating: Rides.self, options: options).content
                return rides(answer, kind: kind, evidence: evidence)
            case .hotel, .rentalCar, .parking:
                let answer = try await session.respond(to: prompt, generating: Stay.self, options: options).content
                return stay(answer, kind: kind, evidence: evidence).map { [$0] }
            case .restaurant, .ticket, .other:
                let answer = try await session.respond(to: prompt, generating: Visit.self, options: options).content
                return visit(answer, kind: kind, evidence: evidence).map { [$0] }
            }
        } catch {
            #if DEBUG
            print("[ReservationAI] 読めませんでした: \(error)")
            #endif
            return nil
        }
    }

    // MARK: 照らし合わせて下書きにする

    static func rides(_ answer: Rides, kind: Reservation.Kind, evidence: Evidence) -> [ReservationDraft] {
        var seen: Set<String> = []
        var drafts: [ReservationDraft] = []
        for ride in answer.rides {
            var draft = ReservationDraft(kind: kind)
            // 飛行機は、航空会社の便名の形として読めるものだけ（「NO1ZAOLU」のような運賃の記号を便にしていた）
            let looksLikeFlight = kind != .flight
                || ride.number.map { !ReservationEmailParser.flightNumbers(in: $0).isEmpty } == true
            if looksLikeFlight, let number = evidence.code(ride.number) {
                // 同じ便の繰り返しは捨てる
                guard seen.insert(transportKey(number)).inserted else { continue }
                // 飛行機はルールと同じ書き方にする（AI は「SKY 111便」のように返すことがある）
                draft.transportNumber = kind == .flight
                    ? (ReservationEmailParser.flightNumbers(in: number).first?.number ?? number) : number
            }
            // 便名が本文と合わなくても、ほかの項目（日付・時刻・発着地）は照らし合わせて残す（3.8）。
            // 3.7 までは便ごと捨てていて、読めていた日付まで失っていた
            if kind == .flight {
                draft.departurePlace = evidence.airport(ride.from)
                draft.arrivalPlace = evidence.airport(ride.to)
            } else {
                // AI は「のぞみ21号 東京」のように列車名ごと返すことがある（3.8）
                draft.departurePlace = evidence.written(ride.from).map(ReservationEmailParser.placeName)
                draft.arrivalPlace = evidence.written(ride.to).map(ReservationEmailParser.placeName)
            }
            if let day = evidence.day(ride.date) {
                draft.start = evidence.at(day, time: ride.departureTime)
                draft.arrival = evidence.time(ride.arrivalTime).map { _ in evidence.at(day, time: ride.arrivalTime) }
            }
            // 便名の無い便は、同じ日時・区間のものを2度入れない
            if draft.transportNumber == nil,
               drafts.contains(where: { $0.transportNumber == nil && $0.start == draft.start
                                        && $0.departurePlace == draft.departurePlace && $0.arrivalPlace == draft.arrivalPlace }) {
                continue
            }
            if draft.hasAnyValue { drafts.append(draft) }
        }
        if let number = evidence.confirmation(answer.confirmationNumber,
                                              notIn: drafts.compactMap(\.transportNumber), kind: kind) {
            for index in drafts.indices { drafts[index].confirmationNumber = number }
            if drafts.isEmpty {
                var draft = ReservationDraft(kind: kind)
                draft.confirmationNumber = number
                drafts.append(draft)
            }
        }
        return drafts
    }

    static func stay(_ answer: Stay, kind: Reservation.Kind, evidence: Evidence) -> ReservationDraft? {
        var draft = ReservationDraft(kind: kind)
        draft.confirmationNumber = evidence.confirmation(answer.confirmationNumber, notIn: [], kind: kind)
        if let day = evidence.day(answer.startDate) { draft.start = evidence.at(day, time: answer.startTime) }
        if let day = evidence.day(answer.endDate) { draft.end = evidence.at(day, time: answer.endTime) }
        return draft.hasAnyValue ? draft : nil
    }

    static func visit(_ answer: Visit, kind: Reservation.Kind, evidence: Evidence) -> ReservationDraft? {
        var draft = ReservationDraft(kind: kind)
        draft.confirmationNumber = evidence.confirmation(answer.confirmationNumber, notIn: [], kind: kind)
        if let day = evidence.day(answer.date) { draft.start = evidence.at(day, time: answer.time) }
        return draft.hasAnyValue ? draft : nil
    }

    // MARK: ルールの結果と合わせる

    /// ルールで読めなかった項目だけを、照らし合わせた AI の答えで埋める（3.8 で作り直した）。
    ///
    /// 3.7 までは配列の順番（1件目どうし、2件目どうし）で合わせていたので、AI とルールで便の数や順番が違うと、
    /// 別の便の項目を混ぜていた。**中身で突き合わせる**：
    /// - 便名・日付・発着地・予約番号のうち、両方にあって食い違うものが1つでもあれば、同じ予約とみなさない
    /// - 一致するものが多い組から合わせる。手がかりが無くても、予約が1件ずつなら同じ予約とみなす
    /// - 合わなかった AI の便は、本文で確かめられた便名があり、ルールのどの便とも重ならないときだけ別の便として足す。
    ///   便名の無い AI の便は足さない（支払期限の日を出発日にした便を足していた）。
    ///   宿・レストランなど1件の予約も足さない（ルールが読めたほうを信じる）
    /// - ルールが何も読めなかったときだけは、AI の答えをそのまま使う（便名が無くても日付や発着地を残す）
    static func merge(rules: [ReservationDraft], ai: [ReservationDraft]) -> [ReservationDraft] {
        guard !ai.isEmpty else { return rules }
        if rules.allSatisfy({ !$0.hasAnyValue }) { return ai }

        var result = rules
        var matchedRules: Set<Int> = []
        var unmatched: [ReservationDraft] = []

        // 一致の多い組から順に合わせる
        var pairs: [(rule: Int, ai: Int, score: Int)] = []
        for (aiIndex, suggestion) in ai.enumerated() {
            for (ruleIndex, rule) in rules.enumerated() {
                if let score = matchScore(rule, suggestion) { pairs.append((ruleIndex, aiIndex, score)) }
            }
        }
        var matchedAI: Set<Int> = []
        let singlePair = rules.count == 1 && ai.count == 1
        for pair in pairs.sorted(by: { $0.score > $1.score }) where pair.score > 0 || singlePair {
            guard !matchedRules.contains(pair.rule), !matchedAI.contains(pair.ai) else { continue }
            result[pair.rule] = filled(result[pair.rule], with: ai[pair.ai])
            matchedRules.insert(pair.rule)
            matchedAI.insert(pair.ai)
        }
        for (index, suggestion) in ai.enumerated() where !matchedAI.contains(index) {
            unmatched.append(suggestion)
        }

        for suggestion in unmatched where suggestion.kind.usesRoute {
            guard suggestion.transportNumber != nil,
                  !result.contains(where: { overlaps($0, suggestion) }) else { continue }
            result.append(suggestion)
        }
        return result
    }

    /// 同じ予約らしさ。食い違う項目があれば nil（同じ予約ではない）
    static func matchScore(_ rule: ReservationDraft, _ ai: ReservationDraft) -> Int? {
        guard rule.kind.usesRoute == ai.kind.usesRoute else { return nil }
        var score = 0
        func compare(_ lhs: String?, _ rhs: String?, weight: Int) -> Bool {
            guard let lhs, let rhs else { return true }
            guard transportKey(lhs) == transportKey(rhs) else { return false }
            score += weight
            return true
        }
        guard compare(rule.transportNumber, ai.transportNumber, weight: 4),
              compare(rule.departurePlace, ai.departurePlace, weight: 1),
              compare(rule.arrivalPlace, ai.arrivalPlace, weight: 1) else { return nil }
        // 往復で同じ予約番号のことがあるので、予約番号は一致しても便の手がかりにはしない（食い違えば別の予約）
        if let lhs = rule.confirmationNumber, let rhs = ai.confirmationNumber,
           Evidence.compact(lhs) != Evidence.compact(rhs) { return nil }
        if let lhs = dayKey(rule.start), let rhs = dayKey(ai.start) {
            guard lhs == rhs else { return nil }
            score += 2
        }
        return score
    }

    /// AI の便が、ルールの便と同じ便を指しているか（食い違いが無く、便名か日付が同じ）
    private static func overlaps(_ rule: ReservationDraft, _ ai: ReservationDraft) -> Bool {
        guard let score = matchScore(rule, ai) else { return false }
        if let lhs = rule.transportNumber, let rhs = ai.transportNumber {
            return transportKey(lhs) == transportKey(rhs)
        }
        return score >= 2
    }

    /// 便名・列車名・地名を比べる形。空白を抜いて大文字にし、終わりの「便」「号」「空港」「駅」を外す
    /// （「SKY 111便」と「SKY111」、「神戸」と「神戸空港」を同じとみなす）
    static func transportKey(_ value: String) -> String {
        var key = Evidence.compact(value)
        for suffix in ["便", "号", "空港", "駅", "AIRPORT"] where key.hasSuffix(suffix) && key.count > suffix.count {
            key.removeLast(suffix.count)
        }
        return key
    }

    private static func dayKey(_ components: DateComponents?) -> [Int]? {
        guard let components, let month = components.month, let day = components.day else { return nil }
        // 年は比べない（年が書いていない文面では、片方が補った年になる）
        return [month, day]
    }

    /// 名前（title）は AI では埋めない。それらしいが違う名前（「オーシャンビュー」など）を入れていた
    private static func filled(_ draft: ReservationDraft, with ai: ReservationDraft) -> ReservationDraft {
        var draft = draft
        if draft.confirmationNumber == nil { draft.confirmationNumber = ai.confirmationNumber }
        if draft.transportNumber == nil { draft.transportNumber = ai.transportNumber }
        if draft.departurePlace == nil { draft.departurePlace = ai.departurePlace }
        if draft.arrivalPlace == nil { draft.arrivalPlace = ai.arrivalPlace }
        if draft.start == nil { draft.start = ai.start }
        if draft.arrival == nil { draft.arrival = ai.arrival }
        if draft.end == nil { draft.end = ai.end }
        return draft
    }

    // MARK: 本文との照らし合わせ

    /// AI の値が本文に書かれているかを確かめるための、本文から拾った手がかり
    struct Evidence {
        let compactText: String
        /// 本文（ラベルの位置を確かめるため）
        let text: String
        /// 本文にある日付（予約の日時。受付・支払い・期限の日付は除く）
        let days: [DateComponents]
        /// 本文にある時:分
        let times: Set<Int>

        init(text: String, referenceDate: Date) {
            let prepared = ReservationEmailParser.tableToLabelValues(ReservationEmailParser.normalized(text))
            self.text = prepared
            compactText = Self.compact(prepared)
            days = ReservationEmailParser.dateTimeEvents(in: prepared, referenceDate: referenceDate)
                .filter { !$0.isAdministrative }
                .map { DateComponents(year: $0.components.year, month: $0.components.month, day: $0.components.day) }
            times = Set(ReservationEmailParser.timeMatches(in: prepared).map { $0.hour * 60 + $0.minute })
        }

        /// 本文にある日付のうち、AI と同じ月日のもの。**年は本文の日付から取る**（AI は年を作ることがある）
        func day(_ value: String?) -> DateComponents? {
            guard let value, let match = value.firstMatch(of: /(\d{4})-(\d{1,2})-(\d{1,2})/),
                  let month = Int(match.2), let day = Int(match.3) else { return nil }
            return days.first { $0.month == month && $0.day == day }
        }

        /// 本文にある時:分のときだけ
        func time(_ value: String?) -> (hour: Int, minute: Int)? {
            guard let value, let match = value.firstMatch(of: /(\d{1,2}):(\d{2})/),
                  let hour = Int(match.1), let minute = Int(match.2),
                  times.contains(hour * 60 + minute) else { return nil }
            return (hour, minute)
        }

        func at(_ day: DateComponents, time value: String?) -> DateComponents {
            var components = day
            if let time = time(value) {
                components.hour = time.hour
                components.minute = time.minute
            }
            return components
        }

        /// 便名・列車名：本文に書かれているもの（写真で O と 0 が入れ替わったものも）
        func code(_ value: String?) -> String? {
            guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), value.count >= 3 else { return nil }
            let key = Self.compact(value)
            let found = compactText.contains(key)
                || compactText.contains(key.replacingOccurrences(of: "O", with: "0"))
                || compactText.replacingOccurrences(of: "O", with: "0").contains(key.replacingOccurrences(of: "O", with: "0"))
            return found ? value : nil
        }

        /// 予約番号：英数字とハイフンだけで数字を含み、本文に書かれていて、便名と同じでないもの
        func confirmation(_ value: String?, notIn numbers: [String], kind: Reservation.Kind? = nil) -> String? {
            guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
                  value.wholeMatch(of: /[A-Za-z0-9-]{3,20}/) != nil,
                  value.contains(where: \.isNumber),
                  compactText.contains(Self.compact(value)),
                  !numbers.map(Self.compact).contains(Self.compact(value)),
                  // 電話番号・航空券の番号など、形やラベルから別の番号と分かるものは使わない（3.8。
                  // ANA の e チケットで、13桁の航空券番号を予約番号にしていた）
                  !ReservationEmailParser.isNotConfirmation(value, kind: kind),
                  !ReservationEmailParser.isLabeledAsOtherNumber(value, in: text) else { return nil }
            return value
        }

        /// 空港は、空港の表で正式な名前に直せるものだけ（「JOSAKA (ITAMI)」をそのまま入れていた）
        func airport(_ value: String?) -> String? {
            guard let value, !value.isEmpty else { return nil }
            return ReservationEmailParser.airportMentions(in: value).first?.name
        }

        /// 駅などは、本文に書かれているときだけ
        func written(_ value: String?) -> String? {
            guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty,
                  compactText.contains(Self.compact(value)) else { return nil }
            return value
        }

        /// 空白を抜き、英字を大文字にした形（「EEF03D」と「EEF 03D」を同じとみなす）
        static func compact(_ text: String) -> String {
            String(text.unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) }).uppercased()
        }
    }
}

#endif

extension ReservationDraft {
    /// 何か1つでも読めたか
    var hasAnyValue: Bool {
        !title.isEmpty || confirmationNumber != nil || transportNumber != nil || departurePlace != nil
            || arrivalPlace != nil || start != nil || arrival != nil || end != nil || cost != nil
    }
}
