import SwiftUI
import MapKit

struct PlaceDetailView: View {
    let place: VisitedPlace
    @State private var showEditSheet = false
    @State private var searchQuery: String = ""
    @State private var lookAroundScene: MKLookAroundScene?

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [.blue.opacity(0.3), .white]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    categoryBadge
                    titleSection

                    if let addr = place.address {
                        addressSection(addr)
                    }

                    if let notes = place.notes, !notes.isEmpty {
                        notesSection(notes)
                    }

                    if place.latitude != 0 || place.longitude != 0 {
                        if let lookAroundScene {
                            lookAroundSection(lookAroundScene)
                        }

                        mapSection
                    } else if let addr = place.address {
                        searchableMapSection(addr)
                    }

                    visitDateSection
                }
                .padding(.horizontal)
                .padding(.vertical, 24)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showEditSheet = true
                }) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            EditVisitedPlaceView(place: place)
        }
        .task {
            await loadLookAroundScene()
        }
    }

    // MARK: - Category Badge
    private var categoryBadge: some View {
        HStack {
            Image(systemName: place.category.iconName)
            Text(place.category.displayName)
        }
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.blue.opacity(0.8))
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Title Section
    private var titleSection: some View {
        Text(place.title)
            .font(.system(size: 28, weight: .bold))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Address Section
    private func addressSection(_ address: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "mappin.circle.fill")
                .foregroundStyle(.red)
            Text(address)
                .font(.subheadline)
                .foregroundStyle(.gray)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    // MARK: - Notes Section
    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("メモ", systemImage: "note.text")
                .font(.headline)
                .foregroundStyle(.black)

            Text(notes)
                .font(.body)
                .foregroundStyle(.gray)
                .lineSpacing(4)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    // MARK: - Look Around Section
    private func lookAroundSection(_ scene: MKLookAroundScene) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("ストリートビュー", systemImage: "eye.circle.fill")
                .font(.headline)
                .foregroundStyle(.black)

            LookAroundPreview(initialScene: scene,
                              allowsNavigation: true,
                              showsRoadLabels: true,
                              pointsOfInterest: .all,
                              badgePosition: .topLeading)
            .frame(height: 250)
            .cornerRadius(12)
            .overlay(alignment: .bottomTrailing) {
                HStack {
                    Image(systemName: "mappin.circle.fill")
                    Text(place.title)
                }
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .padding(10)
                .background(.ultraThinMaterial)
                .cornerRadius(8)
                .padding(10)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    // MARK: - Map Section
    private var mapSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("マップ", systemImage: "map.fill")
                .font(.headline)
                .foregroundStyle(.black)

            Map(
                position: .constant(
                    MapCameraPosition.region(
                        MKCoordinateRegion(center: place.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
                    )
                ),
                interactionModes: .all
            ) {
                Marker(place.title, coordinate: place.coordinate)
                    .tint(.red)
            }
            .frame(height: 250)
            .cornerRadius(12)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    // MARK: - Searchable Map Section
    private func searchableMapSection(_ address: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("マップ", systemImage: "map.fill")
                .font(.headline)
                .foregroundStyle(.black)

            SearchableMapView(searchQuery: $searchQuery, initialQuery: address)
                .frame(height: 250)
                .cornerRadius(12)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    // MARK: - Visit Date Section
    private var visitDateSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar")
                .foregroundStyle(.blue)
            Text("訪問日:")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.black)
            if let visitedAt = place.visitedAt {
                Text(visitedAt.japaneseYearMonthDay())
                    .font(.subheadline)
                    .foregroundStyle(.gray)
            } else {
                Text("未設定")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    func loadLookAroundScene() async {
        guard place.latitude != 0 || place.longitude != 0 else { return }
        lookAroundScene = nil
        do {
            let request = MKLookAroundSceneRequest(coordinate: place.coordinate)
            lookAroundScene = try await request.scene
        } catch {
            print("Look Around scene not available: \(error)")
        }
    }
}
