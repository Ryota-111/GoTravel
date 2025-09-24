import SwiftUI
import MapKit

struct PlanDetailView: View {
    @State var plan: Plan
    var onUpdate: ((Plan) -> Void)?
    @State private var region: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.2048, longitude: 138.2529),
        span: MKCoordinateSpan(latitudeDelta: 14, longitudeDelta: 14)
    )
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 39.2048, longitude: 138.2529),
            span: MKCoordinateSpan(latitudeDelta: 14, longitudeDelta: 14)
        )
    )

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if !plan.places.isEmpty {
                    Map(position: $cameraPosition) {
                        ForEach(plan.places) { place in
                            Marker("場所", coordinate: place.coordinate)
                                .tint(.red)
                        }
                    }
                    .frame(height: 300)
                    .onAppear {
                        if let first = plan.places.first {
                            region = MKCoordinateRegion(center: first.coordinate, latitudinalMeters: 2000, longitudinalMeters: 2000)
                        }
                    }
                } else {
                    Color.gray.frame(height: 200).overlay(Text("場所がありません").foregroundColor(.white))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(plan.title).font(.title2).bold()
                    Text("\(dateString(plan.startDate)) 〜 \(dateString(plan.endDate))").foregroundColor(.secondary)
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    Text("行きたい場所").font(.headline).padding(.horizontal)
                    if plan.places.isEmpty {
                        Text("まだ登録されていません").foregroundColor(.secondary).padding(.horizontal)
                    } else {
                        ForEach(plan.places) { p in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(p.name).font(.body)
                                    if let a = p.address { Text(a).font(.caption).foregroundColor(.secondary) }
                                }
                                Spacer()
                                NavigationLink(destination: MapViewForPlace(place: p)) {
                                    Image(systemName: "map")
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }

                Spacer(minLength: 20)
            }
        }
        .navigationTitle("予定詳細")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func dateString(_ d: Date) -> String {
        DateFormatter.localizedString(from: d, dateStyle: .medium, timeStyle: .none)
    }
}

struct MapViewForPlace: View {
    let place: PlannedPlace
    @State private var region: MKCoordinateRegion
    @State private var cameraPosition: MapCameraPosition

    init(place: PlannedPlace) {
        self.place = place
        _region = State(initialValue: MKCoordinateRegion(center: place.coordinate, latitudinalMeters: 800, longitudinalMeters: 800))
        _cameraPosition = State(initialValue: .region(
            MKCoordinateRegion(
                center: place.coordinate,
                latitudinalMeters: 500,
                longitudinalMeters: 500
            )
        ))
    }

    var body: some View {
        Map(position: $cameraPosition) {
            ForEach([place]) { p in
                Marker("場所", coordinate: p.coordinate)
                    .tint(.red)
            }
        }
        .edgesIgnoringSafeArea(.all)
        .navigationTitle(place.name)
    }
}
