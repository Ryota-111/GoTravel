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
    @State private var showLocationPicker = false
    @State private var selectedLocation: MKMapItem?
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var selectedAddress: String?
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
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
                    Button(action: { showLocationPicker = true }) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(travelColor.opacity(0.7))
                                .frame(width: 24)
                            Text("場所を検索")
                                .font(.subheadline)
                                .foregroundColor(themeManager.currentTheme.secondaryText)
                            Spacer()
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

    // MARK: - Location Picker
    private var locationPickerView: some View {
        NavigationView {
            ZStack {
                Map(position: $mapPosition, selection: $selectedMapResult) {
                    ForEach(searchResults, id: \.self) { result in
                        Marker(item: result).tint(themeManager.currentTheme.error)
                    }
                }
                .safeAreaInset(edge: .top) { locationSearchBar }
                .safeAreaInset(edge: .bottom) {
                    if let result = selectedMapResult {
                        locationResultDetail(result)
                    }
                }
                .onMapCameraChange { context in mapVisibleRegion = context.region }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") { showLocationPicker = false }
                }
            }
        }
    }

    private var locationSearchBar: some View {
        TextField("場所を検索", text: $searchText)
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .onSubmit { Task { await performSearch() } }
    }

    private func performSearch() async {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.resultTypes = .pointOfInterest
        request.region = mapVisibleRegion ?? MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 36.2048, longitude: 138.2529),
            span: MKCoordinateSpan(latitudeDelta: 0.0125, longitudeDelta: 0.0125)
        )
        do {
            let response = try await MKLocalSearch(request: request).start()
            searchResults = response.mapItems
            if let first = searchResults.first {
                withAnimation {
                    mapPosition = .region(MKCoordinateRegion(
                        center: first.placemark.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    ))
                }
            }
            searchText = ""
        } catch {}
    }

    private func locationResultDetail(_ result: MKMapItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.name ?? "名称なし")
                        .font(.title3.weight(.bold))
                    if let address = result.placemark.title {
                        Text(address)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
            }

            HStack(spacing: 12) {
                Button { result.openInMaps() } label: {
                    Label("経路", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(themeManager.currentTheme.primary.opacity(0.1))
                        .foregroundStyle(themeManager.currentTheme.primary)
                        .cornerRadius(10)
                }
                Button {
                    selectedLocation = result
                    selectedCoordinate = result.placemark.coordinate
                    selectedAddress = result.placemark.title
                    selectedMapResult = nil
                    showLocationPicker = false
                } label: {
                    Label("この場所を選択", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(travelColor.opacity(0.15))
                        .foregroundStyle(travelColor)
                        .cornerRadius(10)
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: -4)
        .padding(.horizontal)
        .padding(.bottom, 12)
    }
}
