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
    @State private var cost = ""
    @State private var notes = ""
    @State private var linkURL = ""

    // Location
    @StateObject private var locationHistory = LocationHistoryManager.shared
    @State private var showLocationMethodSheet = false
    @State private var showLocationPicker = false
    @State private var showHistoryPicker = false
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
                        dayInfoCard
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
                .presentationDetents([.height(220)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showHistoryPicker) {
            locationHistoryPickerView
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

    // MARK: - Day Info Card
    private var dayInfoCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(travelColor.opacity(0.15))
                    .frame(width: 50, height: 50)
                Text("\(dayNumber)")
                    .font(.title2.weight(.bold))
                    .foregroundColor(travelColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Day \(dayNumber)")
                    .font(.headline.weight(.bold))
                    .foregroundColor(textColor)
                Text(formattedDayDate)
                    .font(.subheadline)
                    .foregroundColor(themeManager.currentTheme.secondaryText)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBg)
                .shadow(color: themeManager.currentTheme.shadow, radius: 6, x: 0, y: 2)
        )
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

                HStack(spacing: 12) {
                    Image(systemName: "yensign.circle")
                        .foregroundColor(travelColor.opacity(0.7))
                        .frame(width: 24)
                    TextField("金額", text: $cost)
                        .keyboardType(.decimalPad)
                        .foregroundColor(textColor)
                    Text("円")
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                }
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
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日(E)"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: dayDate)
    }

    // MARK: - Add Action（即時保存）
    private func addScheduleItem() {
        guard let userId = authVM.userId else { return }

        // viewModelから常に最新のplanを取得（古いスナップショットを使わない）
        let basePlan = viewModel.travelPlans.first(where: { $0.id == plan.id }) ?? plan

        let newItem = ScheduleItem(
            time: time,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            location: selectedLocation?.name,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines),
            latitude: selectedCoordinate?.latitude,
            longitude: selectedCoordinate?.longitude,
            cost: cost.isEmpty ? nil : Double(cost),
            linkURL: linkURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : linkURL.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        var updatedPlan = basePlan
        if let dayIndex = updatedPlan.daySchedules.firstIndex(where: { $0.dayNumber == dayNumber }) {
            updatedPlan.daySchedules[dayIndex].scheduleItems.append(newItem)
        } else {
            let newDay = DaySchedule(dayNumber: dayNumber, date: dayDate, scheduleItems: [newItem])
            updatedPlan.daySchedules.append(newDay)
            updatedPlan.daySchedules.sort { $0.dayNumber < $1.dayNumber }
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

    // MARK: - Map Location Picker（地図から検索）
    private var locationPickerView: some View {
        ZStack(alignment: .top) {
            // 地図
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
                            .foregroundColor(colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1)
                            .padding(10)
                            .background(Color(.systemBackground).opacity(0.9))
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("地図から検索")
                        .font(.headline)
                        .foregroundColor(colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1)
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
                                                .foregroundColor(colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1)
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
                    .frame(maxHeight: 300)
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
        request.region = mapVisibleRegion ?? MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 36.2048, longitude: 138.2529),
            span: MKCoordinateSpan(latitudeDelta: 5, longitudeDelta: 5)
        )
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
                        .foregroundColor(colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1)
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
