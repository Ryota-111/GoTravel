import SwiftUI

struct ProfileView: View {
    @StateObject private var vm = ProfileViewModel()
    @Environment(\.colorScheme) var colorScheme
    @State private var animateCards = false

    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 25) {
                        profileHeaderSection

                        VStack(spacing: 16) {
                            profileEditCard
                            
                            accountCard
                            
                            helpSupportCard
                            
                            developerSupportCard
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top, 5)
                    .padding(.bottom, 30)
                }
                .navigationTitle("プロフィール")
                .navigationBarTitleDisplayMode(.large)
            }
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                    animateCards = true
                }
            }
        }
    }

    // MARK: - Profile Header
    private var profileHeaderSection: some View {
        VStack(spacing: 15) {
            // Avatar
            Group {
                if let ui = vm.avatarImage {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
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

                        Image(systemName: "person.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.8))
                    }
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

            // User Info
            VStack(spacing: 6) {
                Text(vm.displayName)
                    .font(.title2.bold())
                    .foregroundColor(colorScheme == .dark ? .white : .black)

                Text(vm.email)
                    .font(.subheadline)
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .gray)
            }
        }
        .padding(.vertical, 20)
        .opacity(animateCards ? 1 : 0)
        .offset(y: animateCards ? 0 : -20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animateCards)
    }

    // MARK: - Profile Edit Card
    private var profileEditCard: some View {
        NavigationLink(destination: ProfileEditView(vm: vm)) {
            ProfileMenuCard(
                icon: "person.crop.circle",
                title: "プロフィール編集",
                subtitle: "名前、写真の変更",
                color: .blue
            )
        }
        .opacity(animateCards ? 1 : 0)
        .offset(y: animateCards ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: animateCards)
    }

    // MARK: - Account Card
    private var accountCard: some View {
        NavigationLink(destination: AccountActionView(vm: vm)) {
            ProfileMenuCard(
                icon: "person.badge.key",
                title: "アカウント",
                subtitle: "サインアウト、アカウント削除",
                color: .orange
            )
        }
        .opacity(animateCards ? 1 : 0)
        .offset(y: animateCards ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: animateCards)
    }

    // MARK: - Help & Support Card
    private var helpSupportCard: some View {
        NavigationLink(destination: HelpSupportView()) {
            ProfileMenuCard(
                icon: "questionmark.circle",
                title: "ヘルプ・サポート",
                subtitle: "使い方、お問い合わせ",
                color: .green
            )
        }
        .opacity(animateCards ? 1 : 0)
        .offset(y: animateCards ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: animateCards)
    }

    // MARK: - Developer Support Card
    private var developerSupportCard: some View {
        NavigationLink(destination: DeveloperSupportView()) {
            ProfileMenuCard(
                icon: "heart.fill",
                title: "開発者を応援",
                subtitle: "アプリの開発をサポート",
                color: .pink
            )
        }
        .opacity(animateCards ? 1 : 0)
        .offset(y: animateCards ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.25), value: animateCards)
    }

    // MARK: - Background
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

// MARK: - Profile Menu Card
struct ProfileMenuCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 15) {
            // Icon
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
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.white)
            }

            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(colorScheme == .dark ? .white : .black)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .gray)
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.subheadline)
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.5) : .gray.opacity(0.5))
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
                            color.opacity(0.3),
                            color.opacity(0.1)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: color.opacity(0.2), radius: 10, x: 0, y: 5)
    }
}

struct ProfileEditView: View {
    @StateObject var vm: ProfileViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var showImagePicker = false
    @State private var showRemoveAvatarConfirm = false
    
    var body: some View {
        ZStack {
//            Color.black.opacity(0.9).ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    avatarSection
                    
                    nameEmailEditSection
                    
                    saveButton
                }
                .padding()
            }
            .navigationTitle("プロフィール編集")
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
    
    private var avatarSection: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let ui = vm.avatarImage {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .scaledToFill()
                        .foregroundColor(.white.opacity(0.3))
                }
            }
            .frame(width: 150, height: 150)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 3)
            )
            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            
            Menu {
                Button("写真を選択") { showImagePicker = true }
                if vm.avatarImage != nil {
                    Button("削除", role: .destructive) { showRemoveAvatarConfirm = true }
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 40, height: 40)
                    Image(systemName: "pencil")
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .offset(x: -10, y: -10)
        }
        .padding(.top, 20)
    }
    private var nameEmailEditSection: some View {
        VStack(spacing: 15) {
            TextField("名前", text: $vm.profile.name)
                .textFieldStyle(CustomTextFieldStyle())
            
            TextField("メールアドレス", text: $vm.profile.email)
                .textFieldStyle(CustomTextFieldStyle())
        }
    }
    
    private var saveButton: some View {
        Button(action: {
            vm.saveProfile()
            presentationMode.wrappedValue.dismiss()
        }) {
            Text("保存")
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.5))
                .cornerRadius(12)
        }
        .disabled(vm.isSaving)
    }
}

