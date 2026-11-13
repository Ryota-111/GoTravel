import SwiftUI

// MARK: - 見た目の決まり
/// 紹介画面は、テーマを選ぶ前に見る画面なので、Travory の色（青とオレンジ）で固定する。
/// 角丸もテーマに合わせず、ここだけの値にしている
private enum OnboardingStyle {
    static let blueTop = Color(red: 0.04, green: 0.27, blue: 0.72)
    static let blueBottom = Color(red: 0.02, green: 0.42, blue: 0.92)
    static let orange = Color(red: 1.0, green: 0.58, blue: 0.0)
    /// 見本のカードの中の文字（カードは明暗にかかわらず白い紙）
    static let ink = Color(red: 0.10, green: 0.13, blue: 0.20)
    static let subInk = Color(red: 0.45, green: 0.48, blue: 0.55)
    static let paperLine = Color(red: 0.91, green: 0.92, blue: 0.95)
}

// MARK: - Onboarding View
struct OnboardingView: View {
    @State private var currentPage = 0
    /// 一度でも出したページ。出たときに見本が入ってくる動きを始める合図にする。
    /// ページの側の onAppear で持つと、隣のページは先に作られるので取りこぼす
    @State private var shownPages: Set<Int> = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var onComplete: () -> Void

    private let pages = OnboardingPage.all

    /// 機能紹介の後ろにテーマ選択ページを足すため、総ページ数は pages より1多い
    private var totalPages: Int { pages.count + 1 }
    private var isLastPage: Bool { currentPage == totalPages - 1 }

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("スキップ") {
                        withAnimation { currentPage = totalPages - 1 }
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    // 最後のページでも場所は取っておく（消すと下の中身が上へずれる）
                    .opacity(isLastPage ? 0 : 1)
                    .disabled(isLastPage)
                }
                .padding(.top, 8)

                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        OnboardingFeaturePage(page: page, appeared: shownPages.contains(index))
                            .tag(index)
                    }

                    OnboardingThemePage()
                        .tag(pages.count)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                pageIndicator
                    .padding(.vertical, 20)

                Button {
                    if isLastPage {
                        onComplete()
                    } else {
                        withAnimation { currentPage += 1 }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(isLastPage ? "はじめる" : "次へ")
                        Image(systemName: "arrow.right")
                    }
                    .font(.headline)
                    .foregroundStyle(OnboardingStyle.blueTop)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)
                }
                .buttonStyle(ScaleButtonStyle())
                .frame(maxWidth: 520)
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
            }
        }
        .sensoryFeedback(.selection, trigger: currentPage)
        .onAppear { shownPages.insert(currentPage) }
        // 一度出したら戻さない（めくっている途中で中身が消えて見えるため）
        .onChange(of: currentPage) { _, page in shownPages.insert(page) }
    }

    /// 今のページだけ長くする。色ではなく形で分かるようにしている
    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalPages, id: \.self) { index in
                Capsule()
                    .fill(Color.white.opacity(currentPage == index ? 1 : 0.35))
                    .frame(width: currentPage == index ? 22 : 8, height: 8)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: currentPage)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("ページ \(currentPage + 1) / \(totalPages)")
    }

    /// ページごとに色を変えず、同じ青の上でオレンジの光だけが動く
    private var background: some View {
        let glow: [CGSize] = [CGSize(width: -130, height: -280), CGSize(width: 150, height: -150),
                              CGSize(width: -120, height: 200), CGSize(width: 140, height: 300)]
        let position = glow[min(currentPage, glow.count - 1)]

        return ZStack {
            LinearGradient(colors: [OnboardingStyle.blueTop, OnboardingStyle.blueBottom],
                           startPoint: .top, endPoint: .bottom)

            Circle()
                .fill(OnboardingStyle.orange.opacity(0.5))
                .frame(width: 300, height: 300)
                .blur(radius: 90)
                .offset(position)

            Circle()
                .fill(Color.white.opacity(0.14))
                .frame(width: 280, height: 280)
                .blur(radius: 80)
                .offset(x: -position.width, y: -position.height)
        }
        .ignoresSafeArea()
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.7), value: currentPage)
    }
}

// MARK: - 機能紹介の1ページ
/// 上にアプリの画面の見本、下に題と一言。細かい機能は文字で並べず、見本に語らせる
private struct OnboardingFeaturePage: View {
    let page: OnboardingPage
    /// このページが出たか。出たときに見本が入ってくる
    let appeared: Bool

    var body: some View {
        // 収まらないときだけスクロールさせる（Mac の窓・小さい iPhone・大きい文字）
        GeometryReader { proxy in
            // 背の低い画面では、見本を小さくして1画面に収める
            let compact = proxy.size.height < 560

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: compact ? 12 : 28) {
                    Spacer(minLength: 8)

                    OnboardingMock(kind: page.kind, appeared: appeared)
                        .frame(width: 300, height: 300)
                        .scaleEffect(compact ? 0.7 : 1)
                        .frame(height: compact ? 210 : 300)
                        .accessibilityHidden(true)

                    VStack(spacing: 12) {
                        Text(page.title)
                            .font(.system(.title, design: .rounded).bold())
                            .foregroundStyle(.white)

                        Text(page.description)
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.92))
                            .lineSpacing(3)
                    }
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
                    .padding(.horizontal, 32)
                    .onboardingEnter(index: 3, appeared: appeared)

