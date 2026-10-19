import Foundation
import EventKit
import CoreLocation
import Combine

// MARK: - カレンダーの予定を読む（3.0）

/// iPhone のカレンダーの予定。Travory のカレンダータブに並べるだけで、Travory には保存しない
struct ExternalCalendarEvent: Identifiable, Equatable {
    /// 繰り返しの予定は同じ ID の回が並ぶので、始まりの時刻も足す
    let id: String
    /// カレンダーの予定の ID（押したときに、iPhone のカレンダーの詳細を開くのに使う）
    var eventIdentifier: String? = nil
    /// どのカレンダーの予定か（点をカレンダーごとに1つずつ出すのに使う）
    var calendarId: String = ""
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let location: String?
    /// 「仕事（Google）」
    let calendarName: String
    let color: CGColor?

    /// その日（端末の暦）にかかっているか。複数日の予定はかかっている日すべてに出す
    func occurs(on day: Date, calendar: Calendar = .current) -> Bool {
        let dayStart = calendar.startOfDay(for: day)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return false }
        // 終日の予定の終わりは「次の日の 0:00」ちょうどのことがあるので、より前で比べる
        return start < dayEnd && end > dayStart || (start >= dayStart && start < dayEnd)
    }
}

// MARK: - 入れた予定の覚え書き

/// Travory の項目と、カレンダーに入れた予定の対応。**端末の中だけ**に持つ。
/// カレンダーの予定の ID は端末ごとに違うので、同期しない
struct CalendarExportState: Codable, Equatable {
    struct Link: Codable, Equatable {
        var options = CalendarExportOptions()
        /// Travory の目印（"trip" / "item:<id>" など）→ カレンダーの予定の ID
        var events: [String: String] = [:]
        /// カレンダーの側で消された予定。消したくて消したと考え、もう入れない
        var removedKeys: Set<String> = []
    }

    /// 書き出す先のカレンダー
    var calendarIdentifier: String?
    /// "travel:<id>" / "plan:<id>" → 対応
    var links: [String: Link] = [:]
}

enum CalendarExportStore {
    private static var fileURL: URL {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Calendar", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("links.json")
    }

    static func load(from url: URL? = nil) -> CalendarExportState {
        guard let data = try? Data(contentsOf: url ?? fileURL),
              let state = try? JSONDecoder().decode(CalendarExportState.self, from: data) else { return .init() }
        return state
    }

    static func save(_ state: CalendarExportState, to url: URL? = nil) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: url ?? fileURL, options: .atomic)
    }
}

// MARK: - 何をするか（純粋関数。テストで確かめる）

struct CalendarSyncPlan: Equatable {
    var creates: [CalendarEventDraft] = []
    /// 入れてある予定を直す（予定の ID と中身）
    var updates: [(id: String, draft: CalendarEventDraft)] = []
    /// Travory から消えた項目の予定を消す（目印と予定の ID）
    var deletes: [(key: String, id: String)] = []
    /// カレンダーの側で消されていた目印。もう入れない
    var forgotten: [String] = []

    static func == (lhs: CalendarSyncPlan, rhs: CalendarSyncPlan) -> Bool {
        lhs.creates == rhs.creates
            && lhs.updates.map(\.id) == rhs.updates.map(\.id) && lhs.updates.map(\.draft) == rhs.updates.map(\.draft)
            && lhs.deletes.map(\.key) == rhs.deletes.map(\.key) && lhs.deletes.map(\.id) == rhs.deletes.map(\.id)
            && lhs.forgotten == rhs.forgotten
    }

    /// - Parameter eventExists: カレンダーにその予定がまだあるか
    static func make(drafts: [CalendarEventDraft], link: CalendarExportState.Link,
                     eventExists: (String) -> Bool) -> CalendarSyncPlan {
        var plan = CalendarSyncPlan()
        let keys = Set(drafts.map(\.key))
        for draft in drafts {
            if let id = link.events[draft.key] {
                if eventExists(id) {
                    plan.updates.append((id, draft))
                } else {
                    plan.forgotten.append(draft.key)
                }
            } else if !link.removedKeys.contains(draft.key) {
                plan.creates.append(draft)
            }
        }
        for (key, id) in link.events.sorted(by: { $0.key < $1.key }) where !keys.contains(key) {
            plan.deletes.append((key, id))
        }
        return plan
    }
}

