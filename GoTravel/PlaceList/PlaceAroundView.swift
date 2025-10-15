import SwiftUI
import MapKit

// MARK: - StationPoint Model
struct StationPoint: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D

    static func == (lhs: StationPoint, rhs: StationPoint) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - CLLocationCoordinate2D Extensions
extension CLLocationCoordinate2D {
    static let tokyoStationStreet = CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671)
    static let nagoyaStation = CLLocationCoordinate2D(latitude: 35.1706, longitude: 136.8816)
    static let osakaStation = CLLocationCoordinate2D(latitude: 34.7024, longitude: 135.4959)
    static let hakataStation = CLLocationCoordinate2D(latitude: 33.5904, longitude: 130.4206)
}

// MARK: - LocationPreview
struct LocationPreview: View {
    @State private var scene: MKLookAroundScene?
    @Binding var stationPoint: StationPoint

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(stationPoint.name)
                .font(.title2)
                .fontWeight(.bold)

            Text("緯度: \(stationPoint.coordinate.latitude, specifier: "%.4f")")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("経度: \(stationPoint.coordinate.longitude, specifier: "%.4f")")
                .font(.caption)
                .foregroundColor(.secondary)

            if let scene {
                LookAroundPreview(initialScene: scene,
                                  allowsNavigation: true,
                                  showsRoadLabels: true,
                                  pointsOfInterest: .all,
                                  badgePosition: .topLeading)
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .cornerRadius(8)
                .overlay(alignment: .bottomTrailing) {
                    HStack {
                        Image(systemName: "tram.fill")
                        Text(stationPoint.name)
                    }
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                    .padding(8)
                }
            }

            Map(initialPosition: .region(MKCoordinateRegion(
                center: stationPoint.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))) {
                Marker(stationPoint.name, coordinate: stationPoint.coordinate)
                    .tint(.blue)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemBackground))
        .task {
            await loadLookAroundScene()
        }
        .onChange(of: stationPoint) {
            Task {
                await loadLookAroundScene()
            }
        }
    }

    func loadLookAroundScene() async {
        scene = nil
        do {
            let request = MKLookAroundSceneRequest(coordinate: stationPoint.coordinate)
            scene = try await request.scene
        } catch {
            print("Look Around scene not available: \(error)")
        }
    }
}

struct PlaceAroundView: View {
    @State private var selection: UUID?
    @State private var isOnlyPreview = true

    let stations = [
        StationPoint(name: "Tokyo Station", coordinate: .tokyoStationStreet),
        StationPoint(name: "Nagoya Station", coordinate: .nagoyaStation),
        StationPoint(name: "Osaka Station", coordinate: .osakaStation),
        StationPoint(name: "Fukuoka Station", coordinate: .hakataStation)]

    var body: some View {
        VStack {
            Toggle("Only PreView", isOn: $isOnlyPreview)
                .padding([.top, .horizontal])
            // Preview only
            if isOnlyPreview {
                List {
                    ForEach(stations) { location in
                        LocationPreview(
                            stationPoint: .constant(location))
                        .frame(height: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .listStyle(.inset)
            } else {
                // MapView
                Map(selection: $selection) {
                    ForEach(stations) { location in
                        Marker(coordinate: location.coordinate) {
                            Text(location.name)
                            Image(systemName: "tram.fill")
                        }
                        .tint(.blue)
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    if let selection {
                        if let item = stations.first(where: { $0.id == selection }) {
                            LocationPreview(
                                stationPoint: .constant(item))
                            .frame(height: 128)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .padding()
                            .background(.thinMaterial)
                        }
                    }
                }
            }
        }
    }
}


#Preview {
    PlaceAroundView()
}
