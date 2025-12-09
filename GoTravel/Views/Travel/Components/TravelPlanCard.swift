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
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(PlainButtonStyle())
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

            RoundedRectangle(cornerRadius: 25)
                .fill(Color.black.opacity(0.3))
                .frame(width: 200, height: 200)
        }
    }

    private var cardOverlay: some View {
        VStack(alignment: .leading) {
            HStack {
                deleteButton
                Spacer()
                if plan.isShared {
                    sharedBadge
                }
            }
            Spacer()
        }
        .padding()
    }

    private var sharedBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "person.2.fill")
                .font(.caption2)
            Text("\(plan.sharedWith.count)")
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(themeManager.currentTheme.success.opacity(0.8))
        .cornerRadius(12)
    }

    private var deleteButton: some View {
        Button(action: onDelete) {
            ZStack {
                Image(systemName: "trash")
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundColor(themeManager.currentTheme.error)
            }
        }
        .buttonStyle(BorderlessButtonStyle())
        .zIndex(1)
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Spacer()

            VStack(alignment: .leading, spacing: 5) {
                Text(plan.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)

                HStack(spacing: 5) {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundColor(.white)
                    Text(plan.destination)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                HStack(spacing: 5) {
                    Image(systemName: "calendar")
                        .foregroundColor(.white)
                    Text(dateRangeString(from: plan.startDate, to: plan.endDate))
                        .font(.subheadline)
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dateRangeString(from start: Date, to end: Date) -> String {
        let formatter = DateFormatter.japanese
        formatter.dateFormat = "M/d"
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
}
