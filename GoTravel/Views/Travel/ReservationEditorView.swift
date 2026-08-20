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

    @State private var showSchedulePicker = false

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

    private var canSave: Bool {
        !reservation.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
                        field(label: "予約の名前", text: $reservation.title, placeholder: reservation.kind.placeholder)
                        // 空港・駅で必要になるものを先に出す。
                        // 予約番号だけ控えても、便名や座席は結局メールを探すことになる
                        if reservation.kind.usesRoute {
                            routeSection
                        }
                        dateSection
                        numberField
                        optionalFields
                    }
                    .padding(20)
                }
            }
            .navigationTitle(reservation.title.isEmpty ? "予約を追加" : "予約を編集")
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

    /// 予約番号だけは行程に無いので、そこへ入力を促す形で残す
    private func apply(item: ScheduleItem, dayDate: Date) {
        reservation.title = item.title
        reservation.kind = Reservation.guessedKind(title: item.title, location: item.location)

        // 予定の時刻はその日のものとして扱う。
        // 日付だけを日程側に合わせ、時刻は予定のものを使う
        let calendar = Calendar.current
        let day = calendar.dateComponents([.year, .month, .day], from: dayDate)
        let time = calendar.dateComponents([.hour, .minute], from: item.time)
        var merged = DateComponents()
        merged.year = day.year
        merged.month = day.month
        merged.day = day.day
        merged.hour = time.hour
        merged.minute = time.minute
        date = calendar.date(from: merged) ?? item.time
        hasDate = true

        // 場所は予約の名前に含まれないことが多いのでメモへ回す。
        // すでに書いてある内容は消さない
        let existingNote = reservation.note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let pieces = [item.location, item.notes]
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

            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: $hasArrivalDate) {
                    Text("到着時刻を入れる")
                        .font(.subheadline)
                        .foregroundColor(textColor)
                }
                .tint(accent)

                if hasArrivalDate {
                    DatePicker("", selection: $arrivalDate)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(cardFill))

            HStack(spacing: 12) {
                field(label: "座席", text: binding(\.seat),
                      placeholder: isFlight ? "例：12A" : "例：7号車 3D")
                if isFlight {
                    field(label: "ターミナル", text: binding(\.terminal), placeholder: "例：第2")
                }
            }
        }
    }

    private var isFlight: Bool { reservation.kind == .flight }

    /// 任意項目は nil と空文字を行き来するので、まとめて扱えるようにする
    private func binding(_ keyPath: WritableKeyPath<Reservation, String?>) -> Binding<String> {
        Binding(
            get: { reservation[keyPath: keyPath] ?? "" },
            set: { reservation[keyPath: keyPath] = $0 }
        )
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $hasDate) {
                Text("日時を設定する")
                    .font(.subheadline)
                    .foregroundColor(textColor)
            }
            .tint(accent)

            if hasDate {
                DatePicker("", selection: $date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(cardFill))
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
        edited.title = edited.title.trimmingCharacters(in: .whitespacesAndNewlines)
        edited.date = hasDate ? date : nil
        edited.arrivalDate = hasArrivalDate ? arrivalDate : nil

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
