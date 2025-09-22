import SwiftUI
import MapKit
import CoreLocation

extension CLLocationCoordinate2D: @retroactive Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

extension CLLocationCoordinate2D: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(latitude)
        hasher.combine(longitude)
    }
}

struct MapHomeView: View {
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var vm = PlacesViewModel()
    @State private var centerCoordinate = CLLocationCoordinate2D(latitude: 35.681236, longitude: 139.767125) // 初期は東京駅など
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var showingSaveSheet: Bool = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            MapViewRepresentable(centerCoordinate: $centerCoordinate, selectedCoordinate: $selectedCoordinate, annotations: mkAnnotations())
                .edgesIgnoringSafeArea(.all)
                .onChange(of: selectedCoordinate) { new in
                    if new != nil {
                        showingSaveSheet = true
                    }
                }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        // 現在地を中心にする（ユーザー位置取得は MKMapView の user location 等で強化可能）
                        // ここでは最新の places の最初を中心にする例（無ければ既定のまま）
                        if let first = vm.places.first {
                            centerCoordinate = first.coordinate
                        }
                    }) {
                        Image(systemName: "location.fill")
                            .padding()
                            .background(Color.white.opacity(0.9))
                            .clipShape(Circle())
                    }
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showingSaveSheet, onDismiss: {
            selectedCoordinate = nil
        }) {
            if let coord = selectedCoordinate {
                SavePlaceView(vm: SavePlaceViewModel(coord: coord))
                    .environmentObject(auth)
            } else {
                // 安全策
                Text("座標が取得できませんでした").padding()
            }
        }
        .navigationTitle("マップ")
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
