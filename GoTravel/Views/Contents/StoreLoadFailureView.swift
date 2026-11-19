import SwiftUI
import UIKit

/// 端末の中のデータを開けなかったときの画面（3.8）。
///
/// 3.6 までは、ここで落ちていた。開けない理由は端末によって違う（空き容量が無い・ロックが解けていない など）ので、
/// 落とさずに知らせて、開き直せるようにする。
/// ロックが解けたときや、アプリが前に出たときにも、ひとりでに開き直す
struct StoreLoadFailureView: View {
    let failure: StoreLoadFailure

    @Environment(\.scenePhase) private var scenePhase
    @State private var isRetrying = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "externaldrive.badge.exclamationmark")
                    .font(.system(size: 52, weight: .regular))
                    .foregroundStyle(.orange)
                    .padding(.top, 72)

                Text("データを開けませんでした")
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 12) {
                    Text("これまでに入れた旅行や予定は消えていません。少し待ってから「もう一度開く」を押してください。")
                    if failure.looksLikeLowStorage {
                        Text("iPhone の空き容量が少ないようです。設定の「一般」→「iPhoneストレージ」で空きを作ってから、もう一度開いてください。")
                            .fontWeight(.semibold)
                    } else {
                        Text("直らないときは、iPhone の空き容量を確かめるか、iPhone を再起動してから開いてください。")
                    }
                }
                .font(.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    retry()
                } label: {
                    HStack(spacing: 8) {
                        if isRetrying {
                            ProgressView().tint(.white)
                        }
                        Text("もう一度開く")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(isRetrying)

                Text("この不具合の情報（エラーの番号だけ）は開発者に届きます。お問い合わせのときは、次の番号をお伝えください。\n\(failure.shortCode)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        // 裏から戻ってきたときだけ開き直す（起動した直後の「前に出た」では開き直さない。いま失敗したばかりなので）
        .onChange(of: scenePhase) { old, phase in
            if old == .background && phase == .active { retry() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataDidBecomeAvailableNotification)) { _ in
            retry()
        }
    }

    private func retry() {
        guard !isRetrying else { return }
        isRetrying = true
        // 押したことが分かるよう、少しだけ待ってから開く
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            CoreDataManager.shared.retryLoadingStores()
            isRetrying = false
        }
    }
}

#Preview {
    StoreLoadFailureView(failure: StoreLoadFailure(domain: "NSCocoaErrorDomain", code: 134110,
                                                   underlying: ["NSSQLiteErrorDomain 13"],
                                                   availableCapacity: 50_000_000))
}
