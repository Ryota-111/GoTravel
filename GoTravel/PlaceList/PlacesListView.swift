import SwiftUI

struct PlacesListView: View {
    @StateObject private var vm = PlacesViewModel()

    var body: some View {
        NavigationView {
            Group {
                if vm.places.isEmpty {
                    VStack {
                        Text("まだ保存された場所はありません")
                            .foregroundColor(.secondary)
                            .padding()
                        Text("マップをタップして場所を追加しましょう")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        ForEach(vm.places) { place in
                            NavigationLink(destination: PlaceDetailView(place: place)) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(place.title).font(.headline)
                                        if let visited = place.visitedAt {
                                            Text(DateFormatter.localizedString(from: visited, dateStyle: .medium, timeStyle: .none))
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        } else {
                                            Text(DateFormatter.localizedString(from: place.createdAt, dateStyle: .medium, timeStyle: .none))
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 8)
                            }
                        }
                        .onDelete { idx in
                            let toDelete = idx.map { vm.places[$0] }
                            toDelete.forEach { place in
                                FirestoreService.shared.delete(place: place) { err in
                                    if let err = err {
                                        print("delete error:", err.localizedDescription)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("保存済みの場所")
        }
    }
}
