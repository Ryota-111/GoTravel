import SwiftUI

struct EnjoyWorldView: View {
    @StateObject private var travelPlanViewModel = TravelPlanViewModel()
    @StateObject private var plansViewModel = PlansViewModel()
    @State private var selectedTab = "All"
    @State private var likedPlans: Set<String> = []
    @State private var selectedEventType: EventType? = .hotel
    @State private var showAddTravelPlan = false
    @State private var planToDelete: TravelPlan? = nil
    @State private var showDeleteConfirmation = false
    @Environment(\.colorScheme) var colorScheme

    let tabs = ["All", "Popular", "Tours"]

    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Button(action: {}) {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 24))
                                .foregroundColor(.black)
                        }

                        Spacer()

                        Button(action: {}) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 24))
                                .foregroundColor(.black)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

                    // Title
                    Text("Enjoy The World")
                        .font(.custom("Poppins-SemiBold", size: 28))
                        .padding(.horizontal, 20)

                    // Tab Selection
                    HStack(spacing: 15) {
                        ForEach(tabs, id: \.self) { tab in
                            Button(action: {
                                withAnimation(.spring()) {
                                    selectedTab = tab
                                }
                            }) {
                                Text(tab)
                                    .font(.custom("Poppins-Regular", size: 16))
                                    .foregroundColor(selectedTab == tab ? .white : .gray)
                                    .padding(.horizontal, 25)
                                    .padding(.vertical, 10)
                                    .background(
                                        Capsule()
                                            .fill(selectedTab == tab ? Color("cOrange") : Color.clear)
                                    )
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)

                    // Travel Cards
                    if travelPlanViewModel.travelPlans.isEmpty {
                        // プランがない場合：追加ボタンのみ表示
                        Button(action: {
                            showAddTravelPlan = true
                        }) {
                            VStack(spacing: 15) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(Color("cOrange"))

                                Text("旅行計画を作成")
                                    .font(.custom("Poppins-SemiBold", size: 18))
                                    .foregroundColor(.primary)

                                Text("新しい旅行計画を追加してください")
                                    .font(.custom("Poppins-Regular", size: 14))
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(width: 250, height: 250)
                            .background(Color.white)
                            .cornerRadius(25)
                            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                        }
                        .padding(.horizontal, 20)
                    } else {
                        // プランがある場合：カードと追加ボタンを横スクロール
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 15) {
                                ForEach(travelPlanViewModel.travelPlans) { plan in
                                    TravelPlanCard(
                                        plan: plan,
                                        isLiked: likedPlans.contains(plan.id ?? ""),
                                        onLikeTap: {
                                            if let id = plan.id {
                                                if likedPlans.contains(id) {
                                                    likedPlans.remove(id)
                                                } else {
                                                    likedPlans.insert(id)
                                                }
                                            }
                                        },
                                        onDelete: {
                                            planToDelete = plan
                                            showDeleteConfirmation = true
                                        }
                                    )
                                }

                                // 追加ボタン
                                Button(action: {
                                    showAddTravelPlan = true
                                }) {
                                    VStack {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 50))
                                            .foregroundColor(Color("cOrange"))

                                        Text("追加")
                                            .font(.custom("Poppins-SemiBold", size: 16))
                                            .foregroundColor(.primary)
                                    }
                                    .frame(width: 150, height: 250)
                                    .background(Color.white)
                                    .cornerRadius(25)
                                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }

                    // All Events Section
                    HStack {
                        Text("All Events")
                            .font(.custom("Poppins-SemiBold", size: 22))
                            .foregroundColor(.black)

                        Spacer()

                        Button(action: {}) {
                            Text("See All")
                                .font(.custom("Poppins-Regular", size: 16))
                                .foregroundColor(Color("cOrange"))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

                    // Event Type Icons
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 20) {
                            ForEach(EventType.allCases) { eventType in
                                horizontalEventsCard(
                                    menuName: eventType.displayName,
                                    menuImage: eventType.iconName,
                                    rectColor: selectedEventType == eventType ? Color("cOrange") : Color.white,
                                    imageColors: selectedEventType == eventType ? .white : Color("cOrange"),
                                    textColor: selectedEventType == eventType ? Color("cOrange") : .gray
                                )
                                .onTapGesture {
                                    withAnimation(.spring()) {
                                        selectedEventType = eventType
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    // Hotel List
                    VStack(spacing: 15) {
                        ForEach(Hotels.allCases) { hotel in
                            NavigationLink(destination: HotelDetailView(hotel: hotel)) {
                                EventList(
                                    eventName: hotel.displayName,
                                    eventImage: hotel.imageName,
                                    eventLocation: hotel.locationName,
                                    eventLocationImage: "mappin.circle",
                                    eventPrice: hotel.price,
                                    eventRate: hotel.rate,
                                    eventRateImage: "star.fill"
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: colorScheme == .dark ? [.blue.opacity(0.7), .black] : [.blue.opacity(0.8), .white]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
        }
        .sheet(isPresented: $showAddTravelPlan) {
            AddTravelPlanView { newPlan in
                travelPlanViewModel.add(newPlan)
            }
        }
        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text("旅行計画を削除"),
                message: Text("この旅行計画を本当に削除しますか？"),
                primaryButton: .destructive(Text("削除")) {
                    if let plan = planToDelete {
                        travelPlanViewModel.delete(plan)
                    }
                },
                secondaryButton: .cancel(Text("キャンセル"))
            )
        }
    }
}

struct TravelPlanCard: View {
    let plan: TravelPlan
    let isLiked: Bool
    let onLikeTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ZStack {
            // Background Image or Color
            if let localImageFileName = plan.localImageFileName,
               let image = FileManager.documentsImage(named: localImageFileName) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 250, height: 250)
                    .cornerRadius(25)
            } else {
                RoundedRectangle(cornerRadius: 25)
                    .fill(
                        LinearGradient(
                            colors: [
                                plan.cardColor?.opacity(0.8) ?? Color.blue.opacity(0.8),
                                plan.cardColor?.opacity(0.4) ?? Color.blue.opacity(0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 250, height: 250)
            }

            // Overlay for better text visibility
            RoundedRectangle(cornerRadius: 25)
                .fill(Color.black.opacity(0.3))
                .frame(width: 250, height: 250)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Button(action: onDelete) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.white)
                                .frame(width: 40, height: 40)
                            Image(systemName: "trash")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 20, height: 20)
                                .foregroundColor(.red)
                        }
                    }

                    Spacer()

                    Button(action: onLikeTap) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.white)
                                .frame(width: 40, height: 40)
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 25, height: 25)
                                .foregroundColor(Color("cOrange"))
                        }
                    }
                }

                Spacer()

                Text(plan.title)
                    .font(.custom("Poppins-SemiBold", size: 18))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                HStack(spacing: 5) {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundColor(.white)
                    Text(plan.destination)
                        .font(.custom("Poppins-Light", size: 14))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                HStack(spacing: 5) {
                    Image(systemName: "calendar")
                        .foregroundColor(.white)
                    Text(dateRangeString(from: plan.startDate, to: plan.endDate))
                        .font(.custom("Poppins-Light", size: 14))
                        .foregroundStyle(.white)
                }
            }
            .padding()
        }
        .frame(width: 250, height: 250)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }

    private func dateRangeString(from start: Date, to end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
}

enum EventType: String, CaseIterable, Identifiable {
    case hotel
    case camp
    case ship
    case flight
    case mountain

    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .hotel:
            return "Hotel"
        case .camp:
            return "Camp"
        case .ship:
            return "Ship"
        case .flight:
            return "Flight"
        case .mountain:
            return "Mountain"
        }
    }

    var iconName: String {
        switch self {
        case .hotel:
            return "house.fill"
        case .camp:
            return "tent.fill"
        case .ship:
            return "ferry.fill"
        case .flight:
            return "airplane"
        case .mountain:
            return "mountain.2.fill"
        }
    }
}

#Preview {
    EnjoyWorldView()
}
