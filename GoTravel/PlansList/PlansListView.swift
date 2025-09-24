import SwiftUI
import MapKit

struct PlansListView: View {
    @StateObject private var vm = PlansViewModel()
    @State private var showAddPlanSheet = false

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(gradient: Gradient(colors: [.blue, .black]), startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        PlanSectionView(
                            title: "現在の予定",
                            plans: vm.currentPlans,
                            emptyMessage: "現在進行中の予定はありません",
                            viewModel: vm
                        )
                        
                        PlanSectionView(
                            title: "今後の予定",
                            plans: vm.futurePlans,
                            emptyMessage: "今後の予定はありません",
                            viewModel: vm
                        )
                        
                        PlanSectionView(
                            title: "過去の予定",
                            plans: vm.pastPlans,
                            emptyMessage: "過去の予定はありません",
                            viewModel: vm
                        )
                    }
                    .padding()
                }
                
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        FloatingButton {
                            showAddPlanSheet = true
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("予定一覧")
            .sheet(isPresented: $showAddPlanSheet) {
                AddPlanView { plan in
                    vm.add(plan)
                }
            }
        }
    }
}

struct PlanSectionView: View {
    let title: String
    let plans: [Plan]
    let emptyMessage: String
    let viewModel: PlansViewModel
    
    @State private var planToDelete: Plan? = nil
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                if !plans.isEmpty {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    ForEach(plans) { plan in
                        PlanCardView(plan: plan, onDelete: {
                            planToDelete = plan
                            showingDeleteConfirmation = true
                        })
                    }
                }
            }
            .alert(isPresented: $showingDeleteConfirmation) {
                Alert(
                    title: Text("予定の削除"),
                    message: Text("この予定を本当に削除しますか？"),
                    primaryButton: .destructive(Text("削除")) {
                        if let plan = planToDelete {
                            viewModel.delete(plan)
                        }
                    },
                    secondaryButton: .cancel(Text("キャンセル"))
                )
            }
        }
}

struct PlanCardView: View {
    let plan: Plan
    var onDelete: (() -> Void)? = nil
    var body: some View {
        NavigationLink(destination: PlanDetailView(plan: plan)) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(plan.title)
                            .font(.headline)
                            .foregroundColor(.white)

                        Text("\(dateString(plan.startDate)) 〜 \(dateString(plan.endDate))")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }

                    Spacer()

                    if let onDelete = onDelete {
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .foregroundColor(.white)
                        }
                    }
                }

                Divider()
                    .background(Color.white.opacity(0.5))

                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.white)

                    Text("\(plan.places.count) 件の場所")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.blue.opacity(0.6)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(15)
            .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
        }
    }

    private func dateString(_ d: Date) -> String {
        DateFormatter.localizedString(from: d, dateStyle: .medium, timeStyle: .none)
    }
}

extension PlansViewModel {
    func delete(_ plan: Plan) {
        if let index = plans.firstIndex(where: { $0.id == plan.id }) {
            plans.remove(at: index)
        }
    }
    var currentPlans: [Plan] {
        plans.filter { plan in
            let now = Date()
            return plan.startDate <= now && plan.endDate >= now
        }.sorted { $0.endDate < $1.endDate }
    }
    
    var futurePlans: [Plan] {
        plans.filter { plan in
            let now = Date()
            return plan.startDate > now
        }.sorted { $0.startDate < $1.startDate }
    }
    
    var pastPlans: [Plan] {
        plans.filter { plan in
            let now = Date()
            return plan.endDate < now
        }.sorted { $0.endDate > $1.endDate }
    }
}
