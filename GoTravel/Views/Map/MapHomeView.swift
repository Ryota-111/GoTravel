import SwiftUI
import MapKit
import Combine

extension CLLocationCoordinate2D {
    static let tokyoStation = CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671)
}

// MARK: - Location Manager
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = manager.authorizationStatus
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }
}

struct MapHomeView: View {
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var vm = PlacesViewModel()
    @StateObject private var locationManager = LocationManager()
    @ObservedObject var themeManager = ThemeManager.shared
    @State private var inputText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var location: CLLocationCoordinate2D = .tokyoStation
    @State private var position: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 36.2048, longitude: 138.2529), // 日本の中心
        span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
    ))
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var selectedResult: MKMapItem?
    @State private var showingSaveSheet: Bool = false
    
    var body: some View {
        Map(position: $position, selection: $selectedResult) {
            UserAnnotation(anchor: .top) { userLocation in
                EmptyView()
                    .onAppear {
                        location = userLocation.location?.coordinate ?? .tokyoStation
                    }
            }
            
            ForEach(searchResults, id: \.self) { result in
                Marker(item: result)
                    .tint(themeManager.currentTheme.error)
            }

            ForEach(vm.places) { place in
                Annotation(place.title, coordinate: place.coordinate) {
                    ZStack {
                        Circle()
                            .fill(themeManager.currentTheme.error.opacity(0.3))
                            .frame(width: 32, height: 32)

                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(themeManager.currentTheme.error)
                            .font(.title2)
                    }
                }
            }
        }
        .safeAreaInset(edge: .top) {
            searchBarView
        }
        .safeAreaInset(edge: .bottom) {
            if let selectedResult {
                selectedResultDetailView(selectedResult)
            }
        }
        .onMapCameraChange { context in
            visibleRegion = context.region
        }
        .sheet(isPresented: $showingSaveSheet, onDismiss: {
            selectedResult = nil
        }) {
            if let result = selectedResult {
                SavePlaceView(vm: {
                    let saveVM = SavePlaceViewModel(coord: result.placemark.coordinate, placesVM: vm)
                    saveVM.title = result.name ?? ""
                    return saveVM
                }())
                .environmentObject(auth)
            }
        }
        .navigationTitle("マップ")
        .onAppear {
            locationManager.requestPermission()
        }
    }

    // MARK: - Search Bar View
    private var searchBarView: some View {
        TextField("場所を検索", text: $inputText)
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
                    searchResults = await searchLocations(searchText: inputText)
                    if let firstResult = searchResults.first {
                        withAnimation {
                            position = .region(MKCoordinateRegion(
                                center: firstResult.placemark.coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                            ))
                        }
                    }
                    inputText = ""
                }
            }
    }

    // MARK: - Selected Result Detail View
    private func selectedResultDetailView(_ result: MKMapItem) -> some View {
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
                    showingSaveSheet = true
                } label: {
                    Label("保存", systemImage: "bookmark.fill")
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

    // MARK: - Search Locations
    private func searchLocations(searchText: String) async -> [MKMapItem] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.resultTypes = .pointOfInterest
        request.region = visibleRegion ?? MKCoordinateRegion(
            center: location,
            span: MKCoordinateSpan(latitudeDelta: 0.0125, longitudeDelta: 0.0125)
        )

        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start().mapItems
            return response
        } catch {
            return []
        }
    }
}

// MARK: - Info Chip Component
struct InfoChip: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption)
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color)
        .cornerRadius(12)
    }
}

extension CLLocationCoordinate2D: @retroactive Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}
