import SwiftUI
import StoreKit

struct ProfileView: View {
    @StateObject private var vm = ProfileViewModel()
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject var themeManager = ThemeManager.shared
    /// Pro のカードの文言が購入の直後に切り替わるように見張る
    @ObservedObject private var proStore = ProStore.shared
    @Environment(\.colorScheme) var colorScheme
    @State private var animateCards = false
    /// カードの副題を、設定画面から戻ったときに書き換えるため
    @AppStorage(MapNavigator.preferenceKey) private var mapAppPreference: String = MapApp.ask.rawValue
    @EnvironmentObject var travelPlanViewModel: TravelPlanViewModel

    var body: some View {
        ZStack {
            // Background with mesh gradient effect
            backgroundGradient

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    profileHeaderSection

                    // 上から「Pro」「設定」「データ」「サポート」「アカウント」。
                    //
                    // 前は12枚のカードが同じ大きさで並び、どれが何のまとまりか分からなかった。
                    // 見出しでまとめ、1行を小さくする。名前の編集は上の名前を押して行う。
                    // 「共有コードで参加」はホームとカレンダーの一覧にあるので、ここには置かない
                    VStack(spacing: 22) {
                        proCard

                        ProfileMenuGroup(title: "設定") {
                            appsettingCard
                            reminderDefaultsCard
                            calendarExportCard
                            mapAppCard
                        }

                        ProfileMenuGroup(title: "データ") {
                            dataBackupCard
                            recentlyDeletedCard
                        }

                        ProfileMenuGroup(title: "サポート") {
                            helpSupportCard
                            tipJarCard
                        }

                        ProfileMenuGroup(title: nil) {
                            accountCard
                        }

                        // cloudKitTestCard // 開発用：必要時にコメント解除
                    }
                    .opacity(animateCards ? 1 : 0)
                    .offset(y: animateCards ? 0 : 20)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: animateCards)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("プロフィール")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                animateCards = true
            }
        }
    }

    // MARK: - Background Gradient
    private var backgroundGradient: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: colorScheme == .dark ?
                    [themeManager.currentTheme.backgroundDark, themeManager.currentTheme.secondaryBackgroundDark] :
                    [themeManager.currentTheme.backgroundLight, themeManager.currentTheme.secondaryBackgroundLight]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            themeManager.currentTheme.primary.opacity(0.3),
                            Color.clear
                        ]),
                        center: .topLeading,
                        startRadius: 50,
                        endRadius: 400
                    )
                )
                .offset(x: -100, y: -200)
                .blur(radius: 60)

            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            themeManager.currentTheme.secondary.opacity(0.25),
                            Color.clear
                        ]),
                        center: .bottomTrailing,
                        startRadius: 50,
                        endRadius: 350
                    )
                )
                .offset(x: 150, y: 400)
                .blur(radius: 70)

            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            themeManager.currentTheme.primary.opacity(0.2),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: 30,
                        endRadius: 300
                    )
                )
                .offset(x: 50, y: 100)
                .blur(radius: 80)
        }
    }

    // MARK: - Profile Header
    /// 名前と写真。押すと名前・メール・写真を直せる（前は「アカウント編集」のカードが別にあった）
    private var profileHeaderSection: some View {
        NavigationLink(destination: ProfileEditView(vm: vm)) {
        VStack(spacing: 0) {
            ZStack {
                // Avatar with glassmorphism effect
                VStack(spacing: 20) {
                    Spacer()
                        .frame(height: 16)

                    // Profile Photo
                    ZStack {
                        // Glowing background
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        themeManager.currentTheme.primary.opacity(0.6),
                                        themeManager.currentTheme.secondary.opacity(0.4),
                                        themeManager.currentTheme.primary.opacity(0.5)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 110, height: 110)
                            .blur(radius: 20)

                        // Avatar container
                        ZStack(alignment: .bottomTrailing) {
                            ZStack {
                                if let ui = vm.avatarImage {
                                    Image(uiImage: ui)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                } else {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    themeManager.currentTheme.primary.opacity(0.5),
                                                    themeManager.currentTheme.secondary.opacity(0.3)
                                                ]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 100, height: 100)

                                    Image(systemName: "person.fill")
                                        .font(.system(size: 48))
                                        .foregroundColor(.white.opacity(0.9))
                                }
                            }
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.white.opacity(0.8),
                                                themeManager.currentTheme.primary.opacity(0.4),
                                                themeManager.currentTheme.secondary.opacity(0.4)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 4
                                    )
                            )
                            .shadow(color: themeManager.currentTheme.primary.opacity(0.4), radius: 20, x: 0, y: 10)
                        }
                    }

                    // User Info with glassmorphism card
                    VStack(spacing: 12) {
                        HStack(spacing: 6) {
                        Text(authVM.userFullName ?? "ユーザー")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            // text は白0.1の固定色で、暗い背景では黒いまま消える
                            .foregroundColor(themeManager.currentTheme.adaptiveText(for: colorScheme))
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(themeManager.currentTheme.secondaryTextOnScreen(for: colorScheme))
                        }

                        Text(authVM.userEmail ?? "")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(themeManager.currentTheme.secondaryTextOnCardBackground2(for: colorScheme))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(themeManager.currentTheme.cardBackground2)
                                    .overlay(
                                        Capsule()
                                            .stroke(themeManager.currentTheme.cardBorder, lineWidth: 1)
                                    )
                            )
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 20)
                }
            }
        }
        }
        .buttonStyle(CardButtonStyle())
        .accessibilityLabel("プロフィールを編集")
        .opacity(animateCards ? 1 : 0)
        .scaleEffect(animateCards ? 1 : 0.9)
        .animation(.spring(response: 0.7, dampingFraction: 0.7), value: animateCards)
    }

    // MARK: - 行（`ProfileMenuGroup` の中に並べる）

    private var appsettingCard: some View {
        NavigationLink(destination: AppSettingView()) {
            ProfileMenuRow(icon: "paintpalette.fill", color: .purple, title: "テーマ・操作")
        }
    }

    private var reminderDefaultsCard: some View {
        NavigationLink(destination: PlanReminderDefaultsView()) {
            ProfileMenuRow(icon: "bell.badge.fill", color: .orange, title: "通知の初期設定")
        }
    }

    /// 旅行計画・予定をまとめてカレンダーに入れる・カレンダーの予定を表示する（3.0）
    private var calendarExportCard: some View {
        NavigationLink(destination: CalendarExportSettingsView()) {
            ProfileMenuRow(icon: "calendar", color: .red, title: "iPhone のカレンダー")
        }
    }

    private var mapAppCard: some View {
        NavigationLink(destination: MapAppSettingView()) {
            ProfileMenuRow(icon: "arrow.triangle.turn.up.right.diamond.fill", color: .teal, title: "経路案内のアプリ",
                           value: (MapApp(rawValue: mapAppPreference) ?? .ask).displayName)
        }
    }

    /// データの書き出し・読み込み（3.0）。前の書き出しから3か月たったら、ここで知らせる
    private var dataBackupCard: some View {
        let last = UserDefaults.standard.double(forKey: DataBackupView.lastExportKey)
        let value: String
        var isWarning = false
        if last == 0 {
            value = "まだ書き出していません"
        } else if Date().timeIntervalSince1970 - last > DataBackupView.reminderInterval {
            value = "3か月たちました"
            isWarning = true
        } else {
            value = "前回 \(Date(timeIntervalSince1970: last).formatted(.dateTime.month().day()))"
        }
        return NavigationLink(destination: DataBackupView()) {
            ProfileMenuRow(icon: "externaldrive.fill", color: .indigo, title: "書き出し・読み込み",
                           value: value, valueIsWarning: isWarning)
        }
    }

    private var recentlyDeletedCard: some View {
        NavigationLink(destination: RecentlyDeletedTravelPlansView().environmentObject(travelPlanViewModel)) {
            ProfileMenuRow(icon: "trash.fill", color: .gray, title: "最近削除した旅行計画",
                           value: travelPlanViewModel.recentlyDeleted.isEmpty
                               ? nil : "\(travelPlanViewModel.recentlyDeleted.count)件")
        }
    }

    private var helpSupportCard: some View {
        NavigationLink(destination: HelpSupportView()) {
            ProfileMenuRow(icon: "questionmark.circle.fill", color: .cyan, title: "ヘルプ・ご意見")
        }
    }

    private var tipJarCard: some View {
        NavigationLink(destination: TipJarView()) {
            ProfileMenuRow(icon: "heart.fill", color: .pink, title: "開発者を応援する")
        }
    }

    private var accountCard: some View {
        NavigationLink(destination: AccountActionView(vm: vm)) {
            ProfileMenuRow(icon: "person.crop.circle", color: .gray, title: "アカウント管理",
                           value: "サインアウト・削除")
        }
    }

    // MARK: - Pro Card
    //
    // これまで買い切りの入口は「アプリ設定 → テーマ」の中だけで、
    // テーマを見に行った人しか存在に気づけなかった。
    // 購入済みかどうかで文言だけ変え、カード自体は常に置いておく
    private var proCard: some View {
        NavigationLink(destination: ProView()) {
            GlassMenuCard(
                icon: proStore.isPurchased ? "checkmark.seal.fill" : "sparkles",
                title: "Travory Pro",
                subtitle: proStore.isPurchased
                    ? "ご利用中です"
                    : "予約メールの取り込み・テーマ・写真の保管",
                gradientColors: [Color.yellow, Color.orange.opacity(0.8)]
            )
        }
        .buttonStyle(CardButtonStyle())
        .opacity(animateCards ? 1 : 0)
        .scaleEffect(animateCards ? 1 : 0.8)
        .offset(y: animateCards ? 0 : 30)
        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.15), value: animateCards)
    }

    // MARK: - CloudKit Test Card
    private var cloudKitTestCard: some View {
        NavigationLink(destination: CloudKitTestView()) {
            GlassMenuCard(
                icon: "icloud.fill",
                title: "CloudKit テスト",
                subtitle: "iCloud接続確認、データ同期",
                gradientColors: [Color.purple, Color.pink]
            )
        }
        .buttonStyle(CardButtonStyle())
        .opacity(animateCards ? 1 : 0)
        .scaleEffect(animateCards ? 1 : 0.8)
        .offset(y: animateCards ? 0 : 30)
        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.45), value: animateCards)
    }

}

