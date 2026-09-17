import SwiftUI

/// 共有中の旅行計画に出す、同期の様子と更新ボタン。
///
/// これまで更新の手段は**ホームを引っぱること**しか無く、
/// 共有した計画を見ている画面からは更新できなかった。
/// しかも引っぱる操作は、やってみるまで存在が見えない。
///
/// さらに同期の状態がどこにも出ていなかったため、いま見ている内容が
/// 最新なのか古いのかを判断する材料がゼロだった。
/// 「3分前に更新」が出ていれば、古ければ自分で押せばよいと分かる。
///
/// **共有していない計画では何も描かない。** 置く側に分岐は要らない。
struct SharedPlanSyncBar: View {
    let plan: TravelPlan

    @EnvironmentObject var viewModel: TravelPlanViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject private var themeManager = ThemeManager.shared

    /// 「最新にしました」を数秒だけ出すためのもの。
    /// 出しっぱなしだと、いつの結果なのか分からなくなる
    @State private var showsResult = false

    private var theme: ThemePreset { themeManager.currentTheme }
    private var planId: String { plan.id ?? "" }
    private var state: TravelPlanViewModel.SyncState? { viewModel.syncStates[planId] }

    var body: some View {
        if plan.isShared {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(tint)

                Text(message)
                    .font(.system(size: 12))
                    .foregroundColor(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 4)

                refreshButton
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(tint.opacity(0.10))
            )
            .task(id: planId) {
                // 開いたときに一度だけそろえる。
                // 以降はボタンを押したときだけにして、開くたびの通信を避ける
                guard let userId = authVM.userId, state == nil else { return }
                await viewModel.refreshSharedPlan(planId: planId, userId: userId)
                flashResult()
            }
        }
    }

    private var refreshButton: some View {
        Button {
            guard let userId = authVM.userId else { return }
            Task {
                await viewModel.refreshSharedPlan(planId: planId, userId: userId)
                flashResult()
            }
        } label: {
            if state == .syncing {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 26, height: 26)
            } else {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ThemePreset.readableTint(theme.actionFill, on: theme.backgroundLight))
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
        .disabled(state == .syncing)
        .accessibilityLabel("共有の内容を更新")
    }

    /// 結果は数秒で引っ込め、そのあとは「◯分前に更新」に戻す
    private func flashResult() {
        showsResult = true
        Task {
            try? await Task.sleep(for: .seconds(3))
            showsResult = false
        }
    }

    // MARK: - 出す言葉

    private var memberText: String {
        let count = max(plan.sharedWith.count, 1)
        return count > 1 ? "\(count)人で共有中" : "共有中"
    }

    private var message: String {
        switch state {
        case .syncing:
            return "更新しています…"
        case .failed:
            return "更新できませんでした"
        case .unshared:
            return "この共有は解除されました"
        case .updated where showsResult:
            return "最新の内容にしました"
        case .upToDate where showsResult:
            return "最新です"
        default:
            return "\(memberText)・\(lastSyncedText)"
        }
    }

    private var icon: String {
        switch state {
        case .failed:   return "exclamationmark.triangle.fill"
        case .unshared: return "person.2.slash"
        case .updated where showsResult, .upToDate where showsResult:
            return "checkmark.circle.fill"
        default:        return "person.2.fill"
        }
    }

    private var tint: Color {
        switch state {
        case .failed:   return theme.error
        case .unshared: return theme.secondaryText
        case .updated where showsResult, .upToDate where showsResult:
            return theme.success
        default:        return theme.secondaryText
        }
    }

    /// 「3分前に更新」。これが古ければ、押せばよいと分かる
    private var lastSyncedText: String {
        guard let date = SharedPlanBaseStore.lastSyncedAt(planId: planId) else {
            return "まだ更新していません"
        }

        let seconds = Date().timeIntervalSince(date)
        if seconds < 60 { return "たった今更新" }

        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.unitsStyle = .short
        return "\(formatter.localizedString(for: date, relativeTo: Date()))に更新"
    }
}
