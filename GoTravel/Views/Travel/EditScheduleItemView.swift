import SwiftUI
import MapKit

// タイムスケジュールの予定編集画面（AddScheduleItemViewと同じデザイン言語）
struct EditScheduleItemView: View {
    // MARK: - Properties
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var viewModel: TravelPlanViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme

    let plan: TravelPlan
    let daySchedule: DaySchedule
    let item: ScheduleItem

    @State private var title: String
    @State private var location: String
    @State private var notes: String
    @State private var time: Date
    @State private var cost: String
    @State private var actualCost: String
    @State private var linkURL: String
    @State private var showDeleteConfirmation = false

    // Location
    @StateObject private var locationHistory = LocationHistoryManager.shared
    @State private var showLocationMethodSheet = false
    @State private var showLocationPicker = false
    @State private var showHistoryPicker = false
    @State private var showSavedPlacePicker = false
    @State private var selectedLocation: MKMapItem?
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var selectedAddress: String?
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    @State private var mapPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 36.2048, longitude: 138.2529),
        span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
    ))
    @State private var selectedMapResult: MKMapItem?
    @State private var mapVisibleRegion: MKCoordinateRegion?
    @State private var hasCenteredOnDestination = false

    // MARK: - Initialization
    init(plan: TravelPlan, daySchedule: DaySchedule, item: ScheduleItem) {
        self.plan = plan
        self.daySchedule = daySchedule
        self.item = item

        _title = State(initialValue: item.title)
        _location = State(initialValue: item.location ?? "")
        _notes = State(initialValue: item.notes ?? "")
        _time = State(initialValue: item.time)
        _cost = State(initialValue: item.cost != nil ? String(Int(item.cost!)) : "")
        _actualCost = State(initialValue: item.actualCost != nil ? String(Int(item.actualCost!)) : "")
        _linkURL = State(initialValue: item.linkURL ?? "")

        // 既存の場所情報を選択済み状態として復元
        if let lat = item.latitude, let lon = item.longitude {
            let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coord))
            mapItem.name = item.location
            _selectedLocation = State(initialValue: mapItem)
            _selectedCoordinate = State(initialValue: coord)
            _selectedAddress = State(initialValue: nil)
        }
    }

    // MARK: - Computed
    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    /// 地図と検索の起点（`AddScheduleItemView` と同じ理由・同じ内容）
    private var searchStartRegion: MKCoordinateRegion {
        guard let latitude = plan.latitude, let longitude = plan.longitude else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 36.2048, longitude: 138.2529),
                span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
            )
        }
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    }

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

    private var cardBg: Color {
        colorScheme == .dark ? themeManager.currentTheme.secondaryBackgroundDark : themeManager.currentTheme.secondaryBackgroundLight
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
                    VStack(spacing: 14) {
                        titleSection
                        timeSection
                        locationSection
                        optionalSection
                        deleteRow
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }

                saveButton
            }
        }
        .alert("予定を削除しますか？", isPresented: $showDeleteConfirmation) {
            Button("キャンセル", role: .cancel) { }
            Button("削除", role: .destructive) {
                deleteScheduleItem()
            }
        } message: {
            Text("この操作は取り消せません")
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
        .fullScreenCover(isPresented: $showLocationPicker) {
            locationPickerView
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
                Text("予定を編集")
                    .font(.headline)
                    .foregroundColor(textColor)
                Text("Day \(daySchedule.dayNumber) · \(formattedDayDate)")
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
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(travelColor.opacity(0.8))
                        .frame(width: 24)
                    Text("時刻")
                        .font(.subheadline)
                        .foregroundColor(textColor)
                    Spacer()
                    DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                        .colorMultiply(travelColor)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                }
                .padding(14)
                .background(fieldBg)
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Location Section
    private var locationSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("場所（任意）", icon: "mappin.circle.fill")

                if selectedLocation != nil || !location.isEmpty {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(travelColor)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedLocation?.name ?? (location.isEmpty ? "場所" : location))
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(textColor)
                            if let address = selectedAddress ?? selectedLocation?.placemark.title {
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
                            location = ""
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

                HStack(spacing: 12) {
                    Image(systemName: "yensign.circle")
                        .foregroundColor(travelColor.opacity(0.7))
                        .frame(width: 24)
                    TextField("予算", text: $cost)
                        .keyboardType(.decimalPad)
                        .foregroundColor(textColor)
                    Text("円")
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                }
                .padding(14)
                .background(fieldBg)
                .cornerRadius(12)

                // 旅行後に実際いくら使ったかを記録する欄
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(themeManager.currentTheme.success.opacity(0.8))
                        .frame(width: 24)
                    TextField("実際に使った金額", text: $actualCost)
                        .keyboardType(.decimalPad)
                        .foregroundColor(textColor)
                    Text("円")
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                }
                .padding(14)
                .background(fieldBg)
                .cornerRadius(12)

                if let diff = costDifference {
                    Text(diff > 0
                         ? "予算より \(Int(diff))円 多く使いました"
                         : (diff < 0 ? "予算より \(Int(-diff))円 少なく済みました" : "予算どおりです"))
                        .font(.caption)
                        .foregroundColor(diff > 0 ? themeManager.currentTheme.error : themeManager.currentTheme.success)
                }

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

    // MARK: - Delete Row
    private var deleteRow: some View {
        Button(action: { showDeleteConfirmation = true }) {
            HStack(spacing: 6) {
                Image(systemName: "trash")
                Text("この予定を削除")
            }
            .font(.subheadline.weight(.medium))
            .foregroundColor(themeManager.currentTheme.error)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(themeManager.currentTheme.error.opacity(0.08))
            )
        }
        .padding(.top, 8)
    }

    // MARK: - Save Button
    private var saveButton: some View {
        Button(action: saveScheduleItem) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                Text("保存")
            }
            .font(.headline.weight(.bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(canSave ? travelColor : themeManager.currentTheme.secondaryText)
                    .shadow(color: travelColor.opacity(canSave ? 0.4 : 0), radius: 8, x: 0, y: 4)
            )
            .animation(.easeInOut(duration: 0.2), value: canSave)
        }
        .disabled(!canSave)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 32)
        .background(.ultraThinMaterial)
    }

    // MARK: - Helper Views
    @ViewBuilder
    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardBg)
                    .shadow(color: themeManager.currentTheme.shadow, radius: 6, x: 0, y: 2)
            )
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
        let formatter = DateFormatter.japanese
        formatter.dateFormat = "M月d日(E)"
        return formatter.string(from: daySchedule.date)
    }

    // MARK: - Actions
    private func saveScheduleItem() {
        guard let userId = authVM.userId else { return }

        let updatedItem = createUpdatedItem()
        let updatedPlan = updatePlanWithItem(updatedItem)

        viewModel.update(updatedPlan, userId: userId)
        presentationMode.wrappedValue.dismiss()
    }

    private func createUpdatedItem() -> ScheduleItem {
        let costValue = cost.isEmpty ? nil : Double(cost)
        let locationName = selectedLocation?.name ?? (location.isEmpty ? nil : location.trimmingCharacters(in: .whitespacesAndNewlines))

        return ScheduleItem(
            id: item.id,
            time: time,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            location: locationName,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines),
            latitude: selectedCoordinate?.latitude,
            longitude: selectedCoordinate?.longitude,
            cost: costValue,
            actualCost: actualCost.isEmpty ? nil : Double(actualCost),
            linkURL: linkURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : linkURL.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    /// 実績 - 予算。どちらかが未入力なら比較しない
    private var costDifference: Double? {
        guard let budget = Double(cost), let actual = Double(actualCost) else { return nil }
        return actual - budget
    }

    private func updatePlanWithItem(_ updatedItem: ScheduleItem) -> TravelPlan {
        // viewModelから常に最新のplanを取得（古いスナップショットで他の変更を潰さない）
        var updatedPlan = viewModel.travelPlans.first(where: { $0.id == plan.id }) ?? plan

        if let dayIndex = updatedPlan.daySchedules.firstIndex(where: { $0.id == daySchedule.id }) {
            if let itemIndex = updatedPlan.daySchedules[dayIndex].scheduleItems.firstIndex(where: { $0.id == item.id }) {
                updatedPlan.daySchedules[dayIndex].scheduleItems[itemIndex] = updatedItem
            }
        }

        return updatedPlan
    }

    private func deleteScheduleItem() {
        guard let userId = authVM.userId else { return }

        var updatedPlan = viewModel.travelPlans.first(where: { $0.id == plan.id }) ?? plan
        if let dayIndex = updatedPlan.daySchedules.firstIndex(where: { $0.id == daySchedule.id }) {
            updatedPlan.daySchedules[dayIndex].scheduleItems.removeAll(where: { $0.id == item.id })
        }

        viewModel.update(updatedPlan, userId: userId)
        presentationMode.wrappedValue.dismiss()
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
                        .foregroundColor(disabled ? themeManager.currentTheme.secondaryText : textColor)
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
                        ForEach(locationHistory.history) { historyItem in
                            Button(action: {
                                applyHistoryItem(historyItem)
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
                                        Text(historyItem.name)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundColor(textColor)
                                        if let address = historyItem.address {
                                            Text(address)
                                                .font(.caption)
                                                .foregroundColor(themeManager.currentTheme.secondaryText)
                                                .lineLimit(1)
                                        }
                                    }
                                    Spacer()
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

    private func applyHistoryItem(_ historyItem: LocationHistoryManager.LocationHistoryItem) {
        let coord = CLLocationCoordinate2D(latitude: historyItem.latitude, longitude: historyItem.longitude)
        let placemark = MKPlacemark(coordinate: coord)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = historyItem.name
        selectedLocation = mapItem
        selectedCoordinate = coord
        selectedAddress = historyItem.address
        location = historyItem.name
    }

    // MARK: - Map Location Picker（地図から検索）
    private var locationPickerView: some View {
        ZStack(alignment: .top) {
            Map(position: $mapPosition, selection: $selectedMapResult) {
                ForEach(searchResults, id: \.self) { result in
                    Marker(item: result).tint(themeManager.currentTheme.error)
                }
            }
            .ignoresSafeArea()
            .safeAreaInset(edge: .bottom) {
                if let result = selectedMapResult {
                    locationResultDetail(result)
                }
            }
            .onMapCameraChange { context in mapVisibleRegion = context.region }
            // 初回だけ寄せる。すでに場所が入っている予定はその場所、
            // 入っていなければ旅行の目的地。2回目以降は前に見ていた場所のまま
            .onAppear {
                guard !hasCenteredOnDestination else { return }
                hasCenteredOnDestination = true

                let region: MKCoordinateRegion
                if let coordinate = selectedCoordinate {
                    region = MKCoordinateRegion(
                        center: coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
                } else {
                    region = searchStartRegion
                }

                mapPosition = .region(region)
                mapVisibleRegion = region
            }

            VStack(spacing: 0) {
                // ヘッダー
                HStack {
                    Button(action: {
                        showLocationPicker = false
                        searchText = ""
                        searchResults = []
                        selectedMapResult = nil
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(textColor)
                            .padding(10)
                            .background(Color(.systemBackground).opacity(0.9))
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("地図から検索")
                        .font(.headline)
                        .foregroundColor(textColor)
                    Spacer()
                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)

                // 検索バー
                HStack(spacing: 10) {
                    Image(systemName: isSearching ? "clock" : "magnifyingglass")
                        .foregroundColor(travelColor)
                        .font(.system(size: 15))
                    TextField("場所・スポット名を入力", text: $searchText)
                        .font(.subheadline)
                        .onSubmit { Task { await performSearch() } }
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            searchResults = []
                            selectedMapResult = nil
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(themeManager.currentTheme.secondaryText)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)

                // 検索結果リスト
                if !searchResults.isEmpty && selectedMapResult == nil {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            ForEach(searchResults, id: \.self) { result in
                                Button(action: {
                                    withAnimation {
                                        selectedMapResult = result
                                        mapPosition = .region(MKCoordinateRegion(
                                            center: result.placemark.coordinate,
                                            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                                        ))
                                        searchResults = [result]
                                    }
                                }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "mappin.circle.fill")
                                            .foregroundColor(themeManager.currentTheme.error)
                                            .font(.system(size: 22))
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(result.name ?? "名称なし")
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundColor(textColor)
                                            if let address = result.placemark.title {
                                                Text(address)
                                                    .font(.caption)
                                                    .foregroundColor(themeManager.currentTheme.secondaryText)
                                                    .lineLimit(1)
                                            }
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption2)
                                            .foregroundColor(themeManager.currentTheme.secondaryText.opacity(0.5))
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                                .buttonStyle(PlainButtonStyle())
                                Divider().padding(.leading, 56)
                            }
                        }
                    }
                    .background(Color(.systemBackground))
                    .frame(height: min(CGFloat(searchResults.count) * 65, 300))
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: searchResults.isEmpty)
    }

    private func performSearch() async {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearching = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.resultTypes = [.pointOfInterest, .address]
        request.region = mapVisibleRegion ?? searchStartRegion
        do {
            let response = try await MKLocalSearch(request: request).start()
            searchResults = response.mapItems
            selectedMapResult = nil
            if let first = searchResults.first {
                withAnimation {
                    mapPosition = .region(MKCoordinateRegion(
                        center: first.placemark.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                    ))
                }
            }
        } catch {}
        isSearching = false
    }

    private func locationResultDetail(_ result: MKMapItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(themeManager.currentTheme.error.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(themeManager.currentTheme.error)
                        .font(.system(size: 22))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.name ?? "名称なし")
                        .font(.headline)
                        .foregroundColor(textColor)
                    if let address = result.placemark.title {
                        Text(address)
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.secondaryText)
                            .lineLimit(2)
                    }
                }
                Spacer()
                Button(action: { selectedMapResult = nil; searchResults = [] }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                        .font(.title3)
                }
            }

            HStack(spacing: 10) {
                Button { result.openInMaps() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond")
                        Text("経路")
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(travelColor.opacity(0.1))
                    .foregroundColor(travelColor)
                    .cornerRadius(12)
                }
                Button {
                    selectedLocation = result
                    selectedCoordinate = result.placemark.coordinate
                    selectedAddress = result.placemark.title
                    location = result.name ?? ""
                    if let name = result.name, let coord = result.placemark.location?.coordinate {
                        locationHistory.add(
                            name: name,
                            address: result.placemark.title,
                            latitude: coord.latitude,
                            longitude: coord.longitude
                        )
                    }
                    selectedMapResult = nil
                    searchResults = []
                    searchText = ""
                    showLocationPicker = false
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("この場所を選択")
                    }
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(travelColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
        }
        .padding(18)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.15), radius: 14, x: 0, y: -4)
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
    }
}
