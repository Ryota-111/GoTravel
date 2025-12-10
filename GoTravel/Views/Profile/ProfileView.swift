import SwiftUI
import StoreKit

struct ProfileView: View {
    @StateObject private var vm = ProfileViewModel()
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme
    @State private var animateCards = false

    var body: some View {
        ZStack {
            // Background with mesh gradient effect
            backgroundGradient

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    profileHeaderSection

                    VStack(spacing: 16) {
                        profileEditCard

                        accountCard

                        helpSupportCard
                        
                        appsettingCard

                        // cloudKitTestCard // 開発用：必要時にコメント解除
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 30)
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
            // Multi-layer gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.1, green: 0.05, blue: 0.2),
                    Color(red: 0.15, green: 0.1, blue: 0.25),
                    Color(red: 0.05, green: 0.05, blue: 0.15)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Animated gradient circles
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.purple.opacity(0.3),
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
                            Color.blue.opacity(0.25),
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
                            Color.pink.opacity(0.2),
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
    private var profileHeaderSection: some View {
        VStack(spacing: 0) {
            ZStack {
                // Avatar with glassmorphism effect
                VStack(spacing: 20) {
                    Spacer()
                        .frame(height: 40)

                    // Profile Photo
                    ZStack {
                        // Glowing background
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.purple.opacity(0.6),
                                        Color.pink.opacity(0.4),
                                        Color.blue.opacity(0.5)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 150, height: 150)
                            .blur(radius: 20)

                        // Avatar container
                        ZStack(alignment: .bottomTrailing) {
                            ZStack {
                                if let ui = vm.avatarImage {
                                    Image(uiImage: ui)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 140, height: 140)
                                } else {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color.purple.opacity(0.5),
                                                    Color.pink.opacity(0.3)
                                                ]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 140, height: 140)

                                    Image(systemName: "person.fill")
                                        .font(.system(size: 70))
                                        .foregroundColor(.white.opacity(0.9))
                                }
                            }
                            .frame(width: 140, height: 140)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.white.opacity(0.8),
                                                Color.purple.opacity(0.4),
                                                Color.pink.opacity(0.4)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 4
                                    )
                            )
                            .shadow(color: Color.purple.opacity(0.4), radius: 20, x: 0, y: 10)
                        }
                    }

