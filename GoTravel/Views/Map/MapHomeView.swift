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
        center: CLLocationCoordinate2D(latitude: 36.2048, longitude: 138.2529),
        span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
    ))
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var selectedResult: MKMapItem?
    @State private var showingSaveSheet: Bool = false
    @State private var isSearching = false

    var body: some View {
        Map(position: $position, selection: $selectedResult) {
            UserAnnotation(anchor: .top) { userLocation in
                EmptyView()
                    .onAppear {
                        location = userLocation.location?.coordinate ?? .tokyoStation
                    }
            }

            // 検索結果マーカー（赤）
            ForEach(searchResults, id: \.self) { result in
                Marker(item: result)
                    .tint(themeManager.currentTheme.error)
            }

            // 保存済み場所マーカー（赤で統一）
            ForEach(vm.places) { place in
                Annotation(place.title, coordinate: place.coordinate) {
                    ZStack {
                        Circle()
                            .fill(themeManager.currentTheme.error.opacity(0.9))
                            .frame(width: 34, height: 34)
                            .shadow(color: themeManager.currentTheme.error.opacity(0.4), radius: 4, x: 0, y: 2)
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
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
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: selectedResult != nil)
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
            if let userId = auth.userId {
                vm.setupFetchedResultsController(userId: userId)
            }
        }
    }

    // MARK: - Search Bar
    private var searchBarView: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: isSearching ? "xmark.circle.fill" : "magnifyingglass")
                    .foregroundColor(isSearching ? themeManager.currentTheme.secondaryText : themeManager.currentTheme.secondaryText)
                    .onTapGesture {
                        if isSearching {
                            inputText = ""
                            searchResults = []
                            isSearching = false
                        }
                    }

                TextField("場所を検索（例：東京タワー）", text: $inputText)
                    .textFieldStyle(.plain)
                    .submitLabel(.search)
                    .onSubmit { performSearch() }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Color(.systemBackground))
            .cornerRadius(14)
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)

            if !inputText.isEmpty {
                Button(action: performSearch) {
                    Text("検索")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(themeManager.currentTheme.primary)
                        .cornerRadius(14)
                        .shadow(color: themeManager.currentTheme.primary.opacity(0.3), radius: 6, x: 0, y: 2)
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: inputText.isEmpty)
    }

    // MARK: - Selected Result Detail Panel
    private func selectedResultDetailView(_ result: MKMapItem) -> some View {
        VStack(spacing: 0) {
            // ドラッグハンドル
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 14)

            VStack(alignment: .leading, spacing: 12) {
                // 場所名・閉じるボタン
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.name ?? "名称なし")
                            .font(.title3.weight(.bold))
                            .foregroundColor(.primary)
                            .lineLimit(2)

                        if let category = result.pointOfInterestCategory?.rawValue {
                            Text(category.replacingOccurrences(of: "MKPOICategory", with: ""))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Button(action: { withAnimation { selectedResult = nil } }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(Color(.systemGray3))
                    }
                }

                // 住所
                if let address = result.placemark.title {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(themeManager.currentTheme.error)
                            .font(.body)
                        Text(address)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                // 電話・Web（コンパクト表示）
                HStack(spacing: 10) {
                    if let phoneNumber = result.phoneNumber {
                        Button {
                            if let url = URL(string: "tel:\(phoneNumber.replacingOccurrences(of: " ", with: ""))") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Label("電話", systemImage: "phone.fill")
                                .font(.caption.weight(.medium))
                                .foregroundColor(themeManager.currentTheme.success)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(themeManager.currentTheme.success.opacity(0.1))
                                .cornerRadius(20)
                        }
                    }

                    if let url = result.url {
                        Button { UIApplication.shared.open(url) } label: {
                            Label("Web", systemImage: "safari.fill")
                                .font(.caption.weight(.medium))
                                .foregroundColor(themeManager.currentTheme.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(themeManager.currentTheme.primary.opacity(0.1))
                                .cornerRadius(20)
                        }
                    }

                    Spacer()
                }

                // アクションボタン
                HStack(spacing: 10) {
                    Button {
                        result.openInMaps()
                    } label: {
                        Label("経路", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(themeManager.currentTheme.primary.opacity(0.1))
                            .foregroundStyle(themeManager.currentTheme.primary)
                            .cornerRadius(14)
                    }

                    Button {
                        showingSaveSheet = true
                    } label: {
                        Label("この場所を保存", systemImage: "bookmark.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(themeManager.currentTheme.primary)
                            .foregroundStyle(.white)
                            .cornerRadius(14)
                            .shadow(color: themeManager.currentTheme.primary.opacity(0.3), radius: 6, x: 0, y: 3)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.background)
                .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: -4)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Search
    private func performSearch() {
        guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearching = true
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
            return try await search.start().mapItems
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
