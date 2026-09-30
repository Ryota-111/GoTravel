import SwiftUI

// MARK: - Travel Plan Card
struct TravelPlanCard: View {
    @EnvironmentObject var viewModel: TravelPlanViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject var themeManager = ThemeManager.shared
    let plan: TravelPlan
    let onDelete: () -> Void

    @State private var showDuplicateSheet = false

    private var theme: ThemePreset { themeManager.currentTheme }

    var body: some View {
        NavigationLink(destination: TravelPlanDetailView(plan: plan).environmentObject(viewModel)) {
            // 見た目の切り替えはテーマ名ではなく decor トークンで決める。
            // 意匠を持つテーマが増えても、増えるのはここの case だけ
            switch theme.style.decor {
            case .ticket: ticketBody
            case .plain:  plainBody
            }
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showDuplicateSheet) {
            DuplicateTravelPlanView(plan: plan)
                .environmentObject(viewModel)
                .environmentObject(authVM)
        }
    }

    private var plainBody: some View {
        ZStack {
            cardBackground
            cardOverlay
            cardContent
        }
        .frame(width: 200, height: 200)
        .overlay(
            // ガラス風のハイライト縁取り
            RoundedRectangle(cornerRadius: theme.style.cardRadius)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.45), Color.white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        // 影は付けない。カードは横スクロールの帯とほぼ同じ高さで、
        // 帯からはみ出した影が上下で切り取られ、black な帯として見えてしまう。
        // 帯を高くすれば収まるが、今の高さを変えたくないので影ごと外した。
        // 写真と白い縁取りがあるので、影が無くても浮いて見える
    }

    // MARK: - 切符

    /// 216×226。上 170 が写真、その下が半券。
    /// 切り取り線は y=170、両端に 16px の半円を重ねる
    private var ticketBody: some View {
        let radius = theme.radius(.large)
        let rule = theme.cardBorder
        let border = theme.style.borderWidth

        return VStack(spacing: 0) {
            ticketArt
            ticketStub
        }
        .frame(width: 216, height: 226)
        .background(theme.cardBackground2)
        .clipShape(RoundedRectangle(cornerRadius: radius))
        .overlay(
            RoundedRectangle(cornerRadius: radius)
                .strokeBorder(rule, lineWidth: 1)
        )
        .overlay(
            TicketNotches(y: 170, diameter: 16,
                          fill: theme.backgroundLight,
                          border: rule, borderWidth: border > 0 ? 1 : 0)
        )
    }

    private var ticketArt: some View {
        ZStack(alignment: .bottomLeading) {
            ticketArtBackground

            // 下だけ沈める。写真を残しつつ文字を読ませる
            LinearGradient(
                stops: [
                    .init(color: theme.text.opacity(0), location: 0.38),
                    .init(color: theme.text.opacity(0.72), location: 1.0)
                ],
                startPoint: .top, endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 8, weight: .bold))
                    Text(plan.destination.uppercased())
                        .font(theme.style.monoFont(size: 9))
                        .tracking(1.44)      // 0.16em
                        .lineLimit(1)
                }
                .foregroundColor(theme.cardBackground2.opacity(0.9))

