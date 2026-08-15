import SwiftUI
import MapKit
import Combine

/// 地図の長押しで場所を追加するための状態と処理。
///
/// マップ画面と場所保存タブの地図の両方で使う。
/// 片方だけ直して挙動が食い違うのを防ぐため、1か所にまとめている。
@MainActor
final class MapPlacePicker: ObservableObject {
    /// 長押しで立てたピンの位置
    @Published var coordinate: CLLocationCoordinate2D?
    /// 保存画面に渡す名前の初期値。住所から引く
    @Published var title = ""
    @Published var isPresentingSheet = false

    /// 1回の長押しでピンを立て直さないための目印。
    /// 押している間ドラッグの更新が何度も届くため
    private var hasDroppedInThisPress = false

    /// 長押しが成立した時点で呼ぶ。指を離す前にピンが立つ
    func dropPinIfNeeded(at point: CGPoint, proxy: MapProxy) {
        guard !hasDroppedInThisPress else { return }
        hasDroppedInThisPress = true

        guard let coordinate = proxy.convert(point, from: .local) else { return }
        dropPin(at: coordinate)
    }

    /// 指を離したときに呼ぶ。
    /// 指を動かさずドラッグの更新が届かなかった場合の保険
    func finishPress(at point: CGPoint?, proxy: MapProxy) {
        defer { hasDroppedInThisPress = false }

        guard !hasDroppedInThisPress, let point else { return }
        guard let coordinate = proxy.convert(point, from: .local) else { return }
        dropPin(at: coordinate)
    }

    func clearPin() {
        coordinate = nil
    }

    private func dropPin(at coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
        title = ""

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        // 住所が分かれば名前の初期値にする。分からなくても保存はできる
        Task {
            let placemark = try? await CLGeocoder().reverseGeocodeLocation(
                CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            ).first

            let name = placemark?.name
                ?? [placemark?.locality, placemark?.thoroughfare].compactMap { $0 }.joined()

            self.title = name ?? ""
            self.isPresentingSheet = true
        }
    }
}

// MARK: - 地図に載せる部品

extension View {
    /// 地図の長押しでピンを立てる。
    ///
    /// **必ず Map の直下（safeAreaInset より前）に付け、座標空間は .local を使うこと。**
    /// - safeAreaInset の後に付けると、上に重ねたバーの高さぶん下にずれる
    /// - .named(...) を使うと基準が食い違い、さらにずれる
    func longPressToDropPin(proxy: MapProxy, picker: MapPlacePicker) -> some View {
        simultaneousGesture(
            LongPressGesture(minimumDuration: 0.45)
                .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
                .onChanged { value in
                    guard case .second(true, let drag?) = value else { return }
                    picker.dropPinIfNeeded(at: drag.location, proxy: proxy)
                }
                .onEnded { value in
                    guard case .second(true, let drag?) = value else {
                        picker.finishPress(at: nil, proxy: proxy)
                        return
                    }
                    picker.finishPress(at: drag.location, proxy: proxy)
                }
        )
    }
}

/// 長押しで立てたピン。Map の中身として置く
@MapContentBuilder
func droppedPinContent(at coordinate: CLLocationCoordinate2D?, color: Color) -> some MapContent {
    if let coordinate {
        Annotation("追加する場所", coordinate: coordinate) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 34))
                .foregroundStyle(color)
                .shadow(radius: 3)
                // 絵の中心が座標に来ると指に隠れるので、少し上に出す
                .offset(y: -8)
        }
    }
}

/// 長押しは見えない操作なので、地図の上に案内を出す
struct LongPressHintLabel: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "hand.tap.fill")
                .font(.caption)
            // 右下の追加ボタンと重ならないよう短くしている
            Text("地図を長押しして場所を登録")
                .font(.caption)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.black.opacity(0.55)))
        .padding(.bottom, 10)
    }
}
