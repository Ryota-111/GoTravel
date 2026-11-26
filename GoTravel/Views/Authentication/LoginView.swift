import SwiftUI
import AuthenticationServices

// MARK: - 見た目の決まり
/// ダウンロードして最初に見る画面なので、紹介画面と同じ Travory の色（青とオレンジ）で固定する。
/// テーマはまだ選んでいない人もいるため、テーマの色には合わせない
private enum LoginStyle {
    static let blueTop = Color(red: 0.04, green: 0.27, blue: 0.72)
    static let blueBottom = Color(red: 0.02, green: 0.42, blue: 0.92)
    static let orange = Color(red: 1.0, green: 0.72, blue: 0.35)
    /// iPad でも横に広がりすぎないように
    static let maxContentWidth: CGFloat = 440
    static let maxContentWidthWide: CGFloat = 560
}

struct LoginView: View {

    // MARK: - Properties
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var appeared = false
    @State private var failed = false

    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                background
                content
            }
            .navigationBarHidden(true)
        }
        // iPad では `NavigationView` が既定で2列に割れる。
        // 左のサイドバー幅に画面が押し込まれ、右半分が白いまま残ってしまうため、
        // 1列に固定する
        .navigationViewStyle(.stack)
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.1)) { appeared = true }
            }
        }
    }

    // MARK: - View Components
    private var background: some View {
        LinearGradient(colors: [LoginStyle.blueTop, LoginStyle.blueBottom], startPoint: .top, endPoint: .bottom)
            .overlay(alignment: .bottom) {
                // 下のほうだけ夕日の色をうっすら差す
                RadialGradient(colors: [LoginStyle.orange.opacity(0.28), .clear],
                               center: .bottom, startRadius: 0, endRadius: 420)
            }
            .ignoresSafeArea()
    }

    /// iPad は広いので、全体を大きくして縦の真ん中に置く
    private var isWide: Bool { sizeClass == .regular }

    private var content: some View {
        VStack(spacing: 0) {
            if isWide { Spacer(minLength: 24) }

            brand
                .padding(.top, isWide ? 0 : 28)

            ShowcaseMemoriesVisual()
                .frame(maxWidth: .infinity, minHeight: 140, maxHeight: isWide ? 480 : 330)
                .padding(.vertical, isWide ? 32 : 20)
                .scaleEffect(appeared ? 1 : 0.9)
                .opacity(appeared ? 1 : 0)
                .accessibilityHidden(true)

            message

            if isWide {
                Spacer().frame(height: 48)
            } else {
                Spacer(minLength: 24)
            }

            signIn
                .frame(maxWidth: isWide ? 400 : .infinity)
                .padding(.bottom, 16)

            if isWide { Spacer(minLength: 24) }
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: isWide ? LoginStyle.maxContentWidthWide : LoginStyle.maxContentWidth)
        .frame(maxWidth: .infinity)
    }

    private var brand: some View {
        VStack(spacing: 6) {
            Image("IconPreview-Default")
                .resizable()
                .scaledToFit()
                .frame(width: isWide ? 84 : 64, height: isWide ? 84 : 64)
                .clipShape(RoundedRectangle(cornerRadius: isWide ? 19 : 15, style: .continuous))
                .shadow(color: .black.opacity(0.25), radius: 10, y: 5)
                .padding(.bottom, 6)
                .accessibilityHidden(true)

            Text("Travory")
                .font(.custom("PlayfairDisplay-Regular", size: isWide ? 54 : 42))
                .foregroundStyle(.white)

            Text("plan, travel & remember")
                .font(.custom("Caveat-Regular", size: isWide ? 28 : 22))
                .foregroundStyle(LoginStyle.orange)
        }
        .accessibilityElement(children: .combine)
    }

    private var message: some View {
        VStack(spacing: 10) {
            Text("旅の計画から、思い出まで。")
                .font(isWide ? .title.weight(.bold) : .title2.weight(.bold))
                .foregroundStyle(.white)

            Text("予定・持ち物・費用をひとつにまとめて。\n旅のあとは、写真がコラージュや動画になります。")
                .font(isWide ? .body : .subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .lineSpacing(3)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var signIn: some View {
        VStack(spacing: 14) {
            AppleAuthView(buttonStyle: .white) { failed = true }
                .environmentObject(auth)

            if failed {
                Text("サインインできませんでした。もう一度お試しください。")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white)
            }

            Label {
                Text("データはあなたの iCloud に保存され、\nほかの端末とも同期します")
            } icon: {
                Image(systemName: "lock.icloud")
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.75))
            .multilineTextAlignment(.leading)
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(AuthViewModel())
    }
}
