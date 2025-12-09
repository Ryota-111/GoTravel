import SwiftUI
import MapKit

// MARK: - Schedule Item Card
struct ScheduleItemCard: View {

    // MARK: - Properties
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var themeManager = ThemeManager.shared
    let item: ScheduleItem
    @Binding var editingItem: ScheduleItem?
    @State private var showMapView = false
    @State private var showLink = false

    // MARK: - Computed Properties
    private var hasLocationData: Bool {
        item.latitude != nil && item.longitude != nil
    }

    // MARK: - Body
    var body: some View {
        HStack(spacing: 15) {
            timeSection
            contentSection
            Spacer()
            actionButtonsSection
        }
        .padding()
        .background(Color.white.opacity(0.2))
        .cornerRadius(15)
        .sheet(isPresented: $showMapView) {
            mapViewSheet
        }
        .sheet(isPresented: $showLink) {
            if let linkURL = item.linkURL, let url = URL(string: linkURL) {
                SafariView(url: url)
            }
        }
    }

    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            if hasLocationData {
                mapActionButton
            }
            editButton
        }
    }

    private var editButton: some View {
        Button(action: {
            editingItem = item
        }) {
            Image(systemName: "pencil.circle.fill")
                .font(.system(size: 28))
                .foregroundColor(themeManager.currentTheme.primary)
        }
        .buttonStyle(.borderless)
    }

    private var mapActionButton: some View {
        Button(action: { showMapView = true }) {
            Image(systemName: "map.circle.fill")
                .font(.system(size: 28))
                .foregroundColor(themeManager.currentTheme.success)
        }
        .buttonStyle(.borderless)
    }

    private var mapViewSheet: some View {
        NavigationView {
            Group {
                if let latitude = item.latitude, let longitude = item.longitude {
                    Map(initialPosition: .region(MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    ))) {
                        if let location = item.location {
                            Marker(location, coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
                                .tint(themeManager.currentTheme.error)
                        } else {
                            Marker(item.title, coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
                                .tint(themeManager.currentTheme.error)
                        }
                    }
                } else {
                    Text("位置情報がありません")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle(item.location ?? item.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        showMapView = false
                    }
                }
                if let latitude = item.latitude, let longitude = item.longitude {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("マップで開く") {
                            openInMaps(latitude: latitude, longitude: longitude)
                        }
                    }
                }
            }
        }
    }

    // MARK: - View Components
    private var timeSection: some View {
        VStack(spacing: 5) {
            Text(formatTime(item.time))
                .font(.headline)
                .foregroundColor(themeManager.currentTheme.accent1)

            Image(systemName: "clock.fill")
                .foregroundColor(themeManager.currentTheme.accent1.opacity(0.7))
                .font(.caption)
        }
        .frame(width: 60)
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.title)
                .font(.headline)
                .foregroundColor(colorScheme == .dark ? .white : .black)

            if let location = item.location {
                locationInfo(location: location)
            }

            if let cost = item.cost {
                costInfo(cost: cost)
            }

            if let linkURL = item.linkURL {
                linkButton(linkURL: linkURL)
            }

            if let notes = item.notes {
                notesInfo(notes: notes)
            }
        }
    }

    private func locationInfo(location: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "mappin.circle.fill")
                .font(.caption)
                .foregroundColor(themeManager.currentTheme.accent1)
            Text(location)
                .font(.subheadline)
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.7))
        }
    }

    private func costInfo(cost: Double) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "yensign.circle.fill")
                .font(.caption)
                .foregroundColor(themeManager.currentTheme.success)
            Text(formatCurrency(cost))
                .font(.subheadline)
                .foregroundColor(themeManager.currentTheme.success)
        }
    }

    private func linkButton(linkURL: String) -> some View {
        Button(action: { showLink = true }) {
            HStack(spacing: 5) {
                Image(systemName: "link")
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.primary)
                Text("リンク")
                    .font(.subheadline)
                    .foregroundColor(themeManager.currentTheme.primary)
            }
        }
    }

    private func notesInfo(notes: String) -> some View {
        Text(notes)
            .font(.caption)
            .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : themeManager.currentTheme.secondaryText)
            .lineLimit(2)
    }

    // MARK: - Helper Methods
    private func formatTime(_ date: Date) -> String {
        DateFormatter.japaneseTime.string(from: date)
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return "¥\(formatter.string(from: NSNumber(value: amount)) ?? "0")"
    }

    private func openInMaps(latitude: Double, longitude: Double) {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = item.location ?? item.title
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
}
