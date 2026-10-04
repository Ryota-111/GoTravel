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
        .navigationViewStyle(.stack)
    }

    // MARK: - 色
    //
    // 文字と飾りの色は、実際に敷いている背景から決める。
    // 以前はダークモード用の文字色（accent2）を決め打ちしていて、明るい地のテーマでは
    // 「共有コード」「参加について」が地に溶けて読めなかった（ご報告から）。
    // デフォルトカラーも、暗いグラデーションの上に暗い文字を置いていた

    /// デフォルトカラーのグラデーション。予定の一覧の画面と同じく、明暗に合わせる。
    /// 以前はライトモードでも青から黒へのグラデーションで、下のほうの文字が黒い地に沈んでいた
    private var defaultGradientColors: [Color] {
        let theme = themeManager.currentTheme
        return colorScheme == .dark ? [theme.gradientDark, theme.dark] : [theme.gradientLight, theme.light]
    }

    /// 文字の下にある地の色。デフォルトカラーはグラデーションの上側（見出しのあたり）の色
    private var ground: Color {
        let theme = themeManager.currentTheme
        if theme.type == .originalColor {
            return ThemePreset.composite(defaultGradientColors[0], over: colorScheme == .dark ? .black : .white)
        }
        return colorScheme == .dark ? theme.backgroundDark : theme.backgroundLight
    }

    private var textColor: Color { ThemePreset.readableText(on: ground) }
    private var subTextColor: Color { textColor.opacity(0.75) }
    /// アイコンなどの差し色。地に対して読める濃さに寄せる
    private var tintColor: Color { readableIcon(themeManager.currentTheme.actionFill) }
    private var infoTint: Color { readableIcon(themeManager.currentTheme.secondary) }

    /// テーマの色を地に対して読める濃さに寄せる。地と同じ系統の色で寄せきれなければ、文字の色にする
    /// （デフォルトカラーは青の地に青のアイコンになる）
    private func readableIcon(_ color: Color) -> Color {
        let tinted = ThemePreset.readableTint(color, on: ground)
        return ThemePreset.contrastRatio(tinted, ground) >= 3.0 ? tinted : textColor
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 15) {
            Image(systemName: "person.badge.plus.fill")
                .font(.system(size: 70))
                .foregroundColor(tintColor)

            VStack(spacing: 8) {
                Text("旅行計画に参加")
                    .font(.title2.bold())
                    .foregroundColor(textColor)

                Text("共有コードを入力して、他のユーザーの旅行計画に参加できます")
                    .font(.subheadline)
                    .foregroundColor(subTextColor)
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
                .foregroundColor(textColor)

            TextField("例: TRAVEL-ABCD1234", text: $shareCode)
                .font(.system(size: 20, weight: .medium, design: .monospaced))
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .submitLabel(.join)
                .onSubmit(joinPlan)
                .foregroundColor(textColor)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(textColor.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(shareCode.isEmpty ? themeManager.currentTheme.cardBorder : themeManager.currentTheme.success.opacity(0.5), lineWidth: 2)
                )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(textColor.opacity(0.05))
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
            // 塗りの色に対して読める文字色にする（白固定だと、明るい緑の上で読みにくい）
            .foregroundColor(ThemePreset.readableText(on: shareCode.isEmpty
                ? ThemePreset.composite(themeManager.currentTheme.secondaryText, over: ground, opacity: 0.5)
                : themeManager.currentTheme.success))
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
                    .foregroundColor(tintColor)
                Text("参加について")
                    .font(.headline)
                    .foregroundColor(textColor)
            }

            VStack(alignment: .leading, spacing: 8) {
                ColoredInfoRow(icon: "checkmark.circle", text: "オーナーから受け取った共有コードを入力してください", color: infoTint, textColor: subTextColor)
                ColoredInfoRow(icon: "checkmark.circle", text: "参加後、すぐにスケジュールを編集できます", color: infoTint, textColor: subTextColor)
                ColoredInfoRow(icon: "checkmark.circle", text: "他のメンバーと情報が共有されます", color: infoTint, textColor: subTextColor)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(textColor.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(textColor.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Background
    /// グラデーションはデフォルトカラーだけ。ほかのテーマでは、テーマの地の色を一色で敷く
    /// （グラデーションの暗い色が、紙やパステルのテーマの雰囲気に合わなかったため）
    @ViewBuilder
    private var backgroundGradient: some View {
        if themeManager.currentTheme.type == .originalColor {
            LinearGradient(
                gradient: Gradient(colors: defaultGradientColors),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        } else {
            (colorScheme == .dark
                ? themeManager.currentTheme.backgroundDark
                : themeManager.currentTheme.backgroundLight)
                .ignoresSafeArea()
        }
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
                } else if ICloudGuidanceText.isAccountProblem(error) {
                    // 汎用文言では原因に辿り着けないため、確認手順ごと案内する
                    errorMessage = ICloudGuidanceText.sharingUnavailable
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
    /// 文字の色。地に合わせて渡す（渡さなければ、これまでどおりダークモード用の文字色）
    var textColor: Color? = nil
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var themeManager = ThemeManager.shared

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.caption)

            Text(text)
                .font(.caption)
                .foregroundColor(textColor ?? themeManager.currentTheme.accent2.opacity(0.8))
        }
    }
}

