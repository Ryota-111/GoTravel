import SwiftUI
import StoreKit

struct TipJarView: View {
    @StateObject private var store = TipStore.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme
    @State private var showThankYou = false

    private var accentColor: Color {
        colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1
    }

    private var cardBg: Color {
        colorScheme == .dark
            ? themeManager.currentTheme.secondaryBackgroundDark
            : themeManager.currentTheme.backgroundLight
    }

    var body: some View {
        ZStack {
            backgroundGradient

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    headerSection
                        .padding(.top, 20)

                    messageCard

                    if store.products.isEmpty {
                        loadingSection
                    } else {
                        tipProductsSection
                    }

                    footerNote
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("開発者を応援する")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: store.purchaseState) { _, state in
            if state == .success {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    showThankYou = true
                }
            }
        }
        .overlay {
            if showThankYou {
                thankYouOverlay
            }
        }
        .alert("購入エラー", isPresented: Binding(
            get: {
                if case .failed = store.purchaseState { return true }
                return false
            },
            set: { if !$0 { store.resetState() } }
        )) {
            Button("OK") { store.resetState() }
        } message: {
            if case .failed(let msg) = store.purchaseState {
                Text(msg)
            }
        }
    }

    // MARK: - Background
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: colorScheme == .dark
                ? [themeManager.currentTheme.backgroundDark, themeManager.currentTheme.secondaryBackgroundDark]
                : [themeManager.currentTheme.backgroundLight, themeManager.currentTheme.secondaryBackgroundLight]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.pink, Color.red.opacity(0.7)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: Color.pink.opacity(0.5), radius: 16, x: 0, y: 6)

                Image(systemName: "heart.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.white)
            }

            VStack(spacing: 6) {
                Text("開発者を応援する")
                    .font(.title2.weight(.bold))
                    .foregroundColor(accentColor)

                Text("GoTravelを気に入っていただけたら")
                    .font(.subheadline)
                    .foregroundColor(themeManager.currentTheme.secondaryText)
            }
        }
    }

    // MARK: - Message Card
    private var messageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "message.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Color.pink)
                Text("開発者からのメッセージ")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(accentColor)
            }

            Text("GoTravelを使っていただきありがとうございます。このアプリは一人で開発・維持しています。投げ銭は開発の継続やアップデートの励みになります。金額はいくらでもかまいません。あなたのサポートがとても嬉しいです！")
                .font(.subheadline)
                .foregroundColor(themeManager.currentTheme.secondaryText)
                .lineSpacing(4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBg)
                .shadow(color: Color.pink.opacity(0.1), radius: 6, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.pink.opacity(0.2), lineWidth: 1.5)
        )
    }

    // MARK: - Loading
    private var loadingSection: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
            Text("読み込み中...")
                .font(.caption)
                .foregroundColor(themeManager.currentTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Tip Products
    private var tipProductsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "gift.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Color.pink)
                Text("金額を選択")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(accentColor)
                Spacer()
            }

            ForEach(store.products) { product in
                TipProductRow(
                    product: product,
                    isPurchasing: store.purchaseState == .purchasing
                ) {
                    Task { await store.purchase(product) }
                }
            }
        }
    }

    // MARK: - Footer
    private var footerNote: some View {
        VStack(spacing: 6) {
            Text("購入はApp Storeを通じて安全に行われます")
                .font(.caption2)
                .foregroundColor(themeManager.currentTheme.secondaryText.opacity(0.6))
                .multilineTextAlignment(.center)
            Text("投げ銭は消耗型購入です。何度でも応援できます")
                .font(.caption2)
                .foregroundColor(themeManager.currentTheme.secondaryText.opacity(0.6))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Thank You Overlay
    private var thankYouOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.pink, Color.red.opacity(0.7)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 90, height: 90)
                    Image(systemName: "heart.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                }
                .scaleEffect(showThankYou ? 1 : 0.5)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showThankYou)

                VStack(spacing: 8) {
                    Text("ありがとうございます！")
                        .font(.title2.weight(.bold))
                        .foregroundColor(.white)
                    Text("あなたの応援がとても励みになります")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                }

                Button(action: {
                    withAnimation { showThankYou = false }
                    store.resetState()
                }) {
                    Text("閉じる")
                        .font(.headline.weight(.bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 36)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.2))
                                .overlay(Capsule().stroke(Color.white.opacity(0.4), lineWidth: 1))
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(.ultraThinMaterial)
            )
            .padding(.horizontal, 40)
        }
        .transition(.opacity)
    }
}

// MARK: - Tip Product Row
struct TipProductRow: View {
    let product: Product
    let isPurchasing: Bool
    let onPurchase: () -> Void

    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme

    private var cardBg: Color {
        colorScheme == .dark
            ? themeManager.currentTheme.secondaryBackgroundDark
            : themeManager.currentTheme.backgroundLight
    }

    private var accentColor: Color {
        colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1
    }

    private var emoji: String {
        switch product.id {
        case _ where product.id.hasSuffix(".small"):   return "☕️"
        case _ where product.id.hasSuffix(".medium"):  return "🧃"
        case _ where product.id.hasSuffix(".large"):   return "🍱"
        case _ where product.id.hasSuffix(".xlarge"):  return "🎁"
        default: return "💝"
        }
    }

    private var label: String {
        switch product.id {
        case _ where product.id.hasSuffix(".small"):   return "コーヒー1杯"
        case _ where product.id.hasSuffix(".medium"):  return "ジュース1本"
        case _ where product.id.hasSuffix(".large"):   return "ランチ半分"
        case _ where product.id.hasSuffix(".xlarge"):  return "ランチ1食"
        default: return product.displayName
        }
    }

    var body: some View {
        Button(action: onPurchase) {
            HStack(spacing: 14) {
                Text(emoji)
                    .font(.system(size: 32))
                    .frame(width: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text(label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(accentColor)
                    Text(product.displayName.isEmpty ? "応援する" : product.displayName)
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                }

                Spacer()

                if isPurchasing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .frame(width: 60)
                } else {
                    Text(product.displayPrice)
                        .font(.headline.weight(.bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.pink, Color.red.opacity(0.8)]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .shadow(color: Color.pink.opacity(0.4), radius: 6, x: 0, y: 3)
                        )
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(cardBg)
                    .shadow(color: Color.pink.opacity(0.08), radius: 4, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.pink.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isPurchasing)
    }
}
