import SwiftUI

/// 思い出タブの「旅の思い出をつくる」（3.8）。写真コラージュ・旅行ポスター・旅行日記の入口
struct MemoriesMakerSection: View {
    let plans: [TravelPlan]
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// しまっているか（見出しを押して切り替える。思い出タブが覚えておく）
    @Binding var isCollapsed: Bool
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var choosing: MemoryKind?

    /// 作れる旅行（もう始まった旅行。新しい順）
    private var candidates: [TravelPlan] {
        let today = Calendar.current.startOfDay(for: Date())
        return plans.filter { Calendar.current.startOfDay(for: $0.startDate) <= today }
            .sorted { $0.startDate > $1.startDate }
    }

    private var accent: Color {
        colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { isCollapsed.toggle() }
            } label: {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("旅の思い出をつくる")
                            .font(.headline)
                            .foregroundColor(accent)
                        if !isCollapsed {
                            Text("旅行中に撮った写真から、そのまま投稿できる1枚に")
                                .font(.caption)
                                .foregroundColor(themeManager.currentTheme.secondaryText)
                        }
                    }
                    Spacer()
                    CollapseChevron(isCollapsed: isCollapsed, color: themeManager.currentTheme.secondaryText)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(isCollapsed ? "押すと出します" : "押すとしまいます")
            .padding(.horizontal, 20)

            if !isCollapsed {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(MemoryKind.allCases) { kind in
                        Button { choosing = kind } label: { MemoryKindCard(kind: kind) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        // iPad など広い画面では全画面で開く（シートの小さな窓だと、作品が小さく作りにくいため。3.8）
        .sheet(item: horizontalSizeClass == .regular ? .constant(nil) : $choosing) { kind in
            MemoryTripPicker(kind: kind, plans: candidates)
        }
        .fullScreenCover(item: horizontalSizeClass == .regular ? $choosing : .constant(nil)) { kind in
            MemoryTripPicker(kind: kind, plans: candidates)
        }
    }
}

/// 種類ごとのカード。小さな見本の絵と名前
private struct MemoryKindCard: View {
    let kind: MemoryKind

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            illustration
                .frame(width: 150, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(kind.title).font(.subheadline.weight(.bold))
                Text(kind.subtitle).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
            }
            .frame(width: 150, alignment: .leading)
        }
    }

    @ViewBuilder
    private var illustration: some View {
        switch kind {
        case .photoDump:
            ZStack {
                MemoryColor.paper
                ForEach(0..<3, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(LinearGradient(colors: [[Color.teal, .orange, .indigo][index], [Color.blue, .pink, .purple][index]],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 58, height: 50)
                        .padding(5).padding(.bottom, 9)
                        .background(Color.white)
                        .shadow(color: .black.opacity(0.18), radius: 3, y: 2)
                        .rotationEffect(.degrees([-8.0, 6, -3][index]))
                        .offset(x: [-28.0, 26, -4][index], y: [-24.0, -14, 30][index])
                }
                Text("Trip").font(.custom("GreatVibes-Regular", fixedSize: 30)).foregroundStyle(MemoryColor.ink)
                    .offset(x: 34, y: 48)
            }
        case .poster:
            ZStack {
                LinearGradient(colors: [Color(red: 0.45, green: 0.75, blue: 0.95), Color(red: 0.1, green: 0.55, blue: 0.75)],
                               startPoint: .top, endPoint: .bottom)
                VStack(spacing: 0) {
                    Text("TRIP").font(.custom("PlayfairDisplay-Regular", fixedSize: 34).weight(.bold))
                    Text("A Journey").font(.custom("GreatVibes-Regular", fixedSize: 20))
                }
                .foregroundStyle(MemoryColor.ink)
                .offset(y: -34)
                Rectangle().fill(MemoryColor.paper).frame(height: 30).frame(maxHeight: .infinity, alignment: .bottom)
            }
        case .diary:
            ZStack(alignment: .topLeading) {
                MemoryColor.paper
                Text("Day 1").font(.custom("Caveat-Regular", fixedSize: 26)).foregroundStyle(MemoryColor.ink)
                    .padding(.leading, 12).padding(.top, 6)
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(0..<3, id: \.self) { index in
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill([Color.teal, .orange, .indigo][index].opacity(0.8))
                                .frame(width: 42, height: 26)
                                .padding(3)
                                .background(Color.white)
                                .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
                            VStack(alignment: .leading, spacing: 4) {
                                Capsule().fill(MemoryColor.ink.opacity(0.5)).frame(width: 50, height: 4)
                                Capsule().fill(MemoryColor.ink.opacity(0.3)).frame(width: 36, height: 4)
                            }
                        }
                    }
                }
                .padding(.leading, 14).padding(.top, 42)
            }
        }
    }
}

