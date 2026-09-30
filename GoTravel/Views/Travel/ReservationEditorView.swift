import SwiftUI

/// 予約の追加・編集
struct ReservationEditorView: View {
    let planId: String
    @State var reservation: Reservation

    @EnvironmentObject var viewModel: TravelPlanViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss

    /// 日時が決まっていない予約もあるので、入力するかどうかを選べるようにする
    @State private var hasDate = false
    @State private var date = Date()
    @State private var hasArrivalDate = false
    @State private var arrivalDate = Date()
    /// 日時をどこの時計で入れるか。飛行機は出発と到着で違う
    @State private var dateZone = ScheduleClock.legacyTimeZone
    /// 期間の終わり（チェックアウト・返却など）。時間帯は始まりと同じ（場所は1か所）
    @State private var hasEndDate = false
    @State private var endDate = Date()
    @State private var arrivalZone = ScheduleClock.legacyTimeZone
    /// 目的地の時間帯。日本と時差があるときだけ入る
    @State private var destinationTimeZone: TimeZone?

    @State private var showSchedulePicker = false
    /// 保存と同時に行程へも入れるか。
    ///
    /// **既定はオフ。** 予約を控えただけのつもりの人の行程が、保存のたびに
    /// 勝手に増えるのは驚きが大きい。とくに前から入っている予約を
    /// 開いて閉じただけで増えるのは事故に近い。
    /// 行程に出したいかどうかは予約ごとに違うので、その都度選んでもらう
    @State private var addsToItinerary = false

    // MARK: メールからの取り込み（Travory Pro）

    @ObservedObject private var proStore = ProStore.shared
    @State private var showsEmailImport = false
    @State private var showsProSheet = false
    /// メールから取り込んだときだけ入る。確かめてほしいこと（年を補った・時刻が無かった など）
    @State private var importNotes: [String]?
    /// 1通に複数の予約があったときの、まだ開いていない分。保存すると次を開く
    @State private var pendingImports: [ImportedReservation] = []
    /// 種類を自分で選んだか。選んでいれば、メールもその種類として読む。
    /// 開いた直後の「宿泊」は既定なだけなので、選んだことにしない
    @State private var hasChosenKind = false
    /// 費用の入力欄。数字以外を打たれても消さずに持っておく
    @State private var costText = ""

    private var plan: TravelPlan? {
        viewModel.travelPlans.first(where: { $0.id == planId })
    }

    /// 追加のときだけ取り込みを出す。
    /// 編集中に出すと、入力済みの内容を上書きすることになって危ない
    private var isNewReservation: Bool {
        guard let plan else { return true }
        return !plan.reservations.contains { $0.id == reservation.id }
    }

    private var hasScheduleItems: Bool {
        plan?.daySchedules.contains { !$0.scheduleItems.isEmpty } ?? false
    }

    private var cardFill: Color {
        colorScheme == .dark
            ? themeManager.currentTheme.secondaryBackgroundDark
            : themeManager.currentTheme.secondaryBackgroundLight
    }

    private var textColor: Color { ThemePreset.readableText(on: cardFill) }
    private var accent: Color { themeManager.currentTheme.actionFill }

    /// 白黒テーマは背景とカードの明るさがほぼ同じなので、必ず縁を引く
    private var cardStroke: Color { textColor.opacity(0.12) }

