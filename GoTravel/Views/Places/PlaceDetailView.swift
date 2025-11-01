import SwiftUI
import MapKit

struct PlaceDetailView: View {
    let place: VisitedPlace

    @State private var showStreetView = false
    @State private var showMap = true
    @State private var lookAroundScene: MKLookAroundScene?
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Header Image
                headerImage

                // Content Card
                VStack(alignment: .leading, spacing: 15) {
                    // Category Tag
                    categoryTag
                    
                    // Title and Favorite
                    titleSection

                    // Notes Section
                    if let notes = place.notes, !notes.isEmpty {
                        notesSection(notes)
                    }

                    // Action Buttons
                    actionButtons

                    // Map Section (expandable)
                    if showMap {
                        mapSection
                    }

                    // Street View Section (expandable)
                    if showStreetView {
                        streetViewSection
                    }

                    // Visit Date
                    visitDateSection
                }
                .padding(24)
            }
        }
        .background(Color(.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadLookAroundScene()
        }
    }

    // MARK: - Header Image
    private var headerImage: some View {
        ZStack(alignment: .topTrailing) {
            // Placeholder or actual image
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.orange.opacity(0.6),
                            Color.orange.opacity(0.3)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 200)
                .overlay(
                    Image(systemName: place.category.iconName)
                        .font(.system(size: 80))
                        .foregroundColor(.white.opacity(0.3))
                )
                .cornerRadius(15)
                .padding(24)
        }
    }

    // MARK: - Title Section
    private var titleSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text(place.title)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)

                if let address = place.address {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text(address)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
            }

            Spacer()
        }
    }

    // MARK: - Category Tag
    private var categoryTag: some View {
        HStack(spacing: 8) {
            Image(systemName: place.category.iconName)
                .font(.caption)
            Text(place.category.displayName)
                .font(.subheadline.weight(.semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 13)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.orange)
        )
        .shadow(color: Color.orange.opacity(0.3), radius: 4, x: 0, y: 2)
    }

    // MARK: - Notes Section
    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "note.text")
                    .font(.headline)
                    .foregroundColor(.orange)
                Text("メモ")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
            }

            Text(notes)
                .font(.body)
                .foregroundColor(.secondary)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Action Buttons
    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Show on Map Button
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showMap.toggle()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: showMap ? "map.slash.fill" : "map.fill")
                        .font(.body)
                    Text(showMap ? "閉じる" : "マップで開く")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundColor(.orange)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.orange.opacity(0.6),
                                    Color.orange.opacity(0.1)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.orange, lineWidth: 2)
                        )
                )
            }
            .buttonStyle(ScaleButtonStyle())

            // Street View Button
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showStreetView.toggle()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: showStreetView ? "eye.slash.fill" : "eye.fill")
                        .font(.body)
                    Text(showStreetView ? "閉じる" : "ストリートビュー")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundColor(.orange)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.orange.opacity(0.6),
                                    Color.orange.opacity(0.1)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.orange, lineWidth: 2)
                        )
                )
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    // MARK: - Street View Section
    private var streetViewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "eye.circle.fill")
                    .font(.headline)
                    .foregroundColor(.orange)
                Text("ストリートビュー")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
            }

            if let scene = lookAroundScene {
                LookAroundPreview(
                    initialScene: scene,
                    allowsNavigation: true,
                    showsRoadLabels: true,
                    pointsOfInterest: .all,
                    badgePosition: .topLeading
                )
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(alignment: .bottomTrailing) {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption)
                        Text(place.title)
                            .font(.caption.weight(.medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(12)
                }
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Street Viewを読み込み中...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.tertiarySystemBackground))
                )
            }
        }
        .transition(.asymmetric(
            insertion: .scale.combined(with: .opacity),
            removal: .scale.combined(with: .opacity)
        ))
    }

    // MARK: - Map Section
    private var mapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "map.circle.fill")
                    .font(.headline)
                    .foregroundColor(.orange)
                Text("マップ")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
            }

            Map(position: .constant(.region(MKCoordinateRegion(
                center: place.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )))) {
                Marker(place.title, coordinate: place.coordinate)
                    .tint(.orange)
            }
            .frame(height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(alignment: .bottomTrailing) {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.caption)
                    Text(place.title)
                        .font(.caption.weight(.medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .padding(12)
            }
        }
        .transition(.asymmetric(
            insertion: .scale.combined(with: .opacity),
            removal: .scale.combined(with: .opacity)
        ))
    }

    // MARK: - Visit Date Section
    private var visitDateSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar.circle.fill")
                .font(.title3)
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 4) {
                Text("訪問日")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)

                if let visitedAt = place.visitedAt {
                    Text(visitedAt.japaneseYearMonthDay())
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                } else {
                    Text("未設定")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Helper Functions

    private func loadLookAroundScene() async {
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

// MARK: - Scale Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    NavigationStack {
        PlaceDetailView(
            place: VisitedPlace(
                title: "Munich",
                notes: "Beautiful city center with amazing architecture and history.", latitude: 48.1351, longitude: 11.5820, visitedAt: Date(), address: "Marienplatz 1, 80331 München", category: .hotel
            )
        )
    }
}
