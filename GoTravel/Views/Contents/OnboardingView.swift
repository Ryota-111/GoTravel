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

    var body: some View {
        ZStack {
            // Background gradient
            backgroundGradient

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    if currentPage < pages.count - 1 {
                        Button(action: {
                            withAnimation {
                                currentPage = pages.count - 1
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
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)

                // Custom page indicator
                HStack(spacing: 10) {
                    ForEach(0..<pages.count, id: \.self) { index in
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
                    if currentPage == pages.count - 1 {
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

    private var backgroundGradient: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: pages[currentPage].gradientColors),
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

// MARK: - Onboarding Page Model
struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
    let gradientColors: [Color]
    let features: [String]
}