// MARK: - Glass Menu Card
struct GlassMenuCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let gradientColors: [Color]
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(themeManager.currentTheme.cardBackground2)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(themeManager.currentTheme.cardBorder, lineWidth: 1.5)
                )
                .shadow(color: themeManager.currentTheme.shadow, radius: 15, x: 0, y: 8)

            HStack(spacing: 18) {
                // Gradient Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: gradientColors),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .overlay(Circle().stroke(themeManager.currentTheme.cardBorder, lineWidth: 2))
                        .shadow(color: gradientColors[0].opacity(0.5), radius: 12, x: 0, y: 5)

                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 6) {
                    // 半透明のカードの明るさから文字の色を決める（デフォルトカラーのダークモードでは黒）
                    Text(title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(themeManager.currentTheme.textOnCardBackground2(for: colorScheme))

                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(themeManager.currentTheme.secondaryTextOnCardBackground2(for: colorScheme))
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(themeManager.currentTheme.secondaryTextOnCardBackground2(for: colorScheme))
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
        }
        .frame(height: 100)
    }
}

// MARK: - まとまり（見出しと、角の丸い枠の中に並ぶ行）

struct ProfileMenuGroup<Content: View>: View {
    let title: String?
    @ViewBuilder let content: Content
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(themeManager.currentTheme.secondaryTextOnScreen(for: colorScheme))
                    .padding(.leading, 6)
            }
            // 行と行のあいだに区切り線を入れる
            Group(subviews: content) { rows in
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        row
                        if index < rows.count - 1 {
                            Divider().padding(.leading, 58)
                        }
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(themeManager.currentTheme.cardBackground2)
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(themeManager.currentTheme.cardBorder, lineWidth: 1))
                    .shadow(color: themeManager.currentTheme.shadow, radius: 10, x: 0, y: 4)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }
}

