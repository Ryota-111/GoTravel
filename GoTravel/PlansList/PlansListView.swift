import SwiftUI
import MapKit

struct PlansListView: View {
    @StateObject private var vm = PlansViewModel()
    @State private var showAddPlanSheet = false

    var body: some View {
        NavigationView {
            ZStack {
                Group {
                    if vm.plans.isEmpty {
                        VStack(spacing: 12) {
                            Text("予定はまだありません").foregroundColor(.secondary)
                            Text("＋ボタンで予定を追加しましょう").font(.subheadline).foregroundColor(.secondary)
                        }
                        .padding()
                    } else {
                        List {
                            ForEach(vm.plans) { plan in
                                NavigationLink(destination: PlanDetailView(plan: plan, onUpdate: { updated in
                                    vm.update(updated)
                                })) {
                                    VStack(alignment: .leading) {
                                        Text(plan.title).font(.headline)
                                        Text("\(dateString(plan.startDate)) 〜 \(dateString(plan.endDate))")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Text("\(plan.places.count) 件の場所").font(.caption).foregroundColor(.secondary)
                                    }
                                }
                            }
                            .onDelete(perform: vm.delete)
                            .onMove(perform: vm.move)
                        }
                        .listStyle(PlainListStyle())
                    }
                }
                // FloatingButton を画面右下に重ねる
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        FloatingButton {
                            showAddPlanSheet = true
                        }
                        // Safe area 下の余白を加える
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
                // もし「マイページの上のあたり」に置きたい場合は上の VStack を以下のように変更してください:
                // VStack {
                //     HStack {
                //         Spacer()
                //         FloatingButton { showAddPlanSheet = true }
                //             .padding(.trailing, 20)
                //             .padding(.top, 90) // 調整して「マイページの上あたり」に配置
                //     }
                //     Spacer()
                // }
            }
            .navigationTitle("予定一覧")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !vm.plans.isEmpty {
                        EditButton()
                    }
                }
                // 左上や右上のツールバーは不要になったので削除しています（元の＋ボタンを移動）
            }
            .sheet(isPresented: $showAddPlanSheet) {
                AddPlanView { plan in
                    vm.add(plan)
                }
            }
        }
    }

    private func dateString(_ d: Date) -> String {
        DateFormatter.localizedString(from: d, dateStyle: .medium, timeStyle: .none)
    }
}