// MARK: - カレンダーに書く

/// 旅行計画・予定を、iPhone のカレンダーに入れる（3.0、`docs/設計_3.0.md` 2章）。
///
/// - Travory → カレンダーの片道だけ。カレンダーで直したものは Travory に戻さない
/// - 入れた予定を覚えておき、旅行計画を直したらカレンダーも直す（古いまま残るのが一番困るため）
/// - ゴミ箱に入れたらカレンダーからも消す。**一覧から見えなくなっただけでは消さない**
///   （iCloud が外れて一覧が空になったときに、カレンダーまで消してしまわないため）
@MainActor
final class CalendarExportService: ObservableObject {
    static let shared = CalendarExportService()

    static let calendarTitle = "Travory"

    private let store = EKEventStore()
    @Published private(set) var state: CalendarExportState
    /// カレンダーへのアクセスの許可。画面の出し分けに使うので、変わったら知らせる
    @Published private(set) var authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    /// iPhone のカレンダーの予定を、Travory のカレンダータブに並べるか（はじめはオフ）
    @Published var showsExternalEvents: Bool {
        didSet { UserDefaults.standard.set(showsExternalEvents, forKey: Self.showsExternalKey) }
    }
    /// 並べないカレンダー。新しく足したカレンダーは出るよう、出さないほうを覚える
    @Published private(set) var hiddenCalendarIds: Set<String> {
        didSet { UserDefaults.standard.set(Array(hiddenCalendarIds), forKey: Self.hiddenCalendarsKey) }
    }
    /// カレンダーの中身が変わった回数。カレンダータブが読み直す合図にする
    @Published private(set) var eventsRevision = 0

    private static let showsExternalKey = "showsExternalCalendarEvents"
    private static let hiddenCalendarsKey = "hiddenExternalCalendarIds"
    private var pendingTravelPlans: [TravelPlan]?
    private var pendingPlans: [Plan]?
    private var syncWork: DispatchWorkItem?

