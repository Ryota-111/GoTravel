import SwiftUI
import MapKit

struct PlaceDetailView: View {
    let place: VisitedPlace

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let urlStr = place.photoURL, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(maxWidth: .infinity, minHeight: 200)
                        case .success(let image):
                            image.resizable().scaledToFit().frame(maxHeight: 300).cornerRadius(8)
                        case .failure:
                            Color.gray.frame(height: 200)
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
                Text(place.title).font(.title2).bold()
                if let notes = place.notes, !notes.isEmpty {
                    Text(notes).font(.body)
                }
                if let addr = place.address {
                    Text(addr).font(.subheadline).foregroundColor(.secondary)
                }
                Map(coordinateRegion: .constant(MKCoordinateRegion(center: place.coordinate, latitudinalMeters: 500, longitudinalMeters: 500)), interactionModes: [])
                    .frame(height: 200)
                    .cornerRadius(8)
                Spacer()
            }
            .padding()
        }
        .navigationTitle("詳細")
    }
}
