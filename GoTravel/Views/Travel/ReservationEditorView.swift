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
    /// 宿泊のチェックアウト。時間帯はチェックインと同じ（宿は1か所）
    @State private var hasCheckOut = false
    @State private var checkOutDate = Date()
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
                        if isNewReservation && hasScheduleItems {
                            importFromScheduleButton
                        }
                        kindPicker
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
                if let existing = reservation.checkOutDate {
                    hasCheckOut = true
                    checkOutDate = existing
                }
                // いま行程に出ているかどうかを、そのままトグルの状態にする。
                // これをしないと、一度オンにしたものをオフに戻せない
                addsToItinerary = plan?.hasScheduleItems(forReservation: reservation.id) ?? false
            }
            .task { await resolveDestinationTimeZone() }
            .sheet(isPresented: $showSchedulePicker) {
                if let plan {
                    ScheduleItemPickerView(plan: plan) { item, dayDate in
                        apply(item: item, dayDate: dayDate)
                    }
                }
            }
        }
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

    private var isHotel: Bool { reservation.kind == .hotel }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $hasDate) {
                // 宿泊ではこの日時がチェックイン。滞在中の各日に宿を出すのに使う
                Text(isHotel ? "チェックインを設定する" : "日時を設定する")
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

                if isHotel {
                    Divider()
                    checkOutRow
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(cardFill))
        // チェックインを現地時間・日本時間で切り替えたら、チェックアウトも同じ時計に付け替える。
        // 付け替えないと、チェックアウトの時:分だけ時差の分ずれて見える
        .onChange(of: dateZone) { oldZone, newZone in
            guard hasCheckOut else { return }
            checkOutDate = ScheduleClock.keepingWallClock(checkOutDate, from: oldZone, to: newZone)
        }
    }

    /// チェックアウト。入れると、泊まっている各日の日程の一番上に宿が出る
    @ViewBuilder
    private var checkOutRow: some View {
        if hasCheckOut {
            HStack {
                Text("チェックアウト")
                    .font(.subheadline)
                    .foregroundColor(textColor)
                Spacer()
                DatePicker("", selection: $checkOutDate, in: date...)
                    .environment(\.timeZone, dateZone)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                Button {
                    hasCheckOut = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("チェックアウトを消す")
            }
            if let nights = nightsText {
                Text(nights)
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.secondaryText)
            }
        } else {
            Button {
                // 翌日の 11:00 から始める。よくあるチェックアウトの時刻
                let clock = ScheduleClock.calendar(in: dateZone)
                let nextDay = clock.date(byAdding: .day, value: 1, to: date) ?? date
                checkOutDate = clock.date(bySettingHour: 11, minute: 0, second: 0, of: nextDay) ?? nextDay
                hasCheckOut = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle")
                    Text("チェックアウトを追加")
                }
                .font(.subheadline)
                .foregroundColor(accent)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Text("入れると、泊まっている日の日程の一番上に宿が表示されます")
                .font(.caption)
                .foregroundColor(themeManager.currentTheme.secondaryText)
        }
    }

    /// 「3泊」。宿の時計で日付を数える
    private var nightsText: String? {
        let clock = ScheduleClock.calendar(in: dateZone)
        let nights = clock.dateComponents([.day],
                                          from: clock.startOfDay(for: date),
                                          to: clock.startOfDay(for: checkOutDate)).day ?? 0
        return nights > 0 ? "\(nights)泊" : nil
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

    private var optionalFields: some View {
        VStack(spacing: 16) {
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
        // チェックアウトは宿泊でチェックインがあるときだけ残す
        edited.checkOutDate = (edited.kind == .hotel && edited.date != nil && hasCheckOut) ? checkOutDate : nil

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
