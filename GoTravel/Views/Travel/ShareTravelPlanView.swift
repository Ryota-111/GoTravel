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
    /// この旅行での自分の呼び方を変えるとき
    @State private var showRename = false
    @State private var renameText = ""
    @State private var renameFailed = false
    /// ウェブで見る用の合言葉（3.5、`SharedWebPage`）。nil ならオフ。開いたときは覚え書きの値で出し、共有レコードで確かめ直す
    @State private var webToken: String?
    @State private var isUpdatingWebPage = false
    /// 切り替えるたびに増やす。確かめ直しの結果が、そのあとの切り替えを古い値で上書きしないように使う
    @State private var webPageGeneration = 0
    /// 共有をやめる途中（先にウェブのページを止めている）
    @State private var isStoppingSharing = false
    @State private var stopSharingError: String?
    @State private var webPageError: String?
    @State private var showWebLinkCopied = false

    private var webPageEnabled: Bool { webToken != nil }

    /// ウェブで見るリンク。共有コードは入れない（見る用の合言葉だけ）
    private var webPageURL: URL? {
        guard let planId = currentPlan.id, let webToken else { return nil }
        return SharedWebPage.url(planId: planId, token: webToken)
    }

    /// ViewModelから常に最新のプランを参照する
    /// （`plan`はシート表示時点のコピーなので、コード生成やメンバー参加が反映されない）
    private var currentPlan: TravelPlan {
        viewModel.travelPlans.first(where: { $0.id == plan.id }) ?? plan
    }

    /// 招待メッセージ（共有シートで送る本文）。ウェブで見られるなら、そのリンクも添える
    private var inviteMessage: String {
        var message = """
        「\(currentPlan.title)」の旅行計画に招待します！
        Travoryアプリの「共有に参加」から、この共有コードを入力してください。

        共有コード: \(shareCode)
        """
        if let url = webPageURL {
            message += "\n\nアプリが無くても（Androidでも）、ここから見られます：\n\(url.absoluteString)"
        }
        return message
    }

    /// ウェブで見る設定を変えられるのは、計画を作った人だけ
    private var canChangeWebPage: Bool {
        guard let userId = authVM.userId else { return false }
        return currentPlan.isOwner(userId: userId)
    }

    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient

                ScrollView {
                    VStack(spacing: 25) {
                        // 同期の様子と手動の更新。旅行計画の画面では困ったときしか出さないので、
                        // 「いつ更新されたか」を確かめたい人はここを見る
                        if currentPlan.isShared {
                            SharedPlanSyncBar(plan: currentPlan, presentation: .always)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(themeManager.currentTheme.secondaryText.opacity(0.08))
                                )
                        }

                        headerSection

                        if !shareCode.isEmpty {
                            shareCodeSection
                            webPageSection
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
            .alert("この旅行での呼び方", isPresented: $showRename) {
                TextField("例：父、さくら", text: $renameText)
                Button("保存") { saveMyName() }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("共有メンバーに見える名前です。空にすると、プロフィールの名前に戻ります。")
            }
            .alert("呼び方を変更できませんでした", isPresented: $renameFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("通信環境をご確認のうえ、もう一度お試しください。")
            }
            .alert("共有をやめられませんでした", isPresented: Binding(
                get: { stopSharingError != nil }, set: { if !$0 { stopSharingError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("ウェブで見るページを止められなかったため、共有はそのままです。" + (stopSharingError ?? ""))
            }
            .alert("ウェブで見る設定を変えられませんでした", isPresented: Binding(
                get: { webPageError != nil }, set: { if !$0 { webPageError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(webPageError ?? "")
            }
            .alert("共有コードを発行できませんでした", isPresented: $showPublishError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(publishErrorMessage)
            }
        }
        .navigationViewStyle(.stack)
        .onAppear {
            if let code = currentPlan.shareCode {
                shareCode = code
            }
            if let planId = currentPlan.id {
                webToken = SharedWebPage.cachedToken(planId: planId)
            }
        }
        .task(id: shareCode) { await refreshWebPageState() }
    }

    // MARK: - Web Page Section（3.5）
    /// ウェブでも見られるようにする。オンにすると、リンクを開いた人がアプリ無しで（Android でも）見られる
    private var webPageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: Binding(get: { webPageEnabled }, set: { setWebPage($0) })) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("ウェブでも見られるようにする")
                        .font(.headline)
                        .foregroundColor(themeManager.currentTheme.dark)
                    Text("リンクを開いた人は、アプリが無くても（Androidでも）ブラウザで見られます。見るだけで、直すことはできません。")
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.dark.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(themeManager.currentTheme.success)
            .disabled(!canChangeWebPage || isUpdatingWebPage)

            if isUpdatingWebPage {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }

            if !canChangeWebPage {
                Text("ウェブで見る設定は、計画を作った人が変えられます。")
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.dark.opacity(0.75))
            }

            if let url = webPageURL {
                Text(url.absoluteString)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundColor(themeManager.currentTheme.dark)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(themeManager.currentTheme.light.opacity(0.3)))
                    .textSelection(.enabled)

                HStack(spacing: 10) {
                    Button {
                        UIPasteboard.general.url = url
                        showWebLinkCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showWebLinkCopied = false }
                    } label: {
                        Label(showWebLinkCopied ? "コピーしました" : "リンクをコピー",
                              systemImage: showWebLinkCopied ? "checkmark.circle.fill" : "link")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(themeManager.currentTheme.light.opacity(0.3)))
                    }
                    ShareLink(item: url, message: Text("「\(currentPlan.title)」の旅行計画")) {
                        Label("リンクを送る", systemImage: "square.and.arrow.up")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(themeManager.currentTheme.light.opacity(0.3)))
                    }
                }
                .foregroundColor(themeManager.currentTheme.dark)

                Text("リンクを知っている人は誰でも見られます。予約番号やメモも見えるので、送る相手に気をつけてください。")
                    .font(.caption2)
                    .foregroundColor(themeManager.currentTheme.dark.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(themeManager.currentTheme.accent2)
        )
        .shadow(color: themeManager.currentTheme.accent1.opacity(0.1), radius: 10, x: 0, y: 5)
    }

    /// 共有レコードの値で確かめ直す（ほかの端末で変えていることもある）
    private func refreshWebPageState() async {
        guard !shareCode.isEmpty, let planId = currentPlan.id else { return }
        let generation = webPageGeneration
        guard let token = try? await CloudKitService.shared.sharedWebPageToken(planId: planId) else { return }
        // 読んでいる間に切り替えていたら、その結果のほうが新しいので捨てる
        guard generation == webPageGeneration, !isUpdatingWebPage else { return }
        webToken = token
        SharedWebPage.cache(token: token, planId: planId)
    }

    private func setWebPage(_ enabled: Bool) {
        guard canChangeWebPage, !isUpdatingWebPage, enabled != webPageEnabled, let planId = currentPlan.id else { return }
        let previous = webToken
        webPageGeneration += 1
        isUpdatingWebPage = true
        Task {
            do {
                let token = try await CloudKitService.shared.setSharedWebPageEnabled(enabled, planId: planId)
                webToken = token
                SharedWebPage.cache(token: token, planId: planId)
            } catch {
                webToken = previous
                webPageError = Self.publishErrorText(for: error)
            }
            isUpdatingWebPage = false
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 15) {
            Image(systemName: "person.2.circle.fill")
                .font(.system(size: 70))
                .foregroundColor(groundText.opacity(0.8))

            VStack(spacing: 8) {
                Text("この旅行計画を共有")
                    .font(.title2.bold())
                    .foregroundColor(groundText)

                Text(plan.title)
                    .font(.headline)
                    .foregroundColor(groundText)

                Text("共有コードを生成して、他のユーザーと一緒に旅行計画を編集できます")
                    .font(.subheadline)
                    .foregroundColor(groundText.opacity(0.7))
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
                        if isStoppingSharing {
                            ProgressView()
                        } else {
                            Image(systemName: "person.2.slash")
                                .font(.subheadline)
                        }

                        Text(isStoppingSharing ? "ウェブのページを止めています…" : "共有を停止")
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundColor(themeManager.currentTheme.error)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .disabled(isStoppingSharing)
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
                    Text(displayName(of: userId))
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

                // 自分の行でだけ、この旅行での呼び方を変えられる
                if userId == authVM.userId {
                    Button("呼び方を変更") {
                        renameText = viewModel.memberNames(for: currentPlan.id)[userId] ?? ""
                        showRename = true
                    }
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.info)
                }
            }

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(themeManager.currentTheme.light.opacity(0.05))
        .cornerRadius(8)
    }

    /// 共有メンバーの名前。付いていなければ「自分」「メンバー2」のように出す。
    /// 以前は ID の先頭8文字を出すだけで、誰が誰か分からなかった
    private func displayName(of userId: String) -> String {
        SharedMembers.displayName(
            of: userId,
            names: viewModel.memberNames(for: currentPlan.id),
            members: currentPlan.sharedWith,
            myUserId: authVM.userId
        )
    }

    private func saveMyName() {
        guard let planId = currentPlan.id, let userId = authVM.userId else { return }
        Task {
            do {
                try await viewModel.setMyMemberName(renameText, planId: planId, userId: userId)
            } catch {
                renameFailed = true
            }
        }
    }

    // MARK: - Info Section
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(groundText)
                Text("共有機能について")
                    .font(.headline)
                    .foregroundColor(groundText)
            }

            VStack(alignment: .leading, spacing: 8) {
                InfoRow(icon: "checkmark.circle", text: "共有コードを他のユーザーに送信できます")
                InfoRow(icon: "checkmark.circle", text: "コードを入力したユーザーが計画に参加できます")
                InfoRow(icon: "checkmark.circle", text: "全員がスケジュールを編集できます")
                InfoRow(icon: "checkmark.circle", text: "変更内容は自動的に同期されます")
                InfoRow(icon: "checkmark.circle", text: "オンにすると、アプリの無い人（Android）もウェブで見られます")
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
    // 地は `ThemePreset.screenGradient`、カードの外の文字はその地から決める（新しい旅行の画面と同じ直し）
    private var backgroundGradient: some View {
        themeManager.currentTheme.screenGradient(for: colorScheme)
            .ignoresSafeArea()
    }

    /// カードの外（地の上）に置く文字の色
    private var groundText: Color {
        ThemePreset.readableText(on: themeManager.currentTheme.screenGround(for: colorScheme))
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
        if ICloudGuidanceText.isAccountProblem(error) {
            return ICloudGuidanceText.sharingUnavailable
        }
        return "通信環境をご確認のうえ、もう一度お試しください。"
    }

    private func stopSharing() {
        guard let planId = currentPlan.id, let userId = authVM.userId, !isStoppingSharing else { return }
        Task {
            // ウェブで見られるようにしていたら、先にウェブのページを止めて、止まったのを確かめる。
            // 共有レコードの削除は待たずに進むので、削除に失敗するとウェブで見え続けてしまうため
            if webPageEnabled {
                isStoppingSharing = true
                webPageGeneration += 1
                do {
                    try await CloudKitService.shared.setSharedWebPageEnabled(false, planId: planId)
                } catch {
                    isStoppingSharing = false
                    stopSharingError = Self.publishErrorText(for: error)
                    return
                }
                isStoppingSharing = false
            }
            viewModel.stopSharing(planId: planId, userId: userId)
            shareCode = ""
            webToken = nil
            SharedWebPage.cache(token: nil, planId: planId)
        }
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
                .foregroundColor(ThemePreset.readableTintEitherWay(themeManager.currentTheme.actionFill,
                                                                   on: themeManager.currentTheme.screenGround(for: colorScheme),
                                                                   minimum: 3.0))
                .font(.caption)

            Text(text)
                .font(.caption)
                .foregroundColor(themeManager.currentTheme.secondaryText)
        }
    }
}
