import SwiftUI
import MapKit

struct MapHomeView: View {
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var vm = PlacesViewModel()
    @State private var centerCoordinate = CLLocationCoordinate2D(latitude: 36.2048, longitude: 138.2529)
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var showingSaveSheet: Bool = false
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var zoomLevel: Double?
    @State private var searchWorkItem: DispatchWorkItem?

    var body: some View {
        ZStack(alignment: .top) {
            MapViewRepresentable(
                centerCoordinate: $centerCoordinate,
                selectedCoordinate: $selectedCoordinate,
                annotations: mkAnnotations(),
                zoomLevel: zoomLevel
            )
            .edgesIgnoringSafeArea(.all)

            VStack {
                HStack {
                    TextField("場所を検索", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(10)
                        .onChange(of: searchText) { oldValue, newValue in
                            searchWorkItem?.cancel()

                            let workItem = DispatchWorkItem { [self] in
                                if !newValue.isEmpty && newValue.count >= 3 {
                                    performSearch()
                                } else {
                                    searchResults = []
                                }
                            }

                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
                            searchWorkItem = workItem
                        }
                        .onSubmit {
                            performSearch()
                        }
                }
                .padding()
                .background(Color.white.opacity(0.5))

                Spacer()
            }
        }
        .onChange(of: selectedCoordinate) { _, newValue in
            if let _ = newValue {
                showingSaveSheet = true
            }
        }
        .sheet(isPresented: $showingSaveSheet, onDismiss: {
            selectedCoordinate = nil
        }) {
            if let coord = selectedCoordinate {
                SavePlaceView(vm: SavePlaceViewModel(coord: coord))
                    .environmentObject(auth)
            }
        }
        .navigationTitle("マップ")
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

        search.start { [self] response, error in
            guard let response = response, !response.mapItems.isEmpty else {
                print("検索エラー: \(error?.localizedDescription ?? "不明なエラー")")
                return
            }

            if let firstItem = response.mapItems.first,
               let location = firstItem.placemark.location {
                DispatchQueue.main.async {
                    zoomToLocation(location.coordinate)
                    searchText = ""
                }
            }
        }
    }

    private func zoomToLocation(_ coordinate: CLLocationCoordinate2D) {
        withAnimation {
            centerCoordinate = coordinate
            zoomLevel = 0.01
        }
    }

    private func mkAnnotations() -> [MKPointAnnotation] {
        vm.places.map { place in
            let ann = MKPointAnnotation()
            ann.title = place.title
            ann.coordinate = place.coordinate
            return ann
        }
    }
}

extension CLLocationCoordinate2D: @retroactive Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}
