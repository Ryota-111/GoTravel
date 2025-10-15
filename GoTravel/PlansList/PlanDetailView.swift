import SwiftUI
import MapKit

struct PlanDetailView: View {
    @State var plan: Plan
    @Environment(\.colorScheme) var colorScheme
    
    var onUpdate: ((Plan) -> Void)?

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    basicInfoSection

                    if plan.planType == .daily && hasDailyPlanDetails {
                        dailyPlanDetailsSection
                    }

                    if !plan.places.isEmpty {
                        mapSection
                        placesSection
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .frame(minHeight: geometry.size.height)
            }
        }
        .background(backgroundGradient)
        .navigationTitle(plan.planType == .outing ? "おでかけプラン" : "日常プラン")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            print("📱 PlanDetailView: プラン表示")
            print("   タイトル: \(plan.title)")
            print("   プランタイプ: \(plan.planType.rawValue)")
            print("   時間: \(plan.time?.description ?? "なし")")
            print("   説明: \(plan.description ?? "なし")")
            print("   リンク: \(plan.linkURL ?? "なし")")
        }
    }

    // MARK: - Computed Properties
    private var hasDailyPlanDetails: Bool {
        let hasDescription = plan.description != nil && !plan.description!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasLink = plan.linkURL != nil && !plan.linkURL!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasDescription || hasLink
    }
    
    // MARK: - Helper Views
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: plan.planType == .daily ? [.orange, colorScheme == .dark ? .black : .white] : (colorScheme == .dark ? [.blue.opacity(0.7), .black] : [.blue.opacity(0.8), .white])),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var mapSection: some View {
        Map(initialPosition: .region(calculateMapRegion())) {
            ForEach(plan.places) { place in
                Marker(place.name, coordinate: place.coordinate)
                    .tint(.red)
            }
        }
        .frame(height: 250)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(plan.title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(plan.planType == .daily ? .black : .primary)

            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(plan.planType == .daily ? .black : .primary)
                if plan.planType == .outing {
                    Text("\(dateRangeString(plan.startDate, plan.endDate))")
                        .foregroundColor(plan.planType == .daily ? .black.opacity(0.7) : .secondary)
                } else {
                    Text("\(formatDate(plan.startDate))")
                        .foregroundColor(plan.planType == .daily ? .black.opacity(0.7) : .secondary)
                }
            }

            if plan.planType == .daily, let time = plan.time {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(plan.planType == .daily ? .black : .primary)
                    Text("\(formatTime(time))")
                        .foregroundColor(plan.planType == .daily ? .black.opacity(0.7) : .secondary)
                }
            }
        }
    }

    private var dailyPlanDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let description = plan.description, !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("予定内容")
                        .font(.headline)
                        .foregroundColor(plan.planType == .daily ? .black : .primary)

                    Text(description)
                        .font(.body)
                        .foregroundColor(plan.planType == .daily ? .black.opacity(0.7) : .secondary)
                }
            }

            if let linkURL = plan.linkURL, !linkURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let url = URL(string: linkURL) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("関連リンク")
                        .font(.headline)
                        .foregroundColor(plan.planType == .daily ? .black : .primary)

                    Link(destination: url) {
                        HStack {
                            Image(systemName: "link")
                            Text(linkURL)
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                        }
                        .foregroundColor(plan.planType == .daily ? .black : .blue)
                        .padding()
                        .background(plan.planType == .daily ? Color.black.opacity(0.1) : Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
        }
    }

    private var placesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("訪問予定の場所")
                .font(.headline)

            ForEach(plan.places) { place in
                PlaceRow(place: place)
            }
        }
    }
    
    private func calculateMapRegion() -> MKCoordinateRegion {
        guard let firstPlace = plan.places.first else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 36.2048, longitude: 138.2529),
                span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
            )
        }
        
        return MKCoordinateRegion(
            center: firstPlace.coordinate,
            latitudinalMeters: CLLocationDistance(max(plan.places.count * 1000, 2000)),
            longitudinalMeters: CLLocationDistance(max(plan.places.count * 1000, 2000))
        )
    }
    
    private func dateRangeString(_ start: Date, _ end: Date) -> String {
        let formatter = DateFormatter.japaneseDate
        return "\(formatter.string(from: start)) 〜 \(formatter.string(from: end))"
    }

    private func formatDate(_ date: Date) -> String {
        DateFormatter.japaneseDate.string(from: date)
    }

    private func formatTime(_ time: Date) -> String {
        DateFormatter.japaneseTime.string(from: time)
    }
}

struct PlaceRow: View {
    let place: PlannedPlace
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(place.name)
                    .font(.headline)
                
                if let address = place.address {
                    Text(address)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            NavigationLink(destination: PlaceDetailMapView(place: place)) {
                Image(systemName: "map.fill")
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

struct PlaceDetailMapView: View {
    let place: PlannedPlace
    
    var body: some View {
        Map(initialPosition: .region(
            MKCoordinateRegion(
                center: place.coordinate,
                latitudinalMeters: 1000,
                longitudinalMeters: 1000
            )
        )) {
            Marker(place.name, coordinate: place.coordinate)
                .tint(.red)
        }
        .edgesIgnoringSafeArea(.all)
        .navigationTitle(place.name)
    }
}
