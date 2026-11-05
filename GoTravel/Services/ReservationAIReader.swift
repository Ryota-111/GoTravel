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

    /// AI に読んでもらい、本文と照らし合わせた下書きにする。使えない・失敗したときは nil
    static func suggest(text: String, kind: Reservation.Kind, referenceDate: Date) async -> [ReservationDraft]? {
        let prompt = String(text.prefix(maxCharacters))
        let instructions = """
        あなたは旅行の予約確認メールや予約画面の文字から、予約の内容を取り出す係です。
        文面に書かれていることだけを答えてください。書かれていない値は空にし、推測で作らないでください。
        """
        let options = GenerationOptions(sampling: .greedy, maximumResponseTokens: 400)
        let evidence = Evidence(text: text, referenceDate: referenceDate)
        do {
            let session = LanguageModelSession(instructions: instructions)
            switch kind {
            case .flight, .train:
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
            if looksLikeFlight, let number = evidence.code(ride.number), seen.insert(Evidence.compact(number)).inserted {
                draft.transportNumber = number
            } else if ride.number != nil {
                continue   // 本文に無い便名・同じ便の繰り返しは捨てる
            }
            if kind == .flight {
                draft.departurePlace = evidence.airport(ride.from)
                draft.arrivalPlace = evidence.airport(ride.to)
            } else {
                draft.departurePlace = evidence.written(ride.from)
                draft.arrivalPlace = evidence.written(ride.to)
            }
            if let day = evidence.day(ride.date) {
                draft.start = evidence.at(day, time: ride.departureTime)
                draft.arrival = evidence.time(ride.arrivalTime).map { _ in evidence.at(day, time: ride.arrivalTime) }
            }
            if draft.hasAnyValue { drafts.append(draft) }
        }
        if let number = evidence.confirmation(answer.confirmationNumber,
                                              notIn: drafts.compactMap(\.transportNumber)) {
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
        draft.confirmationNumber = evidence.confirmation(answer.confirmationNumber, notIn: [])
        if let day = evidence.day(answer.startDate) { draft.start = evidence.at(day, time: answer.startTime) }
        if let day = evidence.day(answer.endDate) { draft.end = evidence.at(day, time: answer.endTime) }
        return draft.hasAnyValue ? draft : nil
    }

    static func visit(_ answer: Visit, kind: Reservation.Kind, evidence: Evidence) -> ReservationDraft? {
        var draft = ReservationDraft(kind: kind)
        draft.confirmationNumber = evidence.confirmation(answer.confirmationNumber, notIn: [])
        if let day = evidence.day(answer.date) { draft.start = evidence.at(day, time: answer.time) }
        return draft.hasAnyValue ? draft : nil
    }

    // MARK: ルールの結果と合わせる

    /// ルールで読めなかった項目だけを、照らし合わせた AI の答えで埋める。
    /// ルールが見つけなかった便・列車（往復の帰りの便など）は、まだ無い便名のものだけ足す
    static func merge(rules: [ReservationDraft], ai: [ReservationDraft]) -> [ReservationDraft] {
        guard !ai.isEmpty else { return rules }
        if rules.allSatisfy({ !$0.hasAnyValue }) { return ai }

        var result = rules
        for (index, suggestion) in ai.enumerated() {
            if index < result.count {
                result[index] = filled(result[index], with: suggestion)
            } else if [.flight, .train].contains(suggestion.kind),
                      let number = suggestion.transportNumber,
                      !result.contains(where: { $0.transportNumber == number }) {
                result.append(suggestion)
            }
        }
        return result
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
        /// 本文にある日付（予約の日時。受付・支払い・期限の日付は除く）
        let days: [DateComponents]
        /// 本文にある時:分
        let times: Set<Int>

        init(text: String, referenceDate: Date) {
            let prepared = ReservationEmailParser.tableToLabelValues(ReservationEmailParser.normalized(text))
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
        func confirmation(_ value: String?, notIn numbers: [String]) -> String? {
            guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
                  value.wholeMatch(of: /[A-Za-z0-9-]{3,20}/) != nil,
                  value.contains(where: \.isNumber),
                  compactText.contains(Self.compact(value)),
                  !numbers.map(Self.compact).contains(Self.compact(value)) else { return nil }
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
