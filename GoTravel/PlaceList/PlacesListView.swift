import SwiftUI

struct PlacesListView: View {
    @StateObject private var vm = PlacesViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [.blue.opacity(0.7), .black]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack {
                    if vm.places.isEmpty {
                        emptyStateView
                    } else {
                        placesListView
                    }
                }
            }
            .navigationTitle("保存済みの場所")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "map.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.white.opacity(0.7))
            
            Text("まだ保存された場所はありません")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("マップをタップして場所を追加しましょう")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding()
    }
    
    private var placesListView: some View {
        ScrollView {
            VStack(spacing: 15) {
                ForEach(vm.places) { place in
                    placeCardView(place)
                }
            }
            .padding()
        }
    }
    
    private func placeCardView(_ place: VisitedPlace) -> some View {
        NavigationLink(destination: PlaceDetailView(place: place)) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.white)
                    
                    Text(place.title)
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                Divider()
                    .background(Color.white.opacity(0.5))
                
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text(formattedDate(place))
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [.black.opacity(0.6), .blue.opacity(0.7)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(15)
            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
        }
        .contextMenu {
            Button(role: .destructive) {
                deletePlace(place)
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
    }
    
    private func formattedDate(_ place: VisitedPlace) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        
        return place.visitedAt != nil
            ? formatter.string(from: place.visitedAt!)
            : formatter.string(from: place.createdAt)
    }
    
    private func deletePlace(_ place: VisitedPlace) {
        FirestoreService.shared.delete(place: place) { err in
            if let err = err {
                print("delete error:", err.localizedDescription)
            }
        }
    }
}
