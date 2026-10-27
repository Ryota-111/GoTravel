import SwiftUI
import EventKit

// MARK: - 1件をカレンダーに入れる

/// 旅行計画・予定をカレンダーに入れる画面（3.0）。
///
/// 許可を求める前に、なぜ読む許可まで要るのかを書いておく
/// （書き込みだけの許可では、入れた予定をあとから直せないため）
struct CalendarExportSheet: View {
    enum Target {
        case travel(TravelPlan)
        case plan(Plan)
    }

    let target: Target
    let tint: Color
    /// 終わったときに出す一言
    var onFinish: (String) -> Void = { _ in }

    @ObservedObject private var service = CalendarExportService.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var options = CalendarExportOptions()
    @State private var calendarId: String?
    @State private var errorMessage: String?
    @State private var icsURL: URL?

    private var linkKey: String {
        switch target {
        case .travel(let plan): return CalendarExportService.key(travelPlanId: plan.id ?? "")
        case .plan(let plan): return CalendarExportService.key(planId: plan.id)
        }
    }

    private var isLinked: Bool { service.isLinked(linkKey) }

    private var drafts: [CalendarEventDraft] {
        switch target {
        case .travel(let plan): return CalendarEventBuilder.drafts(for: plan, options: options)
        case .plan(let plan): return CalendarEventBuilder.drafts(for: plan)
        }
    }

    private var title: String {
        switch target {
        case .travel(let plan): return plan.title
        case .plan(let plan): return plan.title
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("この予定を iPhone のカレンダーにも追加します。Travory で直すと、追加した予定も直ります。\nGoogle カレンダーを使っている場合は、追加先に Google のカレンダーを選ぶと、Google カレンダーにも出ます。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                if case .travel = target {
                    Section("入れるもの") {
                        Toggle("旅行の期間（終日）", isOn: $options.includesTrip)
                        Toggle("日程の予定", isOn: $options.includesSchedule)
                        Toggle("予約（日程に入れていないもの）", isOn: $options.includesReservations)
                    }
                    .tint(tint)
                }

                if service.hasAccess {
                    calendarSection
                }

                Section {
                    if service.isDenied {
                        Text("カレンダーへのアクセスが許可されていません。設定アプリの「Travory」→「カレンダー」で「フルアクセス」を選んでください。")
                            .font(.footnote)
                        Button("設定アプリを開く") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                    } else {
                        Button {
                            Task { await export() }
                        } label: {
                            Label(isLinked ? "この内容で追加し直す" : "カレンダーに追加（\(drafts.count)件）",
                                  systemImage: "calendar.badge.plus")
                                .fontWeight(.semibold)
                        }
                        .disabled(drafts.isEmpty)
                        if !service.hasAccess {
                            Text("入れた予定をあとで直すために、カレンダーを読む許可（フルアクセス）をお願いします。カレンダーの中身を外に送ることはありません。")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    if isLinked {
                        Button("カレンダーから外す", role: .destructive) {
                            service.unlink(linkKey)
                            onFinish("カレンダーから外しました")
                            dismiss()
                        }
                    }
                }

                Section {
                    if let icsURL {
                        ShareLink(item: icsURL) {
                            Label("ファイル（.ics）で送る", systemImage: "square.and.arrow.up")
                        }
                    }
                } footer: {
                    Text("許可しなくても、ファイルで送って Google カレンダーなどに取り込めます。こちらは一度きりで、あとで直しても反映されません。")
                }
            }
            .tint(tint)
            .navigationTitle("カレンダーに追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .alert("カレンダーに追加できませんでした", isPresented: errorBinding) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .onAppear {
                service.refreshAuthorization()
                if case .travel = target { options = service.options(for: linkKey) }
                calendarId = service.selectedCalendar?.calendarIdentifier
                refreshICS()
            }
            .onChange(of: options) { _, _ in refreshICS() }
        }
    }

    private var calendarSection: some View {
        Section {
            Picker("追加先", selection: $calendarId) {
                if service.selectedCalendar == nil {
                    Text("新しく「\(CalendarExportService.calendarTitle)」を作る").tag(String?.none)
                }
                ForEach(service.writableCalendars(), id: \.calendarIdentifier) { calendar in
                    Text("\(calendar.title)（\(calendar.source.title)）").tag(Optional(calendar.calendarIdentifier))
                }
            }
            .onChange(of: calendarId) { _, newValue in
                guard let newValue,
                      let calendar = service.writableCalendars().first(where: { $0.calendarIdentifier == newValue }) else { return }
                service.selectCalendar(calendar)
            }
        } footer: {
            Text("追加先を変えると、Travory から追加したほかの予定も、次に直したときにそのカレンダーへ移ります。")
        }
    }

    private func export() async {
        // 断られたら、画面が設定アプリへの案内に切り替わる
        guard await service.requestAccess() else { return }
        let wasLinked = isLinked
        do {
            switch target {
            case .travel(let plan): try service.export(plan, options: options)
            case .plan(let plan): try service.export(plan)
            }
            onFinish(wasLinked ? "追加した予定を直しました" : "カレンダーに追加しました")
            dismiss()
        } catch {
            errorMessage = "カレンダーに書き込めませんでした。追加先のカレンダーを変えて、もう一度お試しください。"
        }
    }

    private func refreshICS() {
        let prefix: String
        switch target {
        case .travel(let plan): prefix = "travel-\(plan.id ?? "")"
        case .plan(let plan): prefix = "plan-\(plan.id)"
        }
        icsURL = CalendarICS.writeFile(drafts, uidPrefix: prefix, fileName: title)
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }
}

// MARK: - まとめて（プロフィール）

/// すべての旅行計画・予定をカレンダーに入れる・外す画面（プロフィールから）
struct CalendarExportSettingsView: View {
    @EnvironmentObject private var travelPlanViewModel: TravelPlanViewModel
    @EnvironmentObject private var plansViewModel: PlansViewModel
    @ObservedObject private var service = CalendarExportService.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.openURL) private var openURL
    @State private var calendarId: String?
    @State private var message: String?
    @State private var showsRemoveAll = false