                    Spacer(minLength: 8)
                }
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

// MARK: - 入ってくる動き
/// 見本の部品を、少しずつ遅らせて下から入れる。「視差効果を減らす」のときは濃さだけ変える
private struct OnboardingEnter: ViewModifier {
    let index: Int
    let appeared: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 26)
            .scaleEffect(appeared || reduceMotion ? 1 : 0.94)
            .animation(.spring(response: 0.55, dampingFraction: 0.78).delay(0.08 + Double(index) * 0.09),
                       value: appeared)
    }
}

private extension View {
    func onboardingEnter(index: Int, appeared: Bool) -> some View {
        modifier(OnboardingEnter(index: index, appeared: appeared))
    }

    /// 見本の白いカード
    func onboardingPaper(radius: CGFloat = 20) -> some View {
        background(Color.white, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 10)
    }
}

// MARK: - 画面の見本
/// アプリの画面を小さく描いた見本（300×300 の中に置く）。
/// 本物の画面の部品はデータやテーマを必要とするので、ここでは絵として描いている
private struct OnboardingMock: View {
    let kind: OnboardingPage.Kind
    let appeared: Bool

    var body: some View {
        ZStack {
            switch kind {
            case .plan: plan
            case .memory: memory
            case .share: share
            }
        }
    }

    // MARK: 計画する

