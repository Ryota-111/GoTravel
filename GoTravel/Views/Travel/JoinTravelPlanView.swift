import SwiftUI
import CloudKit

// MARK: - Join Travel Plan View
struct JoinTravelPlanView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var viewModel: TravelPlanViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject var themeManager = ThemeManager.shared
    @State private var shareCode: String = ""
    @State private var isJoining: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var showSuccess: Bool = false
    @State private var joinedPlanTitle: String = ""

    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient

                ScrollView {
                    VStack(spacing: 25) {
                        headerSection

                        codeInputSection

                        joinButton

                        infoSection
                    }
                    .padding()
                }
            }
            .navigationTitle("旅行計画に参加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .alert("エラー", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert("参加しました", isPresented: $showSuccess) {
                Button("OK") {
                    presentationMode.wrappedValue.dismiss()
                }
            } message: {
                Text("「\(joinedPlanTitle)」に参加しました。旅行計画の一覧に表示されます。")
            }
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 15) {
            Image(systemName: "person.badge.plus.fill")
                .font(.system(size: 70))
                .foregroundColor(themeManager.currentTheme.accent2.opacity(0.8))

            VStack(spacing: 8) {
                Text("旅行計画に参加")
                    .font(.title2.bold())
                    .foregroundColor(colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1)

                Text("共有コードを入力して、他のユーザーの旅行計画に参加できます")
                    .font(.subheadline)
                    .foregroundColor(colorScheme == .dark ? themeManager.currentTheme.accent2.opacity(0.7) : themeManager.currentTheme.accent1.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }

    // MARK: - Code Input Section
    private var codeInputSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("共有コード")
                .font(.headline)
                .foregroundColor(themeManager.currentTheme.accent2)

            TextField("例: TRAVEL-ABCD1234", text: $shareCode)
                .font(.system(size: 20, weight: .medium, design: .monospaced))
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .submitLabel(.join)
                .onSubmit(joinPlan)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(themeManager.currentTheme.accent2.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(shareCode.isEmpty ? themeManager.currentTheme.cardBorder : themeManager.currentTheme.success.opacity(0.5), lineWidth: 2)
                )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(themeManager.currentTheme.accent2.opacity(0.05))
        )
        .shadow(color: themeManager.currentTheme.accent1.opacity(0.3), radius: 10, x: 0, y: 5)

    }

    // MARK: - Join Button
    private var joinButton: some View {
        Button(action: joinPlan) {
            HStack {
                if isJoining {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "person.badge.plus")
                        .font(.title3)

                    Text("参加する")
                        .font(.headline)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: shareCode.isEmpty ?
                        [themeManager.currentTheme.secondaryText.opacity(0.5), themeManager.currentTheme.secondaryText.opacity(0.4)] :
                        [themeManager.currentTheme.success, themeManager.currentTheme.success.opacity(0.8)]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(15)
            .shadow(color: themeManager.currentTheme.accent1.opacity(0.3), radius: 10, x: 0, y: 5)
        }
        .disabled(shareCode.isEmpty || isJoining)
    }

    // MARK: - Info Section
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(themeManager.currentTheme.accent2)
                Text("参加について")
                    .font(.headline)
                    .foregroundColor(themeManager.currentTheme.accent2)
            }

            VStack(alignment: .leading, spacing: 8) {
                ColoredInfoRow(icon: "checkmark.circle", text: "オーナーから受け取った共有コードを入力してください", color: themeManager.currentTheme.secondary)
                ColoredInfoRow(icon: "checkmark.circle", text: "参加後、すぐにスケジュールを編集できます", color: themeManager.currentTheme.secondary)
                ColoredInfoRow(icon: "checkmark.circle", text: "他のメンバーと情報が共有されます", color: themeManager.currentTheme.secondary)
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
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Actions

    /// 入力の揺れ（空白・全角ハイフン・プレフィックス省略）を吸収して正規化する
    private func normalizeShareCode(_ input: String) -> String {
        var code = input
            .uppercased()
            .replacingOccurrences(of: "ー", with: "-")
            .replacingOccurrences(of: "−", with: "-")
            .filter { !$0.isWhitespace }

        // 「TRAVEL-」を省略して8桁のコードだけ入力された場合は補完する
        if !code.isEmpty && !code.hasPrefix("TRAVEL-") {
            let body = code.hasPrefix("TRAVEL") ? String(code.dropFirst("TRAVEL".count)) : code
            if body.count == 8 && body.allSatisfy({ $0.isLetter || $0.isNumber }) {
                code = "TRAVEL-\(body)"
            }
        }
        return code
    }

    private func joinPlan() {
        let trimmedCode = normalizeShareCode(shareCode)

        guard !trimmedCode.isEmpty else {
            errorMessage = "共有コードを入力してください"
            showError = true
            return
        }

        guard trimmedCode.hasPrefix("TRAVEL-") else {
            errorMessage = "無効な共有コードです。正しい形式で入力してください（例: TRAVEL-ABCD1234）"
            showError = true
            return
        }

        guard let userId = authVM.userId else {
            errorMessage = "ログインが必要です。"
            showError = true
            return
        }

        isJoining = true
        hideKeyboard()

        viewModel.joinPlanByShareCode(trimmedCode, userId: userId) { result in
            isJoining = false

            switch result {
            case .success(let plan):
                joinedPlanTitle = plan.title
                showSuccess = true
            case .failure(let error):
                if let apiError = error as? APIClientError {
                    switch apiError {
                    case .notFound:
                        errorMessage = "共有コードに一致する旅行計画が見つかりませんでした。コードを確認してください。"
                    case .authenticationError:
                        errorMessage = "ログインが必要です。"
                    default:
                        errorMessage = apiError.localizedDescription
                    }
                } else if let ckError = error as? CKError, ckError.code == .notAuthenticated {
                    // iCloud未サインインだと汎用文言では原因に辿り着けない
                    errorMessage = "iCloudにサインインしていないため、共有機能を利用できません。設定アプリでiCloudにサインインしてから、もう一度お試しください。"
                } else {
                    errorMessage = "参加できませんでした。通信環境をご確認のうえ、もう一度お試しください。"
                }
                showError = true
            }
        }
    }
}

// MARK: - Colored Info Row
struct ColoredInfoRow: View {
    let icon: String
    let text: String
    let color: Color
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var themeManager = ThemeManager.shared

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.caption)

            Text(text)
                .font(.caption)
                .foregroundColor(themeManager.currentTheme.accent2.opacity(0.8))
        }
    }
}

