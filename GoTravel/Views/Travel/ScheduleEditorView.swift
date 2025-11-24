import SwiftUI
import MapKit

// Day""のスケジュールの右＋ボタンの遷移先画面
struct ScheduleEditorView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var viewModel: TravelPlanViewModel
    @EnvironmentObject var authVM: AuthViewModel

    let plan: TravelPlan
    @State private var daySchedules: [DaySchedule]
    @State private var selectedDay: Int = 1
    @State private var showAddScheduleItem = false
    @State private var isSaving = false

    init(plan: TravelPlan) {
        self.plan = plan
        _daySchedules = State(initialValue: plan.daySchedules)
    }

    var tripDuration: Int {
        let days = Calendar.current.dateComponents([.day], from: plan.startDate, to: plan.endDate).day ?? 0
        return days + 1
    }

    var currentDaySchedule: DaySchedule? {
        daySchedules.first(where: { $0.dayNumber == selectedDay })
    }

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: colorScheme == .dark ? [Color.blue.opacity(0.7), Color.black] : [Color.blue.opacity(0.8), Color.white]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    headerView

                    ScrollView {
                        VStack(spacing: 20) {
                            planInfoCard
                            daySelectionTabs
                            scheduleItemsList
                        }
                        .padding()
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }

    private var headerView: some View {
        HStack {
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.white)
                    .imageScale(.large)
                Text("戻る")
                    .foregroundColor(.white)
            }

            Spacer()

            Text("スケジュール編集")
                .font(.headline)
                .foregroundColor(.white)

            Spacer()

            Button(action: saveSchedule) {
                if isSaving {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("保存")
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                }
            }
            .disabled(isSaving)
        }
        .padding()
        .background(Color.black.opacity(0.2))
    }

    private var planInfoCard: some View {
        VStack(spacing: 10) {
            Text(plan.title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(colorScheme == .dark ? .white : .black)

            HStack(spacing: 15) {
                HStack(spacing: 5) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.orange)
                    Text(plan.destination)
                        .font(.subheadline)
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .gray)
                }

                HStack(spacing: 5) {
                    Image(systemName: "calendar")
                        .foregroundColor(.orange)
                    Text(dateRangeString)
                        .font(.subheadline)
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .gray)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.2))
        .cornerRadius(15)
    }

    private var daySelectionTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(1...tripDuration, id: \.self) { day in
                    Button(action: {
                        withAnimation(.spring()) {
                            selectedDay = day
                        }
                    }) {
                        VStack(spacing: 5) {
                            Text("Day \(day)")
                                .font(.headline)
                                .foregroundColor(selectedDay == day ? .white : (colorScheme == .dark ? .white.opacity(0.6) : .gray))

                            if let daySchedule = daySchedules.first(where: { $0.dayNumber == day }) {
                                Text("\(daySchedule.scheduleItems.count)件")
                                    .font(.caption2)
                                    .foregroundColor(selectedDay == day ? .white.opacity(0.8) : (colorScheme == .dark ? .white.opacity(0.5) : .gray.opacity(0.7)))
                            } else {
                                Text("0件")
                                    .font(.caption2)
                                    .foregroundColor(selectedDay == day ? .white.opacity(0.8) : (colorScheme == .dark ? .white.opacity(0.5) : .gray.opacity(0.7)))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(selectedDay == day ? Color.orange : Color.white.opacity(0.3))
                        )
                    }
                }
            }
        }
    }

    private var scheduleItemsList: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("Day \(selectedDay)の予定")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(colorScheme == .dark ? .white : .black)

                Spacer()

                Button(action: { showAddScheduleItem = true }) {
                    HStack(spacing: 5) {
                        Image(systemName: "plus.circle.fill")
                        Text("追加")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.orange)
                }
            }

            if let currentSchedule = currentDaySchedule {
                if currentSchedule.scheduleItems.isEmpty {
                    emptyScheduleView
                } else {
                    ForEach(sortedScheduleItems(currentSchedule.scheduleItems)) { item in
                        ScheduleItemEditCard(
                            item: item,
                            colorScheme: colorScheme,
                            plan: plan,
                            onDelete: {
                                deleteScheduleItem(item)
                            },
                            onEdit: {
                                // 編集機能は後で追加可能
                            }
                        )
                    }
                }
            } else {
                emptyScheduleView
            }
        }
        .padding()
        .background(Color.white.opacity(0.2))
        .cornerRadius(15)
        .sheet(isPresented: $showAddScheduleItem) {
            AddScheduleItemToEditorView(
                dayNumber: selectedDay,
                daySchedules: $daySchedules,
                plan: plan
            )
        }
    }

    private var emptyScheduleView: some View {
        VStack(spacing: 15) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 50))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.5) : .gray.opacity(0.5))

            Text("まだ予定がありません")
                .font(.subheadline)
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .gray)

            Button(action: { showAddScheduleItem = true }) {
                Text("最初の予定を追加")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(.orange)
                    .cornerRadius(25)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color.white.opacity(0.1))
        .cornerRadius(15)
    }

    private var dateRangeString: String {
        let formatter = DateFormatter.japanese
        formatter.dateFormat = "M/d"
        return "\(formatter.string(from: plan.startDate)) - \(formatter.string(from: plan.endDate))"
    }

    private func sortedScheduleItems(_ items: [ScheduleItem]) -> [ScheduleItem] {
        let calendar = Calendar.current

        return items.sorted { item1, item2 in
            // Extract hour and minute components only (ignore date)
            let components1 = calendar.dateComponents([.hour, .minute], from: item1.time)
            let components2 = calendar.dateComponents([.hour, .minute], from: item2.time)

            let hour1 = components1.hour ?? 0
            let minute1 = components1.minute ?? 0
            let hour2 = components2.hour ?? 0
            let minute2 = components2.minute ?? 0

            // Compare by hour first, then by minute
            if hour1 != hour2 {
                return hour1 < hour2
            } else {
                return minute1 < minute2
            }
        }
    }

    private func deleteScheduleItem(_ item: ScheduleItem) {
        if let dayIndex = daySchedules.firstIndex(where: { $0.dayNumber == selectedDay }) {
            daySchedules[dayIndex].scheduleItems.removeAll(where: { $0.id == item.id })
        }
    }

    private func saveSchedule() {
        isSaving = true

        var updatedPlan = plan
        updatedPlan.daySchedules = daySchedules

        if let userId = authVM.userId {
            viewModel.update(updatedPlan, userId: userId)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSaving = false
            presentationMode.wrappedValue.dismiss()
        }
    }
}

