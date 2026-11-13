import SwiftUI
import MapKit

/// タイムスケジュールの1件を追加・編集する画面。
///
/// 以前はこの画面だけ作りが違った。
/// テーマを通さず iOS のシステム色（`Color(.secondarySystemBackground)` など）を直に使い、
/// 背景は `.black` 直書きの強い色付きグラデーション、
/// そしてカード（角丸16・影）の中に入力欄の箱（角丸10・枠線）という二重構造だった。
/// 予定の編集画面（`PlanDetailView.editSection`）と同じ、区切り線だけの組みに揃えてある
struct ScheduleItemEditorView: View {
    @Binding var plan: Plan
    let scheduleItem: PlanScheduleItem?
    let onSave: (Plan) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var themeManager = ThemeManager.shared

    @State private var time: Date
    @State private var selectedDay: Int
    @State private var title: String
    @State private var selectedPlaceId: String?
    @State private var note: String
    /// この画面で新しく足した場所。保存を押すまで予定には入れない
    @State private var addedPlaces: [PlannedPlace] = []
    @State private var showPlaceSearch = false
    /// 「移動」の予定か（3.5。旅行の日程と同じ）
    @State private var isMove: Bool
    @State private var moveInput: MoveInput
    /// 時間未定か（3.5）。未定のときは時刻の代わりに「入れる位置」を選ぶ
    @State private var isUndecided: Bool
    /// 未定の予定のすぐ前に来る予定の id（nil ならいちばん前）
    @State private var anchorID: String?

    private var isEditing: Bool {
        scheduleItem != nil
    }

    init(plan: Binding<Plan>, scheduleItem item: PlanScheduleItem?, onSave: @escaping (Plan) -> Void) {
        self._plan = plan
        self.scheduleItem = item
        self.onSave = onSave

        // Initialize @State variables
        _time = State(initialValue: item.map(PlanScheduleUndecided.startingTime(for:)) ?? Date())
        // 名前が自動で付けたもの（「梅田 → 京都」）なら空で始め、発着地を変えたら名前もついてくるようにする
        _title = State(initialValue: item.map { $0.hasDefaultMoveTitle ? "" : $0.title } ?? "")
        _isMove = State(initialValue: item?.isMove ?? false)
        _moveInput = State(initialValue: item?.move.map(MoveInput.init) ?? MoveInput())
        _isUndecided = State(initialValue: item?.hasUndecidedTime ?? false)
        _selectedPlaceId = State(initialValue: item?.placeId)
        _note = State(initialValue: item?.note ?? "")

        // 何日目の予定かを復元する。新規なら1日目から
        let planValue = plan.wrappedValue
        let day = item.map { planValue.dayNumber(for: $0) } ?? 1
        _selectedDay = State(initialValue: day)
        // 入れる位置の初期値：直すときは今の位置、足すときはその日のいちばん後ろ
        let dayItems = planValue.scheduleItems.filter { planValue.dayNumber(for: $0) == day }
        if let item {
            _anchorID = State(initialValue: PlanScheduleUndecided.anchorID(of: item.id, in: dayItems))
        } else {
            _anchorID = State(initialValue: dayItems.sorted(by: PlanScheduleItem.chronologically).last?.id)
        }
    }

    /// 選んだ日の、この予定のほかの予定（並んでいる順）。時間未定の「入れる位置」に使う
    private var otherDayItems: [PlanScheduleItem] {
        plan.scheduleItems
            .filter { $0.id != scheduleItem?.id && plan.dayNumber(for: $0) == selectedDay }
            .sorted(by: PlanScheduleItem.chronologically)
    }

