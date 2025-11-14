import SwiftUI
import MapKit

struct PlaceSearchView: View {
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var selectedName: String = ""
    @State private var selectedAddress: String?

    let onPlaceSelected: (PlannedPlace) -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

                    TextField("場所を検索", text: $searchText)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            searchPlaces()
                        }

                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            searchResults = []
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))

                // Search Results
                if isSearching {
                    ProgressView()
                        .padding()
                } else if !searchResults.isEmpty {
                    List(searchResults, id: \.self) { item in
                        Button(action: {
                            selectPlace(item)
                        }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name ?? "不明な場所")
                                    .font(.body)
                                    .foregroundColor(.primary)

                                if let address = item.placemark.title {
                                    Text(address)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                } else if !searchText.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("「\(searchText)」を検索")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("場所を検索してください")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("場所を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func searchPlaces() {
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.resultTypes = [.pointOfInterest, .address]

        let search = MKLocalSearch(request: request)
        search.start { response, error in
            DispatchQueue.main.async {
                isSearching = false

                if let error = error {
                    print("検索エラー: \(error.localizedDescription)")
                    searchResults = []
                    return
                }

                searchResults = response?.mapItems ?? []
            }
        }
    }

    private func selectPlace(_ item: MKMapItem) {
        let coordinate = item.placemark.coordinate
        let name = item.name ?? "不明な場所"
        let address = item.placemark.title

        let plannedPlace = PlannedPlace(
            name: name,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            address: address
        )

        onPlaceSelected(plannedPlace)
    }
}