                Text(plan.title)
                    .font(theme.style.bodyFont(size: 16, weight: .bold))
                    .lineSpacing(2)
                    .lineLimit(2)
                    .foregroundColor(theme.cardBackground2)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)

            VStack {
                HStack(alignment: .top) {
                    menuButton
                    Spacer()
                    ticketStamp
                }
                Spacer()
            }
            .padding(.top, 6)
            .padding(.horizontal, 6)
        }
        .frame(width: 216, height: 170)
        .clipped()
    }

    // 写真には必ず実寸の frame を付ける。
    //
    // scaledToFill は元画像の縦横比のまま広がるので、frame が無いと
    // ZStack 自体が写真の実寸まで押し広げられる。すると上のスタンプと
    // 下のタイトル・日程が 216×170 の外に押し出され、`clipped()` で切れていた。
    // 写真の無いカードでは起きないので気づきにくい
    @ViewBuilder
    private var ticketArtBackground: some View {
        if let planId = plan.id, let image = viewModel.planImages[planId] {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 216, height: 170)
                .clipped()
        } else if let name = plan.localImageFileName,
                  let image = FileManager.documentsImage(named: name) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 216, height: 170)
                .clipped()
        } else {
            LinearGradient(
                colors: [
                    plan.cardColor?.opacity(0.8) ?? theme.primary.opacity(0.8),
                    plan.cardColor?.opacity(0.4) ?? theme.primary.opacity(0.4)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }

    /// 状態はバッジではなくスタンプで出す。少し傾けるだけで押印に見える
    private var ticketStamp: some View {
        Text(stampText)
            .font(theme.style.monoFont(size: 10))
            .tracking(1.6)
            .foregroundColor(theme.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: theme.radius(.small))
                    .fill(theme.cardBackground2.opacity(0.82))
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.radius(.small))
                    .strokeBorder(theme.primary, lineWidth: 2)
            )
            .rotationEffect(.degrees(-9))
            .padding(.trailing, 4)
            .padding(.top, 6)
    }

    private var stampText: String {
        switch status {
        case .ongoing: return "進行中"
        case .upcoming(let days): return days == 1 ? "明日" : "あと\(days)日"
        case .past: return "終了"
        }
    }

    /// 切り取り線から下。日付と泊数を等幅で並べる
    private var ticketStub: some View {
        HStack(spacing: 8) {
            Text(ticketDateRange)
                .font(theme.style.monoFont(size: 13))
                .tracking(0.26)
                .foregroundColor(theme.text)

            Spacer(minLength: 0)

            if plan.isShared {
                HStack(spacing: 3) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 8, weight: .bold))
                    Text("\(plan.sharedWith.count)")
                        .font(theme.style.monoFont(size: 10))
                }
                .foregroundColor(theme.secondaryText)
            }

            Text(nightsText)
                .font(theme.style.monoFont(size: 10, weight: .regular))
                .tracking(0.8)
                .foregroundColor(theme.secondaryText)
        }
        .padding(.horizontal, 9)
        .frame(maxHeight: .infinity)
        .overlay(alignment: .top) {
            DashedRule()
                .stroke(theme.cardBorder,
                        style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                .frame(height: 1.5)
                .padding(.horizontal, 9)
        }
    }

    private var ticketDateRange: String {
        let f = DateFormatter.japanese
        f.dateFormat = "M/d"
        return "\(f.string(from: plan.startDate)) — \(f.string(from: plan.endDate))"
    }

    private var nightsText: String {
        let days = Calendar.current.dayDifference(from: plan.startDate, to: plan.endDate)
        return days <= 0 ? "日帰り" : "\(days)泊\(days + 1)日"
    }

    // MARK: - Status
    private enum PlanStatus {
        case ongoing
        case upcoming(daysUntil: Int)
        case past
    }

    private var status: PlanStatus {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.startOfDay(for: plan.startDate)
        let end = calendar.startOfDay(for: plan.endDate)

        if today >= start && today <= end {
            return .ongoing
        } else if start > today {
            let days = calendar.dayDifference(from: today, to: start)
            return .upcoming(daysUntil: days)
        } else {
            return .past
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch status {
        case .ongoing:
            statusChip(text: "旅行中", dotColor: themeManager.currentTheme.success)
        case .upcoming(let days):
            statusChip(text: days == 1 ? "明日から" : "あと\(days)日", dotColor: themeManager.currentTheme.warning)
        case .past:
            statusChip(text: "終了", dotColor: Color.gray)
        }
    }

    private func statusChip(text: String, dotColor: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.caption2.weight(.bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private var cardBackground: some View {
        ZStack {
            // CloudKitから取得した画像を優先的に表示
            if let planId = plan.id,
               let image = viewModel.planImages[planId] {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 200, height: 200)
                    .clipped()
                    .cornerRadius(theme.style.cardRadius)
            } else if let localImageFileName = plan.localImageFileName,
                      let image = FileManager.documentsImage(named: localImageFileName) {
                // フォールバック：ローカルストレージから画像を取得
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 200, height: 200)
                    .clipped()
                    .cornerRadius(theme.style.cardRadius)
            } else {
                // 画像がない場合はグラデーション背景を表示
                RoundedRectangle(cornerRadius: theme.style.cardRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                plan.cardColor?.opacity(0.8) ?? themeManager.currentTheme.primary.opacity(0.8),
                                plan.cardColor?.opacity(0.4) ?? themeManager.currentTheme.primary.opacity(0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 200, height: 200)
            }

            // 下部のみ暗くするスクリム（写真を活かしつつ文字の可読性を確保）
            RoundedRectangle(cornerRadius: theme.style.cardRadius)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color.black.opacity(0.15), location: 0),
                            .init(color: Color.black.opacity(0.0), location: 0.35),
                            .init(color: Color.black.opacity(0.65), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 200, height: 200)
        }
    }

    private var cardOverlay: some View {
        VStack(alignment: .leading) {
            HStack(spacing: 6) {
                menuButton
                Spacer()
                statusBadge
            }
            Spacer()
            if plan.isShared {
                HStack {
                    Spacer()
                    sharedBadge
                }
            }
        }
        .padding(12)
    }

    private var sharedBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "person.2.fill")
                .font(.caption2)
            Text("\(plan.sharedWith.count)")
                .font(.caption2)
                .fontWeight(.bold)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial, in: Capsule())
    }

    /// **contextMenu（長押し）は使わないこと。**
    /// このカードは縦横2重の ScrollView の中にあり、帯の高さがカードと
    /// ほぼ同じで上下左右に逃げ場がない。長押しで持ち上がったカードが
    /// 切り取られ、見出しやタブバーの下に潜り込んで見える。
    /// preview を渡しても直らなかったため、Menu に置き換えた
    private var menuButton: some View {
        Menu {
            Button {
                showDuplicateSheet = true
            } label: {
                Label("この計画を複製", systemImage: "doc.on.doc")
            }

            Button("削除", systemImage: "trash", role: .destructive, action: onDelete)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(BorderlessButtonStyle())
        .accessibilityLabel("旅行計画のメニュー")
        .zIndex(1)
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Spacer()

            VStack(alignment: .leading, spacing: 6) {
                Text(plan.title)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)

                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.85))
                    Text(plan.destination)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                }

                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                    Text(dateRangeString(from: plan.startDate, to: plan.endDate))
                        // 日程は等幅を持つテーマならその書体で。
                        // 持たないテーマは今までの caption のまま
                        .font(theme.style.tabularFont(size: 12, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial, in: Capsule())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dateRangeString(from start: Date, to end: Date) -> String {
        let formatter = DateFormatter.japanese
        formatter.dateFormat = "M/d"
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
}