/// どの旅行で作るかを選ぶ。表紙の写真を大きく敷いたカードを並べる
struct MemoryTripPicker: View {
    let kind: MemoryKind
    let plans: [TravelPlan]
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared
    /// 表紙の写真（小さく縮めたもの）
    @State private var covers: [String: UIImage] = [:]
    /// 旅行計画なしで作ったもの（3.8）
    @State private var freeMemories: [FreeMemory] = FreeMemoryStore.all()
    @State private var settingUpFree = false
    /// 「自由に作る」で決めたもの。決める画面を閉じてから作る画面へ移る
    @State private var createdFree: FreeMemory?
    @State private var openFree: FreeMemory?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    freeButton
                    if plans.isEmpty && freeMemories.isEmpty {
                        emptyState
                    }
                    ForEach(plans, id: \.id) { plan in
                        NavigationLink {
                            editor(for: plan)
                        } label: {
                            tripCard(plan)
                        }
                        .buttonStyle(.plain)
                    }
                    if !freeMemories.isEmpty {
                        Text("自由に作ったもの")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.top, plans.isEmpty ? 0 : 8)
                        ForEach(freeMemories) { memory in
                            NavigationLink {
                                editor(for: memory.plan)
                            } label: {
                                tripCard(memory.plan)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    FreeMemoryStore.delete(id: memory.id)
                                    withAnimation { freeMemories = FreeMemoryStore.all() }
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("旅行を選ぶ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() } }
            }
            .task { await loadCovers() }
            .navigationDestination(item: $openFree) { memory in
                editor(for: memory.plan)
            }
            .sheet(isPresented: $settingUpFree, onDismiss: {
                // 決める画面が閉じてから移る（閉じる途中に移ると、移らないことがあるため）
                if let createdFree { openFree = createdFree }
                createdFree = nil
            }) {
                NavigationStack {
                    FreeMemorySetupView(purpose: kind.title) { memory in
                        freeMemories = FreeMemoryStore.all()
                        createdFree = memory
                        settingUpFree = false
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func editor(for plan: TravelPlan) -> some View {
        if kind == .diary {
            DiaryEditorView(plan: plan)
        } else {
            MemoryEditorView(plan: plan, kind: kind)
        }
    }

    /// 旅行計画なしで作る入口（3.8）。作るものと同じ紙と墨の見た目にして、旅行の写真のカードと並べても負けないように
    private var freeButton: some View {
        Button { settingUpFree = true } label: {
            HStack(spacing: 16) {
                // 白いふちの写真が2枚重なった絵
                ZStack {
                    freeStackCard(angle: -10, x: -8, icon: "photo")
                    freeStackCard(angle: 8, x: 8, icon: "sparkles")
                }
                .frame(width: 78, height: 78)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Make your own")
                        .font(MemoryFont.script(28))
                    Text("旅行を選ばずに自由に作る")
                        .font(.system(size: 14, weight: .bold))
                    Text("期間か写真を選ぶだけ。旅行計画がなくても大丈夫")
                        .font(MemoryFont.sans(10.5))
                        .foregroundStyle(MemoryColor.softInk)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 3)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(MemoryColor.paper)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(MemoryColor.ink))
            }
            .foregroundStyle(MemoryColor.ink)
            .padding(.vertical, 18)
            .padding(.horizontal, 16)
            .background(PaperBackground())
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(alignment: .top) {
                // マスキングテープ
                Rectangle()
                    .fill(Color(red: 0.86, green: 0.78, blue: 0.62).opacity(0.8))
                    .frame(width: 70, height: 16)
                    .rotationEffect(.degrees(-3))
                    .offset(y: -7)
            }
            .shadow(color: .black.opacity(0.12), radius: 10, y: 5)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
    }

    private func freeStackCard(angle: Double, x: CGFloat, icon: String) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(MemoryColor.paperShadow.opacity(0.6))
                .frame(width: 46, height: 46)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .light))
                        .foregroundStyle(MemoryColor.softInk)
                }
            Color.clear.frame(width: 46, height: 10)
        }
        .padding(4)
        .background(Color.white)
        .shadow(color: .black.opacity(0.18), radius: 3, y: 1.5)
        .rotationEffect(.degrees(angle))
        .offset(x: x)
    }

    /// 何を作るか
    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: kind.icon)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(themeManager.currentTheme.xprimary))
            VStack(alignment: .leading, spacing: 3) {
                Text(kind.title)
                    .font(.title3.weight(.bold))
                Text("どの旅行の写真で作りますか？")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "airplane.departure")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("旅行が始まると、旅行中に撮った写真から作れます。\n旅行計画がなくても、上の「自由に作る」から作れます。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    /// 旅行1つ。表紙の写真か旅行の色を敷き、下に名前・目的地・期間・日数
    private func tripCard(_ plan: TravelPlan) -> some View {
        let color = Album.resolvedPlanColor(for: plan)
        return ZStack(alignment: .bottomLeading) {
            Group {
                if let id = plan.id, let cover = covers[id] {
                    Image(uiImage: cover).resizable().scaledToFill()
                } else {
                    LinearGradient(colors: [color, color.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        .overlay(alignment: .topTrailing) {
                            Image(systemName: "airplane")
                                .font(.system(size: 64, weight: .light))
                                .rotationEffect(.degrees(-20))
                                .foregroundStyle(.white.opacity(0.35))
                                .padding(20)
                        }
                }
            }
            .frame(height: 168)
            .frame(maxWidth: .infinity)
            .clipped()

            LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .center, endPoint: .bottom)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.title)
                        .font(.title3.weight(.bold))
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        if !plan.destination.isEmpty {
                            Label(plan.destination, systemImage: "mappin.and.ellipse")
                                .lineLimit(1)
                        }
                        Text(MemoryBuilder.dateRangeText(start: plan.startDate, end: plan.endDate))
                        Text("・\(plan.dayCount)日間")
                    }
                    .font(.caption.weight(.semibold))
                    .opacity(0.92)
                }
                Spacer(minLength: 8)
                HStack(spacing: 4) {
                    Text("作る")
                    Image(systemName: "arrow.right")
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(MemoryColor.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(.white))
            }
            .foregroundStyle(.white)
            .padding(16)
        }
        .frame(height: 168)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 5)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityHint("この旅行で\(kind.title)を作ります")
    }

    private func loadCovers() async {
        for plan in plans {
            guard let id = plan.id, covers[id] == nil,
                  let image = TravelBookletRenderer.coverImage(for: plan) else { continue }
            covers[id] = image.downscaled(maxPixel: 900)
        }
        // 自由に作ったものは、使う写真の最初の1枚を表紙にする
        for memory in freeMemories where covers[memory.id] == nil {
            guard let first = FreeMemoryStore.coverAssetId(for: memory),
                  let image = await TripPhotoLibrary.image(assetId: first, maxPixel: 900) else { continue }
            covers[memory.id] = image
        }
    }
}

/// しまう・出すの印（しまっているときは右向き、出しているときは下向き）
struct CollapseChevron: View {
    let isCollapsed: Bool
    let color: Color

    var body: some View {
        Image(systemName: "chevron.down")
            .font(.subheadline.weight(.semibold))
            .foregroundColor(color)
            .rotationEffect(.degrees(isCollapsed ? -90 : 0))
            .frame(width: 28, height: 28)
            .background(Circle().fill(color.opacity(0.12)))
    }
}
