import SwiftUI

// MARK: - Schedule Item Card
struct ScheduleItemCard: View {

    // MARK: - Properties
    @Environment(\.colorScheme) var colorScheme
    let item: ScheduleItem
    @Binding var editingItem: ScheduleItem?
    @State private var showMapView = false
    @State private var showLink = false

    // MARK: - Body
    var body: some View {
        HStack(spacing: 15) {
            timeSection
            contentSection
            Spacer()
            if item.mapURL != nil {
                mapButton
            }
        }
        .padding()
        .background(Color.white.opacity(0.2))
        .cornerRadius(15)
        .contentShape(Rectangle())
        .onTapGesture {
            editingItem = item
        }
        .sheet(isPresented: $showMapView) {
            if let mapURL = item.mapURL, let url = URL(string: mapURL) {
                SafariView(url: url)
            }
        }
        .sheet(isPresented: $showLink) {
            if let linkURL = item.linkURL, let url = URL(string: linkURL) {
                SafariView(url: url)
            }
        }
    }

    // MARK: - View Components
    private var timeSection: some View {
        VStack(spacing: 5) {
            Text(formatTime(item.time))
                .font(.headline)
                .foregroundColor(.orange)

            Image(systemName: "clock.fill")
                .foregroundColor(.orange.opacity(0.7))
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
                .foregroundColor(.orange)
            Text(location)
                .font(.subheadline)
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.7))
        }
    }

    private func costInfo(cost: Double) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "yensign.circle.fill")
                .font(.caption)
                .foregroundColor(.green)
            Text(formatCurrency(cost))
                .font(.subheadline)
                .foregroundColor(.green)
        }
    }

    private func linkButton(linkURL: String) -> some View {
        Button(action: { showLink = true }) {
            HStack(spacing: 5) {
                Image(systemName: "link")
                    .font(.caption)
                    .foregroundColor(.blue)
                Text("リンク")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
        }
    }

    private func notesInfo(notes: String) -> some View {
        Text(notes)
            .font(.caption)
            .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .gray)
            .lineLimit(2)
    }

    private var mapButton: some View {
        Button(action: { showMapView = true }) {
            ZStack {
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 80, height: 80)
                    .cornerRadius(10)

                Image(systemName: "map.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.blue)
            }
        }
        .buttonStyle(PlainButtonStyle())
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
}
