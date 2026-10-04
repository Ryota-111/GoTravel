import SwiftUI
import StoreKit

/// Travory Pro の紹介ページ。
///
/// これまで買い切りへの入口は「アプリ設定 → テーマ」の中だけで、
/// テーマを選びに行った人しか存在に気づけなかった。
/// **何が入っているのかを一枚で説明する場所**として独立させ、
/// プロフィールから直接開けるようにしている。
///
/// 購入の処理そのものは `ProStore` が持つ。ここは説明と入口だけ。
struct ProView: View {

    /// テーマ一覧から「このテーマを使いたい」で開かれたときに、そのテーマ名を見出しに出す。
    /// プロフィールから開いたときは nil
    var highlighted: ThemePreset.ThemeType? = nil
    /// 買えたらすぐ閉じるか。使いたい機能から開かれたとき（予約メールの取り込みなど）は、
    /// 買ったその場で元の画面に戻して使ってもらう
    var dismissesOnPurchase = false

    @ObservedObject private var store = ProStore.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    private var theme: ThemePreset { themeManager.currentTheme }

    /// この画面の差し色。
    ///
    /// **`primary` を直接使わないこと。** 白黒テーマは `primary` が白で、
    /// 背景も白なので、アイコンも購入ボタンも見えなくなる。
    /// `actionFill` は白黒のときだけ黒を返す
    private var accent: Color { theme.actionFill }

    /// 差し色で塗った面の上に置く文字の色。
    /// 白地に白文字（白黒テーマ）を出さないために、明るさから決める
    private var onAccent: Color { ThemePreset.readableText(on: accent) }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header

                if store.isPurchased {
                    purchasedNotice
                }

                // 予約メールの取り込みを先頭に置く（Pro の目玉）
                featureReservationEmail
                featureThemes
                featurePhotoSync
                onceOnlyCard

                if !store.isPurchased {
                    purchaseArea
                }