/// まとまりの中の1行。左に色つきの小さいアイコン、右に今の値
struct ProfileMenuRow: View {
    let icon: String
    let color: Color
    let title: String
    var value: String? = nil
    var valueIsWarning = false
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 8).fill(color.gradient))
            // 文字の色は、行の地（半透明のカード）の明るさから決める。
            // デフォルトカラーのダークモードではカードが明るい灰色になるので、黒い文字になる
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(themeManager.currentTheme.textOnCardBackground2(for: colorScheme))
            Spacer(minLength: 8)
            if let value {
                Text(value)
                    .font(.system(size: 14))
                    .foregroundColor(valueIsWarning
                                     ? ThemePreset.readableTint(.orange, on: cardSurface)
                                     : themeManager.currentTheme.secondaryTextOnCardBackground2(for: colorScheme))
                    .lineLimit(1)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(themeManager.currentTheme.secondaryTextOnCardBackground2(for: colorScheme))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    /// 行の地（半透明のカードを画面の地に重ねた色）
    private var cardSurface: Color {
        let theme = themeManager.currentTheme
        return ThemePreset.composite(theme.cardBackground2,
                                     over: colorScheme == .dark ? theme.backgroundDark : theme.backgroundLight)
    }
}

// MARK: - Card Button Style
struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct ProfileEditView: View {
    @ObservedObject var vm: ProfileViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @State private var showImagePicker = false
    @State private var showRemoveAvatarConfirm = false
    @State private var animateContent = false

    // 名前とメールは Apple から初回しか貰えないので、自分で直せるようにしてある
    @State private var editedName = ""
    @State private var editedEmail = ""

    private var hasProfileChanges: Bool {
        editedName.trimmingCharacters(in: .whitespacesAndNewlines) != (authVM.userFullName ?? "")
            || editedEmail.trimmingCharacters(in: .whitespacesAndNewlines) != (authVM.userEmail ?? "")
    }

    var body: some View {
        ZStack {
            backgroundGradient

            ScrollView(showsIndicators: false) {
                VStack(spacing: 25) {
                    userInfoSection

                    avatarSection

                    infoNote
                }
                .padding(.horizontal)
                .padding(.top, 20)
                .padding(.bottom, 30)
            }
            .navigationTitle("プロフィール編集")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            editedName = authVM.userFullName ?? ""
            editedEmail = authVM.userEmail ?? ""

            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                animateContent = true
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("保存") {
                    authVM.updateProfile(fullName: editedName, email: editedEmail)
                    presentationMode.wrappedValue.dismiss()
                }
                .fontWeight(.semibold)
                .foregroundColor(hasProfileChanges
                                 ? themeManager.currentTheme.xprimary
                                 : themeManager.currentTheme.secondaryText)
                .disabled(!hasProfileChanges)
            }
        }
        .sheet(isPresented: $showImagePicker) {
            PhotoPicker { image in
                vm.saveAvatar(image)
                showImagePicker = false
            }
        }
        .confirmationDialog("プロフィール画像を削除",
                            isPresented: $showRemoveAvatarConfirm) {
            Button("削除", role: .destructive) { vm.removeAvatar() }
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: colorScheme == .dark ?
                [themeManager.currentTheme.backgroundDark, themeManager.currentTheme.secondaryBackgroundDark] :
                [themeManager.currentTheme.backgroundLight, themeManager.currentTheme.secondaryBackgroundLight]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var userInfoSection: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "person.fill")
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.xprimary)
                    Text("名前")
                        .font(.caption.bold())
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                }

                TextField("ユーザー", text: $editedName)
                    .font(.body)
                    .foregroundColor(themeManager.currentTheme.text)
                    .textInputAutocapitalization(.never)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(themeManager.currentTheme.cardBackground2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(themeManager.currentTheme.xprimary.opacity(0.3), lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "envelope.fill")
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.xprimary)
                    Text("メールアドレス")
                        .font(.caption.bold())
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                }

                TextField("未設定", text: $editedEmail)
                    .font(.body)
                    .foregroundColor(themeManager.currentTheme.text)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(themeManager.currentTheme.cardBackground2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(themeManager.currentTheme.xprimary.opacity(0.3), lineWidth: 1)
                    )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(themeManager.currentTheme.cardBackground2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            themeManager.currentTheme.xprimary.opacity(0.3),
                            themeManager.currentTheme.xprimary.opacity(0.1)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: themeManager.currentTheme.xprimary.opacity(0.2), radius: 10, x: 0, y: 5)
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : -20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animateContent)
    }

    private var infoNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(themeManager.currentTheme.xprimary)
                Text("お知らせ")
                    .font(.caption.bold())
                    .foregroundColor(themeManager.currentTheme.adaptiveText(for: colorScheme))
            }

            // Apple から名前とメールを貰えるのは初回の1回きりで、取り直す手段がない。
            // 「Apple IDの設定から変更してください」は実際には効かない案内だった
            Text("名前とメールアドレスは、初回のサインイン時にApple IDから取得したものです。この端末での表示にだけ使うので、ここで自由に変更できます。")
                .font(.caption)
                .foregroundColor(themeManager.currentTheme.secondaryText)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(themeManager.currentTheme.xprimary.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(themeManager.currentTheme.xprimary.opacity(0.3), lineWidth: 1)
        )
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: animateContent)
    }

    private var avatarSection: some View {
        VStack(spacing: 15) {
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    if let ui = vm.avatarImage {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                    } else {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        themeManager.currentTheme.xprimary.opacity(0.6),
                                        themeManager.currentTheme.xsecondary.opacity(0.6)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)

                        Image(systemName: "person.fill")
                            .font(.system(size: 60))
                            .foregroundColor(themeManager.currentTheme.accent2.opacity(0.8))
                    }
                }
                .frame(width: 120, height: 120)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(themeManager.currentTheme.cardBorder, lineWidth: 3)
                )
                .shadow(color: themeManager.currentTheme.shadow, radius: 15, x: 0, y: 8)

                Menu {
                    Button("写真を選択") { showImagePicker = true }
                    if vm.avatarImage != nil {
                        Button("削除", role: .destructive) { showRemoveAvatarConfirm = true }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(themeManager.currentTheme.xprimary.opacity(0.8))
                            .frame(width: 36, height: 36)
                        Image(systemName: "pencil")
                            .foregroundColor(themeManager.currentTheme.accent2)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .shadow(color: themeManager.currentTheme.xprimary.opacity(0.3), radius: 5, x: 0, y: 2)
                }
                .offset(x: -5, y: -5)
            }

            Text("プロフィール写真")
                .font(.caption)
                .foregroundColor(themeManager.currentTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(themeManager.currentTheme.cardBackground2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            themeManager.currentTheme.xprimary.opacity(0.3),
                            themeManager.currentTheme.xprimary.opacity(0.1)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: themeManager.currentTheme.xprimary.opacity(0.2), radius: 10, x: 0, y: 5)
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : -20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animateContent)
    }
}

