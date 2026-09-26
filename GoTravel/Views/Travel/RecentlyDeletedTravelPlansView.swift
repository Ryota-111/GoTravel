import SwiftUI

/// 最近削除した旅行計画。30日間はここから戻せる。
///
/// 「過去の旅行計画が一切表示されなくなった」と報告があり、
/// 消したものを取り戻す手段がまったく無かったため作った
struct RecentlyDeletedTravelPlansView: View {
    @EnvironmentObject var viewModel: TravelPlanViewModel
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme

    @State private var planToDeleteForever: TravelPlanViewModel.DeletedTravelPlan?
    @State private var showEmptyTrashConfirmation = false
    @State private var restoredTitle: String?

    private var textColor: Color {
        themeManager.currentTheme.adaptiveText(for: colorScheme)
    }

    var body: some View {
        List {
            Section {
                Text("削除した旅行計画は\(TravelPlanViewModel.trashRetentionDays)日間ここに残り、その後自動で完全に削除されます。共有していた計画は、戻すと自分だけの計画になります。")
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.secondaryText)
            }

            if viewModel.recentlyDeleted.isEmpty {
                Section {
                    Text("最近削除した旅行計画はありません")
                        .font(.subheadline)
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                }
            } else {
                Section {
                    ForEach(viewModel.recentlyDeleted) { item in
                        row(item)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    planToDeleteForever = item
                                } label: {
                                    Label("完全に削除", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    restore(item)
                                } label: {
                                    Label("戻す", systemImage: "arrow.uturn.backward")
                                }
                                .tint(themeManager.currentTheme.success)
                            }
                    }
                }
            }
        }
        .navigationTitle("最近削除した旅行計画")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !viewModel.recentlyDeleted.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("すべて削除", role: .destructive) {
                        showEmptyTrashConfirmation = true
                    }
                    .foregroundColor(themeManager.currentTheme.error)
                }
            }
        }
        .alert("完全に削除しますか？", isPresented: Binding(
            get: { planToDeleteForever != nil },
            set: { if !$0 { planToDeleteForever = nil } }
        ), presenting: planToDeleteForever) { item in
            Button("完全に削除", role: .destructive) {
                viewModel.deletePermanently(planId: item.id)
            }
            Button("キャンセル", role: .cancel) {}
        } message: { item in
            Text("「\(item.plan.title)」を完全に削除します。写真とアルバムも削除され、元に戻せません。")
        }
        .alert("すべて完全に削除しますか？", isPresented: $showEmptyTrashConfirmation) {
            Button("すべて削除", role: .destructive) {
                viewModel.emptyTrash()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("\(viewModel.recentlyDeleted.count)件の旅行計画を完全に削除します。写真とアルバムも削除され、元に戻せません。")
        }
        .overlay(alignment: .bottom) {
            if let restoredTitle {
                Text("「\(restoredTitle)」を戻しました")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.black.opacity(0.75)))
                    .padding(.bottom, 24)
                    .transition(.opacity)
            }
        }
    }

    private func row(_ item: TravelPlanViewModel.DeletedTravelPlan) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.plan.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(textColor)
                    .lineLimit(2)

                Text("\(dateRange(item.plan))・\(item.plan.destination)")
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.secondaryText)
                    .lineLimit(1)

                Text(item.daysUntilPurge == 0 ? "今日中に完全に削除されます" : "あと\(item.daysUntilPurge)日で完全に削除されます")
                    .font(.caption2)
                    .foregroundColor(item.daysUntilPurge <= 3
                                     ? themeManager.currentTheme.error
                                     : themeManager.currentTheme.secondaryText)
            }

            Spacer(minLength: 8)

            // スワイプに気づかない人のために、戻すボタンは見えるところに置く
            Button("戻す") { restore(item) }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.bordered)
                .tint(themeManager.currentTheme.actionFill)
        }
        .padding(.vertical, 4)
    }

    private func restore(_ item: TravelPlanViewModel.DeletedTravelPlan) {
        viewModel.restore(planId: item.id)
        withAnimation { restoredTitle = item.plan.title }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { if restoredTitle == item.plan.title { restoredTitle = nil } }
        }
    }

    private func dateRange(_ plan: TravelPlan) -> String {
        let formatter = DateFormatter.japanese
        formatter.dateFormat = "yyyy/M/d"
        return "\(formatter.string(from: plan.startDate))〜\(formatter.string(from: plan.endDate))"
    }
}
