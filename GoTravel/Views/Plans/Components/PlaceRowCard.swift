import SwiftUI
import MapKit

// MARK: - Place Row Card
struct PlaceRowCard: View {
    let place: PlannedPlace
    let planColor: Color
    @State private var showMapView = false

    var body: some View {
        Button(action: {
            showMapView = true
        }) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    planColor,
                                    planColor.opacity(0.6)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)

                    Image(systemName: "mappin.circle.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                }
                .shadow(color: planColor.opacity(0.3), radius: 4, x: 0, y: 2)

                // Content
                VStack(alignment: .leading, spacing: 6) {
                    Text(place.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if let address = place.address {
                        Text(address)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                // Arrow
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
            )
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
        .fullScreenCover(isPresented: $showMapView) {
            PlaceDetailMapView(place: place, planColor: planColor)
        }
    }
}

// MARK: - Place Detail Map View
struct PlaceDetailMapView: View {
    let place: PlannedPlace
    let planColor: Color
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Map(initialPosition: .region(
                MKCoordinateRegion(
                    center: place.coordinate,
                    latitudinalMeters: 1000,
                    longitudinalMeters: 1000
                )
            )) {
                Marker(place.name, coordinate: place.coordinate)
                    .tint(planColor)
            }
            .edgesIgnoringSafeArea(.all)
            .navigationTitle(place.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                    .foregroundColor(planColor)
                }
            }
        }
    }
}
