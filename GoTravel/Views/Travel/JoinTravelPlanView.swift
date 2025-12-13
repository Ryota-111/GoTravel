import SwiftUI

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
            .foregroundColor(themeManager.currentTheme.accent2)
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
                InfoRow(icon: "checkmark.circle", text: "共有コードは大文字で入力してください", color: themeManager.currentTheme.secondary)
                InfoRow(icon: "checkmark.circle", text: "参加後、すぐにスケジュールを編集できます", color: themeManager.currentTheme.secondary)
                InfoRow(icon: "checkmark.circle", text: "他のメンバーと情報がリアルタイムで共有されます", color: themeManager.currentTheme.secondary)
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
    private func joinPlan() {
        let trimmedCode = shareCode.trimmingCharacters(in: .whitespaces).uppercased()

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

        isJoining = true

        guard let userId = authVM.userId else {
            errorMessage = "ログインが必要です。"
            showError = true
            isJoining = false
            return
        }

        viewModel.joinPlanByShareCode(trimmedCode, userId: userId) { result in
            isJoining = false

            switch result {
            case .success(_):
                // Close the view on success
                presentationMode.wrappedValue.dismiss()
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
                } else {
                    errorMessage = "参加できませんでした。もう一度お試しください。"
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

// Extension for InfoRow to support color
extension InfoRow {
    init(icon: String, text: String, color: Color) {
        self.icon = icon
        self.text = text
    }
}