// MARK: - Account Action View
struct AccountActionView: View {
    @ObservedObject var vm: ProfileViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme
    @State private var showSignOutConfirm = false
    @State private var animateButtons = false

    var body: some View {
        ZStack {
            backgroundGradient

            ScrollView(showsIndicators: false) {
                VStack(spacing: 25) {
                    // Info Section
                    VStack(spacing: 15) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(themeManager.currentTheme.warning.opacity(0.8))
                            .padding(.top, 30)

                        VStack(spacing: 8) {
                            Text("アカウント管理")
                                .font(.title2.bold())
                                .foregroundColor(themeManager.currentTheme.adaptiveText(for: colorScheme))

                            Text("サインアウトしても、データは消えません")
                                .font(.subheadline)
                                .foregroundColor(themeManager.currentTheme.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .opacity(animateButtons ? 1 : 0)
                    .offset(y: animateButtons ? 0 : -20)

                    // Buttons
                    VStack(spacing: 16) {
                        // Sign Out Button
                        Button(action: {
                            showSignOutConfirm = true
                        }) {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.title3)
                                    .foregroundColor(themeManager.currentTheme.adaptiveText(for: colorScheme))

                                Text("サインアウト")
                                    .font(.headline)
                                    .foregroundColor(themeManager.currentTheme.adaptiveText(for: colorScheme))

                                Spacer()
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(themeManager.currentTheme.cardBackground2)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .opacity(animateButtons ? 1 : 0)
                        .offset(y: animateButtons ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: animateButtons)

                        // Warning Text
                        VStack(alignment: .leading, spacing: 8) {
                            Text("⚠️ 注意事項")
                                .font(.headline)
                                .foregroundColor(.red.opacity(0.8))

                            Text("• サインアウト: 再度ログインすることでアカウントを復元できます")
                                .font(.caption)
                                .foregroundColor(themeManager.currentTheme.secondaryText)

                            Text("• アカウント削除: iCloud のデータも含めてすべて消え、取り消せません")
                                .font(.caption)
                                .foregroundColor(themeManager.currentTheme.secondaryText)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.red.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
                        .opacity(animateButtons ? 1 : 0)
                        .offset(y: animateButtons ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: animateButtons)

                        // アカウント削除は、サインアウトと並べずに離して置き、別の画面で確かめる。
                        // 並んでいると押し間違えるおそれがある（`AccountDeletionView`）
                        NavigationLink(destination: AccountDeletionView()) {
                            Text("アカウントを削除する…")
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(.red.opacity(0.8))
                                .padding(.vertical, 8)
                        }
                        .padding(.top, 40)
                        .opacity(animateButtons ? 1 : 0)
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 30)
            }
            .navigationTitle("アカウント管理")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                animateButtons = true
            }
        }
        .confirmationDialog("サインアウトしますか？", isPresented: $showSignOutConfirm) {
            Button("サインアウト", role: .destructive) {
                authVM.signOut()
            }
        } message: {
            Text("再度ログインすることでアカウントを復元できます")
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: colorScheme == .dark ?
                [themeManager.currentTheme.backgroundDark, themeManager.currentTheme.secondaryBackgroundDark] :
                [themeManager.currentTheme.backgroundLight, themeManager.currentTheme.secondaryBackgroundLight]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

// MARK: - Help Support View
struct HelpSupportView: View {
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme
    @State private var animateCards = false
    @State private var showUserGuide = false
    @State private var showContactAlert = false
    @State private var showFeedbackForm = false
    @State private var showDataDiagnostics = false
    @EnvironmentObject private var authVM: AuthViewModel

    var body: some View {
        ZStack {
            backgroundGradient

            ScrollView(showsIndicators: false) {
                VStack(spacing: 25) {
                    // Header
                    VStack(spacing: 15) {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(themeManager.currentTheme.success.opacity(0.8))
                            .padding(.top, 30)

                        VStack(spacing: 8) {
                            Text("ヘルプ・サポート")
                                .font(.title2.bold())
                                .foregroundColor(themeManager.currentTheme.adaptiveText(for: colorScheme))

                            Text("使い方やお困りの際はこちら")
                                .font(.subheadline)
                                .foregroundColor(themeManager.currentTheme.secondaryText)

                            Text("みなさんの声をもとに改善しています。\nご要望をお気軽にお寄せください")
                                .font(.caption)
                                .foregroundColor(themeManager.currentTheme.secondaryText)
                                .multilineTextAlignment(.center)
                                .padding(.top, 2)
                        }
                    }
                    .opacity(animateCards ? 1 : 0)
                    .offset(y: animateCards ? 0 : -20)

                    // Help Cards
                    VStack(spacing: 16) {
                        // User Guide
                        Button(action: { showUserGuide = true }) {
                            HelpCard(
                                icon: "book.fill",
                                title: "使い方ガイド",
                                description: "アプリの基本的な使い方を確認できます",
                                color: .blue
                            )
                        }
                        .opacity(animateCards ? 1 : 0)
                        .offset(y: animateCards ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: animateCards)

                        // Feedback
                        Button(action: { showFeedbackForm = true }) {
                            HelpCard(
                                icon: "lightbulb.fill",
                                title: "ご意見・ご要望",
                                description: "欲しい機能や不具合をこの場で送れます。いただいた声をもとに改善しています",
                                color: .yellow
                            )
                        }
                        .opacity(animateCards ? 1 : 0)
                        .offset(y: animateCards ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: animateCards)

                        // 旅行計画が見当たらないとき（`DataDiagnosticsView`）
                        Button(action: { showDataDiagnostics = true }) {
                            HelpCard(
                                icon: "stethoscope",
                                title: "データの診断",
                                description: "旅行計画が見当たらないときに、端末とiCloudのどちらに残っているかを確かめます",
                                color: .teal
                            )
                        }
                        .opacity(animateCards ? 1 : 0)
                        .offset(y: animateCards ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.16), value: animateCards)

                        // Contact
                        Button(action: { showContactAlert = true }) {
                            HelpCard(
                                icon: "envelope.fill",
                                title: "メールでお問い合わせ",
                                description: "個別のご相談はこちらから",
                                color: .green
                            )
                        }
                        .opacity(animateCards ? 1 : 0)
                        .offset(y: animateCards ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.18), value: animateCards)

                        // 公式アカウント（2026-10 に開設）
                        Button(action: { UIApplication.shared.open(TravoryLinks.instagram) }) {
                            HelpCard(
                                icon: "camera.fill",
                                title: "Instagram",
                                description: "@\(TravoryLinks.accountName)  旅のアイデアやアプリの使い方を発信しています",
                                color: .pink
                            )
                        }
                        .opacity(animateCards ? 1 : 0)
                        .offset(y: animateCards ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.19), value: animateCards)

                        Button(action: { UIApplication.shared.open(TravoryLinks.threads) }) {
                            HelpCard(
                                icon: "at",
                                title: "Threads",
                                description: "@\(TravoryLinks.accountName)  新しい機能のお知らせもこちらで",
                                color: .indigo
                            )
                        }
                        .opacity(animateCards ? 1 : 0)
                        .offset(y: animateCards ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.195), value: animateCards)

                        // Review
                        Button(action: { requestReview() }) {
                            HelpCard(
                                icon: "star.fill",
                                title: "レビューを書く",
                                description: "アプリの評価をお願いします",
                                color: .orange
                            )
                        }
                        .opacity(animateCards ? 1 : 0)
                        .offset(y: animateCards ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: animateCards)

                        // Version Info
                        HelpCard(
                            icon: "info.circle.fill",
                            title: "バージョン情報",
                            description: "Version \(appVersionString)",
                            color: .purple
                        )
                        .opacity(animateCards ? 1 : 0)
                        .offset(y: animateCards ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.25), value: animateCards)
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 30)
            }
            .navigationTitle("ヘルプ・サポート")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                animateCards = true
            }
        }
        .sheet(isPresented: $showUserGuide) {
            UserGuideView()
        }
        .sheet(isPresented: $showFeedbackForm) {
            FeedbackFormView()
        }
        .sheet(isPresented: $showDataDiagnostics) {
            DataDiagnosticsView()
                .environmentObject(authVM)
        }
        .alert("お問い合わせ", isPresented: $showContactAlert) {
            Button("メールを送る") {
                openEmail()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("ご質問やご要望がございましたら、下記のメールアドレスまでお問い合わせください。\n\n\(TravoryLinks.supportEmail)")
        }
    }

    private var appVersionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return build.map { "\(version) (\($0))" } ?? version
    }

    private func requestReview() {
        // 自分でタップした場合は回数や間隔の条件を見ずに出す
        ReviewRequestManager.shared.requestManually()
    }

    private func openEmail() {
        let email = TravoryLinks.supportEmail
        let subject = "Travoryについてのお問い合わせ"
        let urlString = "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"

        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: colorScheme == .dark ?
                [themeManager.currentTheme.backgroundDark, themeManager.currentTheme.secondaryBackgroundDark] :
                [themeManager.currentTheme.backgroundLight, themeManager.currentTheme.secondaryBackgroundLight]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

struct AppSettingView: View {
    @ObservedObject var themeManager = ThemeManager.shared
    @AppStorage(TravelPlanDetailView.tabSwipeKey) private var switchesTabBySwipe = true
    @Environment(\.colorScheme) var colorScheme
    @State private var animateCards = false
    /// 未購入のテーマが選ばれたとき、どれから開かれたかを覚えて購入画面を出す
    @State private var storeTargetTheme: ThemePreset.ThemeType?

    var body: some View {
        ZStack {
            backgroundGradient

            ScrollView(showsIndicators: false) {
                VStack(spacing: 25) {
                    // Header
                    VStack(spacing: 15) {
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: 60))
                            // primary は白黒テーマで白になり背景に溶けるため actionFill を使う
                            .foregroundColor(themeManager.currentTheme.actionFill.opacity(0.8))
                            .padding(.top, 30)

                        VStack(spacing: 8) {
                            Text("アプリ設定")
                                .font(.title2.bold())
                                .foregroundColor(themeManager.currentTheme.adaptiveText(for: colorScheme))

                            Text("テーマカラーをカスタマイズ")
                                .font(.subheadline)
                                .foregroundColor(themeManager.currentTheme.secondaryText)
                        }
                    }
                    .opacity(animateCards ? 1 : 0)
                    .offset(y: animateCards ? 0 : -20)

                    // Current Theme Display
                    VStack(alignment: .leading, spacing: 12) {
                        Text("現在のテーマ")
                            .font(.headline)
                            .foregroundColor(themeManager.currentTheme.adaptiveText(for: colorScheme))

                        HStack {
                            HStack(spacing: 8) {
                                ThemeColorDot(color: themeManager.currentTheme.primary, size: 30)
                                ThemeColorDot(color: themeManager.currentTheme.secondary, size: 30)
                                ThemeColorDot(color: themeManager.currentTheme.tertiary, size: 30)
                            }

                            Spacer()

                            // 半透明のカードの上なので、重ねた色から決める（ダークモードで読めなかった）
                            Text(themeManager.currentTheme.type.displayName)
                                .font(.headline)
                                .foregroundColor(themeManager.currentTheme.textOnCardBackground2(for: colorScheme))
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(themeManager.currentTheme.cardBackground2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(themeManager.currentTheme.cardBorder, lineWidth: 1)
                        )
                        .shadow(color: themeManager.currentTheme.shadow, radius: 10, x: 0, y: 5)
                    }
                    .padding(.horizontal)
                    .opacity(animateCards ? 1 : 0)
                    .offset(y: animateCards ? 0 : 20)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: animateCards)

                    operationSection
                        .padding(.horizontal)
                        .opacity(animateCards ? 1 : 0)
                        .offset(y: animateCards ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: animateCards)

                    // ホーム画面のアイコン（Travory Pro）
                    AppIconPicker()
                        .padding(.horizontal)
                        .opacity(animateCards ? 1 : 0)
                        .offset(y: animateCards ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.18), value: animateCards)

                    // Theme Selection
                    VStack(alignment: .leading, spacing: 16) {
                        Text("テーマを選択")
                            .font(.headline)
                            .foregroundColor(themeManager.currentTheme.adaptiveText(for: colorScheme))
                            .padding(.horizontal)

                        themeList(ThemePreset.ThemeType.freeCases, startIndex: 0)

                        HStack(spacing: 8) {
                            Text("追加のテーマ")
                                .font(.headline)
                                .foregroundColor(themeManager.currentTheme.text)

                            if themeManager.isPremiumUnlocked {
                                Text("購入済み")
                                    .font(.caption2.bold())
                                    .foregroundColor(themeManager.currentTheme.success)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        Capsule().fill(themeManager.currentTheme.success.opacity(0.14))
                                    )
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)

                        themeList(ThemePreset.ThemeType.premiumCases,
                                  startIndex: ThemePreset.ThemeType.freeCases.count)
                    }
                }
                .padding(.bottom, 30)
            }
            .navigationTitle("アプリ設定")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                animateCards = true
            }
        }
        .sheet(item: $storeTargetTheme) { target in
            ProSheet(highlighted: target)
        }
    }

    /// テーマの一覧。startIndex は登場アニメーションの順番をずらすためだけに使う
    @ViewBuilder
    private func themeList(_ types: [ThemePreset.ThemeType], startIndex: Int) -> some View {
        ForEach(Array(types.enumerated()), id: \.element) { index, themeType in
            ThemeCard(
                themeType: themeType,
                isSelected: themeManager.currentTheme.type == themeType,
                isLocked: !themeManager.canUse(themeType),
                isSeasonallyOpen: themeManager.isSeasonallyOpen(themeType),
                onSelect: {
                    if themeManager.canUse(themeType) {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            themeManager.setTheme(themeType)
                        }
                    } else {
                        storeTargetTheme = themeType
                    }
                }
            )
            .padding(.horizontal)
            .opacity(animateCards ? 1 : 0)
            .offset(y: animateCards ? 0 : 20)
            .animation(
                .spring(response: 0.6, dampingFraction: 0.8)
                    .delay(0.15 + Double(startIndex + index) * 0.05),
                value: animateCards
            )
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: colorScheme == .dark ?
                [themeManager.currentTheme.backgroundDark, themeManager.currentTheme.secondaryBackgroundDark] :
                [themeManager.currentTheme.backgroundLight, themeManager.currentTheme.secondaryBackgroundLight]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - 操作

    /// 旅行計画の画面で、横にスライドしてタブを移るか
    private var operationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("操作")
                .font(.headline)
                .foregroundColor(themeManager.currentTheme.adaptiveText(for: colorScheme))

            VStack(alignment: .leading, spacing: 6) {
                Toggle(isOn: $switchesTabBySwipe) {
                    Text("横にスライドしてタブを切り替える")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(themeManager.currentTheme.textOnCardBackground2(for: colorScheme))
                }
                .tint(themeManager.currentTheme.actionFill)

                Text(switchesTabBySwipe
                     ? "旅行計画の画面で、日程や持ち物を横にスライドすると隣のタブへ移ります。"
                     : "タブは上のボタンで切り替えます。日程を横になぞっても、地図のタブへ移りません。")
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.textOnCardBackground2(for: colorScheme).opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(themeManager.currentTheme.cardBackground2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(themeManager.currentTheme.cardBorder, lineWidth: 1)
            )
        }
    }
}

