import SwiftUI
import MapKit

struct AddPlanView: View {

    // MARK: - Properties
    @Environment(\.presentationMode) var presentationMode

    var onSave: (Plan) -> Void

    @State private var selectedPlanType: PlanType = .outing
    @State private var title: String = ""
    @State private var selectedCardColor: Color = .blue
    @State private var selectedImage: UIImage? = nil
    @State private var showImagePicker = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var isUploading = false
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()
    @State private var places: [PlannedPlace] = []
    @State private var showMapPicker: Bool = false
    @State private var searchText: String = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var dailyDate: Date = Date()
    @State private var dailyTime: Date = Date()
    @State private var description: String = ""
    @State private var linkURL: String = ""

    // MARK: - Computed Properties
    private var isFormValid: Bool {
        let titleValid = !title.trimmingCharacters(in: .whitespaces).isEmpty
        if selectedPlanType == .outing {
            return titleValid && startDate <= endDate
        } else {
            return titleValid
        }
    }

    private var normalizedEndDate: Date {
        endDate < startDate ? startDate : endDate
    }

    private var primaryTextColor: Color {
        selectedPlanType == .outing ? .white : .black
    }

    private var secondaryTextColor: Color {
        selectedPlanType == .outing ? .white.opacity(0.7) : .black.opacity(0.7)
    }

    private var sectionBackgroundColor: Color {
        selectedPlanType == .outing ? Color.white.opacity(0.1) : Color.white.opacity(0.3)
    }

    private var fieldBackgroundColor: Color {
        selectedPlanType == .outing ? Color.white.opacity(0.2) : Color.white.opacity(0.4)
    }

    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: selectedPlanType == .outing ? [Color.blue.opacity(0.9), Color.black] : [Color.orange.opacity(0.9), Color.white.opacity(0.8)]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var saveButtonGradient: LinearGradient {
        if selectedPlanType == .outing {
            return LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.black.opacity(0.8)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                gradient: Gradient(colors: [Color.orange.opacity(0.8), Color.red.opacity(0.6)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var addPlaceButtonColor: Color {
        if selectedPlanType == .outing {
            return Color.blue
        } else {
            return Color.orange
        }
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            backgroundGradient

            VStack {
                headerView
                scrollContent
                saveButton
            }
        }
        .fullScreenCover(isPresented: $showMapPicker) {
            mapPickerView
        }
        .navigationBarHidden(true)
    }

    // MARK: - View Components
    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                planTypeSelectionSection

                if selectedPlanType == .outing {
                    outingFormSections
                } else {
                    dailyFormSections
                }
            }
            .padding()
        }
    }

    private var outingFormSections: some View {
        Group {
            basicInfoSection
            placesSection
        }
    }

    private var dailyFormSections: some View {
        Group {
            dailyBasicInfoSection
            placesSection
            dailyDescriptionSection
            dailyLinkSection
        }
    }

    private var headerView: some View {
        HStack {
            backButton

            Spacer()

            Text("新しい予定計画")
                .font(.headline)
                .foregroundColor(primaryTextColor)

            Spacer()
        }
        .padding()
        .background(Color.black.opacity(0.2))
    }

    private var backButton: some View {
        Button(action: { presentationMode.wrappedValue.dismiss() }) {
            HStack {
                Image(systemName: "chevron.left")
                    .foregroundColor(primaryTextColor)
                    .imageScale(.large)
                Text("戻る")
                    .foregroundColor(primaryTextColor)
            }
        }
    }

    private var planTypeSelectionSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("プランの種類")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(primaryTextColor)

