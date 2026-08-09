import SwiftUI

// MARK: - Onboarding View
struct OnboardingView: View {
    @State private var currentPage = 0
    @State private var animateContent = false
    @Environment(\.colorScheme) var colorScheme

    var onComplete: () -> Void

    let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "airplane.departure",
            title: "旅行計画を作成",
            description: "行きたい場所、日程、スケジュールをまとめて管理できます",
            gradientColors: [Color.blue, Color.cyan],
            features: [
                "目的地の天気予報を自動表示",
                "スケジュールと費用を一元管理",
                "持ち物リストで忘れ物防止"
            ]
        ),
        OnboardingPage(
            icon: "map.fill",
            title: "訪れた場所を記録",
            description: "思い出の場所を写真やメモと一緒に保存しましょう",
            gradientColors: [Color.green, Color.mint],
            features: [
                "写真とメモで思い出を記録",
                "マップビューで位置を確認",
                "タグで場所を整理"
            ]
        ),
        OnboardingPage(
            icon: "calendar",
            title: "予定をカレンダーで管理",
            description: "日常の予定も旅行も、すべてまとめて確認できます",
            gradientColors: [Color.orange, Color.yellow],
            features: [
                "カレンダーで予定を一目で確認",
                "おでかけと日常を分けて管理",
                "今日・今後の予定を素早くチェック"
            ]
        ),
        OnboardingPage(
            icon: "person.2.fill",
            title: "計画を共有",
            description: "友達や家族と旅行計画を共有して、一緒に楽しみましょう",
            gradientColors: [Color.purple, Color.pink],
            features: [
                "共有コードで簡単に招待",
                "リアルタイムで同期",
                "みんなで編集できる"
            ]
        )
    ]

    /// 機能紹介の後ろにテーマ選択ページを足すため、総ページ数は pages より1多い
    private var totalPages: Int { pages.count + 1 }

    /// テーマ選択ページの背景。機能紹介とは違う色にして切り替わったことを伝える
    private let themePageGradient: [Color] = [Color.indigo, Color.purple]

    var body: some View {
        ZStack {
            // Background gradient
            backgroundGradient

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    if currentPage < totalPages - 1 {
                        Button(action: {
                            withAnimation {
                                currentPage = totalPages - 1
                            }
                        }) {
                            Text("スキップ")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                        }
                    }
                }
                .padding(.top, 50)
                .padding(.trailing, 20)

                // Pages
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }

                    OnboardingThemePage()
                        .tag(pages.count)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)

                // Custom page indicator
                HStack(spacing: 10) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        Circle()
                            .fill(currentPage == index ? Color.white : Color.white.opacity(0.3))
                            .frame(width: currentPage == index ? 10 : 8, height: currentPage == index ? 10 : 8)
                            .scaleEffect(currentPage == index ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: currentPage)
                    }
                }
                .padding(.vertical, 20)

                // Action buttons
                VStack(spacing: 15) {
                    if currentPage == totalPages - 1 {
                        Button(action: {
                            onComplete()
                        }) {
                            HStack {
                                Text("はじめる")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)

                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.3),
                                        Color.white.opacity(0.2)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                            )
                            .shadow(color: Color.white.opacity(0.2), radius: 10, x: 0, y: 5)
                        }
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        Button(action: {
                            withAnimation {
                                currentPage += 1
                            }
                        }) {
                            HStack {
                                Text("次へ")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)

                                Image(systemName: "arrow.right")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.3),
                                        Color.white.opacity(0.2)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                            )
                        }
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
                animateContent = true
            }
        }
    }

    /// テーマ選択ページは pages に含まれないため、範囲外参照を避けて振り分ける
    private var currentGradientColors: [Color] {
        currentPage < pages.count ? pages[currentPage].gradientColors : themePageGradient
    }

    private var backgroundGradient: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: currentGradientColors),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.5), value: currentPage)

            // Animated circles
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 300, height: 300)
                .offset(x: -100, y: -200)
                .blur(radius: 60)

            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 250, height: 250)
                .offset(x: 150, y: 400)
                .blur(radius: 70)
        }
    }
}

