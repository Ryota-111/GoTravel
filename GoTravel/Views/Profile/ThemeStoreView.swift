import SwiftUI
import StoreKit

/// 追加テーマの購入画面。
/// 未購入でも全テーマを一覧に出したうえで、選ばれたときにここを開く。
struct ThemeStoreView: View {
    /// どのテーマから開かれたか。見出しに出す
    let highlighted: ThemePreset.ThemeType?

    @ObservedObject private var store = ProStore.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    private var theme: ThemePreset { themeManager.currentTheme }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    swatches
                    benefits
                    purchaseArea
                    footnote
                }
                .padding(20)
            }
            .background(theme.backgroundLight.ignoresSafeArea())
            .navigationTitle("テーマを追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                        .foregroundColor(theme.secondaryText)
                }
            }
        }
        .onChange(of: store.isPurchased) { _, purchased in
            // 購入できたら、開くきっかけになったテーマをそのまま当てる
            if purchased {
                if let highlighted {
                    themeManager.setTheme(highlighted)
                }
                dismiss()
            }
        }
    }

    // MARK: - Header
    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "paintpalette.fill")
                .font(.system(size: 34))
                .foregroundColor(theme.primary)
                .padding(20)
                .background(Circle().fill(theme.primary.opacity(0.12)))

            Text(highlighted.map { "「\($0.displayName)」を使う" } ?? "テーマを増やす")
                .font(theme.displayFont(.title2))
                .foregroundColor(theme.text)
                .multilineTextAlignment(.center)

            Text("一度の購入で、追加テーマがすべて使えます。これから増えるぶんも含まれます。")
                .font(.subheadline)
                .foregroundColor(theme.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
    }

    // MARK: - Swatches
    private var swatches: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("入っているテーマ")
                .font(theme.displayFont(.subheadline))
                .foregroundColor(theme.text)

            ForEach(ThemePreset.ThemeType.premiumCases, id: \.self) { type in
                let preset = ThemePreset(type: type)

                HStack(spacing: 12) {
                    HStack(spacing: -6) {
                        swatchDot(preset.outingPlanColor)
                        swatchDot(preset.dailyPlanColor)
                        swatchDot(preset.travelColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(type.displayName)
                                .font(.subheadline.bold())
                                .foregroundColor(theme.text)

                            if let season = type.season {
                                Text(season.displayName)
                                    .font(.caption2.bold())
                                    .foregroundColor(theme.secondaryText)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule().fill(theme.secondaryText.opacity(0.12))
                                    )
                            }
                        }

                        Text(type.subtitle)
                            .font(.caption)
                            .foregroundColor(theme.tertiaryText)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.vertical, 6)
            }
        }
        .padding(16)
        .themedCard()
    }

    private func swatchDot(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 22, height: 22)
            .overlay(Circle().stroke(theme.backgroundLight, lineWidth: 2))
    }

    // MARK: - Benefits
    private var benefits: some View {
        VStack(alignment: .leading, spacing: 14) {
            benefitRow(
                icon: "infinity",
                title: "これから増えるテーマも込み",
                detail: "追加のたびに買い直す必要はありません。"
            )
            benefitRow(
                icon: "leaf",
                title: "季節のテーマは、その季節だけ無料",
                detail: "桜・瀬戸内・紅葉・雪国は、旬のあいだ購入なしで使えます。購入すると一年中使えます。"
            )
            benefitRow(
                icon: "iphone",
                title: "同じ Apple ID の端末で使えます",
                detail: "買い直しは不要です。機種を変えたら「購入を復元」から戻せます。"
            )
        }
        .padding(16)
        .themedCard()
    }

    private func benefitRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(theme.primary)
                .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(theme.text)
                Text(detail)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Purchase
    @ViewBuilder
    private var purchaseArea: some View {
        VStack(spacing: 12) {
            switch store.loadingState {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 54)

            case .failed(let message):
                VStack(spacing: 10) {
                    Text("価格を読み込めませんでした")
                        .font(.subheadline.bold())
                        .foregroundColor(theme.text)
                    Text(message)
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("もう一度読み込む") {
                        Task { await store.loadProduct() }
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(theme.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(16)

            case .loaded:
                Button {
                    Task { await store.purchase() }
                } label: {
                    HStack(spacing: 8) {
                        if store.purchaseState == .purchasing {
                            ProgressView().tint(.white)
                        } else {
                            Text(store.displayPrice.map { "\($0) で購入" } ?? "購入")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(
                        RoundedRectangle(cornerRadius: theme.radius(.large)).fill(theme.primary)
                    )
                    .foregroundColor(.white)
                }
                .disabled(store.purchaseState == .purchasing || store.purchaseState == .restoring)

                Button {
                    Task { await store.restore() }
                } label: {
                    Text(store.purchaseState == .restoring ? "復元しています…" : "購入を復元")
                        .font(.subheadline)
                        .foregroundColor(theme.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .disabled(store.purchaseState == .purchasing || store.purchaseState == .restoring)
            }

            if case .failed(let message) = store.purchaseState {
                Text(message)
                    .font(.caption)
                    .foregroundColor(theme.error)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var footnote: some View {
        Text("買い切りです。月額や年額の支払いはありません。")
            .font(.caption2)
            .foregroundColor(theme.tertiaryText)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
}