            HStack(spacing: 15) {
                planTypeButton(type: .outing, title: "おでかけ用", icon: "figure.walk")
                planTypeButton(type: .daily, title: "日常用", icon: "house.fill")
            }
        }
        .padding()
        .background(sectionBackgroundColor)
        .cornerRadius(15)
    }

    private func planTypeButton(type: PlanType, title: String, icon: String) -> some View {
        let isSelected = selectedPlanType == type
        let textColor: Color = {
            if isSelected {
                return .white
            } else {
                return selectedPlanType == .outing ? .white.opacity(0.5) : .black.opacity(0.5)
            }
        }()

        return Button(action: {
            withAnimation {
                selectedPlanType = type
            }
        }) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 30))
                    .foregroundColor(textColor)

                Text(title)
                    .font(.headline)
                    .foregroundColor(textColor)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                isSelected
                    ? (type == .outing ? Color.blue.opacity(0.5) : Color.orange.opacity(0.9))
                    : Color.white.opacity(0.2)
            )
            .cornerRadius(10)
        }
    }

    private var dailyBasicInfoSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("予定の詳細")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(primaryTextColor)

            customTextField(
                icon: "text.alignleft",
                placeholder: "タイトル",
                text: $title
            )

            HStack {
                VStack(alignment: .leading, spacing: 10) {
                    Text("日付")
                        .foregroundColor(primaryTextColor)
                        .font(.headline)
                    DatePicker("", selection: $dailyDate, displayedComponents: .date)
                        .datePickerStyle(CompactDatePickerStyle())
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .background(fieldBackgroundColor)
                .cornerRadius(10)

                VStack(alignment: .leading, spacing: 10) {
                    Text("時間")
                        .foregroundColor(primaryTextColor)
                        .font(.headline)
                    DatePicker("", selection: $dailyTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(CompactDatePickerStyle())
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .background(fieldBackgroundColor)
                .cornerRadius(10)
            }
        }
        .padding()
        .background(sectionBackgroundColor)
        .cornerRadius(15)
    }

    private var dailyDescriptionSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("何をするのか")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(primaryTextColor)

            TextEditor(text: $description)
                .frame(height: 120)
                .foregroundColor(primaryTextColor)
                .scrollContentBackground(.hidden)
                .padding()
                .background(fieldBackgroundColor)
                .cornerRadius(10)
        }
        .padding()
        .background(sectionBackgroundColor)
        .cornerRadius(15)
    }

    private var dailyLinkSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("リンク（任意）")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(primaryTextColor)

            customTextField(
                icon: "link",
                placeholder: "https://example.com",
                text: $linkURL
            )
        }
        .padding()
        .background(sectionBackgroundColor)
        .cornerRadius(15)
    }

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("予定の詳細")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(primaryTextColor)

            customTextField(
                icon: "text.alignleft",
                placeholder: "タイトル",
                text: $title
            )

            HStack {
                VStack(alignment: .leading, spacing: 10) {
                    Text("開始日")
                        .foregroundColor(primaryTextColor)
                        .font(.headline)
                    DatePicker("", selection: $startDate, displayedComponents: .date)
                        .datePickerStyle(CompactDatePickerStyle())
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .background(fieldBackgroundColor)
                .cornerRadius(10)

                VStack(alignment: .leading, spacing: 10) {
                    Text("終了日")
                        .foregroundColor(primaryTextColor)
                        .font(.headline)
                    DatePicker("", selection: $endDate, displayedComponents: .date)
                        .datePickerStyle(CompactDatePickerStyle())
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .background(fieldBackgroundColor)
                .cornerRadius(10)
            }
        }
        .padding()
        .background(sectionBackgroundColor)
        .cornerRadius(15)
    }

    private var placesSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("行きたい場所")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(primaryTextColor)

            if places.isEmpty {
                emptyPlacesView
            } else {
                ForEach(places) { place in
                    placeItemView(place)
                }
            }

            addPlaceButton
        }
        .padding()
        .background(sectionBackgroundColor)
        .cornerRadius(15)
    }

    private var emptyPlacesView: some View {
        Text("まだ場所が追加されていません")
            .foregroundColor(secondaryTextColor)
            .padding()
            .frame(maxWidth: .infinity)
            .background(fieldBackgroundColor)
            .cornerRadius(10)
    }

    private var addPlaceButton: some View {
        Button(action: { showMapPicker = true }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("場所を追加")
            }
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(addPlaceButtonColor)
            .cornerRadius(10)
        }
    }

    private var saveButton: some View {
        Button(action: savePlan) {
            HStack {
                if isUploading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("保存中...")
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                } else {
                    Image(systemName: selectedPlanType == .outing ? "airplane.departure" : "calendar.badge.clock")
                        .foregroundColor(.white)
                    Text(selectedPlanType == .outing ? "おでかけプランを保存" : "日常プランを保存")
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                }
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(saveButtonGradient)
            .cornerRadius(15)
            .shadow(color: selectedPlanType == .outing ? Color.blue.opacity(0.4) : Color.orange.opacity(0.8), radius: 10, x: 0, y: 5)
        }
        .padding()
        .disabled(!isFormValid || isUploading)
    }

    // MARK: - Map Picker View
    @State private var mapPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 36.2048, longitude: 138.2529),
        span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
    ))
    @State private var selectedMapResult: MKMapItem?
    @State private var mapVisibleRegion: MKCoordinateRegion?

    private var mapPickerView: some View {
        NavigationView {
            ZStack {
                Map(position: $mapPosition, selection: $selectedMapResult) {
                    ForEach(searchResults, id: \.self) { result in
                        Marker(item: result)
                            .tint(.red)
                    }
                }
                .safeAreaInset(edge: .top) {
                    mapSearchBarView
                }
                .safeAreaInset(edge: .bottom) {
                    if let selectedResult = selectedMapResult {
                        mapSelectedResultDetailView(selectedResult)
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
                        showMapPicker = false
                    }
                }
            }
        }
    }

    // MARK: - Map Search Bar
    private var mapSearchBarView: some View {
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
                    await performMapSearch()
                }
            }
    }

    private func performMapSearch() async {
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

    // MARK: - Map Selected Result Detail View
    private func mapSelectedResultDetailView(_ result: MKMapItem) -> some View {
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
                    addPlaceFromMapResult(result)
                } label: {
                    Label("追加", systemImage: "plus.circle.fill")
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

    private func addPlaceFromMapResult(_ result: MKMapItem) {
        let place = PlannedPlace(
            name: result.name ?? "名称不明",
            latitude: result.placemark.coordinate.latitude,
            longitude: result.placemark.coordinate.longitude,
            address: result.placemark.title
        )
        places.append(place)
        selectedMapResult = nil
        showMapPicker = false
    }

    // MARK: - Helper Views
    private func customTextField(icon: String, placeholder: String, text: Binding<String>) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(secondaryTextColor)
            TextField(placeholder, text: text)
                .foregroundColor(primaryTextColor)
        }
        .padding()
        .background(fieldBackgroundColor)
        .cornerRadius(10)
    }

    private func datePickerCard(title: String, date: Binding<Date>) -> some View {
        VStack {
            Text(title)
                .foregroundColor(secondaryTextColor)
            DatePicker("", selection: date, displayedComponents: .date)
                .datePickerStyle(CompactDatePickerStyle())
                .foregroundColor(primaryTextColor)
        }
        .padding()
        .background(fieldBackgroundColor)
        .cornerRadius(10)
    }

    private func placeItemView(_ place: PlannedPlace) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(place.name)
                    .foregroundColor(primaryTextColor)
                if let address = place.address {
                    Text(address)
                        .font(.caption)
                        .foregroundColor(secondaryTextColor)
                }
            }
            Spacer()
            deletePlaceButton(place: place)
        }
        .padding()
        .background(fieldBackgroundColor)
        .cornerRadius(10)
    }

    private func deletePlaceButton(place: PlannedPlace) -> some View {
        Button(action: {
            deletePlace(place)
        }) {
            Image(systemName: "trash")
                .foregroundColor(.red)
        }
    }

    // MARK: - Helper Methods

    private func deletePlace(_ place: PlannedPlace) {
        if let index = places.firstIndex(where: { $0.id == place.id }) {
            let placeToDelete = places[index]
            FirestoreService.shared.deletePlannedPlace(place: placeToDelete) { err in
                if err != nil {
                } else {
                    DispatchQueue.main.async {
                        places.remove(at: index)
                    }
                }
            }
        }
    }

    private func savePlan() {

        isUploading = true
        createAndSavePlan()
    }

    private func createAndSavePlan() {
        let plan: Plan

        if selectedPlanType == .outing {
            plan = Plan(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                startDate: startDate,
                endDate: normalizedEndDate,
                places: places,
                planType: .outing
            )
        } else {
            plan = Plan(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                startDate: dailyDate,
                endDate: dailyDate,
                places: places,
                planType: .daily,
                time: dailyTime,
                description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                linkURL: linkURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : linkURL.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        onSave(plan)
        isUploading = false
        presentationMode.wrappedValue.dismiss()
    }
}
