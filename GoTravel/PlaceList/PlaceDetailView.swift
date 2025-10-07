import SwiftUI
import MapKit

struct PlaceDetailView: View {
    let place: VisitedPlace
    @State private var showEditSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // デバッグ情報
                Text("座標: \(place.latitude), \(place.longitude)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let notes = place.notes, !notes.isEmpty {
                    Text(notes).font(.body)
                }
                if let addr = place.address {
                    Text(addr).font(.subheadline).foregroundColor(.secondary)
                }
                Map(
                    position: .constant(
                        MapCameraPosition.region(
                            MKCoordinateRegion(center: place.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
                        )
                    ),
                    interactionModes: .all
                )
                .frame(height: 200)
                .cornerRadius(8)
                
                if let urlStr = place.photoURL, let url = URL(string: urlStr) {
                    Text("写真")
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
                } else if let localName = place.localPhotoFileName, let ui = FileManager.documentsImage(named: localName) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .cornerRadius(8)
                }
            }
            .padding()
        }
        .navigationTitle(place.title)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showEditSheet = true
                }) {
                    Text("編集")
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            EditVisitedPlaceView(place: place)
        }
    }
}
