import SwiftUI

/// 思い出タブの「旅の思い出をつくる」（3.8）。写真コラージュ・旅行ポスター・旅行日記の入口
struct MemoriesMakerSection: View {
    let plans: [TravelPlan]
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
            VStack(alignment: .leading, spacing: 2) {
                Text("旅の思い出をつくる")
                    .font(.headline)
                    .foregroundColor(accent)
                Text("旅行中に撮った写真から、そのまま投稿できる1枚に")
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.secondaryText)
            }
            .padding(.horizontal, 20)

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
        }
        .sheet(item: $choosing) { kind in
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    if plans.isEmpty {
                        emptyState
                    }
                    ForEach(plans, id: \.id) { plan in
                        NavigationLink {
                            if kind == .diary {
                                DiaryEditorView(plan: plan)
                            } else {
                                MemoryEditorView(plan: plan, kind: kind)
                            }
                        } label: {
                            tripCard(plan)
                        }
                        .buttonStyle(.plain)
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
            .task { loadCovers() }
        }
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
            Text("旅行が始まると、旅行中に撮った写真から作れます。")
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

    private func loadCovers() {
        for plan in plans {
            guard let id = plan.id, covers[id] == nil,
                  let image = TravelBookletRenderer.coverImage(for: plan) else { continue }
            covers[id] = image.downscaled(maxPixel: 900)
        }
    }
}
