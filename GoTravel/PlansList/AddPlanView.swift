import SwiftUI
import MapKit

struct AddPlanView: View {

    // MARK: - Properties
    @Environment(\.presentationMode) var presentationMode

    var onSave: (Plan) -> Void

    @State private var title: String = ""
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
    @State private var selectedCardColor: Color = .blue
    @State private var selectedImage: UIImage? = nil
    @State private var showImagePicker = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var isUploading = false

    // MARK: - Computed Properties
    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && startDate <= endDate
    }

    private var normalizedEndDate: Date {
        endDate < startDate ? startDate : endDate
    }

    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [Color.blue.opacity(0.9), Color.black]),
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
                basicInfoSection
                imagePickerSection
                placesSection
                colorSelectionSection
            }
            .padding()
        }
    }

    private var headerView: some View {
        HStack {
            backButton

            Spacer()

            Text("新しい旅行計画")
                .font(.headline)
                .foregroundColor(.white)

            Spacer()
        }
        .padding()
        .background(Color.black.opacity(0.2))
    }

    private var backButton: some View {
        Button(action: { presentationMode.wrappedValue.dismiss() }) {
            HStack {
                Image(systemName: "chevron.left")
                    .foregroundColor(.white)
                    .imageScale(.large)
                Text("戻る")
                    .foregroundColor(.white)
            }
        }
    }

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("旅行の詳細")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            customTextField(
                icon: "text.alignleft",
                placeholder: "タイトル",
                text: $title
            )

            HStack {
                datePickerCard(title: "開始日", date: $startDate)
                datePickerCard(title: "終了日", date: $endDate)
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(15)
    }

    private var imagePickerSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("カード表紙の写真")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            if let image = selectedImage {
                selectedImageView(image: image)
            } else {
                imagePickerButton
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
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
                    .foregroundColor(.white.opacity(0.7))

                Text("写真を選択")
                    .foregroundColor(.white)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .background(Color.white.opacity(0.2))
            .cornerRadius(15)
        }
    }

    private var colorSelectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("カードの色")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach([Color.blue, Color.green, Color.purple, Color.orange, Color.red, Color.pink], id: \.self) { color in
                        colorCircle(color: color)
                    }
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
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
                .foregroundColor(.white)

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
        .background(Color.white.opacity(0.1))
        .cornerRadius(15)
    }

    private var emptyPlacesView: some View {
        Text("まだ場所が追加されていません")
            .foregroundColor(.white.opacity(0.7))
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.1))
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
            MapPickerView(coordinate: $newPlaceCoordinate)
                .frame(height: 300)
                .cornerRadius(15)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.white.opacity(0.5), lineWidth: 2)
                )
        }
        .padding()
    }

    private var placeInfoSection: some View {
        VStack(spacing: 15) {
            placeNameField

            if let coordinate = newPlaceCoordinate {
                coordinateInfo(coordinate: coordinate)
            }
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

    private func coordinateInfo(coordinate: CLLocationCoordinate2D) -> some View {
        VStack(alignment: .leading) {
            Text("座標")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))

            Text("緯度: \(coordinate.latitude, specifier: "%.4f")")
                .foregroundColor(.white)
            Text("経度: \(coordinate.longitude, specifier: "%.4f")")
                .foregroundColor(.white)
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(10)
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
                .foregroundColor(.white.opacity(0.7))
            TextField(placeholder, text: text)
                .foregroundColor(.white)
        }
        .padding()
        .background(Color.white.opacity(0.2))
        .cornerRadius(10)
    }

    private func datePickerCard(title: String, date: Binding<Date>) -> some View {
        VStack {
            Text(title)
                .foregroundColor(.white.opacity(0.7))
            DatePicker("", selection: date, displayedComponents: .date)
                .datePickerStyle(CompactDatePickerStyle())
                .foregroundColor(.white)
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(10)
    }

    private func placeItemView(_ place: PlannedPlace) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(place.name)
                    .foregroundColor(.white)
                if let address = place.address {
                    Text(address)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            Spacer()
            deletePlaceButton(place: place)
        }
        .padding()
        .background(Color.white.opacity(0.1))
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
        if let address = item.placemark.address {
            newPlaceAddress = address.formattedAddress
        }
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
        print("   画像: \(selectedImage != nil ? "あり" : "なし")")

        isUploading = true

        if let image = selectedImage {
            saveWithImage(image)
        } else {
            saveWithoutImage()
        }
    }

    private func saveWithImage(_ image: UIImage) {
        print("📸 AddPlanView: 画像ローカル保存開始")
        FirestoreService.shared.savePlanImageLocally(image) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let fileName):
                    print("✅ AddPlanView: 画像保存成功 - \(fileName)")
                    createAndSavePlan(with: fileName)

                case .failure(let error):
                    print("❌ AddPlanView: 画像保存エラー - \(error.localizedDescription)")
                    isUploading = false
                    createAndSavePlan(with: nil)
                }
            }
        }
    }

    private func saveWithoutImage() {
        print("⚪️ AddPlanView: 画像なしで保存")
        createAndSavePlan(with: nil)
    }

    private func createAndSavePlan(with fileName: String?) {
        let plan = Plan(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: startDate,
            endDate: normalizedEndDate,
            places: places,
            cardColor: selectedCardColor,
            localImageFileName: fileName
        )
        print("📤 AddPlanView: onSave呼び出し")
        onSave(plan)
        isUploading = false
        presentationMode.wrappedValue.dismiss()
    }
}