// MARK: - Onboarding Page View
struct OnboardingPageView: View {
    let page: OnboardingPage
    @State private var animateIcon = false
    @State private var animateContent = false

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 160, height: 160)
                    .blur(radius: 20)

                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 140, height: 140)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    )

                Image(systemName: page.icon)
                    .font(.system(size: 70, weight: .light))
                    .foregroundColor(.white)
            }
            .scaleEffect(animateIcon ? 1.0 : 0.8)
            .opacity(animateIcon ? 1.0 : 0.0)

            // Title
            Text(page.title)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .opacity(animateContent ? 1.0 : 0.0)
                .offset(y: animateContent ? 0 : 20)

            // Description
            Text(page.description)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .opacity(animateContent ? 1.0 : 0.0)
                .offset(y: animateContent ? 0 : 20)

            // Features
            VStack(spacing: 15) {
                ForEach(Array(page.features.enumerated()), id: \.offset) { index, feature in
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)

                        Text(feature)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.95))

                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .opacity(animateContent ? 1.0 : 0.0)
                    .offset(y: animateContent ? 0 : 30)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double(index) * 0.1), value: animateContent)
                }
            }
            .padding(.horizontal, 30)
            .padding(.top, 10)

            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                animateIcon = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3)) {
                animateContent = true
            }
        }
    }
}

// MARK: - Onboarding Theme Card
/// テーマ1つ分の選択肢。
/// オンボーディングの背景は色が濃いため、文字と枠は白で統一する
private struct OnboardingThemeCard: View {
    let themeType: ThemePreset.ThemeType
    let isSelected: Bool
    let onSelect: () -> Void

    private var preset: ThemePreset { ThemePreset(type: themeType) }

    /// 配色のプレビュー。白い色でも分かるよう明るい下地の上に置いて縁取りする
    private var swatch: some View {
        HStack(spacing: 5) {
            dot(preset.primary)
            dot(preset.secondary)
            dot(preset.travelColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 10).fill(preset.backgroundLight))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.6), lineWidth: 1)
        )
    }

    private func dot(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 14, height: 14)
            .overlay(Circle().stroke(Color.black.opacity(0.18), lineWidth: 1))
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                swatch

                Text(themeType.displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(.white.opacity(isSelected ? 1 : 0.45))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(isSelected ? 0.28 : 0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(isSelected ? 0.85 : 0.25), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Onboarding Theme Page
/// 配色を選ぶページ。
/// 色を変えられること自体を知らないまま使っている人がいたため、
/// 最初に一度触ってもらって存在を知らせる
struct OnboardingThemePage: View {
    @ObservedObject var themeManager = ThemeManager.shared
    @State private var animateContent = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 120, height: 120)
                    .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 2))

                Image(systemName: "paintpalette.fill")
                    .font(.system(size: 54, weight: .light))
                    .foregroundColor(.white)
            }
            .scaleEffect(animateContent ? 1.0 : 0.8)
            .opacity(animateContent ? 1.0 : 0.0)

            VStack(spacing: 10) {
                Text("好きな配色を選べます")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("アプリ全体の色を変えられます。タップして試してみてください")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
            .opacity(animateContent ? 1.0 : 0.0)
            .offset(y: animateContent ? 0 : 20)

            VStack(spacing: 12) {
                ForEach(ThemePreset.ThemeType.allCases, id: \.self) { type in
                    OnboardingThemeCard(
                        themeType: type,
                        isSelected: themeManager.currentTheme.type == type
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            themeManager.setTheme(type)
                        }
                    }
                }
            }
            .padding(.horizontal, 30)
            .opacity(animateContent ? 1.0 : 0.0)
            .offset(y: animateContent ? 0 : 30)

            Text("あとから「プロフィール」→「アプリ設定」で\nいつでも変更できます")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .opacity(animateContent ? 1.0 : 0.0)

            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15)) {
                animateContent = true
            }
        }
    }
}

// MARK: - Onboarding Page Model
struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
    let gradientColors: [Color]
    let features: [String]
}
