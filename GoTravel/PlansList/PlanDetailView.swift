import SwiftUI
import MapKit

struct PlanDetailView: View {
    @State var plan: Plan
    
    var onUpdate: ((Plan) -> Void)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                basicInfoSection

                if !plan.places.isEmpty {
                    mapSection
                    placesSection
                }
            }
            .padding()
        }
        .navigationTitle("旅行プラン")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var mapSection: some View {
        Map(initialPosition: .region(calculateMapRegion())) {
            ForEach(plan.places) { place in
                Marker(place.name, coordinate: place.coordinate)
                    .tint(.red)
            }
        }
        .frame(height: 250)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(plan.title)
                .font(.title2)
                .fontWeight(.bold)

            HStack {
                Image(systemName: "calendar")
                Text("\(dateRangeString(plan.startDate, plan.endDate))")
                    .foregroundColor(.secondary)
            }
        }
    }

    private var placesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("訪問予定の場所")
                .font(.headline)

            ForEach(plan.places) { place in
                PlaceRow(place: place)
            }
        }
    }
    
    private func calculateMapRegion() -> MKCoordinateRegion {
        guard let firstPlace = plan.places.first else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 36.2048, longitude: 138.2529),
                span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
            )
        }
        
        return MKCoordinateRegion(
            center: firstPlace.coordinate,
            latitudinalMeters: CLLocationDistance(max(plan.places.count * 1000, 2000)),
            longitudinalMeters: CLLocationDistance(max(plan.places.count * 1000, 2000))
        )
    }
    
    private func dateRangeString(_ start: Date, _ end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        
        return "\(formatter.string(from: start)) 〜 \(formatter.string(from: end))"
    }
}

struct PlaceRow: View {
    let place: PlannedPlace
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(place.name)
                    .font(.headline)
                
                if let address = place.address {
                    Text(address)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            NavigationLink(destination: PlaceDetailMapView(place: place)) {
                Image(systemName: "map.fill")
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

struct PlaceDetailMapView: View {
    let place: PlannedPlace
    
    var body: some View {
        Map(initialPosition: .region(
            MKCoordinateRegion(
                center: place.coordinate,
                latitudinalMeters: 1000,
                longitudinalMeters: 1000
            )
        )) {
            Marker(place.name, coordinate: place.coordinate)
                .tint(.red)
        }
        .edgesIgnoringSafeArea(.all)
        .navigationTitle(place.name)
    }
}
