import SwiftUI
import Photos

/// 「思い出」タブの、旅行ごとのダイジェストのカード。
///
/// 表紙は旅行のヘッダー写真。無ければ、写真へのアクセスがもう許可されているときだけ、旅行中に撮った最初の写真
/// （タブを開いただけで許可を求めない）。作った動画があれば「作成済み」を出し、押すとすぐ見られる
struct DigestTripCard: View {
    let plan: TravelPlan
    let saved: TripDigestLibrary.Entry?
    let onOpen: () -> Void
    let onPlay: (TripDigestLibrary.Entry) -> Void

    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var cover: UIImage?

    static let size = CGSize(width: 150, height: 220)

    var body: some View {
        // カード全体を押すとダイジェストの画面、「作成済み」だけは別のボタン（ボタンを入れ子にしない）
            Color.clear
                .frame(width: Self.size.width, height: Self.size.height)
                .overlay {
                    if let cover {
                        Image(uiImage: cover).resizable().scaledToFill()
                    } else {
                        LinearGradient(colors: [themeManager.currentTheme.actionFill.opacity(0.7),
                                                themeManager.currentTheme.actionFill.opacity(0.35)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    }
                }
                .overlay {
                    LinearGradient(colors: [.black.opacity(0.35), .clear, .black.opacity(0.6)],
                                   startPoint: .top, endPoint: .bottom)
                }
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(DigestDateStyle.day(plan.startDate))
                            .font(.system(size: 40, weight: .thin).width(.condensed))
                        Text(DigestDateStyle.month(plan.startDate))
                            .font(.system(size: 12, weight: .medium).width(.expanded))
                    }
                    .foregroundColor(.white)
                    .padding(12)
                }
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(plan.title)
                            .font(.subheadline.weight(.bold))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        if let saved {
                            Button {
                                onPlay(saved)
                            } label: {
                                Label("作成済み", systemImage: "play.fill")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(.white.opacity(0.28)))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("作った動画を見る")
                        } else {
                            Text("\(plan.dayCount)日間")
                                .font(.caption)
                                .opacity(0.85)
                        }
                    }
                    .foregroundColor(.white)
                    .padding(12)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .onTapGesture(perform: onOpen)
                .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("\(plan.title)のダイジェスト")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction(named: "ダイジェストを開く", onOpen)
                .task(id: plan.id) { await loadCover() }
    }

    private func loadCover() async {
        if let image = TravelBookletRenderer.coverImage(for: plan) {
            cover = image.downscaled(maxPixel: 600)
            return
        }
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else { return }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: plan.startDate)
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: plan.endDate)) ?? plan.endDate
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate < %@ AND mediaType == %d",
                                        start as NSDate, end as NSDate, PHAssetMediaType.image.rawValue)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        options.fetchLimit = 1
        guard let asset = PHAsset.fetchAssets(with: options).firstObject else { return }
        let request = PHImageRequestOptions()
        request.deliveryMode = .opportunistic
        request.isNetworkAccessAllowed = true
        PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 450, height: 660),
                                              contentMode: .aspectFill, options: request) { image, _ in
            if let image { cover = image }
        }
    }
}
