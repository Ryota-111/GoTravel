import SwiftUI

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

    private var isEditing: Bool {
        scheduleItem != nil
    }

    init(plan: Binding<Plan>, scheduleItem item: PlanScheduleItem?, onSave: @escaping (Plan) -> Void) {
        self._plan = plan
        self.scheduleItem = item
        self.onSave = onSave

        // Initialize @State variables
        _time = State(initialValue: item?.time ?? Date())
        _title = State(initialValue: item?.title ?? "")
        _selectedPlaceId = State(initialValue: item?.placeId)
        _note = State(initialValue: item?.note ?? "")

        // 何日目の予定かを復元する。新規なら1日目から
        let planValue = plan.wrappedValue
        _selectedDay = State(initialValue: item.map { planValue.dayNumber(for: $0) } ?? 1)
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
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // 2日以上の予定のときだけ、何日目かを選べるようにする
                    if plan.isMultiDay {
                        section("日付", icon: "calendar") {
                            daySelection
                        }
                    }

                    section("時刻", icon: "clock") {
                        DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                    }

                    section("予定名", icon: "pencil") {
                        TextField("例：浅草寺を観光", text: $title)
                            .font(.body)
                            .foregroundColor(textColor)
                            .padding(14)
                            .background(fieldBackground)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        title.isEmpty
                                            ? themeManager.currentTheme.error.opacity(0.5)
                                            : accentColor.opacity(0.3),
                                        lineWidth: 1.5
                                    )
                            )
                    }

                    // 予定に場所が1つも無くても出す。
                    // 以前は登録済みの場所からしか選べず、
                    // 先に訪問場所を足しておかないとここで場所を付けられなかった
                    section("場所（任意）", icon: "mappin.circle.fill") {
                        placePicker
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
            .sheet(isPresented: $showPlaceSearch) {
                PlaceSearchView { place in
                    addedPlaces.append(place)
                    selectedPlaceId = place.id
                }
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
                    .foregroundColor(title.isEmpty ? themeManager.currentTheme.secondaryText : accentColor)
                    .disabled(title.isEmpty)
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
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? AnyShapeStyle(fill) : AnyShapeStyle(fieldBackground))
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.clear : themeManager.currentTheme.secondaryText.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
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
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
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
                if let placeId = selectedPlaceId,
                   let place = plan.places.first(where: { $0.id == placeId }) {
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
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
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
                .font(.body)
                .frame(minHeight: 100)
                .foregroundColor(textColor)
                .scrollContentBackground(.hidden)
        }
        .padding(14)
        .background(fieldBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
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
        // 途中でやめたときに残らないよう、保存のときだけ反映する
        let usedNewPlaces = addedPlaces.filter { $0.id == selectedPlaceId }
        updatedPlan.places.append(contentsOf: usedNewPlaces)

        if let existingItem = scheduleItem {
            // 編集モード
            if let index = updatedPlan.scheduleItems.firstIndex(where: { $0.id == existingItem.id }) {
                updatedPlan.scheduleItems[index] = PlanScheduleItem(
                    id: existingItem.id,
                    time: composedDate,
                    title: title,
                    placeId: selectedPlaceId,
                    note: note.isEmpty ? nil : note
                )
            }
        } else {
            // 新規追加モード
            let newItem = PlanScheduleItem(
                time: composedDate,
                title: title,
                placeId: selectedPlaceId,
                note: note.isEmpty ? nil : note
            )
            updatedPlan.scheduleItems.append(newItem)
        }

        onSave(updatedPlan)
        dismiss()
    }
}
