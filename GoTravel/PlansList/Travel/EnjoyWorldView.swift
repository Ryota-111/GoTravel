import SwiftUI

struct EnjoyWorldView: View {
    @StateObject private var travelPlanViewModel = TravelPlanViewModel()
    @StateObject private var plansViewModel = PlansViewModel()
    @State private var selectedTab = "All"
    @State private var selectedEventType: EventType? = .hotel
    @State private var showAddTravelPlan = false
    @State private var showAddPlan = false
    @State private var planToDelete: TravelPlan? = nil
    @State private var showDeleteConfirmation = false
    @State private var planEventToDelete: Plan? = nil
    @State private var showPlanDeleteConfirmation = false
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
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

                    Text("旅行計画")
                        .font(.title.weight(.semibold))
                        .padding(.horizontal, 20)

                    HStack(spacing: 15) {
                        ForEach(tabs, id: \.self) { tab in
                            Button(action: {
                                withAnimation(.spring()) {
                                    selectedTab = tab
                                }
                            }) {
                                Text(tab)
                                    .font(.body)
                                    .foregroundColor(selectedTab == tab ? .white : .gray)
                                    .padding(.horizontal, 25)
                                    .padding(.vertical, 10)
                                    .background(
                                        Capsule()
                                            .fill(selectedTab == tab ? .orange : Color.clear)
                                    )
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)

                    if travelPlanViewModel.travelPlans.isEmpty {
                        Button(action: {
                            showAddTravelPlan = true
                        }) {
                            VStack(spacing: 15) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.orange)

                                Text("旅行計画を作成")
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                Text("新しい旅行計画を追加してください")
                                    .font(.subheadline)
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
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 15) {
                                ForEach(travelPlanViewModel.travelPlans) { plan in
                                    TravelPlanCard(
                                        plan: plan,
                                        onDelete: {
                                            print("🎯 EnjoyWorldView: onDeleteクロージャが呼ばれました - \(plan.title)")
                                            planToDelete = plan
                                            showDeleteConfirmation = true
                                            print("📋 EnjoyWorldView: planToDelete = \(planToDelete?.title ?? "nil"), showDeleteConfirmation = \(showDeleteConfirmation)")
                                        }
                                    )
                                }

                                Button(action: {
                                    showAddTravelPlan = true
                                }) {
                                    VStack {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 50))
                                            .foregroundColor(.orange)

                                        Text("予定を追加")
                                            .font(.headline)
                                            .foregroundColor(.orange)
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

                    HStack {
                        Text("予定計画")
                            .font(.title.weight(.semibold))

                        Spacer()

                        Button(action: {}) {
                            Text("See All")
                                .font(.body)
                                .foregroundColor(.orange)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 20) {
                            ForEach(EventType.allCases) { eventType in
                                horizontalEventsCard(
                                    menuName: eventType.displayName,
                                    menuImage: eventType.iconName,
                                    rectColor: selectedEventType == eventType ? .orange : Color.white,
                                    imageColors: selectedEventType == eventType ? .white : .orange,
                                    textColor: selectedEventType == eventType ? .orange : .gray
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
                    VStack(spacing: 15) {
                        if plansViewModel.plans.isEmpty {
                            VStack(spacing: 15) {
                                Image(systemName: "calendar.badge.plus")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray.opacity(0.5))

                                Text("まだ予定がありません")
                                    .font(.body)
                                    .foregroundColor(.gray)

                                Button(action: {
                                    showAddPlan = true
                                }) {
                                    Text("予定を追加")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 30)
                                        .padding(.vertical, 12)
                                        .background(.orange)
                                        .cornerRadius(25)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            ForEach(plansViewModel.plans.prefix(3)) { plan in
                                NavigationLink(destination: PlanDetailView(plan: plan)) {
                                    PlanEventCard(
                                        plan: plan,
                                        onTap: {},
                                        onDelete: {
                                            planEventToDelete = plan
                                            showPlanDeleteConfirmation = true
                                        }
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }

                            Button(action: {
                                showAddPlan = true
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.orange)
                                    Text("予定を追加")
                                        .font(.headline)
                                        .foregroundColor(.orange)
                                }
                                .padding(.vertical, 15)
                                .frame(maxWidth: .infinity)
                                .background(Color.white)
                                .cornerRadius(15)
                                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                            }

                            if plansViewModel.plans.count > 3 {
                                NavigationLink(destination: PlansListView()) {
                                    HStack {
                                        Text("すべての予定を見る")
                                            .font(.headline)
                                        Image(systemName: "arrow.right")
                                    }
                                    .foregroundColor(.orange)
                                    .padding(.vertical, 10)
                                }
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
            .sheet(isPresented: $showAddTravelPlan) {
                AddTravelPlanView { newPlan in
                    travelPlanViewModel.add(newPlan)
                }
            }
            .sheet(isPresented: $showAddPlan) {
                AddPlanView { newPlan in
                    plansViewModel.add(newPlan)
                }
            }
            .alert("旅行計画を削除", isPresented: $showDeleteConfirmation, presenting: planToDelete) { plan in
                Button("削除", role: .destructive) {
                    print("🗑️ Alert: 削除ボタンが押されました")
                    print("✅ Alert: planToDeleteが存在 - \(plan.title)")
                    travelPlanViewModel.delete(plan)
                    planToDelete = nil
                }
                Button("キャンセル", role: .cancel) {
                    print("🚫 Alert: キャンセルボタンが押されました")
                    planToDelete = nil
                }
            } message: { plan in
                Text("「\(plan.title)」を本当に削除しますか？")
            }
            .alert("予定を削除", isPresented: $showPlanDeleteConfirmation, presenting: planEventToDelete) { plan in
                Button("削除", role: .destructive) {
                    plansViewModel.deletePlan(plan)
                    planEventToDelete = nil
                }
                Button("キャンセル", role: .cancel) {
                    planEventToDelete = nil
                }
            } message: { plan in
                Text("「\(plan.title)」を本当に削除しますか？")
            }
        }
    }
}

struct TravelPlanCard: View {
    let plan: TravelPlan
    let onDelete: () -> Void
    @State private var showingDetail = false

    var body: some View {
        ZStack {
            // Background
            ZStack {
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

                RoundedRectangle(cornerRadius: 25)
                    .fill(Color.black.opacity(0.3))
                    .frame(width: 250, height: 250)
            }
            .onTapGesture {
                showingDetail = true
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Button(action: {
                        print("🗑️ TravelPlanCard: 削除ボタンがタップされました")
                        onDelete()
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.white)
                                .frame(width: 40, height: 40)
                            Image(systemName: "trash")
                                .resizable()
                                .frame(width: 20, height: 20)
                                .foregroundColor(.red)
                        }
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .zIndex(1)

                    Spacer()
                }

                Spacer()

                VStack(alignment: .leading, spacing: 5) {
                    Text(plan.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    HStack(spacing: 5) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundColor(.white)
                        Text(plan.destination)
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }

                    HStack(spacing: 5) {
                        Image(systemName: "calendar")
                            .foregroundColor(.white)
                        Text(dateRangeString(from: plan.startDate, to: plan.endDate))
                            .font(.subheadline)
                            .foregroundStyle(.white)
                    }
                }
                .allowsHitTesting(false)
            }
            .padding()
        }
        .frame(width: 250, height: 250)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        .sheet(isPresented: $showingDetail) {
            Text("TravelPlan詳細画面（未実装）")
                .font(.title)
                .padding()
        }
    }

    private func dateRangeString(from start: Date, to end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
}

struct PlanEventCard: View {
    let plan: Plan
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 25)
                .fill(.white)
                .frame(height: 130)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)

            HStack(spacing: 15) {
                ZStack {
                    if let localImageFileName = plan.localImageFileName,
                       let image = FileManager.documentsImage(named: localImageFileName) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 130, height: 130)
                            .cornerRadius(radius: 25, corners: [.topLeft, .bottomLeft])
                            .clipped()
                    } else {
                        LinearGradient(
                            colors: [
                                (plan.cardColor ?? Color.blue).opacity(0.8),
                                (plan.cardColor ?? Color.blue).opacity(0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .frame(width: 130, height: 130)
                        .cornerRadius(radius: 25, corners: [.topLeft, .bottomLeft])

                        VStack {
                            Image(systemName: "calendar")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(plan.title)
                            .font(.headline)
                            .foregroundColor(.black)
                            .lineLimit(1)

                        Spacer()

                        Button(action: {
                            onDelete()
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 16))
                                .foregroundColor(.red)
                                .padding(8)
                        }
                    }

                    HStack(spacing: 5) {
                        Image(systemName: "calendar.circle")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        Text(dateRangeString(from: plan.startDate, to: plan.endDate))
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    HStack {
                        HStack(spacing: 3) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.orange)
                            Text("\(plan.places.count)箇所")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }

                        Spacer()

                        let days = Calendar.current.dateComponents([.day], from: plan.startDate, to: plan.endDate).day ?? 0
                        HStack(spacing: 3) {
                            Image(systemName: "moon.stars.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.orange)
                            Text("\(days)泊\(days + 1)日")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.vertical, 10)
                .padding(.trailing, 15)
            }
        }
        .frame(height: 130)
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
