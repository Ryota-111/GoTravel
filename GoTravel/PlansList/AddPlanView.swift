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
    @State private var newPlaceCoordinate: CLLocationCoordinate2D?
    @State private var newPlaceName: String = ""
    @State private var newPlaceAddress: String = ""
    @State private var searchText: String = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var searchWorkItem: DispatchWorkItem?
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
        selectedPlanType == .outing ? Color.white.opacity(0.1) : Color.black.opacity(0.15)
    }

    private var fieldBackgroundColor: Color {
        selectedPlanType == .outing ? Color.white.opacity(0.2) : Color.black.opacity(0.25)
    }

    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: selectedPlanType == .outing ? [Color.blue.opacity(0.9), Color.black] : [Color.white, Color.orange]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var saveButtonGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [Color.blue, Color.purple]),
            startPoint: .leading,
            endPoint: .trailing
        )
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
        .sheet(isPresented: $showMapPicker) {
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
                planTypeButton(type: .outing, title: "おでかけ用", icon: "airplane")
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

    private var imagePickerSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("カード表紙の写真")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(primaryTextColor)

            if let image = selectedImage {
                selectedImageView(image: image)
            } else {
                imagePickerButton
            }
        }
        .padding()
        .background(sectionBackgroundColor)
        .cornerRadius(15)
        .sheet(isPresented: $showImagePicker) {
            ImagePickerView(sourceType: imageSourceType, image: $selectedImage)
        }
    }

    private func selectedImageView(image: UIImage) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 200)
                .cornerRadius(15)
                .clipped()

            removeImageButton
        }
    }

    private var removeImageButton: some View {
        Button(action: {
            selectedImage = nil
        }) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 30))
                .foregroundColor(.white)
                .background(Circle().fill(Color.black.opacity(0.5)))
        }
        .padding(8)
    }

    private var imagePickerButton: some View {
        Button(action: {
            showImagePicker = true
        }) {
            VStack(spacing: 10) {
                Image(systemName: "photo.fill")
                    .font(.system(size: 50))
                    .foregroundColor(secondaryTextColor)

                Text("写真を選択")
                    .foregroundColor(primaryTextColor)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .background(fieldBackgroundColor)
            .cornerRadius(15)
        }
    }

    private var colorSelectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("カードの色")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(primaryTextColor)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach([Color.blue, Color.green, Color.purple, Color.orange, Color.red, Color.pink], id: \.self) { color in
                        colorCircle(color: color)
                    }
                }
            }
        }
        .padding()
        .background(sectionBackgroundColor)
        .cornerRadius(15)
    }

    private func colorCircle(color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 40, height: 40)
            .overlay(
                Circle()
                    .stroke(selectedCardColor == color ? Color.white : Color.clear, lineWidth: 3)
            )
            .onTapGesture {
                selectedCardColor = color
            }
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
            .background(Color.blue.opacity(0.5))
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
                } else {
                    Text("旅行計画を保存")
                        .foregroundColor(.white)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(saveButtonGradient)
            .cornerRadius(10)
            .shadow(radius: 10)
        }
        .padding()
        .disabled(!isFormValid || isUploading)
    }

    // MARK: - Map Picker View
    private var mapPickerView: some View {
        NavigationView {
            VStack(spacing: 0) {
                searchBar

                if !searchResults.isEmpty {
                    searchResultsList
                }

                mapSection
                placeInfoSection
                actionButtons
            }
            .navigationBarHidden(true)
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.black.opacity(0.7))

            TextField("場所を検索", text: $searchText)
                .foregroundColor(.white)
                .onChange(of: searchText) { oldValue, newValue in
                    handleSearchTextChange(newValue)
                }

            if !searchText.isEmpty {
                clearSearchButton
            }
        }
        .padding()
        .background(Color.white.opacity(0.2))
        .cornerRadius(10)
        .padding()
    }

    private var clearSearchButton: some View {
        Button(action: { searchText = "" }) {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.black.opacity(0.7))
        }
    }

    private var searchResultsList: some View {
        ForEach(searchResults.indices, id: \.self) { index in
            searchResultButton(item: searchResults[index])
        }
    }

    private func searchResultButton(item: MKMapItem) -> some View {
        Button {
            selectSearchResult(item)
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                Text(item.name ?? "名称不明")
                    .font(.headline)
                    .foregroundColor(.white)
                Text(item.placemark.title ?? "住所不明")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.1))
            .cornerRadius(10)
        }
    }

    private var mapSection: some View {
        ZStack(alignment: .center) {
            if let coordinate = newPlaceCoordinate {
                Map(position: .constant(.region(MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )))) {
                    Marker("選択した場所", coordinate: coordinate)
                        .tint(.red)
                }
                .frame(height: 300)
                .cornerRadius(15)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.white.opacity(0.5), lineWidth: 2)
                )
                .disabled(true)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 300)
                    .cornerRadius(15)
                    .overlay(
                        Text("地図が選択されていません")
                            .foregroundColor(.white)
                    )
            }
        }
        .padding()
    }

    private var placeInfoSection: some View {
        VStack(spacing: 15) {
            placeNameField
        }
        .padding()
    }

    private var placeNameField: some View {
        VStack(alignment: .leading) {
            Text("場所の名前")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))

            TextField("名前を入力", text: $newPlaceName)
                .foregroundColor(.white)
                .padding()
                .background(Color.white.opacity(0.2))
                .cornerRadius(10)
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 20) {
            addLocationButton
            cancelButton
        }
        .padding()
    }

    private var addLocationButton: some View {
        Button(action: addPlace) {
            Text("追加")
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(saveButtonGradient)
                .cornerRadius(10)
        }
        .disabled(newPlaceCoordinate == nil)
    }

    private var cancelButton: some View {
        Button(action: { showMapPicker = false }) {
            Text("キャンセル")
                .foregroundColor(.red)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.2))
                .cornerRadius(10)
        }
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
    private func handleSearchTextChange(_ newValue: String) {
        searchWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            if !newValue.isEmpty && newValue.count >= 3 {
                performSearch()
            } else {
                searchResults = []
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
        searchWorkItem = workItem
    }

    private func selectSearchResult(_ item: MKMapItem) {
        if let location = item.placemark.location {
            newPlaceCoordinate = location.coordinate
        }
        newPlaceName = item.name ?? ""

        // 住所を従来のプロパティから組み立て
        var addressComponents: [String] = []
        if let subThoroughfare = item.placemark.subThoroughfare {
            addressComponents.append(subThoroughfare)
        }
        if let thoroughfare = item.placemark.thoroughfare {
            addressComponents.append(thoroughfare)
        }
        if let locality = item.placemark.locality {
            addressComponents.append(locality)
        }
        if let administrativeArea = item.placemark.administrativeArea {
            addressComponents.append(administrativeArea)
        }
        newPlaceAddress = addressComponents.joined(separator: " ")

        searchResults.removeAll()
    }

    private func performSearch() {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText

        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 36.2048, longitude: 138.2529),
            span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
        )
        request.region = region

        let search = MKLocalSearch(request: request)
        search.start { response, error in
            guard let response = response, !response.mapItems.isEmpty else {
                print("検索エラー: \(error?.localizedDescription ?? "不明なエラー")")
                return
            }
            DispatchQueue.main.async {
                searchResults = response.mapItems
            }
        }
    }

    // MARK: - Actions
    private func addPlace() {
        guard let coord = newPlaceCoordinate else { return }
        let p = PlannedPlace(
            name: newPlaceName.isEmpty ? "無題の場所" : newPlaceName,
            latitude: coord.latitude,
            longitude: coord.longitude,
            address: newPlaceAddress.isEmpty ? nil : newPlaceAddress
        )
        places.append(p)
        showMapPicker = false
    }

    private func deletePlace(_ place: PlannedPlace) {
        if let index = places.firstIndex(where: { $0.id == place.id }) {
            let placeToDelete = places[index]
            FirestoreService.shared.deletePlannedPlace(place: placeToDelete) { err in
                if let err = err {
                    print("Firestore削除エラー: \(err.localizedDescription)")
                } else {
                    DispatchQueue.main.async {
                        places.remove(at: index)
                    }
                }
            }
        }
    }

    private func savePlan() {
        print("🎯 AddPlanView: 保存処理開始")
        print("   タイトル: \(title)")

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
                places: [],
                planType: .daily,
                time: dailyTime,
                description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                linkURL: linkURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : linkURL.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        print("📤 AddPlanView: onSave呼び出し")
        print("   プランタイプ: \(plan.planType.rawValue)")
        print("   時間: \(plan.time?.description ?? "なし")")
        print("   説明: \(plan.description ?? "なし")")
        print("   リンク: \(plan.linkURL ?? "なし")")
        onSave(plan)
        isUploading = false
        presentationMode.wrappedValue.dismiss()
    }
}