                    // User Info with glassmorphism card
                    VStack(spacing: 12) {
                        Text(authVM.userFullName ?? "ユーザー")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [.white, Color.white.opacity(0.8)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Text(authVM.userEmail ?? "")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.15))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            )
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.05))
                                    .blur(radius: 10)
                                    .offset(y: 5)
                            )
                    }
                    .padding(.top, 15)
                    .padding(.bottom, 30)
                }
            }
        }
        .opacity(animateCards ? 1 : 0)
        .scaleEffect(animateCards ? 1 : 0.9)
        .animation(.spring(response: 0.7, dampingFraction: 0.7), value: animateCards)
    }

    // MARK: - Profile Edit Card
    private var profileEditCard: some View {
        NavigationLink(destination: ProfileEditView(vm: vm)) {
            GlassMenuCard(
                icon: "pencil",
                title: "アカウント編集",
                subtitle: "プロフィール情報を変更",
                gradientColors: [Color(red: 0.4, green: 0.5, blue: 1.0), Color(red: 0.5, green: 0.3, blue: 0.9)]
            )
        }
        .buttonStyle(CardButtonStyle())
        .opacity(animateCards ? 1 : 0)
        .scaleEffect(animateCards ? 1 : 0.8)
        .offset(y: animateCards ? 0 : 30)
        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.15), value: animateCards)
    }

    // MARK: - Account Card
    private var accountCard: some View {
        NavigationLink(destination: AccountActionView(vm: vm)) {
            GlassMenuCard(
                icon: "gearshape",
                title: "アカウント管理",
                subtitle: "セキュリティとプライバシー",
                gradientColors: [Color(red: 1.0, green: 0.5, blue: 0.3), Color(red: 1.0, green: 0.3, blue: 0.5)]
            )
        }
        .buttonStyle(CardButtonStyle())
        .opacity(animateCards ? 1 : 0)
        .scaleEffect(animateCards ? 1 : 0.8)
        .offset(y: animateCards ? 0 : 30)
        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.25), value: animateCards)
    }

    // MARK: - Help & Support Card
    private var helpSupportCard: some View {
        NavigationLink(destination: HelpSupportView()) {
            GlassMenuCard(
                icon: "questionmark.circle",
                title: "ヘルプサポート",
                subtitle: "よくある質問とお問い合わせ",
                gradientColors: [Color(red: 0.2, green: 0.8, blue: 0.5), Color(red: 0.3, green: 0.6, blue: 0.9)]
            )
        }
        .buttonStyle(CardButtonStyle())
        .opacity(animateCards ? 1 : 0)
        .scaleEffect(animateCards ? 1 : 0.8)
        .offset(y: animateCards ? 0 : 30)
        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.35), value: animateCards)
    }
    
    private var appsettingCard: some View {
        NavigationLink(destination: AppSettingView()) {
            GlassMenuCard(
                icon: "gearshape",
                title: "アプリ設定",
                subtitle: "アプリカラー",
                gradientColors: [Color(red: 1.0, green: 0.5, blue: 0.3), Color(red: 1.0, green: 0.3, blue: 0.5)]
            )
        }
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

    var body: some View {
        ZStack {
            // Glassmorphism background
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.08)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.1)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 8)

            HStack(spacing: 18) {
                // Gradient Icon
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: gradientColors),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 65, height: 65)
                        .blur(radius: 15)
                        .opacity(0.6)

                    // Icon container
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: gradientColors),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 2)
                        )
                        .shadow(color: gradientColors[0].opacity(0.4), radius: 8, x: 0, y: 4)

                    Image(systemName: icon)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(.white)
                }

                // Text content
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }

                Spacer()

                // Arrow
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
        }
        .frame(height: 100)
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
    @StateObject var vm: ProfileViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @State private var showImagePicker = false
    @State private var showRemoveAvatarConfirm = false
    @State private var animateContent = false

    var body: some View {
        ZStack {
            backgroundGradient

            ScrollView(showsIndicators: false) {
                VStack(spacing: 25) {
                    // User Info (read-only)
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
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                animateContent = true
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
                [.blue.opacity(0.7), .black] :
                [.blue.opacity(0.6), .white.opacity(0.3)]),
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
                        .foregroundColor(.blue)
                    Text("名前")
                        .font(.caption.bold())
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .gray)
                }

                Text(authVM.userFullName ?? "ユーザー")
                    .font(.body)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                colorScheme == .dark ?
                                    Color.white.opacity(0.05) :
                                    Color.white.opacity(0.5)
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "envelope.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text("メールアドレス")
                        .font(.caption.bold())
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .gray)
                }

                Text(authVM.userEmail ?? "")
                    .font(.body)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                colorScheme == .dark ?
                                    Color.white.opacity(0.05) :
                                    Color.white.opacity(0.5)
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    colorScheme == .dark ?
                        Color.white.opacity(0.1) :
                        Color.white.opacity(0.2)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.blue.opacity(0.3),
                            Color.blue.opacity(0.1)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.blue.opacity(0.2), radius: 10, x: 0, y: 5)
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : -20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animateContent)
    }

    private var infoNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("お知らせ")
                    .font(.caption.bold())
                    .foregroundColor(colorScheme == .dark ? .white : .black)
            }

            Text("名前とメールアドレスはApple IDから取得されます。変更する場合は、Apple IDの設定から変更してください。")
                .font(.caption)
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .gray)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.blue.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
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
                            .frame(width: 140, height: 140)
                    } else {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.blue.opacity(0.6),
                                        Color.purple.opacity(0.6)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)

                        Image(systemName: "person.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .frame(width: 120, height: 120)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.5),
                                    Color.white.opacity(0.2)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                )
                .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 8)

                Menu {
                    Button("写真を選択") { showImagePicker = true }
                    if vm.avatarImage != nil {
                        Button("削除", role: .destructive) { showRemoveAvatarConfirm = true }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.8))
                            .frame(width: 36, height: 36)
                        Image(systemName: "pencil")
                            .foregroundColor(.white)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .shadow(color: .blue.opacity(0.3), radius: 5, x: 0, y: 2)
                }
                .offset(x: -5, y: -5)
            }

            Text("プロフィール写真")
                .font(.caption)
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    colorScheme == .dark ?
                        Color.white.opacity(0.1) :
                        Color.white.opacity(0.2)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.blue.opacity(0.3),
                            Color.blue.opacity(0.1)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.blue.opacity(0.2), radius: 10, x: 0, y: 5)
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : -20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animateContent)
    }
}

