import SwiftUI

struct SplashScreenView: View {
    @State private var isActive = false
    @State private var showOnboarding = false
    @State private var opacity = 0.0
    @State private var scale = 0.8

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
                    gradient: Gradient(colors: [.blue.opacity(0.6), .white]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 20) {
                    Image(systemName: "airplane.departure")
                        .font(.system(size: 80))
                        .foregroundColor(.white)

                    Text("Travory")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .opacity(opacity)
                .scaleEffect(scale)
            }
            .onAppear {
                withAnimation(.easeIn(duration: 1.0)) {
                    opacity = 1.0
                    scale = 1.0
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
