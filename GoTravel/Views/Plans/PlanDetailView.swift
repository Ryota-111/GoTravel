import SwiftUI
import MapKit

struct PlanDetailView: View {
    @State var plan: Plan
    @Environment(\.colorScheme) var colorScheme
    @State private var sidebarOffset: CGFloat = -250
    @State private var showSidebar = false
    @State private var showEditSheet = false
    @EnvironmentObject var viewModel: PlansViewModel

    var onUpdate: ((Plan) -> Void)?

    var body: some View {
        ZStack(alignment: .leading) {
            // Main Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection

                    if plan.planType == .daily && hasDailyPlanDetails {
                        dailyPlanDetailsSection
                    }

                    if !plan.places.isEmpty {
                        mapSection
                        placesSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .background(backgroundGradient)
            .offset(x: showSidebar ? 280 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showSidebar)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.width > 0 && !showSidebar {
                            showSidebar = true
                        } else if value.translation.width < -50 && showSidebar {
                            showSidebar = false
                        }
                    }
            )

            // Overlay to close sidebar
            if showSidebar {
                Color.black.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        showSidebar = false
                    }
                    .transition(.opacity)
            }

            // Sidebar
            sidebarView
                .offset(x: showSidebar ? 0 : -280)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showSidebar)
                .zIndex(1)
        }
        .navigationTitle(plan.planType == .outing ? "おでかけプラン" : "日常プラン")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showEditSheet = true
                }) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title3)
                        .foregroundColor(plan.planType == .daily ? .orange : .blue)
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            EditPlanView(plan: plan, viewModel: viewModel)
        }
    }

    // MARK: - Computed Properties
    private var hasDailyPlanDetails: Bool {
        let hasDescription = plan.description != nil && !plan.description!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasLink = plan.linkURL != nil && !plan.linkURL!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasDescription || hasLink
    }

    // MARK: - Computed Properties for Sidebar
    private var sortedPlans: [Plan] {
        viewModel.plans.sorted { $0.startDate < $1.startDate }
    }

    // MARK: - Sidebar View
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("スケジュール")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    Spacer()
                }

                Text("\(sortedPlans.count)件のプラン")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(20)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        plan.planType == .daily ? Color.orange : Color.blue,
                        (plan.planType == .daily ? Color.orange : Color.blue).opacity(0.8)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            // Schedule List
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(sortedPlans) { schedulePlan in
                        sidebarPlanItem(plan: schedulePlan)
                    }
                }
                .padding(12)
            }
            .background(Color(.systemBackground))
        }
        .frame(width: 280)
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.2), radius: 15, x: 5, y: 0)
    }

    private func sidebarPlanItem(plan schedulePlan: Plan) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                plan = schedulePlan
                showSidebar = false
            }
        }) {
            HStack(alignment: .top, spacing: 12) {
                // Plan type icon
                ZStack {
                    Circle()
                        .fill(schedulePlan.planType == .daily ?
                              LinearGradient(gradient: Gradient(colors: [.orange, .orange.opacity(0.7)]), startPoint: .topLeading, endPoint: .bottomTrailing) :
                              LinearGradient(gradient: Gradient(colors: [.blue, .blue.opacity(0.7)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 50, height: 50)

                    Image(systemName: schedulePlan.planType == .outing ? "airplane" : "calendar")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }
                .shadow(color: (schedulePlan.planType == .daily ? Color.orange : Color.blue).opacity(0.3), radius: 4, x: 0, y: 2)

                VStack(alignment: .leading, spacing: 6) {
                    Text(schedulePlan.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        if schedulePlan.planType == .outing {
                            Text(dateRangeString(schedulePlan.startDate, schedulePlan.endDate))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text(formatDate(schedulePlan.startDate))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if !schedulePlan.places.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.caption2)
                                .foregroundColor(schedulePlan.planType == .daily ? .orange : .blue)
                            Text("\(schedulePlan.places.count)件")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                if schedulePlan.id == plan.id {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(schedulePlan.planType == .daily ? .orange : .blue)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(schedulePlan.id == plan.id ?
                          (schedulePlan.planType == .daily ? Color.orange.opacity(0.1) : Color.blue.opacity(0.1)) :
                          Color(.tertiarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(schedulePlan.id == plan.id ?
                            (schedulePlan.planType == .daily ? Color.orange.opacity(0.4) : Color.blue.opacity(0.4)) :
                            Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }


    // MARK: - Helper Views
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: colorScheme == .dark ?
                [Color(.systemBackground), Color(.systemBackground)] :
                [plan.planType == .daily ? Color.orange.opacity(0.05) : Color.blue.opacity(0.05), Color(.systemBackground)]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Plan type badge
            HStack {
                Image(systemName: plan.planType == .outing ? "airplane.circle.fill" : "calendar.circle.fill")
                    .font(.title3)
                    .foregroundColor(plan.planType == .daily ? .orange : .blue)

                Text(plan.planType == .outing ? "おでかけ" : "日常")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(plan.planType == .daily ? .orange : .blue)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill((plan.planType == .daily ? Color.orange : Color.blue).opacity(0.15))
            )

            // Title
            Text(plan.title)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.primary)

            // Date and time info
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.subheadline)
                        .foregroundColor(plan.planType == .daily ? .orange : .blue)
                        .frame(width: 24)

                    if plan.planType == .outing {
                        Text(dateRangeString(plan.startDate, plan.endDate))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text(formatDate(plan.startDate))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                if plan.planType == .daily, let time = plan.time {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.fill")
                            .font(.subheadline)
                            .foregroundColor(plan.planType == .daily ? .orange : .blue)
                            .frame(width: 24)
                        Text(formatTime(time))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                if !plan.places.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.subheadline)
                            .foregroundColor(plan.planType == .daily ? .orange : .blue)
                            .frame(width: 24)
                        Text("\(plan.places.count)件の場所")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.top, 8)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemBackground))
        )
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    private var mapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("マップ")
                .font(.headline.bold())
                .foregroundColor(.primary)
                .padding(.leading, 4)

            Map(initialPosition: .region(calculateMapRegion())) {
                ForEach(plan.places) { place in
                    Marker(place.name, coordinate: place.coordinate)
                        .tint(plan.planType == .daily ? .orange : .blue)
                }
            }
            .frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
        }
    }

    private var dailyPlanDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let description = plan.description, !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "text.alignleft")
                            .font(.headline)
                            .foregroundColor(plan.planType == .daily ? .orange : .blue)
                        Text("予定内容")
                            .font(.headline.bold())
                            .foregroundColor(.primary)
                    }

                    Text(description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemBackground))
                )
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
            }

            if let linkURL = plan.linkURL, !linkURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let url = URL(string: linkURL) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "link")
                            .font(.headline)
                            .foregroundColor(plan.planType == .daily ? .orange : .blue)
                        Text("関連リンク")
                            .font(.headline.bold())
                            .foregroundColor(.primary)
                    }

                    Link(destination: url) {
                        HStack {
                            Image(systemName: "safari")
                                .foregroundColor(plan.planType == .daily ? .orange : .blue)
                            Text(linkURL)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill((plan.planType == .daily ? Color.orange : Color.blue).opacity(0.1))
                        )
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemBackground))
                )
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
            }
        }
    }

    private var placesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("訪問予定の場所")
                .font(.headline.bold())
                .foregroundColor(.primary)
                .padding(.leading, 4)

            ForEach(plan.places) { place in
                PlaceRow(place: place, planType: plan.planType)
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
    let planType: PlanType
    @State private var showMapView = false

    var body: some View {
        Button(action: {
            showMapView = true
        }) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    planType == .daily ? Color.orange : Color.blue,
                                    (planType == .daily ? Color.orange : Color.blue).opacity(0.6)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)

                    Image(systemName: "mappin.circle.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                }
                .shadow(color: (planType == .daily ? Color.orange : Color.blue).opacity(0.3), radius: 4, x: 0, y: 2)

                // Content
                VStack(alignment: .leading, spacing: 6) {
                    Text(place.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if let address = place.address {
                        Text(address)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                // Arrow
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
            )
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .fullScreenCover(isPresented: $showMapView) {
            PlaceDetailMapView(place: place)
        }
    }
}

struct PlaceDetailMapView: View {
    let place: PlannedPlace
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
}
