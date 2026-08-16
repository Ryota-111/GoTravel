import SwiftUI
import CloudKit

// MARK: - Share Travel Plan View
struct ShareTravelPlanView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var viewModel: TravelPlanViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject var themeManager = ThemeManager.shared
    let plan: TravelPlan
    /// 生成したコードをパブリックDBへ公開する。失敗は throw で返る
    let onShareCodeGenerated: (String) async throws -> Void

    @State private var shareCode: String = ""
    @State private var showCopiedAlert = false
    @State private var showStopSharingConfirmation = false
    @State private var isPublishing = false
    @State private var showPublishError = false
    @State private var publishErrorMessage = ""

    /// ViewModelから常に最新のプランを参照する
    /// （`plan`はシート表示時点のコピーなので、コード生成やメンバー参加が反映されない）
    private var currentPlan: TravelPlan {
        viewModel.travelPlans.first(where: { $0.id == plan.id }) ?? plan
    }

    /// 招待メッセージ（共有シートで送る本文）
    private var inviteMessage: String {
        """
        「\(currentPlan.title)」の旅行計画に招待します！
        Travoryアプリの「共有に参加」から、この共有コードを入力してください。

        共有コード: \(shareCode)
        """
    }

    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient

                ScrollView {
                    VStack(spacing: 25) {
                        headerSection

                        if !shareCode.isEmpty {
                            shareCodeSection
                        } else {
                            generateCodeButton
                        }

                        infoSection
                    }
                    .padding()
                }
            }
            .navigationTitle("旅行計画を共有")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .confirmationDialog("共有を停止", isPresented: $showStopSharingConfirmation, titleVisibility: .visible) {
                Button("共有を停止する", role: .destructive) {
                    stopSharing()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("共有コードが無効になり、参加中のメンバーは全員この計画から外れます。再度共有する場合は、新しいコードを作成して全員に参加し直してもらう必要があります。")
            }
            .alert("共有コードを発行できませんでした", isPresented: $showPublishError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(publishErrorMessage)
            }
        }
        .onAppear {
            if let code = currentPlan.shareCode {
                shareCode = code
            }
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 15) {
            Image(systemName: "person.2.circle.fill")
                .font(.system(size: 70))
                .foregroundColor(themeManager.currentTheme.accent2.opacity(0.8))

            VStack(spacing: 8) {
                Text("この旅行計画を共有")
                    .font(.title2.bold())
                    .foregroundColor(themeManager.currentTheme.accent2)

                Text(plan.title)
                    .font(.headline)
                    .foregroundColor(themeManager.currentTheme.accent2)

                Text("共有コードを生成して、他のユーザーと一緒に旅行計画を編集できます")
                    .font(.subheadline)
                    .foregroundColor(themeManager.currentTheme.accent2.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }

    // MARK: - Generate Code Button
    private var generateCodeButton: some View {
        Button(action: generateShareCode) {
            HStack {
                if isPublishing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: themeManager.currentTheme.dark))

                    Text("発行中...")
                        .font(.headline)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)

                    Text("共有コードを生成")
                        .font(.headline)
                }
            }
            .foregroundColor(themeManager.currentTheme.dark)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [themeManager.currentTheme.accent2, themeManager.currentTheme.accent2.opacity(0.8)]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(15)
            .shadow(color: themeManager.currentTheme.accent1.opacity(0.3), radius: 10, x: 0, y: 5)
        }
        .disabled(isPublishing)
    }

    // MARK: - Share Code Section
    private var shareCodeSection: some View {
        VStack(spacing: 15) {
            Text("共有コード")
                .font(.headline)
                .foregroundColor(themeManager.currentTheme.dark)

            // Code Display
            HStack {
                Text(shareCode)
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(themeManager.currentTheme.dark)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(themeManager.currentTheme.accent2.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(themeManager.currentTheme.accent2.opacity(0.3), lineWidth: 2)
                    )
            }

            // Copy Button
            Button(action: copyShareCode) {
                HStack {
                    Image(systemName: showCopiedAlert ? "checkmark.circle.fill" : "doc.on.doc.fill")
                        .font(.title3)

                    Text(showCopiedAlert ? "コピーしました！" : "コードをコピー")
                        .font(.headline)
                }
                .foregroundColor(themeManager.currentTheme.dark)
                .frame(maxWidth: .infinity)
                .padding()
                .background(showCopiedAlert ? themeManager.currentTheme.success : themeManager.currentTheme.light.opacity(0.3))
                .cornerRadius(12)
            }
            .animation(.easeInOut(duration: 0.3), value: showCopiedAlert)

            // Share Button（LINEやメッセージでコードを送る）
            ShareLink(item: inviteMessage) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)

                    Text("コードを送る")
                        .font(.headline)
                }
                .foregroundColor(themeManager.currentTheme.dark)
                .frame(maxWidth: .infinity)
                .padding()
                .background(themeManager.currentTheme.light.opacity(0.3))
                .cornerRadius(12)
            }

            // Shared Users
            if !currentPlan.sharedWith.isEmpty {
                sharedUsersSection
            }

            // Stop Sharing（オーナーのみ）
            if let userId = authVM.userId, currentPlan.isOwner(userId: userId) {
                Button(action: { showStopSharingConfirmation = true }) {
                    HStack {
                        Image(systemName: "person.2.slash")
                            .font(.subheadline)

                        Text("共有を停止")
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundColor(themeManager.currentTheme.error)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(themeManager.currentTheme.accent2)
        )
        .shadow(color: themeManager.currentTheme.accent1.opacity(0.1), radius: 10, x: 0, y: 5)
    }

    // MARK: - Shared Users Section
    private var sharedUsersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()

            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(themeManager.currentTheme.dark)
                    .font(.headline)

                Text("共有メンバー")
                    .font(.headline)
                    .foregroundColor(themeManager.currentTheme.dark)

                Spacer()

                Text("\(currentPlan.sharedWith.count)人")
                    .font(.subheadline)
                    .foregroundColor(themeManager.currentTheme.dark)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(themeManager.currentTheme.accent2.opacity(0.2))
                    .cornerRadius(8)
            }

            // Member list
            VStack(spacing: 8) {
                ForEach(currentPlan.sharedWith, id: \.self) { userId in
                    memberRow(userId: userId, isOwner: userId == currentPlan.ownerId)
                }
            }
        }
    }

    private func memberRow(userId: String, isOwner: Bool) -> some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [themeManager.currentTheme.primary.opacity(0.8), themeManager.currentTheme.primary.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 36, height: 36)

                Image(systemName: "person.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
            }

            // User info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(formatUserId(userId))
                        .font(.subheadline)
                        .foregroundColor(themeManager.currentTheme.dark)

                    if isOwner {
                        Text("オーナー")
                            .font(.caption2)
                            .foregroundColor(themeManager.currentTheme.warning)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(themeManager.currentTheme.warning.opacity(0.2))
                            .cornerRadius(4)
                    }
                }

                Text("UID: \(userId.prefix(8))...")
                    .font(.caption2)
                    .foregroundColor(themeManager.currentTheme.secondaryText)
            }

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(themeManager.currentTheme.light.opacity(0.05))
        .cornerRadius(8)
    }

    private func formatUserId(_ userId: String) -> String {
        // For now, just show first 8 characters
        // In future, could fetch user display names from Firestore
        return "ユーザー \(userId.prefix(8))"
    }

    // MARK: - Info Section
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(themeManager.currentTheme.accent2)
                Text("共有機能について")
                    .font(.headline)
                    .foregroundColor(themeManager.currentTheme.accent2)
            }

            VStack(alignment: .leading, spacing: 8) {
                InfoRow(icon: "checkmark.circle", text: "共有コードを他のユーザーに送信できます")
                InfoRow(icon: "checkmark.circle", text: "コードを入力したユーザーが計画に参加できます")
                InfoRow(icon: "checkmark.circle", text: "全員がスケジュールを編集できます")
                InfoRow(icon: "checkmark.circle", text: "変更内容は自動的に同期されます")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(themeManager.currentTheme.accent2.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(themeManager.currentTheme.accent2.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Background
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [themeManager.currentTheme.gradientDark, themeManager.currentTheme.dark]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - Actions

    /// コードを生成してパブリックDBへ公開する。
    /// 公開に**成功してから**コードを表示する。先に表示すると、
    /// 公開されていないコードをコピーして相手に送れてしまい、
    /// 参加側で「見つかりませんでした」になる（実際に問い合わせが来た症状）。
    private func generateShareCode() {
        guard !isPublishing else { return }
        let code = TravelPlan.generateShareCode()
        isPublishing = true

        Task {
            do {
                try await onShareCodeGenerated(code)
                shareCode = code
            } catch {
                publishErrorMessage = Self.publishErrorText(for: error)
                showPublishError = true
            }
            isPublishing = false
        }
    }

    private static func publishErrorText(for error: Error) -> String {
        if let ckError = error as? CKError,
           ckError.code == .notAuthenticated {
            // サインイン済みでも規約更新の未同意などでCloudKitだけ使えない場合がある
            // （実際の問い合わせで確定した事例）ため、サインイン限定の書き方をしない
            return "iCloudが利用できない状態です。設定アプリを開き、iCloudにサインインしているか、規約への同意などの確認が保留になっていないかをご確認ください。"
        }
        return "通信環境をご確認のうえ、もう一度お試しください。"
    }

    private func stopSharing() {
        guard let planId = currentPlan.id, let userId = authVM.userId else { return }
        viewModel.stopSharing(planId: planId, userId: userId)
        shareCode = ""
    }

    private func copyShareCode() {
        UIPasteboard.general.string = shareCode
        showCopiedAlert = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopiedAlert = false
        }
    }
}

// MARK: - Info Row
struct InfoRow: View {
    let icon: String
    let text: String
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var themeManager = ThemeManager.shared

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(themeManager.currentTheme.accent2)
                .font(.caption)

            Text(text)
                .font(.caption)
                .foregroundColor(themeManager.currentTheme.secondaryText)
        }
    }
}
