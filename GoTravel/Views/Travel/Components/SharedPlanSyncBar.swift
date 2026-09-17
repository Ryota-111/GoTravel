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
/// ## 見せ方
///
/// **普段は限りなく静かに、何か起きたときだけ目立つ。**
///
/// ほとんどの時間に出るのは「2人で共有中・3分前」という平常の情報で、
/// それを箱で囲って色を付けると、常に注意書きが出ているように見える。
/// この画面で静かな情報は枠なしの1行（天気のメモ）なので、それに揃える。
///
/// **状態が変わっても、位置と大きさを動かさない。**
/// 背景の箱を出し入れしていたときは、そのたびに余白ぶん中身がずれて、
/// 別の部品に見えていた。変えるのは色と言葉とアイコンだけにする。
/// アイコンの幅も固定して、文字の始まりがぶれないようにしている。
///
/// 「確かめたが変わっていなかった」は知らせない。
/// 時刻が「たった今更新」に変わることが、そのまま答えになっているため。
///
/// **共有していない計画では何も描かない。** 置く側に分岐は要らない。
struct SharedPlanSyncBar: View {
    let plan: TravelPlan

    @EnvironmentObject var viewModel: TravelPlanViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject private var themeManager = ThemeManager.shared

    /// 結果を数秒だけ出すためのもの。
    /// 出しっぱなしだと、いつの結果なのか分からなくなる
    @State private var showsResult = false

    private var theme: ThemePreset { themeManager.currentTheme }
    private var planId: String { plan.id ?? "" }
    private var state: TravelPlanViewModel.SyncState? { viewModel.syncStates[planId] }

    var body: some View {
        if plan.isShared {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    // 記号ごとに幅が違う。揃えないと文字の始まりが動く
                    .frame(width: 14)

                Text(message)
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 4)

                trailingControl
            }
            .foregroundColor(tint)
            // 行の高さも固定する。ぐるぐると矢印と「もう一度」で高さが違うと、
            // 状態が移るたびに下の内容が上下する
            .frame(height: 24)
            .animation(.easeInOut(duration: 0.2), value: tint)
            .task(id: planId) {
                // 開いたときに一度だけそろえる。
                // 以降はボタンを押したときだけにして、開くたびの通信を避ける
                guard let userId = authVM.userId, state == nil else { return }
                await viewModel.refreshSharedPlan(planId: planId, userId: userId)
                flashResultIfUpdated()
            }
        }
    }

    // MARK: - 右端

    @ViewBuilder
    private var trailingControl: some View {
        switch state {
        case .syncing:
            ProgressView()
                .controlSize(.small)
                .frame(width: 24, height: 24)

        case .failed:
            // 失敗のときは文字にする。何をすればいいかが一目で分かる
            Button("もう一度", action: refresh)
                .font(.caption.weight(.semibold))
                .foregroundColor(theme.error)
                .frame(height: 24)

        case .unshared:
            EmptyView()

        default:
            Button(action: refresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ThemePreset.readableTint(theme.actionFill, on: theme.backgroundLight))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("共有の内容を更新")
        }
    }

    private func refresh() {
        guard let userId = authVM.userId else { return }
        Task {
            await viewModel.refreshSharedPlan(planId: planId, userId: userId)
            flashResultIfUpdated()
        }
    }

    /// 取り込みがあったときだけ、数秒だけ知らせる。
    /// 変わっていなければ時刻の表示が新しくなるだけで足りる
    private func flashResultIfUpdated() {
        guard state == .updated else { return }
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
        default:
            return "\(memberText)・\(lastSyncedText)"
        }
    }

    private var icon: String {
        switch state {
        case .syncing:  return "arrow.triangle.2.circlepath"
        case .failed:   return "exclamationmark.triangle.fill"
        case .unshared: return "person.2.slash"
        case .updated where showsResult:
            return "checkmark.circle.fill"
        default:        return "person.2.fill"
        }
    }

    private var tint: Color {
        switch state {
        case .failed:
            return theme.error
        case .updated where showsResult:
            return theme.success
        default:
            return theme.secondaryText
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