    private var canSave: Bool {
        if reservation.kind.usesRoute {
            // 名前の欄が無いので、便名か区間のどちらかが入っていればよい
            return !composedRouteTitle.isEmpty
        }
        return !reservation.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 経路のある予約の表示名。
    /// カードには区間が別に出るので、便名があればそれだけにして重複を避ける
    private var composedRouteTitle: String {
        let number = reservation.transportNumber?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !number.isEmpty { return number }

        let from = reservation.departurePlace?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let to = reservation.arrivalPlace?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        switch (from.isEmpty, to.isEmpty) {
        case (false, false): return "\(from) → \(to)"
        case (false, true): return from
        case (true, false): return to
        case (true, true): return ""
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark
                    ? themeManager.currentTheme.backgroundDark
                    : themeManager.currentTheme.backgroundLight)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        if let importNotes {
                            importNotesBanner(importNotes)
                        } else if isNewReservation && hasScheduleItems {
                            importFromScheduleButton
                        }
                        kindPicker
                        // 使える人には目立つ場所に出す。買っていない人は、入力のじゃまに
                        // ならないよう画面の下に1行だけ出す（下の proEmailHint）
                        if isNewReservation && importNotes == nil && proStore.isPurchased {
                            importFromEmailButton
                        }
                        // 経路のある予約は便名と区間が名前の代わりになる。
                        // 「ANA123」と「ANA123便 羽田→那覇」を二重に書かせない
                        if reservation.kind.usesRoute {
                            routeSection
                        } else {
                            field(label: "予約の名前", text: $reservation.title, placeholder: reservation.kind.placeholder)
                            dateSection
                        }
                        numberField
                        optionalFields
                        addToItinerarySection
                        if isNewReservation && importNotes == nil && !proStore.isPurchased {
                            proEmailHint
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(isNewReservation ? "予約を追加" : "予約を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                        .foregroundColor(accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") { save() }
                        .foregroundColor(canSave ? accent : themeManager.currentTheme.secondaryText)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .onAppear {
                load(reservation)
                hasChosenKind = !isNewReservation
            }
            .task { await resolveDestinationTimeZone() }
            .sheet(isPresented: $showsEmailImport) {
                if let plan {
                    ReservationEmailImportView(plan: plan, kind: hasChosenKind ? reservation.kind : nil) { results in
                        applyImport(results)
                    }
                }
            }
            // 買えたら、そのまま取り込みを開く（使いたくて買ったので、探し直させない）
            .sheet(isPresented: $showsProSheet, onDismiss: {
                if proStore.isPurchased { showsEmailImport = true }
            }) {
                ProSheet(highlighted: nil, dismissesOnPurchase: true)
            }
            .sheet(isPresented: $showSchedulePicker) {
                if let plan {
                    ScheduleItemPickerView(plan: plan) { item, dayDate in
                        apply(item: item, dayDate: dayDate)
                    }
                }
            }
        }
    }

    /// メールの読み取りは外れることがあるので、補ったところを先に伝える
    private func importNotesBanner(_ notes: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("メールから読み取りました。内容を確かめてから保存してください", systemImage: "envelope.open")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(textColor)
            if !pendingImports.isEmpty {
                Text("このメールには、あと\(pendingImports.count)件の予約があります。保存すると次の予約を開きます。")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(textColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(notes, id: \.self) { note in
                HStack(alignment: .top, spacing: 6) {
                    Text("・")
                    Text(note)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.system(size: 12))
                .foregroundColor(themeManager.currentTheme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(accent.opacity(0.12)))
    }

    /// 入力欄を予約の内容で埋める。開いたときと、メールから取り込んだときに使う
    private func load(_ reservation: Reservation) {
        self.reservation = reservation
        hasDate = false
        hasArrivalDate = false
        hasEndDate = false
        if let existing = reservation.date {
            hasDate = true
            date = existing
        }
        if let existing = reservation.arrivalDate {
            hasArrivalDate = true
            arrivalDate = existing
        }
        dateZone = reservation.dateTimeZone
        arrivalZone = reservation.arrivalTimeZone
        if let existing = reservation.endDate {
            hasEndDate = true
            endDate = existing
        }
        // いま行程に出ているかどうかを、そのままトグルの状態にする。
        // これをしないと、一度オンにしたものをオフに戻せない
        addsToItinerary = plan?.hasScheduleItems(forReservation: reservation.id) ?? false
        costText = reservation.cost.map { String(Int($0)) } ?? ""
    }

    /// 予約確認メールから入れる。種類を選んでから押すと、その種類として読む
    private var importFromEmailButton: some View {
        Button {
            showsEmailImport = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "envelope.open")
                    .font(.system(size: 16))

                VStack(alignment: .leading, spacing: 2) {
                    Text(hasChosenKind ? "\(reservation.kind.label)の予約メールから取り込む" : "予約メールから取り込む")
                        .font(.system(size: 15, weight: .semibold))
                    Text("確認メールを貼り付けると、予約番号・日時・金額を読み取ります")
                        .font(.caption2)
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(themeManager.currentTheme.secondaryText)
            }
            .foregroundColor(accent)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(accent.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }

    /// 買っていない人向けの案内。
    ///
    /// 予約を追加は無料で毎回使う画面なので、入力の途中（種類の下など）には出さない。
    /// 入力を終えた人の目に入る一番下に置き、そのぶん何ができるのかは伝える。
    /// **使える機能と同じ見た目にはしない。** 押すと売り場が開くのに使えそうに見えると、
    /// だまされた感じが出る。「Pro」と先に書き、塗りではなく縁だけのカードにする
    private var proEmailHint: some View {
        Button {
            showsProSheet = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "envelope.open.fill")
                    .font(.system(size: 18))
                    .foregroundColor(accent)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(accent.opacity(0.12)))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("確認メールを貼るだけで、予約が入ります")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(textColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text("予約番号・日時・便名・金額を自動で入力")
                        .font(.caption2)
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                    Text("Travory Pro")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .overlay(Capsule().stroke(accent, lineWidth: 1))
                        .padding(.top, 2)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(themeManager.currentTheme.secondaryText)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(accent.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
        .accessibilityLabel("確認メールを貼るだけで予約が入ります。Travory Pro の説明を開く")
    }

    /// 読み取った1件目を入力欄に入れ、残りは保存したあとに順に開く。
    /// メールに無かった項目は、先に書いてあった内容を残す
    private func applyImport(_ results: [ImportedReservation]) {
        guard var first = results.first else { return }
        let typed = reservation
        first.reservation.id = typed.id
        if first.reservation.title.isEmpty { first.reservation.title = typed.title }
        if first.reservation.confirmationNumber == nil { first.reservation.confirmationNumber = typed.confirmationNumber }
        first.reservation.note = typed.note
        first.reservation.linkURL = typed.linkURL
        if first.reservation.cost == nil { first.reservation.cost = typed.cost ?? Double(costText) }

        load(first.reservation)
        importNotes = first.notes
        pendingImports = Array(results.dropFirst())
        hasChosenKind = true
    }

    /// 行程に書いた飛行機や宿を、予約としても登録したい場面が多い。
    /// 打ち直さずに名前・日時・場所を持ってこられるようにする
    private var importFromScheduleButton: some View {
        Button {
            showSchedulePicker = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 16))

                VStack(alignment: .leading, spacing: 2) {
                    Text("日程から取り込む")
                        .font(.system(size: 15, weight: .semibold))
                    Text("タイムスケジュールに書いた予定から選べます")
                        .font(.caption2)
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(themeManager.currentTheme.secondaryText)
            }
            .foregroundColor(accent)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(accent.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 行程にも追加する
    //
    // 逆向き（行程 → 予約）は取り込みボタンが担っていたが、予約から先に
    // 登録した人は行程にもう一度打ち直すことになっていた。
    // 予約と行程を1つのデータに統合はしない。時刻の決まっていない予約
    // （宿の予約番号だけ控える等）や、行程に出したくない予約があるため。

    /// 保存したときに行程へ入れる内容。時刻が無ければ空
    private var itineraryPreview: [ScheduleItem] {
        var draft = reservation
        draft.date = (hasDate || reservation.kind.usesRoute) ? date : nil
        draft.arrivalDate = hasArrivalDate ? arrivalDate : nil
        draft.timeZoneIdentifier = dateZone.identifier
        draft.arrivalTimeZoneIdentifier = arrivalZone.identifier
        if draft.kind.usesRoute { draft.title = composedRouteTitle }
        return draft.itineraryItems()
    }

    /// 行程に置ける日か。旅行の期間から外れた日時だと置き場所が無い
    private var itineraryDayNumber: Int? {
        guard let plan, let first = itineraryPreview.first else { return nil }
        return plan.dayNumber(forDate: first.time, in: first.timeZone)
    }

    @ViewBuilder
    private var addToItinerarySection: some View {
        if itineraryPreview.isEmpty {
            EmptyView()
        } else if let dayNumber = itineraryDayNumber {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $addsToItinerary) {
                    Text("行程にも追加する")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(textColor)
                }
                .tint(accent)

                Text(addsToItinerary
                     ? "\(dayNumber)日目のタイムスケジュールに、"
                       + itineraryPreview.map { "「\($0.title)」" }.joined(separator: "と")
                       + "が並びます。予約を消すと、この予定も一緒に消えます。"
                     : "オンにすると、\(dayNumber)日目のタイムスケジュールにも並びます。")
                    .font(.system(size: 12))
                    .foregroundColor(themeManager.currentTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(cardFill)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(cardStroke, lineWidth: 1))
            )
        } else {
            itineraryNote(icon: "exclamationmark.circle",
                          text: "この日時は旅行の期間から外れているため、行程には追加できません")
        }
    }

    private func itineraryNote(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13))
            Text(text)
                .font(.system(size: 12))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundColor(themeManager.currentTheme.secondaryText)
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeManager.currentTheme.secondaryText.opacity(0.08))
        )
    }

    /// 予約番号だけは行程に無いので、そこへ入力を促す形で残す
    private func apply(item: ScheduleItem, dayDate: Date) {
        reservation.title = item.title
        reservation.kind = Reservation.guessedKind(title: item.title, location: item.location)

        // 予定の時刻はその日のものとして扱う。
        // 日付だけを日程側に合わせ、時刻は予定のものを使う。
        // **時:分は予定の時計で読む。** 現地時間の予定を端末の時計で読むと、
        // 取り込んだ予約の時刻が時差の分ずれる
        let day = Calendar.current.dateComponents([.year, .month, .day], from: dayDate)
        let time = ScheduleClock.calendar(in: item.timeZone).dateComponents([.hour, .minute], from: item.time)
        var merged = DateComponents()
        merged.year = day.year
        merged.month = day.month
        merged.day = day.day
        merged.hour = time.hour
        merged.minute = time.minute
        date = ScheduleClock.calendar(in: item.timeZone).date(from: merged) ?? item.time
        dateZone = item.timeZone
        hasDate = true

        // 飛行機・新幹線は場所を出発地として扱う。
        // 「神戸空港」をメモに入れても、空港の欄が空のままで意味がない
        var locationForNote = item.location
        if reservation.kind.usesRoute,
           let location = item.location?.trimmingCharacters(in: .whitespacesAndNewlines),
           !location.isEmpty {
            reservation.departurePlace = location
            locationForNote = nil
        }

        // 残りはメモへ回す。すでに書いてある内容は消さない
        let existingNote = reservation.note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let pieces = [locationForNote, item.notes]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !existingNote.contains($0) }
        if !pieces.isEmpty {
            reservation.note = ([existingNote] + pieces)
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
        }

        if let link = item.linkURL, !link.isEmpty,
           (reservation.linkURL ?? "").isEmpty {
            reservation.linkURL = link
        }
    }

