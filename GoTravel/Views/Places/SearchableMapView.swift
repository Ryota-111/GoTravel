import SwiftUI
import MapKit

struct SearchableMapView: View {
    @Binding var searchQuery: String
    let initialQuery: String

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var annotation: IdentifiablePointAnnotation?

    var body: some View {
        ZStack {
            Map(position: .constant(.region(region))) {
                if let annotation = annotation {
                    Marker(annotation.title ?? "", coordinate: annotation.coordinate)
                }
            }
            .onAppear {
                if !initialQuery.isEmpty {
                    searchLocation(query: initialQuery)
                }
            }
            .onChange(of: searchQuery) { oldValue, newValue in
                if !newValue.isEmpty {
                    searchLocation(query: newValue)
                }
            }
        }
    }

    private func searchLocation(query: String) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query

        let search = MKLocalSearch(request: request)
        search.start { response, error in
            guard let response = response,
                  let item = response.mapItems.first,
                  let location = item.placemark.location else {
                print("検索エラー: \(error?.localizedDescription ?? "不明")")
                return
            }

            DispatchQueue.main.async {
                let coordinate = location.coordinate
                region = MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )

                let point = IdentifiablePointAnnotation()
                point.coordinate = coordinate
                point.title = item.name ?? query
                annotation = point

                print("検索成功: \(coordinate.latitude), \(coordinate.longitude)")
            }
        }
    }
}

class IdentifiablePointAnnotation: NSObject, Identifiable {
    let id = UUID()
    var coordinate: CLLocationCoordinate2D = CLLocationCoordinate2D()
    var title: String?
}
