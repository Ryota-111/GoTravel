import SwiftUI

// MARK: - Travel Plan Card
struct TravelPlanCard: View {
    @EnvironmentObject var viewModel: TravelPlanViewModel
    @ObservedObject var themeManager = ThemeManager.shared
    let plan: TravelPlan
    let onDelete: () -> Void

    var body: some View {
        NavigationLink(destination: TravelPlanDetailView(plan: plan).environmentObject(viewModel)) {
            ZStack {
                cardBackground
                cardOverlay
                cardContent
            }
            .frame(width: 200, height: 200)
            .overlay(
                // ガラス風のハイライト縁取り
                RoundedRectangle(cornerRadius: 25)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.45), Color.white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(PlainButtonStyle())
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
            let days = calendar.dateComponents([.day], from: today, to: start).day ?? 0
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
                    .cornerRadius(25)
            } else if let localImageFileName = plan.localImageFileName,
                      let image = FileManager.documentsImage(named: localImageFileName) {
                // フォールバック：ローカルストレージから画像を取得
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 200, height: 200)
                    .clipped()
                    .cornerRadius(25)
            } else {
                // 画像がない場合はグラデーション背景を表示
                RoundedRectangle(cornerRadius: 25)
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
            RoundedRectangle(cornerRadius: 25)
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
                deleteButton
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

    private var deleteButton: some View {
        Button(action: onDelete) {
            Image(systemName: "trash")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(BorderlessButtonStyle())
        .accessibilityLabel("旅行計画を削除")
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
                        .font(.caption.weight(.semibold))
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