// MARK: - Theme Color Dot
/// テーマカラーのプレビュー用の円。白い色でも背景に溶けないよう縁取りを付ける
struct ThemeColorDot: View {
    let color: Color
    var size: CGFloat = 40

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(Color.primary.opacity(0.2), lineWidth: 1)
            )
    }
}

// MARK: - Theme Card
struct ThemeCard: View {
    let themeType: ThemePreset.ThemeType
    let isSelected: Bool
    var isLocked: Bool = false
    var isSeasonallyOpen: Bool = false
    let onSelect: () -> Void

    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: onSelect) {
            let previewTheme = ThemePreset(type: themeType)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        // そのテーマ自身の書体で名前を出す。明朝か丸ゴシックかがここで分かる
                        Text(themeType.displayName)
                            .font(previewTheme.displayFont(.headline))
                            .foregroundColor(themeManager.currentTheme.adaptiveText(for: colorScheme))

                        if isSeasonallyOpen, let season = themeType.season {
                            Text("\(season.displayName)のあいだ使えます")
                                .font(.caption2.bold())
                                .foregroundColor(themeManager.currentTheme.success)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule().fill(themeManager.currentTheme.success.opacity(0.14))
                                )
                        }

                        Spacer(minLength: 0)

                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(themeManager.currentTheme.success)
                        } else if isLocked {
                            Image(systemName: "lock.fill")
                                .font(.subheadline)
                                .foregroundColor(themeManager.currentTheme.tertiaryText)
                        }
                    }

                    Text(themeType.subtitle)
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // テーマの主色3つと、背景・文字。
                    //
                    // 予定の3色（おでかけ・日常・旅行）はここでは使えない。
                    // 既定の3テーマがどれも青・橙・緑をベタ書きで持っているため、
                    // 並べると3つとも同じ見本になってしまう
                    HStack(spacing: 6) {
                        swatch(previewTheme.primary, in: previewTheme)
                        swatch(previewTheme.secondary, in: previewTheme)
                        swatch(previewTheme.tertiary, in: previewTheme)
                        swatch(previewTheme.backgroundLight, in: previewTheme)
                        swatch(previewTheme.text, in: previewTheme)
                    }

                    Spacer(minLength: 0)
                }
                .opacity(isLocked ? 0.55 : 1)

                // 見え方の見本。写真ではなく、そのテーマのトークンで描いている。
                //
                // 未購入でも薄くしない。どんな見た目になるか分からないものは
                // 買われないので、ここは鍵付きのときこそ見せる必要がある
                ThemePreviewCard(preset: previewTheme, width: 88)
            }
            .padding()
            // 枠は今のテーマの形に揃える。
            //
            // 以前はプレビュー側のテーマの角丸と縁幅で描いていた。形の違いが
            // 一覧で分かるという意図だったが、角丸が 6〜22、縁が 0〜1.5 と
            // 幅があるため、行ごとに輪郭が変わって一覧が落ち着かなかった。
            // 形の違いは下の色見本で見せる
            .background(
                RoundedRectangle(cornerRadius: themeManager.currentTheme.radius(.large))
                    // 選択中の枠が白黒テーマで白くなり、どれを選んでいるか分からなくなるため actionFill を使う
                    .fill(isSelected ? themeManager.currentTheme.actionFill.opacity(0.1) : themeManager.currentTheme.cardBackground2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: themeManager.currentTheme.radius(.large))
                    .stroke(
                        isSelected ? themeManager.currentTheme.actionFill : themeManager.currentTheme.cardBorder,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .shadow(color: isSelected ? themeManager.currentTheme.shadow : Color.clear, radius: isSelected ? 15 : 5, x: 0, y: 5)
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
    }

    /// 白や淡い色でも見えるよう、縁を必ず付ける
    /// 色見本。角丸と縁の太さは、そのテーマ自身の値で描く。
    /// 枠を揃えたぶん、形の個性はここで見せる。
    /// 大きさと位置は全テーマで同じなので、並べても一覧は乱れない
    private func swatch(_ color: Color, in preset: ThemePreset) -> some View {
        let shape = RoundedRectangle(cornerRadius: preset.radius(.small))

        return shape
            .fill(color)
            .frame(width: 26, height: 26)
            .overlay(
                shape.stroke(preset.text.opacity(0.18),
                             lineWidth: max(preset.style.borderWidth, 1))
            )
    }
}

