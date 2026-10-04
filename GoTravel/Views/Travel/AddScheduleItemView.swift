import SwiftUI
import MapKit

struct AddScheduleItemView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var viewModel: TravelPlanViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme

    let plan: TravelPlan
    let dayNumber: Int

    @State private var title = ""
    @State private var time = Date()
    /// 時刻をどこの時計で入れるか。海外の旅行では現地の時計から始める
    @State private var timeZone: TimeZone = .current
    /// 目的地の時間帯。日本と時差があるときだけ入る
    @State private var destinationTimeZone: TimeZone?
    /// 共有した旅行で、この予定に参加する人。空なら全員
    @State private var participants: Set<String> = []
    /// 費用。外貨でも入れられる（`CurrencyCostFields`）
    @State private var costInput = CostInput()
    @State private var costNote = ""
    @State private var notes = ""
    @State private var linkURL = ""

    // Location
    @StateObject private var locationHistory = LocationHistoryManager.shared
    @State private var showLocationMethodSheet = false
    @State private var showLocationPicker = false
    @State private var showHistoryPicker = false
    @State private var showSavedPlacePicker = false
    @State private var selectedLocation: MKMapItem?
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var selectedAddress: String?

    // MARK: - Computed
    var dayDate: Date {
        Calendar.current.date(byAdding: .day, value: dayNumber - 1, to: plan.startDate) ?? plan.startDate
    }


    private var canAdd: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    private var travelColor: Color {
        switch themeManager.currentTheme.type {
        case .whiteBlack: return .black
        default: return themeManager.currentTheme.primary
        }
    }

    private var textColor: Color {
        colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1
    }

    private var fieldBg: Color {
        colorScheme == .dark ? themeManager.currentTheme.backgroundDark : themeManager.currentTheme.backgroundLight
    }

    private var bgGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: colorScheme == .dark
                ? [themeManager.currentTheme.backgroundDark, themeManager.currentTheme.secondaryBackgroundDark]
                : [themeManager.currentTheme.backgroundLight, themeManager.currentTheme.secondaryBackgroundLight]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            bgGradient

            VStack(spacing: 0) {
                headerView

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        titleSection
                        timeSection
                        locationSection
                        optionalSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }

                addButton
            }
        }
        .sheet(isPresented: $showLocationMethodSheet) {
            locationMethodSheet
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showHistoryPicker) {
            locationHistoryPickerView
        }
        .sheet(isPresented: $showSavedPlacePicker) {
            SavedPlacePickerView(accentColor: travelColor) { place in
                applySavedPlace(place)
            }
            .environmentObject(authVM)
        }
        // 地図で探す。地図に出ている施設を押しても、長押しでピンを立てても選べる（`MapPlaceSearchView`）
        .fullScreenCover(isPresented: $showLocationPicker) {
            MapPlaceSearchView(title: "地図から検索", startRegion: plan.placeSearchRegion, accent: travelColor) { picked in
                applyPickedPlace(picked)
            }
        }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack {
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                Image(systemName: "xmark")
                    .foregroundColor(textColor)
                    .imageScale(.medium)
                    .padding(8)
                    .background(textColor.opacity(0.1))
                    .clipShape(Circle())
            }

            Spacer()

            VStack(spacing: 2) {
                Text("予定を追加")
                    .font(.headline)
                    .foregroundColor(textColor)
                Text("Day \(dayNumber) · \(formattedDayDate)")
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.secondaryText)
            }

            Spacer()

            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(travelColor.opacity(0.15))
    }

    // MARK: - Title Section
    private var titleSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("タイトル", icon: "text.alignleft")
                TextField("例：浅草寺観光、ランチ", text: $title)
                    .font(.body)
                    .foregroundColor(textColor)
                    .padding(14)
                    .background(fieldBg)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                title.isEmpty
                                    ? themeManager.currentTheme.error.opacity(0.4)
                                    : travelColor.opacity(0.3),
                                lineWidth: 1.5
                            )
                    )
            }
        }
    }

    // MARK: - Time Section
    private var timeSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("時間", icon: "clock.fill")
                ScheduleTimeField(
                    time: $time,
                    timeZone: $timeZone,
                    destination: destinationTimeZone,
                    tint: travelColor,
                    textColor: textColor,
                    secondaryText: themeManager.currentTheme.secondaryText,
                    fieldBackground: fieldBg
                )
                .task { await resolveDestinationTimeZone() }

                // 共有していて2人以上のときだけ出る
                ParticipantPicker(
                    plan: plan,
                    selected: $participants,
                    tint: travelColor,
                    textColor: textColor,
                    secondaryText: themeManager.currentTheme.secondaryText,
                    fieldBackground: fieldBg
                )
            }
        }
    }

    // MARK: - Location Section
    private var locationSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("場所（任意）", icon: "mappin.circle.fill")

                if let selected = selectedLocation {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(travelColor)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selected.name ?? "場所")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(textColor)
                            if let address = selectedAddress ?? selected.placemark.title {
                                Text(address)
                                    .font(.caption)
                                    .foregroundColor(themeManager.currentTheme.secondaryText)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Button(action: {
                            selectedLocation = nil
                            selectedCoordinate = nil
                            selectedAddress = nil
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(themeManager.currentTheme.secondaryText)
                        }
                    }
                    .padding(14)
                    .background(fieldBg)
                    .cornerRadius(12)
                } else {
                    Button(action: { showLocationMethodSheet = true }) {
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(travelColor.opacity(0.7))
                                .frame(width: 24)
                            Text("場所を検索")
                                .font(.subheadline)
                                .foregroundColor(themeManager.currentTheme.secondaryText)
                            Spacer()
                            if !locationHistory.history.isEmpty {
                                Text("\(locationHistory.history.count)件の履歴")
                                    .font(.caption2)
                                    .foregroundColor(travelColor.opacity(0.7))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(travelColor.opacity(0.08))
                                    .clipShape(Capsule())
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(themeManager.currentTheme.secondaryText.opacity(0.5))
                        }
                        .padding(14)
                        .background(fieldBg)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(travelColor.opacity(0.2), lineWidth: 1))
                    }
                }
            }
        }
    }

    // MARK: - Optional Section
    private var optionalSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("その他（任意）", icon: "ellipsis.circle")

                CurrencyCostFields(
                    input: $costInput,
                    tripRates: currentPlan.exchangeRates,
                    accent: travelColor,
                    textColor: textColor,
                    secondaryText: themeManager.currentTheme.secondaryText,
                    fieldBackground: fieldBg
                )
                .onAppear(perform: preselectTripCurrency)

                // 費用のメモ（「2人分」「駐車場代込み」など）。金額の横に出す
                TextField("費用のメモ（例：2人分・駐車場代込み）", text: $costNote)
                    .font(.subheadline)
                    .foregroundColor(textColor)
                    .padding(14)
                    .background(fieldBg)
                    .cornerRadius(12)

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "note.text")
                            .foregroundColor(travelColor.opacity(0.7))
                            .frame(width: 24)
                        Text("メモ")
                            .font(.subheadline)
                            .foregroundColor(textColor)
                    }
                    ZStack(alignment: .topLeading) {
                        if notes.isEmpty {
                            Text("メモを入力…")
                                .foregroundColor(themeManager.currentTheme.secondaryText.opacity(0.5))
                                .font(.body)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                        }
                        TextEditor(text: $notes)
                            .font(.body)
                            .frame(minHeight: 80)
                            .foregroundColor(textColor)
                            .scrollContentBackground(.hidden)
                    }
                    .padding(12)
                    .background(fieldBg)
                    .cornerRadius(12)
                }

                Divider()

                HStack(spacing: 12) {
                    Image(systemName: "link")
                        .foregroundColor(travelColor.opacity(0.7))
                        .frame(width: 24)
                    TextField("https://example.com", text: $linkURL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .foregroundColor(textColor)
                }
                .padding(14)
                .background(fieldBg)
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Add Button
    private var addButton: some View {
        Button(action: addScheduleItem) {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                Text("追加")
            }
            .font(.headline.weight(.bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(canAdd ? travelColor : themeManager.currentTheme.secondaryText)
                    .shadow(color: travelColor.opacity(canAdd ? 0.4 : 0), radius: 8, x: 0, y: 4)
            )
            .animation(.easeInOut(duration: 0.2), value: canAdd)
        }
        .disabled(!canAdd)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 32)
        .background(.ultraThinMaterial)
    }

    // MARK: - Helper Views
    @ViewBuilder
    /// 1区切り。
    ///
    /// 以前はセクションごとに影付きのカードを敷いていたが、中の入力欄も箱を持つため
    /// 箱が二重になっていた。面を塗るのはやめて薄い区切り線だけにする。
    /// 予定計画の編集画面（`PlanDetailView.editSection`）と同じ組み
    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 16)

            Rectangle()
                .fill(themeManager.currentTheme.secondaryText.opacity(0.15))
                .frame(height: 1)
        }
    }

    private func sectionLabel(_ text: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundColor(travelColor)
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(textColor)
        }
    }

    private var formattedDayDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日(E)"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: dayDate)
    }

    /// 目的地が海外なら、現地の時計で入れ始める。
    /// 時:分は変えないので、開いた直後に入力欄の時刻が動いて見えることはない
    private func resolveDestinationTimeZone() async {
        guard destinationTimeZone == nil,
              let zone = await DestinationTimeZoneService.shared.timeZone(for: plan),
              ScheduleClock.isForeign(zone, at: dayDate) else { return }
        destinationTimeZone = zone
        time = ScheduleClock.keepingWallClock(time, from: timeZone, to: zone)
        timeZone = zone
    }

    // MARK: - Add Action（即時保存）
    private func addScheduleItem() {
        guard let userId = authVM.userId else { return }

        // viewModelから常に最新のplanを取得（古いスナップショットを使わない）
        let basePlan = viewModel.travelPlans.first(where: { $0.id == plan.id }) ?? plan
        let costs = costInput.result

        let newItem = ScheduleItem(
            time: time,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            location: selectedLocation?.name,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines),
            latitude: selectedCoordinate?.latitude,
            longitude: selectedCoordinate?.longitude,
            cost: costs.cost,
            linkURL: linkURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : linkURL.trimmingCharacters(in: .whitespacesAndNewlines),
            timeZoneIdentifier: timeZone.identifier,
            participantIds: SharedMembers.normalizedParticipants(participants, members: basePlan.sharedWith),
            foreignCost: costs.foreign,
            costNote: costNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil : costNote.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        var updatedPlan = basePlan
        if let dayIndex = updatedPlan.daySchedules.firstIndex(where: { $0.dayNumber == dayNumber }) {
            updatedPlan.daySchedules[dayIndex].scheduleItems.append(newItem)
        } else {
            let newDay = DaySchedule(dayNumber: dayNumber, date: dayDate, scheduleItems: [newItem])
            updatedPlan.daySchedules.append(newDay)
            updatedPlan.daySchedules.sort { $0.dayNumber < $1.dayNumber }
        }

        // 外貨のレートは旅行ごとに1つ。この予定で入れたレートに、同じ通貨の費用をすべて揃える
        if let foreign = newItem.foreignCost, let rate = foreign.rate {
            updatedPlan.setExchangeRate(rate, for: foreign.currencyCode)
        }

        viewModel.update(updatedPlan, userId: userId)
        presentationMode.wrappedValue.dismiss()
    }

    /// 最新の旅行（外貨のレートを読むのに使う）
    private var currentPlan: TravelPlan {
        viewModel.travelPlans.first(where: { $0.id == plan.id }) ?? plan
    }

    /// この旅行で外貨を1種類だけ使っていれば、最初からその通貨にしておく。
    /// 海外旅行では現地の通貨で続けて入れることが多く、毎回選び直すのは手間
    private func preselectTripCurrency() {
        guard !costInput.isForeign, costInput.amountText.isEmpty else { return }
        let foreign = currentPlan.exchangeRates.filter { $0.key != CurrencyCatalog.yen }
        guard foreign.count == 1, let (code, rate) = foreign.first else { return }
        costInput.currencyCode = code
        costInput.rateText = CurrencyCatalog.editingText(rate)
    }

    // MARK: - Location Method Sheet（選択方法）
    private var locationMethodSheet: some View {
        VStack(spacing: 0) {
            Text("場所の選択方法")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(themeManager.currentTheme.secondaryText)
                .padding(.top, 8)
                .padding(.bottom, 16)

            VStack(spacing: 10) {
                methodOptionButton(
                    icon: "clock.arrow.circlepath",
                    title: "検索履歴から",
                    subtitle: locationHistory.history.isEmpty ? "履歴はまだありません" : "最近選んだ\(locationHistory.history.count)件の場所",
                    color: travelColor,
                    disabled: locationHistory.history.isEmpty
                ) {
                    showLocationMethodSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showHistoryPicker = true
                    }
                }

                methodOptionButton(
                    icon: "mappin.and.ellipse",
                    title: "保存した場所から",
                    subtitle: "「場所保存」に貯めた場所を使う",
                    color: travelColor,
                    disabled: false
                ) {
                    showLocationMethodSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showSavedPlacePicker = true
                    }
                }

                methodOptionButton(
                    icon: "map.fill",
                    title: "地図から検索",
                    subtitle: "キーワードで場所を検索して選択",
                    color: travelColor,
                    disabled: false
                ) {
                    showLocationMethodSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showLocationPicker = true
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 20)
        .background(
            colorScheme == .dark
                ? themeManager.currentTheme.secondaryBackgroundDark
                : themeManager.currentTheme.backgroundLight
        )
    }

    private func methodOptionButton(icon: String, title: String, subtitle: String, color: Color, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(disabled ? 0.06 : 0.12))
                        .frame(width: 46, height: 46)
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(disabled ? themeManager.currentTheme.secondaryText : color)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(disabled ? themeManager.currentTheme.secondaryText : (colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(themeManager.currentTheme.secondaryText.opacity(0.4))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(colorScheme == .dark
                          ? themeManager.currentTheme.secondaryBackgroundDark
                          : themeManager.currentTheme.secondaryBackgroundLight)
                    .shadow(color: themeManager.currentTheme.shadow, radius: 4, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
    }

    // MARK: - History Picker
    private var locationHistoryPickerView: some View {
        NavigationView {
            ZStack {
                (colorScheme == .dark
                    ? themeManager.currentTheme.backgroundDark
                    : themeManager.currentTheme.backgroundLight)
                .ignoresSafeArea()

                if locationHistory.history.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 44))
                            .foregroundColor(themeManager.currentTheme.secondaryText.opacity(0.4))
                        Text("検索履歴がありません")
                            .font(.subheadline)
                            .foregroundColor(themeManager.currentTheme.secondaryText)
                    }
                } else {
                    List {
                        ForEach(locationHistory.history) { item in
                            Button(action: {
                                applyHistoryItem(item)
                                showHistoryPicker = false
                            }) {
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(travelColor.opacity(0.12))
                                            .frame(width: 38, height: 38)
                                        Image(systemName: "mappin.circle.fill")
                                            .foregroundColor(travelColor)
                                            .font(.system(size: 18))
                                    }
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.name)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundColor(colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1)
                                        if let address = item.address {
                                            Text(address)
                                                .font(.caption)
                                                .foregroundColor(themeManager.currentTheme.secondaryText)
                                                .lineLimit(1)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.bold))
                                        .foregroundColor(travelColor)
                                        .opacity(0)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .onDelete { indexSet in
                            indexSet.forEach { locationHistory.delete(locationHistory.history[$0]) }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("検索履歴")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") { showHistoryPicker = false }
                        .foregroundColor(travelColor)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !locationHistory.history.isEmpty {
                        Button("履歴を削除") { locationHistory.clear() }
                            .foregroundColor(themeManager.currentTheme.error)
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    /// 保存済みの場所を行き先として設定する。
    /// 次回から検索履歴にも出るよう履歴にも記録しておく
    private func applySavedPlace(_ place: VisitedPlace) {
        let coordinate = place.coordinate
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = place.title

        selectedLocation = mapItem
        selectedCoordinate = coordinate
        selectedAddress = place.address

        locationHistory.add(
            name: place.title,
            address: place.address,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
    }

    private func applyHistoryItem(_ item: LocationHistoryManager.LocationHistoryItem) {
        let coord = CLLocationCoordinate2D(latitude: item.latitude, longitude: item.longitude)
        let placemark = MKPlacemark(coordinate: coord)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = item.name
        selectedLocation = mapItem
        selectedCoordinate = coord
        selectedAddress = item.address
    }

    /// 地図で選んだ場所を、この予定の場所にする
    private func applyPickedPlace(_ picked: PickedPlace) {
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: picked.coordinate))
        mapItem.name = picked.name
        selectedLocation = mapItem
        selectedCoordinate = picked.coordinate
        selectedAddress = picked.address
    }
}