struct ScheduleItemEditCard: View {
    let item: ScheduleItem
    let colorScheme: ColorScheme
    let plan: TravelPlan
    let onDelete: () -> Void
    let onEdit: () -> Void

    @State private var showSaveAsVisited = false
    @State private var showMapView = false

    private var hasLocationData: Bool {
        item.latitude != nil && item.longitude != nil
    }

    var body: some View {
        HStack(spacing: 15) {
            VStack(spacing: 5) {
                Text(formatTime(item.time))
                    .font(.headline)
                    .foregroundColor(.orange)

                Image(systemName: "clock.fill")
                    .foregroundColor(.orange.opacity(0.7))
                    .font(.caption)
            }
            .frame(width: 60)

            VStack(alignment: .leading, spacing: 8) {
                Text(item.title)
                    .font(.headline)
                    .foregroundColor(colorScheme == .dark ? .white : .black)

                if let location = item.location {
                    HStack(spacing: 5) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text(location)
                            .font(.subheadline)
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.7))
                    }
                }

                if let notes = item.notes {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .gray)
                        .lineLimit(2)
                }
            }

            Spacer()

            VStack(spacing: 12) {
                if hasLocationData {
                    Button(action: { showMapView = true }) {
                        Image(systemName: "map.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.green)
                    }
                    .buttonStyle(.borderless)
                }

                Button(action: { showSaveAsVisited = true }) {
                    Image(systemName: "bookmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.orange)
                }
                .buttonStyle(.borderless)

                Button(action: onDelete) {
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding()
        .background(Color.white.opacity(0.2))
        .cornerRadius(15)
        .sheet(isPresented: $showSaveAsVisited) {
            SaveAsVisitedFromScheduleView(
                scheduleItem: item,
                travelPlanTitle: plan.title,
                travelPlanId: plan.id
            )
        }
        .sheet(isPresented: $showMapView) {
            scheduleMapViewSheet
        }
    }

    private var scheduleMapViewSheet: some View {
        NavigationView {
            Group {
                if let latitude = item.latitude, let longitude = item.longitude {
                    Map(initialPosition: .region(MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    ))) {
                        if let location = item.location {
                            Marker(location, coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
                                .tint(.red)
                        } else {
                            Marker(item.title, coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
                                .tint(.red)
                        }
                    }
                } else {
                    Text("位置情報がありません")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle(item.location ?? item.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        showMapView = false
                    }
                }
                if let latitude = item.latitude, let longitude = item.longitude {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("マップで開く") {
                            openInMaps(latitude: latitude, longitude: longitude)
                        }
                    }
                }
            }
        }
    }

    private func openInMaps(latitude: Double, longitude: Double) {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = item.location ?? item.title
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    private func formatTime(_ date: Date) -> String {
        DateFormatter.japaneseTime.string(from: date)
    }
}

struct AddScheduleItemToEditorView: View {
    @Environment(\.presentationMode) var presentationMode
    let dayNumber: Int
    @Binding var daySchedules: [DaySchedule]
    let plan: TravelPlan

    @State private var title: String = ""
    @State private var location: String = ""
    @State private var notes: String = ""
    @State private var time: Date = Date()
    @State private var cost: String = ""
    @State private var linkURL: String = ""

    // Location search properties
    @State private var showLocationPicker = false
    @State private var searchText: String = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var selectedLocation: MKMapItem?
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var selectedAddress: String?

    var dayDate: Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: dayNumber - 1, to: plan.startDate) ?? plan.startDate
    }

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.9), Color.black]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        dayInfoCard

                        VStack(spacing: 15) {
                            customTextField(icon: "text.alignleft", placeholder: "タイトル（例：浅草寺観光）", text: $title)
                            locationSection

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

                            customTextField(icon: "link", placeholder: "リンク（任意）", text: $linkURL)

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
                        .padding()
                    }
                    .padding()
                }
                .background(Color.clear)
                .onTapGesture {
                    hideKeyboard()
                }
            }
            .navigationTitle("予定を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.red)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("追加") {
                        addScheduleItem()
                    }
                    .foregroundColor(.blue)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private var dayInfoCard: some View {
        VStack(spacing: 10) {
            Text("Day \(dayNumber)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text(formatDate(dayDate))
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.2))
        .cornerRadius(15)
    }

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

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter.japanese
        formatter.dateFormat = "M月d日(E)"
        return formatter.string(from: date)
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let selected = selectedLocation {
                selectedLocationCard(selected)
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

    private func selectedLocationCard(_ mapItem: MKMapItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(mapItem.name ?? "場所")
                        .font(.headline)
                        .foregroundColor(.white)

                    if let address = selectedAddress ?? mapItem.placemark.title {
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

    private func addScheduleItem() {
        let costValue = cost.isEmpty ? nil : Double(cost)

        let newItem = ScheduleItem(
            time: time,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            location: selectedLocation?.name ?? (location.isEmpty ? nil : location.trimmingCharacters(in: .whitespacesAndNewlines)),
            notes: notes.isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines),
            latitude: selectedCoordinate?.latitude,
            longitude: selectedCoordinate?.longitude,
            cost: costValue,
            linkURL: linkURL.isEmpty ? nil : linkURL.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        if let dayIndex = daySchedules.firstIndex(where: { $0.dayNumber == dayNumber }) {
            daySchedules[dayIndex].scheduleItems.append(newItem)
        } else {
            let newDaySchedule = DaySchedule(
                dayNumber: dayNumber,
                date: dayDate,
                scheduleItems: [newItem]
            )
            daySchedules.append(newDaySchedule)
            daySchedules.sort { $0.dayNumber < $1.dayNumber }
        }

        presentationMode.wrappedValue.dismiss()
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
                            .tint(.red)
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
                        .foregroundStyle(.red)
                        .font(.title3)
                    Text(address)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let phoneNumber = result.phoneNumber {
                HStack(spacing: 8) {
                    Image(systemName: "phone.circle.fill")
                        .foregroundStyle(.green)
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
                            .background(Color.green)
                            .foregroundStyle(.white)
                            .cornerRadius(8)
                    }
                }
            }

            if let url = result.url {
                HStack(spacing: 8) {
                    Image(systemName: "safari.fill")
                        .foregroundStyle(.blue)
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
                            .background(Color.blue)
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
                        .background(Color.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .cornerRadius(10)
                }

                Button {
                    selectLocationFromMapResult(result)
                } label: {
                    Label("選択", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.orange.opacity(0.1))
                        .foregroundStyle(.orange)
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
}