// MARK: - Account Action View
struct AccountActionView: View {
    @StateObject var vm: ProfileViewModel
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
                vm.signOut { _ in }
            }
        } message: {
            Text("再度ログインすることでアカウントを復元できます")
        }
        .confirmationDialog("アカウントを削除しますか？", isPresented: $showDeleteConfirm) {
            Button("削除", role: .destructive) {
                vm.deleteAccount { _ in }
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
                        HelpCard(
                            icon: "book.fill",
                            title: "使い方ガイド",
                            description: "アプリの基本的な使い方を確認できます",
                            color: .blue
                        )
                        .opacity(animateCards ? 1 : 0)
                        .offset(y: animateCards ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: animateCards)

                        HelpCard(
                            icon: "envelope.fill",
                            title: "お問い合わせ",
                            description: "ご質問やご要望はこちらから",
                            color: .green
                        )
                        .opacity(animateCards ? 1 : 0)
                        .offset(y: animateCards ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: animateCards)

                        HelpCard(
                            icon: "star.fill",
                            title: "レビューを書く",
                            description: "アプリの評価をお願いします",
                            color: .orange
                        )
                        .opacity(animateCards ? 1 : 0)
                        .offset(y: animateCards ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: animateCards)

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

// MARK: - Developer Support View
struct DeveloperSupportView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var animateCards = false

    var body: some View {
        ZStack {
            backgroundGradient

            ScrollView(showsIndicators: false) {
                VStack(spacing: 25) {
                    // Header
                    VStack(spacing: 15) {
                        Image(systemName: "heart.circle.fill")
                            .font(.system(size: 70))
                            .foregroundColor(.pink.opacity(0.8))
                            .padding(.top, 30)

                        VStack(spacing: 8) {
                            Text("開発者を応援")
                                .font(.title2.bold())
                                .foregroundColor(colorScheme == .dark ? .white : .black)

                            Text("アプリの開発を支援していただけると嬉しいです")
                                .font(.subheadline)
                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                    .opacity(animateCards ? 1 : 0)
                    .offset(y: animateCards ? 0 : -20)

                    // Support Options
                    VStack(spacing: 16) {
                        SupportOptionCard(
                            icon: "cup.and.saucer.fill",
                            title: "コーヒー1杯分",
                            price: "¥300",
                            description: "開発のモチベーションになります",
                            color: .orange
                        )
                        .opacity(animateCards ? 1 : 0)
                        .offset(y: animateCards ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: animateCards)

                        SupportOptionCard(
                            icon: "fork.knife",
                            title: "ランチ1食分",
                            price: "¥800",
                            description: "開発を全力でサポート",
                            color: .green
                        )
                        .opacity(animateCards ? 1 : 0)
                        .offset(y: animateCards ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: animateCards)

                        SupportOptionCard(
                            icon: "star.fill",
                            title: "プレミアムサポート",
                            price: "¥1,500",
                            description: "継続的な開発を応援",
                            color: .pink
                        )
                        .opacity(animateCards ? 1 : 0)
                        .offset(y: animateCards ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: animateCards)

                        // Thank You Message
                        VStack(spacing: 10) {
                            Text("🙏 ありがとうございます")
                                .font(.headline)
                                .foregroundColor(colorScheme == .dark ? .white : .black)

                            Text("皆様の応援が開発の励みになります。より良いアプリを作るために頑張ります！")
                                .font(.caption)
                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .gray)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.pink.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.pink.opacity(0.3), lineWidth: 1)
                        )
                        .opacity(animateCards ? 1 : 0)
                        .offset(y: animateCards ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.25), value: animateCards)
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 30)
            }
            .navigationTitle("開発者を応援")
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
            gradient: Gradient(colors: colorScheme == .dark ?
                [.pink.opacity(0.7), .black] :
                [.pink.opacity(0.6), .white.opacity(0.3)]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

// MARK: - Support Option Card
struct SupportOptionCard: View {
    let icon: String
    let title: String
    let price: String
    let description: String
    let color: Color
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: {
            // TODO: Implement in-app purchase
            print("Support option tapped: \(title)")
        }) {
            HStack(spacing: 15) {
                // Icon
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
                        .frame(width: 55, height: 55)

                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(.white)
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(colorScheme == .dark ? .white : .black)

                    Text(description)
                        .font(.caption)
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .gray)
                }

                Spacer()

                // Price
                Text(price)
                    .font(.title3.bold())
                    .foregroundColor(color)
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
                                color.opacity(0.5),
                                color.opacity(0.2)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
            .shadow(color: color.opacity(0.3), radius: 10, x: 0, y: 5)
        }
    }
}

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .foregroundColor(.white)
            .padding(10)
            .background(Color.white.opacity(0.2))
            .cornerRadius(10)
    }
}
