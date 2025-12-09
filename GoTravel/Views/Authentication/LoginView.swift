import SwiftUI

struct LoginView: View {

    // MARK: - Properties
    @EnvironmentObject var auth: AuthViewModel

    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                backgroundView
                contentView
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: - View Components
    private var backgroundView: some View {
        LinearGradient(
            gradient: Gradient(colors: [ThemeManager.shared.currentTheme.primary.opacity(0.8), ThemeManager.shared.currentTheme.secondary.opacity(0.6)]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var contentView: some View {
        VStack(spacing: 0) {
            Spacer()

            headerSection

            Spacer()
                .frame(height: 100)

            loginSection

            Spacer()
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "paperplane.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.white)

            Text("旅も日常も")
                .font(.system(size: 32, weight: .semibold))
                .foregroundColor(.white)

            Text("ひとつのアプリで")
                .font(.system(size: 32, weight: .semibold))
                .foregroundColor(.white)

            Text("Apple IDでサインイン")
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(.white.opacity(0.9))
                .padding(.top, 20)
        }
        .padding(.horizontal)
    }

    private var loginSection: some View {
        VStack(spacing: 16) {
            AppleAuthView()
                .environmentObject(auth)
        }
        .padding(.horizontal, 40)
    }
}

fileprivate struct BlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(AuthViewModel())
    }
}