    private var plan: some View {
        ZStack {
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("沖縄 3泊4日")
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                        Text("10/6(火) – 10/9(金)")
                            .font(.system(size: 12, weight: .medium))
                            .opacity(0.85)
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "sun.max.fill")
                            .foregroundStyle(.yellow)
                        Text("27°")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.2), in: Capsule())
                }
                .foregroundStyle(.white)
                .padding(16)
                .background(LinearGradient(colors: [Color(red: 0.0, green: 0.55, blue: 0.95),
                                                    Color(red: 0.1, green: 0.75, blue: 0.9)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing))

                VStack(spacing: 0) {
                    scheduleRow("07:00", icon: "airplane", color: OnboardingStyle.blueBottom, title: "羽田 → 那覇")
                    scheduleRow("12:30", icon: "fork.knife", color: OnboardingStyle.orange, title: "首里そばでお昼")
                    scheduleRow("15:00", icon: "bed.double.fill", color: .purple, title: "ホテルにチェックイン")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .frame(width: 264)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .onboardingPaper()
            .rotationEffect(.degrees(-2))
            .offset(y: -22)
            .onboardingEnter(index: 0, appeared: appeared)

            chip(icon: "yensign.circle.fill", text: "¥48,200", filled: true)
                .rotationEffect(.degrees(-4))
                .offset(x: -82, y: 122)
                .onboardingEnter(index: 1, appeared: appeared)

            chip(icon: "checklist", text: "持ち物 8/12", filled: false)
                .rotationEffect(.degrees(3))
                .offset(x: 74, y: 104)
                .onboardingEnter(index: 2, appeared: appeared)
        }
    }

    private func scheduleRow(_ time: String, icon: String, color: Color, title: String) -> some View {
        HStack(spacing: 10) {
            Text(time)
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundStyle(OnboardingStyle.subInk)
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(color, in: Circle())
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(OnboardingStyle.ink)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }

    private func chip(icon: String, text: String, filled: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.system(size: 14, weight: .bold, design: .rounded))
        .foregroundStyle(filled ? Color.white : OnboardingStyle.ink)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(filled ? OnboardingStyle.orange : Color.white, in: Capsule())
        .shadow(color: .black.opacity(0.22), radius: 10, x: 0, y: 6)
    }

    // MARK: 残す

    private var memory: some View {
        ZStack {
            photo(icon: "water.waves", colors: [Color(red: 0.2, green: 0.8, blue: 0.9), Color(red: 0.05, green: 0.45, blue: 0.85)])
                .rotationEffect(.degrees(-9))
                .offset(x: -82, y: -66)
                .onboardingEnter(index: 0, appeared: appeared)

            photo(icon: "mountain.2.fill", colors: [Color(red: 0.45, green: 0.8, blue: 0.55), Color(red: 0.1, green: 0.5, blue: 0.45)])
                .rotationEffect(.degrees(8))
                .offset(x: 80, y: -74)
                .onboardingEnter(index: 1, appeared: appeared)

            photo(icon: "leaf.fill", colors: [Color(red: 1.0, green: 0.7, blue: 0.25), Color(red: 0.9, green: 0.3, blue: 0.2)])
                .rotationEffect(.degrees(-2))
                .offset(y: -40)
                .onboardingEnter(index: 1, appeared: appeared)

            HStack(spacing: 12) {
                Image(systemName: "mappin")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(OnboardingStyle.orange, in: Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text("伏見稲荷大社")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(OnboardingStyle.ink)
                    HStack(spacing: 6) {
                        Text("京都 ・ 11/23")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(OnboardingStyle.subInk)
                        tag("神社")
                        tag("紅葉")
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(width: 264)
            .onboardingPaper(radius: 18)
            .rotationEffect(.degrees(2))
            .offset(y: 98)
            .onboardingEnter(index: 2, appeared: appeared)
        }
    }

    private func photo(icon: String, colors: [Color]) -> some View {
        VStack(spacing: 8) {
            LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
                .frame(width: 104, height: 104)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(.white.opacity(0.92))
                )
                .clipShape(RoundedRectangle(cornerRadius: 4))
            Capsule()
                .fill(OnboardingStyle.paperLine)
                .frame(width: 56, height: 6)
        }
        .padding(.horizontal, 9)
        .padding(.top, 9)
        .padding(.bottom, 12)
        .onboardingPaper(radius: 8)
    }

    private func tag(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(OnboardingStyle.blueTop)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(OnboardingStyle.blueBottom.opacity(0.12), in: Capsule())
    }

    // MARK: 一緒に

    private var share: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("沖縄 3泊4日")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(OnboardingStyle.ink)
                    Spacer()
                    HStack(spacing: -9) {
                        avatar("り", OnboardingStyle.blueBottom)
                        avatar("さ", OnboardingStyle.orange)
                        avatar("け", Color(red: 0.2, green: 0.7, blue: 0.5))
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("共有コード")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(OnboardingStyle.subInk)
                    HStack {
                        Text("TRAVEL-K7M2QX4A")
                            .font(.system(size: 17, weight: .bold, design: .monospaced))
                            .foregroundStyle(OnboardingStyle.ink)
                        Spacer(minLength: 0)
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(OnboardingStyle.blueBottom)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
                    .background(OnboardingStyle.paperLine.opacity(0.7), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                HStack(spacing: 10) {
                    Image(systemName: "link")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(OnboardingStyle.blueBottom, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ウェブで見せる")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(OnboardingStyle.ink)
                        Text("アプリがなくても開けます")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(OnboardingStyle.subInk)
                    }
                }
            }
            .padding(18)
            .frame(width: 264)
            .onboardingPaper()
            .rotationEffect(.degrees(-2))
            .offset(y: 18)
            .onboardingEnter(index: 0, appeared: appeared)

            HStack(spacing: 8) {
                avatar("さ", OnboardingStyle.orange)
                Text("「首里そば」を追加")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(OnboardingStyle.ink)
            }
            .padding(.leading, 6)
            .padding(.trailing, 14)
            .padding(.vertical, 6)
            .background(Color.white, in: Capsule())
            .shadow(color: .black.opacity(0.22), radius: 10, x: 0, y: 6)
            .rotationEffect(.degrees(3))
            .offset(x: 52, y: -122)
            .onboardingEnter(index: 2, appeared: appeared)
        }
    }

    private func avatar(_ initial: String, _ color: Color) -> some View {
        Text(initial)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(color, in: Circle())
            .overlay(Circle().stroke(Color.white, lineWidth: 2))
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
        .background(RoundedRectangle(cornerRadius: AppRadius.medium).fill(preset.backgroundLight))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium)
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
                RoundedRectangle(cornerRadius: AppRadius.large)
                    .fill(Color.white.opacity(isSelected ? 0.28 : 0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.large)
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
        // 画面に収まるときは今までどおり上下の真ん中に置き、収まらないときだけスクロールさせる。
        // 以前は固定の VStack で、Mac の窓や小さい iPhone・大きい文字の設定では
        // テーマの一覧の下が切れたまま動かせなかった（季節のテーマが足されると1つ増える）
        GeometryReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                content
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15)) {
                animateContent = true
            }
        }
    }

    private var content: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 16)

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

            // 今その人が使えるテーマだけを出す。
            //
            // allCases を並べると、未購入でも追加テーマを選べてしまう。
            // 季節テーマはその季節のあいだ無料なので、canUse なら含まれる
            VStack(spacing: 12) {
                ForEach(ThemePreset.ThemeType.allCases.filter { themeManager.canUse($0) }, id: \.self) { type in
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

            Spacer(minLength: 16)
        }
    }
}

// MARK: - Onboarding Page Model
struct OnboardingPage {
    /// どの見本を描くか
    enum Kind {
        case plan, memory, share
    }

    let kind: Kind
    let title: String
    let description: String

    /// 1ページに言うことは1つ。計画する → 残す → 一緒に
    static let all: [OnboardingPage] = [
        OnboardingPage(kind: .plan,
                       title: "旅の計画を、ひとつに",
                       description: "行程・持ち物・費用を1か所にまとめて、\n当日もそのまま使えます"),
        OnboardingPage(kind: .memory,
                       title: "行った場所を、残す",
                       description: "場所と写真を保存して、\n旅のあとはアルバムで振り返れます"),
        OnboardingPage(kind: .share,
                       title: "みんなで、いっしょに",
                       description: "共有コードで招待して、同じ計画を編集。\nアプリがない人にはウェブで見せられます")
    ]
}
