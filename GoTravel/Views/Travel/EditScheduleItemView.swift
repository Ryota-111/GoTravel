import SwiftUI
import MapKit

// TravelPlanCardのスケジュール編集画面
struct EditScheduleItemView: View {
    // MARK: - Properties
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var viewModel: TravelPlanViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject var themeManager = ThemeManager.shared

    let plan: TravelPlan
    let daySchedule: DaySchedule
    let item: ScheduleItem

    @State private var title: String
    @State private var location: String
    @State private var notes: String
    @State private var time: Date
    @State private var cost: String
    @State private var linkURL: String
    @State private var isSaving = false
    @State private var showDeleteConfirmation = false

    // Location search properties
    @State private var showLocationPicker = false
    @State private var searchText: String = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var selectedLocation: MKMapItem?
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var selectedAddress: String?

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
        _linkURL = State(initialValue: item.linkURL ?? "")

        // Initialize location data if it exists
        if let lat = item.latitude, let lon = item.longitude {
            _selectedCoordinate = State(initialValue: CLLocationCoordinate2D(latitude: lat, longitude: lon))
            if let loc = item.location {
                _selectedAddress = State(initialValue: loc)
            }
        }
    }

    // MARK: - Computed Properties
    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [themeManager.currentTheme.primary.opacity(0.9), Color.black]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient
                scrollContent
            }
            .navigationTitle("予定を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    cancelButton
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    saveButton
                }
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
    }

    // MARK: - View Components
    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                dayInfoCard
                formSection
                deleteButton
            }
            .padding()
        }
        .background(Color.clear)
        .onTapGesture {
            hideKeyboard()
        }
    }

    private var dayInfoCard: some View {
        VStack(spacing: 10) {
            Text("Day \(daySchedule.dayNumber)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text(formatDate(daySchedule.date))
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.2))
        .cornerRadius(15)
    }

    private var formSection: some View {
        VStack(spacing: 15) {
            customTextField(icon: "text.alignleft", placeholder: "タイトル（例：浅草寺観光）", text: $title)
            locationSection
            costField
            customTextField(icon: "link", placeholder: "リンク（任意）", text: $linkURL)
            notesField
            timePickerField
        }
        .padding()
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if selectedCoordinate != nil {
                selectedLocationCard
            } else {
                Button(action: { showLocationPicker = true }) {
                    HStack {
                        Image(systemName: "mappin.circle")
                            .foregroundColor(.white.opacity(0.7))
                        Text("場所を検索")
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding()
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(10)
                }
            }
        }
        .fullScreenCover(isPresented: $showLocationPicker) {
            locationPickerView
        }
    }

    private var selectedLocationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(location.isEmpty ? "場所" : location)
                        .font(.headline)
                        .foregroundColor(.white)

                    if let address = selectedAddress, !address.isEmpty {
                        Text(address)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
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
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.2))
        .cornerRadius(10)
    }

    private var costField: some View {
        HStack {
            Image(systemName: "yensign.circle")
                .foregroundColor(.white.opacity(0.7))
            TextField("金額（任意）", text: $cost)
                .foregroundColor(.white)
                .keyboardType(.decimalPad)
            Text("円")
                .foregroundColor(.white.opacity(0.7))
        }
        .padding()
        .background(Color.white.opacity(0.2))
        .cornerRadius(10)
    }

    private var notesField: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "note.text")
                    .foregroundColor(.white.opacity(0.7))
                Text("メモ")
                    .foregroundColor(.white.opacity(0.7))
            }
            TextEditor(text: $notes)
                .frame(height: 100)
                .foregroundColor(.white)
                .scrollContentBackground(.hidden)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
        }
        .padding()
        .background(Color.white.opacity(0.2))
        .cornerRadius(10)
    }

    private var timePickerField: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("時間")
                .foregroundColor(.white)
                .font(.headline)
            DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                .datePickerStyle(WheelDatePickerStyle())
                .labelsHidden()
        }
        .padding()
        .background(Color.white.opacity(0.2))
        .cornerRadius(10)
    }

    private var deleteButton: some View {
        Button(action: { showDeleteConfirmation = true }) {
            HStack {
                Image(systemName: "trash")
                Text("予定を削除")
            }
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(themeManager.currentTheme.error.opacity(0.8))
            .cornerRadius(10)
        }
        .padding()
    }

    private var cancelButton: some View {
        Button("キャンセル") {
            presentationMode.wrappedValue.dismiss()
        }
        .foregroundColor(themeManager.currentTheme.error)
    }

    private var saveButton: some View {
        Button(action: saveScheduleItem) {
            if isSaving {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else {
                Text("保存")
                    .foregroundColor(themeManager.currentTheme.primary)
            }
        }
        .disabled(!isFormValid || isSaving)
    }

    // MARK: - Helper Views
    private func customTextField(icon: String, placeholder: String, text: Binding<String>) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.white.opacity(0.7))
            TextField(placeholder, text: text)
                .foregroundColor(.white)
        }
        .padding()
        .background(Color.white.opacity(0.2))
        .cornerRadius(10)
    }

    // MARK: - Helper Methods
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter.japanese
        formatter.dateFormat = "M月d日(E)"
        return formatter.string(from: date)
    }

    // MARK: - Actions
    private func saveScheduleItem() {
        isSaving = true

        let updatedItem = createUpdatedItem()
        let updatedPlan = updatePlanWithItem(updatedItem)

        if let userId = authVM.userId {
            viewModel.update(updatedPlan, userId: userId)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSaving = false
            presentationMode.wrappedValue.dismiss()
        }
    }

    private func createUpdatedItem() -> ScheduleItem {
        let costValue = cost.isEmpty ? nil : Double(cost)

        return ScheduleItem(
            id: item.id,
            time: time,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            location: selectedLocation?.name ?? (location.isEmpty ? nil : location.trimmingCharacters(in: .whitespacesAndNewlines)),
            notes: notes.isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines),
            latitude: selectedCoordinate?.latitude,
            longitude: selectedCoordinate?.longitude,
            cost: costValue,
            linkURL: linkURL.isEmpty ? nil : linkURL.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    // MARK: - Location Picker View
    @State private var mapPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 36.2048, longitude: 138.2529),
        span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
    ))
    @State private var selectedMapResult: MKMapItem?
    @State private var mapVisibleRegion: MKCoordinateRegion?

    private var locationPickerView: some View {
        NavigationView {
            ZStack {
                Map(position: $mapPosition, selection: $selectedMapResult) {
                    ForEach(searchResults, id: \.self) { result in
                        Marker(item: result)
                            .tint(themeManager.currentTheme.error)
                    }
                }
                .safeAreaInset(edge: .top) {
                    locationSearchBarView
                }
                .safeAreaInset(edge: .bottom) {
                    if let selectedResult = selectedMapResult {
                        locationSelectedResultDetailView(selectedResult)
                    }
                }
                .onMapCameraChange { context in
                    mapVisibleRegion = context.region
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        showLocationPicker = false
                    }
                }
            }
        }
    }

    private var locationSearchBarView: some View {
        TextField("場所を検索", text: $searchText)
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .onSubmit {
                Task {
                    await performLocationSearch()
                }
            }
    }

    private func performLocationSearch() async {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.resultTypes = .pointOfInterest
        request.region = mapVisibleRegion ?? MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 36.2048, longitude: 138.2529),
            span: MKCoordinateSpan(latitudeDelta: 0.0125, longitudeDelta: 0.0125)
        )

        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            searchResults = response.mapItems
            if let firstResult = searchResults.first {
                withAnimation {
                    mapPosition = .region(MKCoordinateRegion(
                        center: firstResult.placemark.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    ))
                }
            }
            searchText = ""
        } catch {
        }
    }

    private func locationSelectedResultDetailView(_ result: MKMapItem) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(result.name ?? "名称なし")
                        .font(.title2)
                        .fontWeight(.bold)

                    if let category = result.pointOfInterestCategory?.rawValue {
                        Text(category)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }

            if let address = result.placemark.title {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundStyle(themeManager.currentTheme.error)
                        .font(.title3)
                    Text(address)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let phoneNumber = result.phoneNumber {
                HStack(spacing: 8) {
                    Image(systemName: "phone.circle.fill")
                        .foregroundStyle(themeManager.currentTheme.success)
                        .font(.title3)
                    Text(phoneNumber)
                        .font(.subheadline)
                    Spacer()
                    Button {
                        if let url = URL(string: "tel:\(phoneNumber.replacingOccurrences(of: " ", with: ""))") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text("電話")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(themeManager.currentTheme.success)
                            .foregroundStyle(.white)
                            .cornerRadius(8)
                    }
                }
            }

            if let url = result.url {
                HStack(spacing: 8) {
                    Image(systemName: "safari.fill")
                        .foregroundStyle(themeManager.currentTheme.primary)
                        .font(.title3)
                    Text(url.host ?? "Website")
                        .font(.subheadline)
                        .lineLimit(1)
                    Spacer()
                    Button {
                        UIApplication.shared.open(url)
                    } label: {
                        Text("開く")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(themeManager.currentTheme.primary)
                            .foregroundStyle(.white)
                            .cornerRadius(8)
                    }
                }
            }

            Divider()

            HStack(spacing: 12) {
                Button {
                    result.openInMaps()
                } label: {
                    Label("経路", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(themeManager.currentTheme.primary.opacity(0.1))
                        .foregroundStyle(themeManager.currentTheme.primary)
                        .cornerRadius(10)
                }

                Button {
                    selectLocationFromMapResult(result)
                } label: {
                    Label("選択", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(themeManager.currentTheme.accent1.opacity(0.1))
                        .foregroundStyle(themeManager.currentTheme.accent1)
                        .cornerRadius(10)
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: -4)
        .padding(.horizontal)
        .padding(.bottom, 12)
    }

    private func selectLocationFromMapResult(_ result: MKMapItem) {
        selectedLocation = result
        selectedCoordinate = result.placemark.coordinate
        selectedAddress = result.placemark.title
        location = result.name ?? ""
        selectedMapResult = nil
        showLocationPicker = false
    }

    private func updatePlanWithItem(_ updatedItem: ScheduleItem) -> TravelPlan {
        var updatedPlan = plan

        if let dayIndex = updatedPlan.daySchedules.firstIndex(where: { $0.id == daySchedule.id }) {
            if let itemIndex = updatedPlan.daySchedules[dayIndex].scheduleItems.firstIndex(where: { $0.id == item.id }) {
                updatedPlan.daySchedules[dayIndex].scheduleItems[itemIndex] = updatedItem
            }
        }

        return updatedPlan
    }

    private func deleteScheduleItem() {
        isSaving = true

        let updatedPlan = removePlaceFromPlan()

        if let userId = authVM.userId {
            viewModel.update(updatedPlan, userId: userId)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSaving = false
            presentationMode.wrappedValue.dismiss()
        }
    }

    private func removePlaceFromPlan() -> TravelPlan {
        var updatedPlan = plan

        if let dayIndex = updatedPlan.daySchedules.firstIndex(where: { $0.id == daySchedule.id }) {
            updatedPlan.daySchedules[dayIndex].scheduleItems.removeAll(where: { $0.id == item.id })
        }

        return updatedPlan
    }
}