// MARK: - Account Action View
struct AccountActionView: View {
    @StateObject var vm: ProfileViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.colorScheme) var colorScheme
    @State private var showSignOutConfirm = false
    @State private var showDeleteConfirm = false
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
                            .foregroundColor(.orange.opacity(0.8))
                            .padding(.top, 30)

                        VStack(spacing: 8) {
                            Text("アカウント管理")
                                .font(.title2.bold())
                                .foregroundColor(colorScheme == .dark ? .white : .black)

                            Text("サインアウトまたはアカウント削除を行います")
                                .font(.subheadline)
                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .gray)
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
                                    .foregroundColor(colorScheme == .dark ? .white : .black)

                                Text("サインアウト")
                                    .font(.headline)
                                    .foregroundColor(colorScheme == .dark ? .white : .black)

                                Spacer()
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        colorScheme == .dark ?
                                            Color.white.opacity(0.1) :
                                            Color.white.opacity(0.2)
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .opacity(animateButtons ? 1 : 0)
                        .offset(y: animateButtons ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: animateButtons)

                        // Delete Account Button
                        Button(action: {
                            showDeleteConfirm = true
                        }) {
                            HStack {
                                Image(systemName: "trash.fill")
                                    .font(.title3)
                                    .foregroundColor(colorScheme == .dark ? .white : .black)

                                Text("アカウント削除")
                                    .font(.headline)
                                    .foregroundColor(colorScheme == .dark ? .white : .black)

                                Spacer()
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        colorScheme == .dark ?
                                            Color.white.opacity(0.1) :
                                            Color.white.opacity(0.2)
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .opacity(animateButtons ? 1 : 0)
                        .offset(y: animateButtons ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: animateButtons)

                        // Warning Text
                        VStack(alignment: .leading, spacing: 8) {
                            Text("⚠️ 注意事項")
                                .font(.headline)
                                .foregroundColor(.red.opacity(0.8))

                            Text("• サインアウト: 再度ログインすることでアカウントを復元できます")
                                .font(.caption)
                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .gray)

                            Text("• アカウント削除: すべてのデータが完全に削除されます。この操作は取り消せません")
                                .font(.caption)
                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .gray)
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
        .confirmationDialog("アカウントを削除しますか？", isPresented: $showDeleteConfirm) {
            Button("削除", role: .destructive) {
                authVM.deleteAccount()
            }
        } message: {
            Text("この操作は取り消せません。すべてのデータが完全に削除されます。")
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: colorScheme == .dark ?
                [.orange.opacity(0.7), .black] :
                [.orange.opacity(0.6), .white.opacity(0.3)]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

// MARK: - Help Support View
struct HelpSupportView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var animateCards = false
    @State private var showUserGuide = false
    @State private var showContactAlert = false

    var body: some View {
        ZStack {
            backgroundGradient

            ScrollView(showsIndicators: false) {
                VStack(spacing: 25) {
                    // Header
                    VStack(spacing: 15) {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green.opacity(0.8))
                            .padding(.top, 30)

                        VStack(spacing: 8) {
                            Text("ヘルプ・サポート")
                                .font(.title2.bold())
                                .foregroundColor(colorScheme == .dark ? .white : .black)

                            Text("使い方やお困りの際はこちら")
                                .font(.subheadline)
                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .gray)
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

                        // Contact
                        Button(action: { showContactAlert = true }) {
                            HelpCard(
                                icon: "envelope.fill",
                                title: "お問い合わせ",
                                description: "ご質問やご要望はこちらから",
                                color: .green
                            )
                        }
                        .opacity(animateCards ? 1 : 0)
                        .offset(y: animateCards ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: animateCards)

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
                            description: "Version 1.0.0",
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
        .alert("お問い合わせ", isPresented: $showContactAlert) {
            Button("メールを送る") {
                openEmail()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("ご質問やご要望がございましたら、下記のメールアドレスまでお問い合わせください。\n\ntaismryotasis@gmail.com")
        }
    }

    private func requestReview() {
        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            AppStore.requestReview(in: scene)
        }
    }

    private func openEmail() {
        let email = "support@gotravel.app"
        let subject = "GoTravelアプリについてのお問い合わせ"
        let urlString = "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"

        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: colorScheme == .dark ?
                [.green.opacity(0.7), .black] :
                [.green.opacity(0.6), .white.opacity(0.3)]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

struct AppSettingView: View {
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme
    @State private var animateCards = false

    var body: some View {
        ZStack {
            backgroundGradient

            ScrollView(showsIndicators: false) {
                VStack(spacing: 25) {
                    // Header
                    VStack(spacing: 15) {
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: 60))
                            .foregroundColor(themeManager.currentTheme.primary.opacity(0.8))
                            .padding(.top, 30)

                        VStack(spacing: 8) {
                            Text("アプリ設定")
                                .font(.title2.bold())
                                .foregroundColor(themeManager.currentTheme.text)

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
                            .foregroundColor(themeManager.currentTheme.text)

                        HStack {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(themeManager.currentTheme.primary)
                                    .frame(width: 30, height: 30)
                                Circle()
                                    .fill(themeManager.currentTheme.secondary)
                                    .frame(width: 30, height: 30)
                                Circle()
                                    .fill(themeManager.currentTheme.tertiary)
                                    .frame(width: 30, height: 30)
                            }

                            Spacer()

                            Text(themeManager.currentTheme.type.displayName)
                                .font(.headline)
                                .foregroundColor(themeManager.currentTheme.text)
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

                    // Theme Selection
                    VStack(alignment: .leading, spacing: 16) {
                        Text("テーマを選択")
                            .font(.headline)
                            .foregroundColor(themeManager.currentTheme.text)
                            .padding(.horizontal)

                        ForEach(Array(ThemePreset.ThemeType.allCases.enumerated()), id: \.offset) { index, themeType in
                            ThemeCard(
                                themeType: themeType,
                                isSelected: themeManager.currentTheme.type == themeType,
                                onSelect: {
                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                        themeManager.setTheme(themeType)
                                    }
                                }
                            )
                            .padding(.horizontal)
                            .opacity(animateCards ? 1 : 0)
                            .offset(y: animateCards ? 0 : 20)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15 + Double(index) * 0.05), value: animateCards)
                        }
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
    }

    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                themeManager.currentTheme.gradientLight,
                themeManager.currentTheme.gradientDark
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

// MARK: - Theme Card
struct ThemeCard: View {
    let themeType: ThemePreset.ThemeType
    let isSelected: Bool
    let onSelect: () -> Void

    @ObservedObject var themeManager = ThemeManager.shared

    var body: some View {
        Button(action: onSelect) {
            let previewTheme = ThemePreset(type: themeType)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(themeType.displayName)
                        .font(.headline)
                        .foregroundColor(themeManager.currentTheme.text)

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(themeManager.currentTheme.success)
                    }
                }

                // Color Preview
                HStack(spacing: 8) {
                    Circle()
                        .fill(previewTheme.primary)
                        .frame(width: 40, height: 40)
                    Circle()
                        .fill(previewTheme.secondary)
                        .frame(width: 40, height: 40)
                    Circle()
                        .fill(previewTheme.tertiary)
                        .frame(width: 40, height: 40)
                    Circle()
                        .fill(previewTheme.accent1)
                        .frame(width: 40, height: 40)
                    Circle()
                        .fill(previewTheme.accent2)
                        .frame(width: 40, height: 40)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? themeManager.currentTheme.primary.opacity(0.1) : themeManager.currentTheme.cardBackground2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? themeManager.currentTheme.primary : themeManager.currentTheme.cardBorder, lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: isSelected ? themeManager.currentTheme.shadow : Color.clear, radius: isSelected ? 15 : 5, x: 0, y: 5)
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Help Card
struct HelpCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    @Environment(\.colorScheme) var colorScheme

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
                        .foregroundColor(colorScheme == .dark ? .white : .black)

                    Text(description)
                        .font(.caption)
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .gray)
                }

                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    colorScheme == .dark ?
                        Color.white.opacity(0.1) :
                        Color.white.opacity(0.2)
                )
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
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedSection: Int = 0

    let guideSections = [
        GuideSection(
            title: "旅行計画の作成",
            icon: "airplane.departure",
            color: .blue,
            steps: [
                "「予定」タブから「+」ボタンをタップ",
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
                "「保存済み」タブを開く",
                "「+」ボタンをタップ",
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
                                .foregroundColor(.blue.opacity(0.8))
                                .padding(.top, 20)

                            Text("使い方ガイド")
                                .font(.title.bold())
                                .foregroundColor(colorScheme == .dark ? .white : .black)

                            Text("GoTravelの基本的な使い方")
                                .font(.subheadline)
                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .gray)
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
    }

    private var closeButton: some View {
        Button(action: { presentationMode.wrappedValue.dismiss() }) {
            Image(systemName: "xmark.circle.fill")
                .font(.title2)
                .foregroundColor(.white.opacity(0.7))
        }
    }

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("便利なヒント")
                    .font(.headline)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
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
                .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.white.opacity(0.2))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
    }

    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: colorScheme == .dark ?
                [.blue.opacity(0.7), .black] :
                [.blue.opacity(0.6), .white.opacity(0.3)]),
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
                    .foregroundColor(colorScheme == .dark ? .white : .black)

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
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .gray)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.white.opacity(0.2))
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

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
                .frame(width: 20)

            Text(text)
                .font(.caption)
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .gray)
        }
    }
}

