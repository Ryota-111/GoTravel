import SwiftUI

struct SplashScreenView: View {
    @ObservedObject var themeManager = ThemeManager.shared
    @State private var isActive = false
    @State private var showOnboarding = false

    // 離陸の動き。まとめて出すのではなく、滑走路・飛行機・文字を別々に動かす
    @State private var runwayScale: CGFloat = 0
    @State private var planeOffset = CGSize(width: -110, height: 80)
    @State private var planeOpacity = 0.0
    @State private var textOffset: CGFloat = 14
    @State private var textOpacity = 0.0

    var body: some View {
        if isActive {
            if showOnboarding {
                OnboardingView {
                    OnboardingManager.shared.completeOnboarding()
                    withAnimation {
                        showOnboarding = false
                    }
                }
                .transition(.opacity.combined(with: .scale))
            } else {
                ContentView()
                    .transition(.opacity.combined(with: .scale))
            }
        } else {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [themeManager.currentTheme.primary.opacity(0.6), themeManager.currentTheme.light]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 20) {
                    // `airplane.departure` は滑走路の線まで含んだ1つの記号なので、
                    // そのまま動かすと線ごと飛んでいってしまう。
                    // 飛行機（`airplane` を離陸の角度に傾けたもの）と線を分けて持つ
                    ZStack(alignment: .bottom) {
                        Image(systemName: "airplane")
                            .font(.system(size: 62, weight: .medium))
                            .rotationEffect(.degrees(-20))
                            .foregroundColor(themeManager.currentTheme.accent2)
                            .offset(planeOffset)
                            .opacity(planeOpacity)
                            .padding(.bottom, 24)

                        Capsule()
                            .fill(themeManager.currentTheme.accent2)
                            .frame(width: 96, height: 7)
                            .scaleEffect(x: runwayScale)
                    }
                    .frame(width: 200, height: 112)

                    Text("Travory")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.currentTheme.accent2)
                        .offset(y: textOffset)
                        .opacity(textOpacity)
                }
            }
            .onAppear {
                // 滑走路が伸びる → 飛行機が左下から上がってくる → 文字が下からつく。
                // 画面が切り替わるまで2.0秒しかないので、1.3秒で収める
                withAnimation(.easeOut(duration: 0.28)) {
                    runwayScale = 1
                }
                withAnimation(.easeOut(duration: 0.85).delay(0.12)) {
                    planeOffset = .zero
                    planeOpacity = 1.0
                }
                withAnimation(.easeOut(duration: 0.5).delay(0.78)) {
                    textOffset = 0
                    textOpacity = 1.0
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    // Check if onboarding needs to be shown
                    showOnboarding = !OnboardingManager.shared.hasCompletedOnboarding

                    withAnimation(.easeOut(duration: 0.5)) {
                        isActive = true
                    }
                }
            }
        }
    }
}
