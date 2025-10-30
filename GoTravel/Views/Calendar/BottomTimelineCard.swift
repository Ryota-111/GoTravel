import SwiftUI

struct BottomTimelineCard: View {
    let selectedDate: Date
    let timelineItems: [CalendarTimelineItem]
    @Binding var isExpanded: Bool

    @Environment(\.colorScheme) var colorScheme
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 0) {
                    // Grip bar
                    gripBar
                        .padding(.top, 12)
                        .padding(.bottom, 8)

                    // Header
                    headerSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)

                    if timelineItems.isEmpty {
                        emptyStateView
                            .frame(height: minHeight(for: geometry) - 80)
                    } else {
                        timelineScrollView
                    }
                }
                .frame(height: currentHeight(for: geometry))
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.ultraThinMaterial)
                        .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: -5)
                )
                .offset(y: max(0, dragOffset))
            }
            .gesture(dragGesture)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isExpanded)
            .animation(.spring(response: 0.3, dampingFraction: 0.9), value: dragOffset)
        }
    }

    private func minHeight(for geometry: GeometryProxy) -> CGFloat {
        geometry.size.height * 0.35
    }

    private func maxHeight(for geometry: GeometryProxy) -> CGFloat {
        geometry.size.height * 0.88
    }

    private func currentHeight(for geometry: GeometryProxy) -> CGFloat {
        isExpanded ? maxHeight(for: geometry) : minHeight(for: geometry)
    }

    // MARK: - Grip Bar
    private var gripBar: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.secondary.opacity(0.3))
            .frame(width: 40, height: 5)
    }

    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(formattedDate)
                    .font(.headline.bold())
                    .foregroundColor(.primary)

                Text("\(timelineItems.count)件の予定")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                Image(systemName: isExpanded ? "chevron.down.circle.fill" : "chevron.up.circle.fill")
                    .font(.title3)
                    .foregroundColor(.orange)
            }
        }
    }

    // MARK: - Timeline Scroll View
    private var timelineScrollView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(timelineItems.enumerated()), id: \.element.id) { index, item in
                    TimelineItemCard(item: item, isLast: index == timelineItems.count - 1)
                        .padding(.bottom, index == timelineItems.count - 1 ? 0 : 24)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 40))
                .foregroundColor(.orange.opacity(0.4))

            Text("予定がありません")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Drag Gesture
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let translation = value.translation.height
                // 下方向のドラッグのみ許可（正の値）
                if translation > 0 {
                    dragOffset = translation * 0.5
                } else {
                    // 上方向のドラッグは抵抗を加える
                    dragOffset = translation * 0.2
                }
            }
            .onEnded { value in
                let translation = value.translation.height
                let velocity = value.predictedEndTranslation.height

                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    // 上方向のスワイプ（展開）
                    if translation < -80 || velocity < -200 {
                        if !isExpanded {
                            isExpanded = true
                        }
                    }
                    // 下方向のスワイプ（縮小）
                    else if translation > 80 || velocity > 200 {
                        if isExpanded {
                            isExpanded = false
                        }
                    }
                    // 元に戻す
                    dragOffset = 0
                }
            }
    }

    // MARK: - Date Formatter
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日(E)"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: selectedDate)
    }
}

// MARK: - Timeline Item Card
struct TimelineItemCard: View {
    let item: CalendarTimelineItem
    let isLast: Bool
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Timeline indicator (vertical line with icon)
            VStack(spacing: 0) {
                // Icon circle
                ZStack {
                    Circle()
                        .fill(itemColor)
                        .frame(width: 50, height: 50)
                        .shadow(color: itemColor.opacity(0.3), radius: 4, x: 0, y: 2)

                    Image(systemName: iconName)
                        .font(.title3)
                        .foregroundColor(.white)
                }

                // Connecting line
                if !isLast {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    itemColor.opacity(0.5),
                                    Color.gray.opacity(0.2)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 2)
                        .padding(.vertical, 4)
                }
            }

            // Card content
            VStack(alignment: .leading, spacing: 12) {
                // Time badge
                Text(formatTime(item.time))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(itemColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(itemColor.opacity(0.15))
                    )

                // Title
                Text(item.title)
                    .font(.headline.bold())
                    .foregroundColor(.primary)
                    .lineLimit(2)

                // Subtitle
                if let subtitle = item.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        colorScheme == .dark ?
                        Color(.secondarySystemBackground) :
                        Color.white.opacity(0.9)
                    )
                    .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                itemColor.opacity(0.2),
                                Color.clear
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
    }

    private var itemColor: Color {
        switch item.type {
        case .dailyPlan: return .orange
        case .outingPlan: return .blue
        case .travel: return .green
        }
    }

    private var iconName: String {
        switch item.type {
        case .dailyPlan: return "house.fill"
        case .outingPlan: return "figure.walk"
        case .travel: return "airplane"
        }
    }

    private func formatTime(_ time: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: time)
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.2)
            .ignoresSafeArea()

        VStack {
            Spacer()

            BottomTimelineCard(
                selectedDate: Date(),
                timelineItems: [],
                isExpanded: .constant(false)
            )
        }
        .ignoresSafeArea(edges: .bottom)
    }
}
