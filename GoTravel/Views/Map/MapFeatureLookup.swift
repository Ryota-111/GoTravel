import MapKit
import SwiftUI

/// 地図に初めから出ている施設（「羽田空港」「東京駅」などの名前とアイコン）を押したときの扱い。
///
/// 地図の見た目には出ているのに押しても何も起きず、検索し直すしかなかった（ご要望から）。
/// 押した施設を、名前と住所の付いた場所（MKMapItem）にして、選ぶ・経路・保存に使う
enum MapFeatureLookup {

    /// 押した施設の詳しい情報を引く。引けなければ、名前と位置だけの場所にする
    @MainActor
    static func mapItem(for feature: MapFeature) async -> MKMapItem {
        if let item = try? await MKMapItemRequest(feature: feature).mapItem {
            if item.name == nil { item.name = feature.title }
            return item
        }
        let item = MKMapItem(placemark: MKPlacemark(coordinate: feature.coordinate))
        item.name = feature.title
        return item
    }
}

/// 地図の施設を押したときに下に出す案内（名前・住所・経路・保存）
struct MapFeatureInfoCard: View {
    let item: MKMapItem
    let accent: Color
    /// 「場所保存」に保存する。保存できない地図では nil（ボタンを出さない）
    var onSave: (() -> Void)? = nil
    let onClose: () -> Void

    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var navigationTarget: MapDestination?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name ?? "名称なし")
                        .font(.headline)
                    if let address = item.placemark.title {
                        Text(address)
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.secondaryText)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                }
                .accessibilityLabel(Text("閉じる"))
            }

            HStack(spacing: 10) {
                Button {
                    navigationTarget = MapDestination(item)
                } label: {
                    Label("経路", systemImage: "arrow.triangle.turn.up.right.diamond")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(accent.opacity(0.12))
                        // 差し色を薄く敷いた上なので、読める濃さに寄せる（地図の上の白っぽい面）
                        .foregroundColor(ThemePreset.readableTint(
                            accent, on: ThemePreset.composite(accent, over: .white, opacity: 0.12)))
                        .cornerRadius(12)
                }
                .mapNavigation($navigationTarget)

                if let onSave {
                    Button(action: onSave) {
                        Label("保存", systemImage: "bookmark.fill")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(accent)
                            .foregroundColor(ThemePreset.readableText(on: accent))
                            .cornerRadius(12)
                    }
                }
            }
        }
        .padding(18)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: -4)
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
    }
}