    private var canSave: Bool {
        isMove || !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Colors

    private var accentColor: Color {
        plan.planType.color(themeManager.currentTheme)
    }

    private var textColor: Color {
        themeManager.currentTheme.adaptiveText(for: colorScheme)
    }

    private var fieldBackground: Color {
        colorScheme == .dark
            ? themeManager.currentTheme.backgroundDark
            : themeManager.currentTheme.backgroundLight
    }

    /// 選べる場所。予定に登録済みのものと、この画面で足したもの
    private var availablePlaces: [PlannedPlace] {
        plan.places + addedPlaces
    }

    /// 選んだ日と時刻を合成した、保存する日時
    private var composedDate: Date {
        let calendar = Calendar.current
        let dayDate = plan.date(forDay: selectedDay)
        let components = calendar.dateComponents([.hour, .minute], from: time)

        return calendar.date(
            bySettingHour: components.hour ?? 0,
            minute: components.minute ?? 0,
            second: 0,
            of: dayDate
        ) ?? dayDate
    }

    // MARK: - Body

    var body: some View {
        // iPad・Mac の広い画面では、入力欄を読みやすい幅にそろえる（iPhone では何もしない）
        editorBody.readableFormWidth()
    }

    @ViewBuilder private var editorBody: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // 2日以上の予定のときだけ、何日目かを選べるようにする
                    if plan.isMultiDay {
                        section("日付", icon: "calendar") {
                            daySelection
                        }
                    }

                    // 予定か移動か（3.5。旅行の日程と同じ）
                    section("種類", icon: "square.grid.2x2") {
                        ScheduleEntryKindPicker(isMove: $isMove.animation(.easeInOut(duration: 0.2)), tint: accentColor)
                    }

                    if isMove {
                        section("移動", icon: moveInput.mode.systemImage) {
                            ScheduleMoveFields(
                                input: $moveInput,
                                searchRegion: placeSearchRegion,
                                tint: accentColor,
                                textColor: textColor,
                                secondaryText: themeManager.currentTheme.secondaryText,
                                fieldBackground: fieldBackground
                            )
                        }
                    }

                    section(isMove ? "出発の時刻" : "時刻", icon: "clock") {
                        VStack(spacing: 10) {
                            UndecidedTimeFields(
                                isUndecided: $isUndecided,
                                anchorID: $anchorID,
                                dayItems: otherDayItems.map {
                                    UndecidedAnchorChoice(id: $0.id, timeText: $0.timeText, title: $0.title)
                                },
                                tint: accentColor,
                                textColor: textColor,
                                secondaryText: themeManager.currentTheme.secondaryText,
                                fieldBackground: fieldBackground
                            )

                            if !isUndecided {
                                DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                                    .datePickerStyle(.wheel)
                                    .labelsHidden()
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }

                    section(isMove ? "名前（任意）" : "予定名", icon: "pencil") {
                        TextField(isMove ? "例：\(moveInput.move.defaultTitle)" : "例：浅草寺を観光", text: $title)
                            .font(.body)
                            .foregroundColor(textColor)
                            .padding(14)
                            .background(fieldBackground)
                            .cornerRadius(AppRadius.medium)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.medium)
                                    .stroke(
                                        title.isEmpty && !isMove
                                            ? themeManager.currentTheme.error.opacity(0.5)
                                            : accentColor.opacity(0.3),
                                        lineWidth: 1.5
                                    )
                            )
                    }

                    // 予定に場所が1つも無くても出す。
                    // 以前は登録済みの場所からしか選べず、
                    // 先に訪問場所を足しておかないとここで場所を付けられなかった
                    // 移動は出発地・到着地を持つので、場所は選ばない
                    if !isMove {
                        section("場所（任意）", icon: "mappin.circle.fill") {
                            placePicker
                        }
                    }

                    section("メモ（任意）", icon: "text.alignleft") {
                        noteEditor
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(
                themeManager.currentTheme.backgroundGradient(for: colorScheme)
                    .ignoresSafeArea()
            )
            // 地図で探す。地図に出ている施設を押しても、長押しでピンを立てても選べる（`MapPlaceSearchView`）。
            // 前は文字で検索するだけの画面で、「地図から」と書いてあるのに地図が出なかった
            .fullScreenCover(isPresented: $showPlaceSearch) {
                MapPlaceSearchView(title: "地図から検索", startRegion: placeSearchRegion, accent: accentColor) { picked in
                    let place = PlannedPlace(name: picked.name,
                                             latitude: picked.coordinate.latitude,
                                             longitude: picked.coordinate.longitude,
                                             address: picked.address)
                    addedPlaces.append(place)
                    selectedPlaceId = place.id
                }
            }
            // 日を変えたら、入れる位置はその日のいちばん後ろから
            .onChange(of: selectedDay) { _, _ in
                anchorID = otherDayItems.last?.id
            }
            .navigationTitle(isEditing ? "スケジュール編集" : "スケジュール追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                    .foregroundColor(themeManager.currentTheme.secondaryText)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveScheduleItem()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(canSave ? accentColor : themeManager.currentTheme.secondaryText)
                    .disabled(!canSave)
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Sections

    /// 予定の編集画面と同じ区切り。面は塗らず、下に線を1本だけ引く
    private func section<Content: View>(
        _ label: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(accentColor)
                    Text(label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(textColor)
                }

                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 16)

            Rectangle()
                .fill(themeManager.currentTheme.secondaryText.opacity(0.15))
                .frame(height: 1)
        }
    }

    private var daySelection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(1...plan.dayCount, id: \.self) { day in
                    dayChip(day)
                }
            }
            .padding(.vertical, 2)
        }
        // 広い画面の余白（readableFormWidth）が、この横の並びの中にまで入らないようにする
        .resetFormMargins()
    }

    private func dayChip(_ day: Int) -> some View {
        let isSelected = selectedDay == day
        // 塗りは白文字が読める濃さまで落とす
        let fill = ThemePreset.readableTint(accentColor, on: .white)

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedDay = day
            }
        } label: {
            VStack(spacing: 3) {
                Text("\(day)日目")
                    .font(.caption.weight(.bold))
                Text(dayLabel(for: day))
                    .font(.caption2)
                    .opacity(0.85)
            }
            .foregroundColor(isSelected ? .white : textColor.opacity(0.75))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background {
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .fill(isSelected ? AnyShapeStyle(fill) : AnyShapeStyle(fieldBackground))
            }
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .stroke(isSelected ? Color.clear : themeManager.currentTheme.secondaryText.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    /// 地図を開く位置。予定にもう場所があればその近く、無ければ日本全体
    private var placeSearchRegion: MKCoordinateRegion {
        guard let first = availablePlaces.first else { return TravelPlan.japanRegion }
        return MKCoordinateRegion(center: first.coordinate, latitudinalMeters: 5000, longitudinalMeters: 5000)
    }

    @ViewBuilder
    private var placePicker: some View {
        if availablePlaces.isEmpty {
            addPlaceButton
        } else {
            placeMenu
        }
    }

    /// 場所がまだ1つも無いとき
    private var addPlaceButton: some View {
        Button { showPlaceSearch = true } label: {
            HStack {
                Image(systemName: "map")
                    .foregroundColor(accentColor)
                Text("地図から場所を探す")
                    .foregroundColor(textColor)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.secondaryText)
            }
            .font(.body)
            .padding(14)
            .background(fieldBackground)
            .cornerRadius(AppRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .stroke(accentColor.opacity(0.2), lineWidth: 1)
            )
        }
    }

    private var placeMenu: some View {
        Menu {
            Button("場所を選択しない") {
                selectedPlaceId = nil
            }

            Button {
                showPlaceSearch = true
            } label: {
                Label("地図から場所を探す", systemImage: "map")
            }

            ForEach(availablePlaces) { place in
                Button(action: {
                    selectedPlaceId = place.id
                }) {
                    HStack {
                        Text(place.name)
                        if selectedPlaceId == place.id {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack {
                // この画面で地図から足した場所（`addedPlaces`）も含めて探す。
                // 予定の場所（`plan.places`）だけを見ていたため、足した直後は「場所を選択」のままだった
                if let placeId = selectedPlaceId,
                   let place = availablePlaces.first(where: { $0.id == placeId }) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(accentColor)
                    Text(place.name)
                        .foregroundColor(textColor)
                } else {
                    Image(systemName: "mappin.circle")
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                    Text("場所を選択")
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.secondaryText)
            }
            .font(.body)
            .padding(14)
            .background(fieldBackground)
            .cornerRadius(AppRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .stroke(accentColor.opacity(0.2), lineWidth: 1)
            )
        }
    }

    private var noteEditor: some View {
        ZStack(alignment: .topLeading) {
            // 差し込み文字と本文の位置を揃える。
            // 以前は枠の外側に別の余白を持っていて、書き始めると文字が飛んでいた
            if note.isEmpty {
                Text("メモを入力...")
                    .foregroundColor(themeManager.currentTheme.secondaryText.opacity(0.45))
                    .font(.body)
                    .padding(.top, 10)
                    .padding(.leading, 5)
            }

            TextEditor(text: $note)
                        .resetFormMargins()
                .font(.body)
                .frame(minHeight: 100)
                .foregroundColor(textColor)
                .scrollContentBackground(.hidden)
        }
        .padding(14)
        .background(fieldBackground)
        .cornerRadius(AppRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .stroke(accentColor.opacity(0.2), lineWidth: 1)
        )
    }

    private func dayLabel(for day: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d(E)"
        return formatter.string(from: plan.date(forDay: day))
    }

    // MARK: - Save

    private func saveScheduleItem() {
        var updatedPlan = plan

        // この画面で足した場所を予定へ入れる。
        // 途中でやめたときに残らないよう、保存のときだけ反映する。移動の予定は場所を使わない
        if !isMove {
            let usedNewPlaces = addedPlaces.filter { $0.id == selectedPlaceId }
            updatedPlan.places.append(contentsOf: usedNewPlaces)
        }

        // 直すときは、この画面で直せる項目だけ書き換える。作り直すと、ここに出ない項目（移動手段など）が消える
        var item = scheduleItem.flatMap { existing in updatedPlan.scheduleItems.first { $0.id == existing.id } }
            ?? PlanScheduleItem(time: composedDate, title: "")
        item.time = composedDate
        item.note = note.isEmpty ? nil : note
        if isMove {
            item.apply(move: moveInput.move, title: title)
        } else {
            item.move = nil
            item.title = title
            item.placeId = selectedPlaceId
        }
        item.isTimeUndecided = isUndecided ? true : nil

        // 選んだ日の予定を並べ直す。未定の予定は選んだ位置に入れ、ほかの未定の予定も位置を付け直す
        let otherDays = updatedPlan.scheduleItems.filter { $0.id != item.id && updatedPlan.dayNumber(for: $0) != selectedDay }
        let sameDay = updatedPlan.scheduleItems.filter { $0.id != item.id && updatedPlan.dayNumber(for: $0) == selectedDay }
        let placedDay: [PlanScheduleItem]
        if isUndecided {
            placedDay = PlanScheduleUndecided.inserting(item, after: anchorID, into: sameDay)
        } else {
            placedDay = PlanScheduleUndecided.normalized((sameDay + [item]).sorted(by: PlanScheduleItem.chronologically))
        }
        updatedPlan.scheduleItems = otherDays + placedDay

        onSave(updatedPlan)
        dismiss()
    }
}