                footnote
            }
            .padding(20)
        }
        .background(theme.backgroundLight.ignoresSafeArea())
        .navigationTitle("Travory Pro")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: store.isPurchased) { _, purchased in
            guard purchased else { return }
            // テーマから開かれていたら、買えたその場で当てる
            if let highlighted {
                themeManager.setTheme(highlighted)
                dismiss()
            } else if dismissesOnPurchase {
                dismiss()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 34))
                .foregroundColor(accent)
                .padding(20)
                .background(Circle().fill(accent.opacity(0.12)))

            Text(highlighted.map { "「\($0.displayName)」を使う" } ?? "Travory Pro")
                .font(theme.displayFont(.title2))
                .foregroundColor(theme.text)
                .multilineTextAlignment(.center)

            Text(highlighted == nil
                 ? "予約確認メールを貼り付けるだけで、予約が入ります。追加テーマ14種と写真のiCloud保管も、一度のお支払いで使えるようになります。月額や年額はありません。"
                 : "一度のお支払いで、予約確認メールの取り込み・追加テーマ14種・写真のiCloud保管が使えるようになります。月額や年額はありません。")
                .font(.subheadline)
                .foregroundColor(theme.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
    }

    private var purchasedNotice: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundColor(theme.success)
            Text("ご購入ありがとうございます。すべての機能をお使いいただけます。")
                .font(.subheadline)
                .foregroundColor(theme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .themedCard()
    }

    // MARK: - 入っているもの②：テーマ

    private var featureThemes: some View {
        VStack(alignment: .leading, spacing: 12) {
            featureHeading(
                icon: "paintpalette.fill",
                title: "テーマが14種類増えます",
                detail: "色だけではありません。書体・角の丸み・縁・影・カードの形まで変わるので、"
                      + "同じアプリでも別物のように見えます。"
            )

            // 色の点だけでは、どんな画面になるのかが伝わらない。
            // 買う前にいちばん知りたいのはそこなので、実際の見え方を並べる
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(ThemePreset.ThemeType.premiumCases, id: \.self) { type in
                        let preset = ThemePreset(type: type)

                        VStack(alignment: .leading, spacing: 7) {
                            ThemePreviewCard(preset: preset, width: 132)

                            HStack(spacing: 5) {
                                Text(type.displayName)
                                    .font(.caption.bold())
                                    .foregroundColor(theme.text)
                                    .lineLimit(1)

                                if let season = type.season {
                                    Text(season.displayName)
                                        .font(.caption2.bold())
                                        .foregroundColor(theme.secondaryText)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(
                                            Capsule().fill(theme.secondaryText.opacity(0.12))
                                        )
                                }
                            }

                            Text(type.subtitle)
                                .font(.caption2)
                                .foregroundColor(theme.tertiaryText)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(width: 132, alignment: .leading)
                    }
                }
                .padding(.horizontal, 16)
            }
            // カードの内側の余白を打ち消して、見本を端まで流す
            .padding(.horizontal, -16)

            bullet("季節のテーマ（桜・瀬戸内・紅葉・雪国）は、旬のあいだ購入なしでもお試しいただけます。ご購入いただくと一年中お使いいただけます。")
            bullet("これから増えるテーマも、追加のお支払いなしで使えます。")
        }
        .padding(16)
        .themedCard()
    }

    // MARK: - 入っているもの③：写真の保管

    private var featurePhotoSync: some View {
        VStack(alignment: .leading, spacing: 12) {
            featureHeading(
                icon: "icloud.and.arrow.up.fill",
                title: "写真をiCloudでお預かりします",
                detail: "旅行計画のカバー写真、保存した場所の写真、アルバムの写真を、"
                      + "お客様ご自身のiCloudにも保管します。"
            )

            bullet("**機種変更やアプリの入れ直しでも写真が残ります。** これまで写真は端末の中だけにあり、端末を変えると記録は残っても写真が消えていました。")
            bullet("同じApple Accountの端末どうしで、同じ写真が見られます。")
            bullet("預け先はお客様のiCloudです。開発者が見ることはできません。")
            bullet("ご購入いただいた時点で、それまでに保存した写真もまとめてお預かりします。")
        }
        .padding(16)
        .themedCard()
    }

    // MARK: - 入っているもの①：予約メールの取り込み（目玉）

    private var featureReservationEmail: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("おすすめ")
                .font(.caption2.bold())
                .foregroundColor(onAccent)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(accent))

            featureHeading(
                icon: "envelope.open.fill",
                title: "予約確認メールを貼るだけで、予約が入ります",
                detail: "飛行機・新幹線・宿・レストラン・チケットの予約確認メールや、予約の確認画面のスクリーンショットから、"
                      + "予約番号・日時・便名・金額を読み取って入力欄に入れます。打ち直す手間がなくなります。"
            )

            // 何が起きるのかは、文章より見本のほうが早く伝わる
            reservationEmailDemo

            bullet("往復の航空券のように、1通に複数の予約があっても順に登録できます。")
            bullet("海外の空港や宿は、現地の時間で入ります。")
            bullet("予約サイトのアプリで確認していてメールが無い予約も、画面のスクリーンショットから取り込めます。")
            bullet("メールアプリや写真アプリの共有メニューから「Travory」を選ぶだけでも送れます。")
            bullet("保存する前に内容を確かめられます。メールや画像はこの端末の中だけで読み取り、どこにも送りません。")
            bullet("予約を手で入力する機能は、これまでどおり無料です。")
        }
        .padding(16)
        .themedCard()
    }

    /// 確認メール → 予約 の見本。実際の予約カードに近い見た目にする
    private var reservationEmailDemo: some View {
        VStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Label("確認メール", systemImage: "envelope")
                    .font(.caption2.bold())
                    .foregroundColor(theme.secondaryText)
                Text("2026年10月6日　SKY 111便\n神戸 07:30 → 那覇 09:35\n予約番号：K7Q2PX\nお支払金額：12,800円")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(theme.secondaryText.opacity(0.08)))

            Image(systemName: "arrow.down")
                .font(.caption.bold())
                .foregroundColor(accent)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "airplane")
                        .font(.system(size: 13))
                        .foregroundColor(accent)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(accent.opacity(0.14)))
                    Text("SKY111")
                        .font(.subheadline.bold())
                        .foregroundColor(theme.text)
                    Spacer()
                    Text("¥12,800")
                        .font(.caption.bold())
                        .foregroundColor(theme.secondaryText)
                }
                HStack {
                    demoEndpoint("神戸空港", "07:30")
                    Spacer()
                    Image(systemName: "airplane")
                        .font(.caption)
                        .foregroundColor(accent)
                    Spacer()
                    demoEndpoint("那覇空港", "09:35")
                }
                Text("予約番号  K7Q2PX")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(theme.text)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(accent.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(accent.opacity(0.35), lineWidth: 1))
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("見本：確認メールの便名・時刻・予約番号・金額が、そのまま予約に入ります")
    }

    private func demoEndpoint(_ place: String, _ time: String) -> some View {
        VStack(spacing: 1) {
            Text(place)
                .font(.caption.bold())
                .foregroundColor(theme.text)
            Text(time)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(theme.text)
        }
    }

    // MARK: - 買い方の説明

    private var onceOnlyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            benefitRow(
                icon: "checkmark.circle",
                title: "買い切りです",
                detail: "月額・年額の支払いはありません。一度だけです。"
            )
            benefitRow(
                icon: "iphone",
                title: "同じApple Accountの端末で使えます",
                detail: "買い直しは不要です。機種を変えたら「購入を復元」から戻せます。"
            )
            benefitRow(
                icon: "lock.open",
                title: "買わなくても、記録と計画の機能はすべて使えます",
                detail: "旅行計画・予定・場所の保存・アルバム・共有・やることリストは無料のままです。標準のテーマも3種類そのままお使いいただけます。"
            )
        }
        .padding(16)
        .themedCard()
    }

    // MARK: - 部品

    private func featureHeading(icon: String, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(accent)
                Text(title)
                    .font(theme.displayFont(.headline))
                    .foregroundColor(theme.text)
            }

            Text(detail)
                .font(.subheadline)
                .foregroundColor(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// 行頭に点を置いた説明文。**強調** はそのまま太字になる
    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(accent.opacity(0.45))
                .frame(width: 5, height: 5)
                .padding(.top, 6)

            Text(.init(text))
                .font(.caption)
                .foregroundColor(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func benefitRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(accent)
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
                    .foregroundColor(accent)
                }
                .frame(maxWidth: .infinity)
                .padding(16)

            case .loaded:
                Button {
                    Task { await store.purchase() }
                } label: {
                    HStack(spacing: 8) {
                        if store.purchaseState == .purchasing {
                            ProgressView().tint(onAccent)
                        } else {
                            Text(store.displayPrice.map { "\($0) で購入" } ?? "購入")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(
                        RoundedRectangle(cornerRadius: theme.radius(.large)).fill(accent)
                    )
                    .foregroundColor(onAccent)
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
        Text("お支払いはAppleが取り扱います。開発者がクレジットカード番号などを受け取ることはありません。")
            .font(.caption2)
            .foregroundColor(theme.tertiaryText)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - シートで開くとき

/// テーマ一覧から開かれる購入画面。
/// 中身は `ProView` そのままで、閉じるボタンだけ足す
struct ProSheet: View {
    let highlighted: ThemePreset.ThemeType?
    var dismissesOnPurchase = false

    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ProView(highlighted: highlighted, dismissesOnPurchase: dismissesOnPurchase)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") { dismiss() }
                            .foregroundColor(themeManager.currentTheme.secondaryText)
                    }
                }
        }
    }
}