    private init() {
        state = CalendarExportStore.load()
        showsExternalEvents = UserDefaults.standard.bool(forKey: Self.showsExternalKey)
        hiddenCalendarIds = Set(UserDefaults.standard.stringArray(forKey: Self.hiddenCalendarsKey) ?? [])
        // カレンダーアプリで予定を足した・直したら、カレンダータブも読み直す
        NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.eventsRevision += 1 }
        }
    }

    // MARK: 読む（カレンダータブに並べる）

    /// 並べられるカレンダー（読めるもの全部。Travory から入れる専用の「Travory」カレンダーは除く）
    func readableCalendars() -> [EKCalendar] {
        store.calendars(for: .event)
            .filter { !isTravoryCalendar($0) }
            .sorted { ($0.source.title, $0.title) < ($1.source.title, $1.title) }
    }

    func isShown(_ calendar: EKCalendar) -> Bool {
        !hiddenCalendarIds.contains(calendar.calendarIdentifier)
    }

    func setShown(_ shown: Bool, calendar: EKCalendar) {
        if shown {
            hiddenCalendarIds.remove(calendar.calendarIdentifier)
        } else {
            hiddenCalendarIds.insert(calendar.calendarIdentifier)
        }
    }

    // MARK: アカウントごと（カレンダー画面の出どころのボタン）

    /// iPhone のカレンダーのアカウント（iCloud・Google など）と、その中のカレンダー
    struct ExternalSource: Identifiable, Equatable {
        let id: String
        let name: String
        let calendarIds: [String]
        let color: CGColor?

        static func == (lhs: ExternalSource, rhs: ExternalSource) -> Bool {
            lhs.id == rhs.id && lhs.name == rhs.name && lhs.calendarIds == rhs.calendarIds
        }
    }

    /// 並べられるカレンダーを、アカウントごとにまとめる
    func externalSources() -> [ExternalSource] {
        let grouped = Dictionary(grouping: readableCalendars()) { $0.source.sourceIdentifier }
        return grouped.compactMap { id, calendars -> ExternalSource? in
            guard let source = calendars.first?.source else { return nil }
            return ExternalSource(id: id, name: Self.displayName(of: source),
                                  calendarIds: calendars.map(\.calendarIdentifier),
                                  color: calendars.first?.cgColor)
        }
        .sorted { (Self.order(of: $0.name), $0.name) < (Self.order(of: $1.name), $1.name) }
    }

    /// アカウントの名前を、見て分かる呼び名にする（Google はメールアドレスが名前になっているため）
    nonisolated static func displayName(of source: EKSource) -> String {
        displayName(title: source.title, type: source.sourceType)
    }

    nonisolated static func displayName(title: String, type: EKSourceType) -> String {
        let lower = title.lowercased()
        switch type {
        case .subscribed: return "購読"
        case .birthdays: return "誕生日"
        case .local: return "iPhone"
        case .exchange: return "Outlook"
        default:
            if lower.contains("gmail") || lower.contains("google") { return "Google" }
            if lower.contains("icloud") { return "iCloud" }
            if lower.contains("outlook") || lower.contains("hotmail") || lower.contains("live.") { return "Outlook" }
            if lower.contains("yahoo") { return "Yahoo!" }
            return title
        }
    }

    private nonisolated static func order(of name: String) -> Int {
        ["iCloud", "Google", "Outlook", "Yahoo!", "iPhone"].firstIndex(of: name) ?? 9
    }

    /// そのアカウントの予定が出ているか（中のカレンダーが1つでも出ていれば出ている）
    func isShown(_ source: ExternalSource) -> Bool {
        showsExternalEvents && source.calendarIds.contains { !hiddenCalendarIds.contains($0) }
    }

    /// そのアカウントのカレンダーを、まとめて出す・出さない
    func setShown(_ shown: Bool, source: ExternalSource) {
        if shown {
            showsExternalEvents = true
            hiddenCalendarIds.subtract(source.calendarIds)
        } else {
            hiddenCalendarIds.formUnion(source.calendarIds)
        }
    }

    /// その期間の、iPhone のカレンダーの予定。
    /// Travory から入れた予定は、Travory の予定として出ているので除く（2重にしない）
    func externalEvents(from start: Date, to end: Date) -> [ExternalCalendarEvent] {
        guard showsExternalEvents, hasAccess else { return [] }
        let calendars = readableCalendars().filter(isShown)
        guard !calendars.isEmpty else { return [] }
        let exported = Set(state.links.values.flatMap { $0.events.values })
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
        let events = store.events(matching: predicate)
            .filter { event in
                !exported.contains(event.eventIdentifier ?? "")
                    && !(event.notes?.contains(CalendarEventBuilder.footer) ?? false)
            }
            .map { event in
                ExternalCalendarEvent(
                    id: "\(event.eventIdentifier ?? UUID().uuidString)@\(event.startDate.timeIntervalSince1970)",
                    eventIdentifier: event.eventIdentifier,
                    calendarId: event.calendar.calendarIdentifier,
                    title: event.title ?? "（題名なし）",
                    start: event.startDate,
                    end: event.endDate,
                    isAllDay: event.isAllDay,
                    location: event.location,
                    calendarName: "\(event.calendar.title)（\(event.calendar.source.title)）",
                    color: event.calendar.cgColor
                )
            }
        return Self.removingDuplicates(events)
    }

    /// 同じ日の同じ予定が、別のカレンダーにも入っているときは1つにする
    /// （祝日を Google と iPhone の両方で購読していると、同じ祝日が2つ並ぶため）
    nonisolated static func removingDuplicates(_ events: [ExternalCalendarEvent]) -> [ExternalCalendarEvent] {
        var seen = Set<String>()
        return events.filter { event in
            let key = "\(event.title)|\(event.isAllDay)|\(Int(event.start.timeIntervalSince1970))|\(Int(event.end.timeIntervalSince1970))"
            return seen.insert(key).inserted
        }
    }

    /// 押したときに詳細を開くための、カレンダーの予定
    func event(identifier: String) -> EKEvent? {
        store.event(withIdentifier: identifier)
    }

    /// 詳細の画面で使う（iOS のカレンダーの画面は、同じ store を渡す必要がある）
    var eventStore: EKEventStore { store }

    /// Travory から入れるために作った「Travory」カレンダーか
    private func isTravoryCalendar(_ calendar: EKCalendar) -> Bool {
        calendar.title == Self.calendarTitle
    }

    // MARK: 許可

    var hasAccess: Bool {
        authorizationStatus == .fullAccess
    }

    /// 許可をもらう。断られていたら false（設定アプリから変えてもらう）
    func requestAccess() async -> Bool {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        if hasAccess { return true }
        guard authorizationStatus == .notDetermined else { return false }
        let granted = (try? await store.requestFullAccessToEvents()) ?? false
        if granted { store.refreshSourcesIfNecessary() }
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        return granted
    }

    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted || authorizationStatus == .writeOnly
    }

    /// 設定アプリで許可を変えて戻ってきたときなどに呼ぶ
    func refreshAuthorization() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    // MARK: 書き出す先

    /// 書き込めるカレンダー（Google などのアカウントのものも含む）
    func writableCalendars() -> [EKCalendar] {
        store.calendars(for: .event)
            .filter(\.allowsContentModifications)
            .sorted { ($0.source.title, $0.title) < ($1.source.title, $1.title) }
    }

    /// いま書き出す先にしているカレンダー。まだ無ければ nil
    var selectedCalendar: EKCalendar? {
        state.calendarIdentifier.flatMap { store.calendar(withIdentifier: $0) }
    }

    func selectCalendar(_ calendar: EKCalendar) {
        state.calendarIdentifier = calendar.calendarIdentifier
        persist()
    }

    /// 書き出す先。選んでいなければ「Travory」カレンダーを作る（iCloud があれば iCloud に）
    private func targetCalendar() throws -> EKCalendar {
        if let selected = selectedCalendar, selected.allowsContentModifications { return selected }
        if let existing = store.calendars(for: .event).first(where: {
            $0.title == Self.calendarTitle && $0.allowsContentModifications
        }) {
            selectCalendar(existing)
            return existing
        }
        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = Self.calendarTitle
        calendar.cgColor = CGColor(red: 0.22, green: 0.55, blue: 0.85, alpha: 1)
        let sources = store.sources
        calendar.source = sources.first { $0.sourceType == .calDAV && $0.title.lowercased().contains("icloud") }
            ?? store.defaultCalendarForNewEvents?.source
            ?? sources.first { $0.sourceType == .local }
        try store.saveCalendar(calendar, commit: true)
        selectCalendar(calendar)
        return calendar
    }

    // MARK: 入れる・外す

    static func key(travelPlanId: String) -> String { "travel:\(travelPlanId)" }
    static func key(planId: String) -> String { "plan:\(planId)" }

    func isLinked(_ key: String) -> Bool { state.links[key] != nil }

    func options(for key: String) -> CalendarExportOptions {
        state.links[key]?.options ?? CalendarExportOptions()
    }

    /// 旅行計画をカレンダーに入れる（入れてあれば、選び直した内容で直す）
    func export(_ plan: TravelPlan, options: CalendarExportOptions) throws {
        guard let id = plan.id else { return }
        let key = Self.key(travelPlanId: id)
        var link = state.links[key] ?? .init()
        link.options = options
        state.links[key] = link
        try sync(key: key, drafts: CalendarEventBuilder.drafts(for: plan, options: options))
    }

    func export(_ plan: Plan) throws {
        let key = Self.key(planId: plan.id)
        if state.links[key] == nil { state.links[key] = .init() }
        try sync(key: key, drafts: CalendarEventBuilder.drafts(for: plan))
    }

    /// カレンダーから外す（入れた予定を消す）
    func unlink(_ key: String) {
        guard let link = state.links[key] else { return }
        if hasAccess {
            for id in link.events.values {
                if let event = store.event(withIdentifier: id) {
                    try? store.remove(event, span: .thisEvent, commit: false)
                }
            }
            try? store.commit()
        }
        state.links[key] = nil
        persist()
    }

    /// 入れてある旅行計画・予定を、いまの中身に合わせて直す。
    /// 同期で一覧が立て続けに変わるので、少し待ってまとめて行う
    func scheduleSync(travelPlans: [TravelPlan]? = nil, plans: [Plan]? = nil) {
        guard !state.links.isEmpty else { return }
        if let travelPlans { pendingTravelPlans = travelPlans }
        if let plans { pendingPlans = plans }
        syncWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in self?.syncPending() }
        }
        syncWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    private func syncPending() {
        guard hasAccess else { return }
        for plan in pendingTravelPlans ?? [] {
            guard let id = plan.id, let link = state.links[Self.key(travelPlanId: id)] else { continue }
            try? sync(key: Self.key(travelPlanId: id), drafts: CalendarEventBuilder.drafts(for: plan, options: link.options))
        }
        for plan in pendingPlans ?? [] where state.links[Self.key(planId: plan.id)] != nil {
            try? sync(key: Self.key(planId: plan.id), drafts: CalendarEventBuilder.drafts(for: plan))
        }
        pendingTravelPlans = nil
        pendingPlans = nil
    }

    private func sync(key: String, drafts: [CalendarEventDraft]) throws {
        guard hasAccess else { return }
        guard var link = state.links[key] else { return }
        let calendar = try targetCalendar()
        let plan = CalendarSyncPlan.make(drafts: drafts, link: link) { store.event(withIdentifier: $0) != nil }

        for draft in plan.creates {
            let event = EKEvent(eventStore: store)
            event.calendar = calendar
            apply(draft, to: event)
            try store.save(event, span: .thisEvent, commit: false)
            link.events[draft.key] = event.eventIdentifier
        }
        for (id, draft) in plan.updates {
            guard let event = store.event(withIdentifier: id) else { continue }
            apply(draft, to: event)
            // 書き出す先を変えたら、入れてある予定も移す
            if event.calendar.calendarIdentifier != calendar.calendarIdentifier { event.calendar = calendar }
            if event.hasChanges {
                try store.save(event, span: .thisEvent, commit: false)
                link.events[draft.key] = event.eventIdentifier
            }
        }
        for (deleteKey, id) in plan.deletes {
            if let event = store.event(withIdentifier: id) {
                try store.remove(event, span: .thisEvent, commit: false)
            }
            link.events[deleteKey] = nil
        }
        for forgottenKey in plan.forgotten {
            link.events[forgottenKey] = nil
            link.removedKeys.insert(forgottenKey)
        }
        try store.commit()
        state.links[key] = link
        persist()
    }

    /// 変わったところだけ書き換える（同じ値を入れ直すと、毎回「変更あり」になるため）
    private func apply(_ draft: CalendarEventDraft, to event: EKEvent) {
        if event.title != draft.title { event.title = draft.title }
        if event.isAllDay != draft.isAllDay { event.isAllDay = draft.isAllDay }
        if event.startDate != draft.start { event.startDate = draft.start }
        if event.endDate != draft.end { event.endDate = draft.end }
        let zone = draft.isAllDay ? nil : draft.timeZone
        if event.timeZone?.identifier != zone?.identifier { event.timeZone = zone }
        if event.notes != draft.notes { event.notes = draft.notes }
        if event.url != draft.url { event.url = draft.url }
        if event.location != draft.location {
            if let location = draft.location {
                let structured = EKStructuredLocation(title: location)
                if let latitude = draft.latitude, let longitude = draft.longitude {
                    structured.geoLocation = CLLocation(latitude: latitude, longitude: longitude)
                }
                event.structuredLocation = structured
            } else {
                event.structuredLocation = nil
                event.location = nil
            }
        }
    }

    private func persist() {
        CalendarExportStore.save(state)
    }
}