    private var linkedCount: Int { service.state.links.count }

    var body: some View {
        Form {
            // カレンダー → Travory（見るだけ）
            Section {
                Toggle("祝日・仕事などの予定を表示", isOn: showsExternalBinding)
                if service.showsExternalEvents && service.hasAccess {
                    ForEach(service.readableCalendars(), id: \.calendarIdentifier) { calendar in
                        Toggle(isOn: Binding(
                            get: { service.isShown(calendar) },
                            set: { service.setShown($0, calendar: calendar) }
                        )) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color(cgColor: calendar.cgColor))
                                    .frame(width: 10, height: 10)
                                Text("\(calendar.title)（\(calendar.source.title)）")
                            }
                        }
                    }
                }
            } header: {
                Text("iPhone の予定を Travory で見る")
            } footer: {
                Text("iPhone のカレンダー（祝日・仕事・Google など）の予定を、Travory のカレンダーに並べて表示します。見るだけで、Travory には保存しません。")
            }

            Section {
                Text("Travory の旅行計画や予定を、iPhone のカレンダーにも追加します。Travory で直すと、追加した予定も直ります。1件ずつ追加するときは、旅行計画の「書き出し」や予定の画面から追加できます。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } header: {
                Text("Travory の予定を iPhone のカレンダーに追加")
            }

            if service.hasAccess {
                Section("追加先") {
                    Picker("カレンダー", selection: $calendarId) {
                        if service.selectedCalendar == nil {
                            Text("新しく「\(CalendarExportService.calendarTitle)」を作る").tag(String?.none)
                        }
                        ForEach(service.writableCalendars(), id: \.calendarIdentifier) { calendar in
                            Text("\(calendar.title)（\(calendar.source.title)）").tag(Optional(calendar.calendarIdentifier))
                        }
                    }
                    .onChange(of: calendarId) { _, newValue in
                        guard let newValue,
                              let calendar = service.writableCalendars().first(where: { $0.calendarIdentifier == newValue }) else { return }
                        service.selectCalendar(calendar)
                    }
                }
            }

            Section {
                if service.isDenied {
                    Text("カレンダーへのアクセスが許可されていません。設定アプリの「Travory」→「カレンダー」で「フルアクセス」を選んでください。")
                        .font(.footnote)
                    Button("設定アプリを開く") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                } else {
                    Button {
                        Task { await exportAll() }
                    } label: {
                        Label("すべての旅行計画・予定を入れる", systemImage: "calendar.badge.plus")
                    }
                }
                if linkedCount > 0 {
                    Button("すべてカレンダーから外す", role: .destructive) {
                        showsRemoveAll = true
                    }
                }
            } footer: {
                Text(linkedCount > 0 ? "いま追加しているもの：\(linkedCount)件" : "")
            }
        }
        .tint(themeManager.currentTheme.actionFill)
        .navigationTitle("iPhone のカレンダー")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            service.refreshAuthorization()
            calendarId = service.selectedCalendar?.calendarIdentifier
        }
        .alert(message ?? "", isPresented: messageBinding) {
            Button("OK", role: .cancel) { message = nil }
        }
        .confirmationDialog("Travory から入れた予定を、すべてカレンダーから消しますか？",
                            isPresented: $showsRemoveAll, titleVisibility: .visible) {
            Button("すべて外す", role: .destructive) {
                for key in Array(service.state.links.keys) { service.unlink(key) }
                message = "カレンダーから外しました"
            }
        }
    }

    private func exportAll() async {
        guard await service.requestAccess() else { return }
        var failed = 0
        for plan in travelPlanViewModel.travelPlans {
            let key = CalendarExportService.key(travelPlanId: plan.id ?? "")
            do { try service.export(plan, options: service.options(for: key)) } catch { failed += 1 }
        }
        for plan in plansViewModel.plans {
            do { try service.export(plan) } catch { failed += 1 }
        }
        calendarId = service.selectedCalendar?.calendarIdentifier
        message = failed == 0 ? "カレンダーに追加しました" : "\(failed)件、追加できませんでした"
    }

    /// 表示をオンにするときは、まず許可をもらう。断られたら戻す
    private var showsExternalBinding: Binding<Bool> {
        Binding(
            get: { service.showsExternalEvents },
            set: { newValue in
                guard newValue else {
                    service.showsExternalEvents = false
                    return
                }
                Task {
                    if await service.requestAccess() {
                        service.showsExternalEvents = true
                    } else {
                        message = "カレンダーへのアクセスが許可されていません。設定アプリの「Travory」→「カレンダー」で「フルアクセス」を選んでください。"
                    }
                }
            }
        )
    }

    private var messageBinding: Binding<Bool> {
        Binding(get: { message != nil }, set: { if !$0 { message = nil } })
    }
}