    private var kindPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("種類")
                .font(.caption.weight(.semibold))
                .foregroundColor(themeManager.currentTheme.secondaryText)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(Reservation.Kind.allCases) { kind in
                    ReservationKindButton(
                        kind: kind,
                        isSelected: reservation.kind == kind,
                        accent: accent,
                        fill: cardFill,
                        textColor: textColor
                    ) {
                        reservation.kind = kind
                        hasChosenKind = true
                    }
                }
            }
        }
    }

    /// 飛行機・新幹線の入力。空港や駅で見たいものを並べる
    private var routeSection: some View {
        VStack(spacing: 16) {
            field(label: isFlight ? "便名" : "列車名",
                  text: binding(\.transportNumber),
                  placeholder: isFlight ? "例：ANA123" : "例：のぞみ21号")

            HStack(spacing: 12) {
                field(label: "出発", text: binding(\.departurePlace),
                      placeholder: isFlight ? "例：羽田空港" : "例：東京駅")
                field(label: "到着", text: binding(\.arrivalPlace),
                      placeholder: isFlight ? "例：那覇空港" : "例：新大阪駅")
            }

            timeCard

            HStack(spacing: 12) {
                field(label: "座席", text: binding(\.seat),
                      placeholder: isFlight ? "例：12A" : "例：7号車 3D")
                if isFlight {
                    field(label: "ターミナル", text: binding(\.terminal), placeholder: "例：第2")
                }
            }
        }
    }

    /// 出発と到着の時刻は1か所にまとめる。
    /// 汎用の「日時を設定する」と「到着時刻」が離れて2か所にあると、
    /// どちらが出発なのか分からない
    private var timeCard: some View {
        VStack(spacing: 10) {
            HStack {
                Text("出発時刻")
                    .font(.subheadline)
                    .foregroundColor(textColor)
                Spacer()
                DatePicker("", selection: $date)
                    .environment(\.timeZone, dateZone)
                    .datePickerStyle(.compact)
                    .labelsHidden()
            }
            zoneChooser(time: $date, zone: $dateZone)

            Divider()

            if hasArrivalDate {
                HStack {
                    Text("到着時刻")
                        .font(.subheadline)
                        .foregroundColor(textColor)
                    Spacer()
                    DatePicker("", selection: $arrivalDate)
                        .environment(\.timeZone, arrivalZone)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                    Button {
                        hasArrivalDate = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(themeManager.currentTheme.secondaryText)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("到着時刻を消す")
                }
                zoneChooser(time: $arrivalDate, zone: $arrivalZone)
            } else {
                Button {
                    // だいたいの目安として2時間後から始める。そのまま使う人は少ないが、
                    // 今の日時から始めると日付から直すことになって手間
                    arrivalDate = Calendar.current.date(byAdding: .hour, value: 2, to: date) ?? date
                    hasArrivalDate = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle")
                        Text("到着時刻を追加")
                    }
                    .font(.subheadline)
                    .foregroundColor(accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(cardFill))
    }

    private var isFlight: Bool { reservation.kind == .flight }

    // MARK: - どこの時計で入れるか

    /// 海外の旅行でだけ、現地時間・日本時間の切り替えを出す
    @ViewBuilder
    private func zoneChooser(time: Binding<Date>, zone: Binding<TimeZone>) -> some View {
        if let destinationTimeZone {
            LocalTimeZoneChooser(
                time: time,
                timeZone: zone,
                destination: destinationTimeZone,
                secondaryText: themeManager.currentTheme.secondaryText,
                showsDate: true
            )
        }
    }

    /// 目的地が海外なら切り替えを出し、新しい予約は現地の時計から始める。
    ///
    /// 飛行機・新幹線の出発だけは日本時間から始める。海外旅行で予約する便は
    /// 日本を出る便が多く、帰りの便は切り替えれば済む。
    /// 時:分は変えないので、開いた直後に入力欄の時刻が動いて見えることはない
    private func resolveDestinationTimeZone() async {
        guard destinationTimeZone == nil,
              let plan,
              let zone = await DestinationTimeZoneService.shared.timeZone(for: plan),
              ScheduleClock.isForeign(zone, at: plan.startDate) else { return }
        destinationTimeZone = zone

        // 行程から取り込んだ直後なら、予定の時計を引き継いでいるので触らない
        guard isNewReservation, !hasDate else { return }
        let departureZone = reservation.kind.usesRoute ? ScheduleClock.legacyTimeZone : zone
        date = ScheduleClock.keepingWallClock(date, from: dateZone, to: departureZone)
        dateZone = departureZone
        arrivalDate = ScheduleClock.keepingWallClock(arrivalDate, from: arrivalZone, to: zone)
        arrivalZone = zone
    }

    /// 任意項目は nil と空文字を行き来するので、まとめて扱えるようにする
    private func binding(_ keyPath: WritableKeyPath<Reservation, String?>) -> Binding<String> {
        Binding(
            get: { reservation[keyPath: keyPath] ?? "" },
            set: { reservation[keyPath: keyPath] = $0 }
        )
    }

    private var kind: Reservation.Kind { reservation.kind }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $hasDate) {
                // 宿泊ならチェックイン、レンタカーなら受け取り。期間の始まりになる
                Text(kind == .hotel || kind == .rentalCar ? "\(kind.startLabel)を設定する" : "日時を設定する")
                    .font(.subheadline)
                    .foregroundColor(textColor)
            }
            .tint(accent)

            if hasDate {
                DatePicker("", selection: $date)
                    .environment(\.timeZone, dateZone)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                zoneChooser(time: $date, zone: $dateZone)

                if kind.usesPeriod {
                    Divider()
                    endDateRow
                    Divider()
                    pinToggle
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(cardFill))
        // 始まりを現地時間・日本時間で切り替えたら、終わりも同じ時計に付け替える。
        // 付け替えないと、終わりの時:分だけ時差の分ずれて見える
        .onChange(of: dateZone) { oldZone, newZone in
            guard hasEndDate else { return }
            endDate = ScheduleClock.keepingWallClock(endDate, from: oldZone, to: newZone)
        }
    }

    /// 終わりの日時（チェックアウト・返却など）と、期間中に一番上に出すかどうか
    @ViewBuilder
    private var endDateRow: some View {
        if hasEndDate {
            HStack {
                Text(kind.endLabel)
                    .font(.subheadline)
                    .foregroundColor(textColor)
                Spacer()
                DatePicker("", selection: $endDate, in: date...)
                    .environment(\.timeZone, dateZone)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                Button {
                    hasEndDate = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(kind.endLabel)を消す")
            }
            if let period = periodText {
                Text(period)
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.secondaryText)
            }

        } else {
            Button {
                // 宿は翌日の 11:00（よくあるチェックアウト）、それ以外は同じ日の2時間後から始める
                let clock = ScheduleClock.calendar(in: dateZone)
                if kind == .hotel {
                    let nextDay = clock.date(byAdding: .day, value: 1, to: date) ?? date
                    endDate = clock.date(bySettingHour: 11, minute: 0, second: 0, of: nextDay) ?? nextDay
                } else {
                    endDate = clock.date(byAdding: .hour, value: 2, to: date) ?? date
                }
                hasEndDate = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle")
                    Text("\(kind.endLabel)を追加")
                }
                .font(.subheadline)
                .foregroundColor(accent)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

        }
    }

    /// 日程の一番上に出すか。初期値はオフで、選んだものだけ出す
    private var pinsDuringPeriodBinding: Binding<Bool> {
        Binding(
            get: { reservation.pinsDuringPeriod == true },
            // 外したときは nil に戻す（選んだことの無い予約と同じ形にする）
            set: { reservation.pinsDuringPeriod = $0 ? true : nil }
        )
    }

    /// 日程の一番上に出すかの切り替え。終わりの有無で、出る日の説明を変える
    private var pinToggle: some View {
        Toggle(isOn: pinsDuringPeriodBinding) {
            VStack(alignment: .leading, spacing: 2) {
                Text("日程の一番上に表示")
                    .font(.subheadline)
                    .foregroundColor(textColor)
                Text(hasEndDate
                     ? "\(kind.startLabel)から\(kind.endLabel)までの毎日、予定より上に出します"
                     : "\(kind.startLabel)の日に、予定より上に出します。\(kind.endLabel)を入れると期間中の毎日に出ます")
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(accent)
    }

    /// 「3泊」「3日間」。予約の時計で日付を数える
    private var periodText: String? {
        var draft = reservation
        draft.date = date
        draft.endDate = endDate
        draft.timeZoneIdentifier = dateZone.identifier
        guard let count = draft.periodCount else { return nil }
        return kind == .hotel ? "\(count)泊" : "\(count)日間"
    }

    private var numberField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("予約番号")
                .font(.caption.weight(.semibold))
                .foregroundColor(themeManager.currentTheme.secondaryText)

            TextField("例：ABC12345", text: Binding(
                get: { reservation.confirmationNumber ?? "" },
                set: { reservation.confirmationNumber = $0 }
            ))
            .font(.system(size: 17, design: .monospaced))
            .autocorrectionDisabled()
            .textInputAutocapitalization(.characters)
            .foregroundColor(textColor)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(cardFill))

            Text("旅行中に一番探すものなので、控えておくと安心です。")
                .font(.caption2)
                .foregroundColor(themeManager.currentTheme.secondaryText)
        }
    }

    /// 費用。行程にも追加すると、行程の予定の金額にも入る（同じ金額を2か所に打たずに済む）
    private var costField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("費用")
                .font(.caption.weight(.semibold))
                .foregroundColor(themeManager.currentTheme.secondaryText)

            HStack(spacing: 6) {
                Text("¥")
                    .foregroundColor(themeManager.currentTheme.secondaryText)
                TextField("例：12000", text: $costText)
                    .keyboardType(.numberPad)
                    .foregroundColor(textColor)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(cardFill))

            Text("予算の画面の合計に入ります。行程にも追加すると、行程の予定の金額として並びます。")
                .font(.caption2)
                .foregroundColor(themeManager.currentTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// "12,000" や全角で打たれても読めるようにする。読めなければ nil（空欄と同じ）
    private var parsedCost: Double? {
        let digits = ReservationEmailParser.normalized(costText)
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "¥", with: "")
            .replacingOccurrences(of: "円", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard let value = Double(digits), value > 0 else { return nil }
        return value
    }

    private var optionalFields: some View {
        VStack(spacing: 16) {
            costField

            field(label: "メモ", text: Binding(
                get: { reservation.note ?? "" },
                set: { reservation.note = $0 }
            ), placeholder: "例：朝食付き / 禁煙ルーム")

            field(label: "リンク", text: Binding(
                get: { reservation.linkURL ?? "" },
                set: { reservation.linkURL = $0 }
            ), placeholder: "予約確認ページのURL")
        }
    }

    private func field(label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundColor(themeManager.currentTheme.secondaryText)

            TextField(placeholder, text: text)
                .foregroundColor(textColor)
                .autocorrectionDisabled()
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 12).fill(cardFill))
        }
    }

    private func save() {
        guard let userId = authVM.userId,
              var plan = viewModel.travelPlans.first(where: { $0.id == planId }) else { return }

        var edited = reservation
        edited.title = edited.kind.usesRoute
            ? composedRouteTitle
            : edited.title.trimmingCharacters(in: .whitespacesAndNewlines)
        // 経路のある予約は時刻のトグルが無く、常に入力されている扱い
        edited.date = (hasDate || edited.kind.usesRoute) ? date : nil
        edited.arrivalDate = hasArrivalDate ? arrivalDate : nil
        edited.timeZoneIdentifier = edited.date == nil ? nil : dateZone.identifier
        edited.arrivalTimeZoneIdentifier = edited.arrivalDate == nil ? nil : arrivalZone.identifier
        // 終わりは、期間を持てる種類で始まりがあるときだけ残す
        edited.endDate = (edited.kind.usesPeriod && edited.date != nil && hasEndDate) ? endDate : nil
        if !edited.kind.usesPeriod { edited.pinsDuringPeriod = nil }

        // 種類を変えたときに、前の種類の入力が残らないようにする
        if !edited.kind.usesRoute {
            edited.transportNumber = nil
            edited.departurePlace = nil
            edited.arrivalPlace = nil
            edited.arrivalDate = nil
            edited.seat = nil
        }
        if edited.kind != .flight { edited.terminal = nil }

        // 空欄は nil に寄せる。空文字が残ると「入力あり」と判定してしまう
        for keyPath in [\Reservation.transportNumber, \.departurePlace, \.arrivalPlace, \.seat, \.terminal] {
            let trimmed = edited[keyPath: keyPath]?.trimmingCharacters(in: .whitespacesAndNewlines)
            edited[keyPath: keyPath] = (trimmed?.isEmpty ?? true) ? nil : trimmed
        }
        edited.confirmationNumber = edited.confirmationNumber?.trimmingCharacters(in: .whitespacesAndNewlines)
        edited.note = edited.note?.trimmingCharacters(in: .whitespacesAndNewlines)
        edited.linkURL = edited.linkURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        edited.cost = parsedCost

        if let index = plan.reservations.firstIndex(where: { $0.id == edited.id }) {
            plan.reservations[index] = edited
        } else {
            plan.reservations.append(edited)
        }

        // 行程との連動。オンなら入れ直し、オフなら消す。
        // 予約の時刻や便名を書き換えたときに古い予定が残らないよう、
        // どちらの場合もいったん消してから作り直す
        plan.syncScheduleItems(for: edited, isOn: addsToItinerary)

        viewModel.update(plan, userId: userId)

        // 1通のメールに残りの予約があれば、閉じずに次を開く
        if !pendingImports.isEmpty {
            let next = pendingImports.removeFirst()
            load(next.reservation)
            importNotes = next.notes
            return
        }
        dismiss()
    }
}

/// 種類の選択ボタン。色の出し分けを本体に書くと型チェックが重くなるため分ける
private struct ReservationKindButton: View {
    let kind: Reservation.Kind
    let isSelected: Bool
    let accent: Color
    let fill: Color
    let textColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: kind.icon)
                    .font(.system(size: 16))
                Text(kind.label)
                    .font(.system(size: 10))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundColor(isSelected ? accent : textColor)
            .background(RoundedRectangle(cornerRadius: 10).fill(isSelected ? accent.opacity(0.16) : fill))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? accent : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}
