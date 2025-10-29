import SwiftUI
import MapKit

struct PlaceDetailView: View {
    let place: VisitedPlace
    @State private var showEditSheet = false
    @State private var searchQuery: String = ""
    @State private var lookAroundScene: MKLookAroundScene?
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            backgroundGradient
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    headerSection

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
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
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
                        .foregroundColor(.orange)
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

    // MARK: - Background Gradient
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: colorScheme == .dark ?
                [Color.orange.opacity(0.3), Color.black] :
                [Color.orange.opacity(0.2), Color.white]),
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Category badge
            HStack {
                Image(systemName: place.category.iconName)
                    .font(.subheadline)
                Text(place.category.displayName)
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.orange.opacity(0.9))
            )

            // Title
            Text(place.title)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.primary)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemBackground))
        )
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    // MARK: - Address Section
    private func addressSection(_ address: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.circle.fill")
                .font(.title3)
                .foregroundStyle(.orange)
            Text(address)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    // MARK: - Notes Section
    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "note.text")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Text("メモ")
                    .font(.headline.bold())
                    .foregroundStyle(.primary)
            }

            Text(notes)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    // MARK: - Look Around Section
    private func lookAroundSection(_ scene: MKLookAroundScene) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "eye.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Text("ストリートビュー")
                    .font(.headline.bold())
                    .foregroundStyle(.primary)
            }

            LookAroundPreview(initialScene: scene,
                              allowsNavigation: true,
                              showsRoadLabels: true,
                              pointsOfInterest: .all,
                              badgePosition: .topLeading)
            .frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(alignment: .bottomTrailing) {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.caption)
                    Text(place.title)
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .padding(12)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    // MARK: - Map Section
    private var mapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "map.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Text("マップ")
                    .font(.headline.bold())
                    .foregroundStyle(.primary)
            }

            Map(
                position: .constant(
                    MapCameraPosition.region(
                        MKCoordinateRegion(center: place.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
                    )
                ),
                interactionModes: .all
            ) {
                Marker(place.title, coordinate: place.coordinate)
                    .tint(.orange)
            }
            .frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    // MARK: - Searchable Map Section
    private func searchableMapSection(_ address: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "map.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Text("マップ")
                    .font(.headline.bold())
                    .foregroundStyle(.primary)
            }

            SearchableMapView(searchQuery: $searchQuery, initialQuery: address)
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    // MARK: - Visit Date Section
    private var visitDateSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar.circle.fill")
                .font(.title3)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text("訪問日")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                if let visitedAt = place.visitedAt {
                    Text(visitedAt.japaneseYearMonthDay())
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                } else {
                    Text("未設定")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
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
