import SwiftUI
import MapKit

struct AddPlanView: View {
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

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.9), Color.black]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack {
                headerView
                ScrollView {
                    VStack(spacing: 20) {
                        basicInfoSection
                        placesSection
                    }
                    .padding()
                }
                saveButton
            }
        }
        .sheet(isPresented: $showMapPicker) {
            mapPickerView
        }
        .navigationBarHidden(true)
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
            
            Text("新しい旅行計画")
                .font(.headline)
                .foregroundColor(.white)
            
            Spacer()
        }
        .padding()
        .background(Color.black.opacity(0.2))
    }
    
//    private var basicInfoSection: some View {
//        VStack(alignment: .leading, spacing: 15) {
//            Text("旅行の詳細")
//                .font(.title2)
//                .fontWeight(.bold)
//                .foregroundColor(.white)
//            
//            customTextField(
//                icon: "text.alignleft",
//                placeholder: "タイトル",
//                text: $title
//            )
//            
//            HStack {
//                datePickerCard(title: "開始日", date: $startDate)
//                datePickerCard(title: "終了日", date: $endDate)
//            }
//        }
//        .padding()
//        .background(Color.white.opacity(0.1))
//        .cornerRadius(15)
//    }
    
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
            
            // 新しい色選択セクション
            colorSelectionSection
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(15)
    }

    private var colorSelectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("カードの色")
                .foregroundColor(.white)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach([Color.blue, Color.green, Color.purple, Color.orange, Color.red, Color.pink], id: \.self) { color in
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
                }
            }
        }
    }
    
    private var placesSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("行きたい場所")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            if places.isEmpty {
                Text("まだ場所が追加されていません")
                    .foregroundColor(.white.opacity(0.7))
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)
            } else {
                ForEach(places) { place in
                    placeItemView(place)
                }
            }
            
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
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(15)
    }
    
    private var saveButton: some View {
        Button(action: savePlan) {
            Text("旅行計画を保存")
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue, Color.purple]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(10)
                .shadow(radius: 10)
        }
        .padding()
        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || startDate > endDate)
    }
    
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
            Button(action: {
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
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(10)
    }
    
    private func savePlan() {
        let normalizedEnd = endDate < startDate ? startDate : endDate
        let plan = Plan(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: startDate,
            endDate: normalizedEnd,
            places: places,
            cardColor: selectedCardColor
        )
        onSave(plan)
        presentationMode.wrappedValue.dismiss()
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.black.opacity(0.7))
            
            TextField("場所を検索", text: $searchText)
                .foregroundColor(.white)
                .onChange(of: searchText) { oldValue, newValue in
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
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.black.opacity(0.7))
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.2))
        .cornerRadius(10)
        .padding()
    }
    
    private var searchResultsList: some View {
        ForEach(searchResults, id: \.placemark) { item in
            Button {
                newPlaceCoordinate = item.placemark.coordinate
                newPlaceName = item.name ?? ""
                newPlaceAddress = item.placemark.title ?? ""
                searchResults.removeAll()
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
                
                if let coordinate = newPlaceCoordinate {
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
            }
            .padding()
        }
    
    private var actionButtons: some View {
            VStack(spacing: 20) {
                Button(action: {
                    guard let coord = newPlaceCoordinate else { return }
                    let p = PlannedPlace(
                        name: newPlaceName.isEmpty ? "無題の場所" : newPlaceName,
                        latitude: coord.latitude,
                        longitude: coord.longitude,
                        address: newPlaceAddress.isEmpty ? nil : newPlaceAddress
                    )
                    places.append(p)
                    showMapPicker = false
                }) {
                    Text("追加")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue, Color.purple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(10)
                }
                .disabled(newPlaceCoordinate == nil)
                
                Button(action: { showMapPicker = false }) {
                    Text("キャンセル")
                        .foregroundColor(.red)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(10)
                }
            }
            .padding()
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
}