// MARK: - Help Card
struct HelpCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var themeManager = ThemeManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    color.opacity(0.8),
                                    color.opacity(0.5)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 45, height: 45)

                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(themeManager.currentTheme.adaptiveText(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)

                    // fixedSize が無いと HStack 内で横に潰され、
                    // 1文字だけ次行に落ちるような不自然な折り返しになる
                    Text(description)
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(themeManager.currentTheme.cardBackground2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: color.opacity(0.2), radius: 10, x: 0, y: 5)
    }
}

// MARK: - User Guide View
struct UserGuideView: View {
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedSection: Int = 0

    let guideSections = [
        GuideSection(
            title: "旅行計画の作成",
            icon: "airplane.departure",
            color: .blue,
            steps: [
                "「計画」タブから「+」ボタンをタップ",
                "旅行のタイトル、目的地、日程を入力",
                "写真を追加（オプション）",
                "「保存」をタップして完了"
            ]
        ),
        GuideSection(
            title: "スケジュール管理",
            icon: "calendar",
            color: .orange,
            steps: [
                "旅行計画の詳細画面を開く",
                "日付タブを選択",
                "「+」ボタンでスケジュールを追加",
                "時間、場所、メモ、費用を入力"
            ]
        ),
        GuideSection(
            title: "訪問済み場所の保存",
            icon: "mappin.circle",
            color: .green,
            steps: [
                "「場所保存」タブを開く",
                "「場所を追加」からマップを開く",
                "場所を検索または選択",
                "写真やメモを追加",
                "タグを設定して保存"
            ]
        ),
        GuideSection(
            title: "天気予報の確認",
            icon: "cloud.sun",
            color: .cyan,
            steps: [
                "旅行計画で目的地を設定",
                "詳細画面で自動的に天気予報を表示",
                "気温、降水確率、UV指数を確認"
            ]
        ),
        GuideSection(
            title: "持ち物リスト",
            icon: "checklist",
            color: .purple,
            steps: [
                "旅行計画の詳細画面を開く",
                "持ち物リストセクションを表示",
                "「+」ボタンでアイテムを追加",
                "チェックボックスで完了を管理"
            ]
        ),
        GuideSection(
            title: "計画の共有",
            icon: "person.2",
            color: .pink,
            steps: [
                "旅行計画の詳細画面を開く",
                "共有ボタン（人アイコン）をタップ",
                "共有コードを作成",
                "友達に共有コードを送信"
            ]
        )
    ]

    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient

                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 10) {
                            Image(systemName: "book.fill")
                                .font(.system(size: 50))
                                .foregroundColor(themeManager.currentTheme.actionFill.opacity(0.8))
                                .padding(.top, 20)

                            Text("使い方ガイド")
                                .font(.title.bold())
                                .foregroundColor(themeManager.currentTheme.adaptiveText(for: colorScheme))

                            Text("GoTravelの基本的な使い方")
                                .font(.subheadline)
                                .foregroundColor(themeManager.currentTheme.secondaryText)
                        }
                        .padding(.bottom, 10)

                        // Guide Sections
                        ForEach(Array(guideSections.enumerated()), id: \.offset) { index, section in
                            GuideSectionCard(section: section)
                                .padding(.horizontal)
                        }

                        // Tips Section
                        tipsSection
                            .padding(.horizontal)
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationBarItems(trailing: closeButton)
        }
        .navigationViewStyle(.stack)
    }

    private var closeButton: some View {
        Button(action: { presentationMode.wrappedValue.dismiss() }) {
            Image(systemName: "xmark.circle.fill")
                .font(.title2)
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.5))
        }
        .accessibilityLabel("閉じる")
    }

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("便利なヒント")
                    .font(.headline)
                    .foregroundColor(themeManager.currentTheme.adaptiveText(for: colorScheme))
            }

            VStack(alignment: .leading, spacing: 10) {
                TipRow(icon: "star.fill", text: "目的地を入力すると自動的に座標が設定され、天気予報が表示されます", color: .orange)
                TipRow(icon: "photo.fill", text: "写真を追加すると旅行の思い出を振り返りやすくなります", color: .blue)
                TipRow(icon: "tag.fill", text: "タグを使って訪問済み場所を整理しましょう", color: .green)
                TipRow(icon: "yensign.circle.fill", text: "スケジュールに費用を入力すると自動的に合計金額が計算されます", color: .cyan)
                TipRow(icon: "map.fill", text: "マップから場所を探して旅行プランに追加できます", color: .orange)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(themeManager.currentTheme.cardBackground2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
    }

    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: colorScheme == .dark ?
                [themeManager.currentTheme.backgroundDark, themeManager.currentTheme.secondaryBackgroundDark] :
                [themeManager.currentTheme.backgroundLight, themeManager.currentTheme.secondaryBackgroundLight]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

// MARK: - Guide Section Model
struct GuideSection {
    let title: String
    let icon: String
    let color: Color
    let steps: [String]
}

// MARK: - Guide Section Card
struct GuideSectionCard: View {
    let section: GuideSection
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var themeManager = ThemeManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Title
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    section.color.opacity(0.8),
                                    section.color.opacity(0.5)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 45, height: 45)

                    Image(systemName: section.icon)
                        .font(.title3)
                        .foregroundColor(.white)
                }

                Text(section.title)
                    .font(.headline)
                    .foregroundColor(themeManager.currentTheme.adaptiveText(for: colorScheme))

                Spacer()
            }

            // Steps
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(section.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1).")
                            .font(.caption.bold())
                            .foregroundColor(section.color)
                            .frame(width: 20, alignment: .leading)

                        Text(step)
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.secondaryText)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(themeManager.currentTheme.cardBackground2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(section.color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Tip Row
struct TipRow: View {
    let icon: String
    let text: String
    let color: Color
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var themeManager = ThemeManager.shared

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
                .frame(width: 20)

            Text(text)
                .font(.caption)
                .foregroundColor(themeManager.currentTheme.secondaryText)
        }
    }
}



/// Travory の連絡先と公式アカウント（2026-10 に開設）
enum TravoryLinks {
    static let supportEmail = "travory.rf@gmail.com"
    static let accountName = "travory.rf"
    static let instagram = URL(string: "https://www.instagram.com/travory.rf/")!
    static let threads = URL(string: "https://www.threads.com/@travory.rf")!
}
