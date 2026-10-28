import SwiftUI
import MapKit

// MARK: - 予定の地図（3.2）
//
// 詳細画面の小さな地図と、押すと開く全画面の地図。
// どちらも行程の順に ①② を付け、全画面では順番どおりに点線でつなぐ（ご要望から）

/// 地図のピン。行程に出てくる場所は番号、出てこない場所は小さな点
struct PlanPlacePin: View {
    let order: Int?
    let color: Color
    var isSelected = false

    var body: some View {
        Group {
            if let order {
                Text("\(order)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(color))
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 16, height: 16)
            }
        }
        .overlay(Circle().stroke(.white, lineWidth: 2.5))
        .shadow(color: color.opacity(0.45), radius: 4, x: 0, y: 2)
        .scaleEffect(isSelected ? 1.2 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

/// 全画面の地図。下の一覧を押すと、その場所へ寄せる
struct PlanFullMapView: View {
    let plan: Plan
    let color: Color

    @Environment(\.dismiss) private var dismiss

    @State private var position: MapCameraPosition = .automatic
    @State private var selectedPlaceID: String?

    private var order: [String: Int] { plan.placeOrder }

    /// 番号の付いた場所を先に、残りはそのあとに
    private var listedPlaces: [PlannedPlace] {
        plan.placesInVisitOrder + plan.places.filter { order[$0.id] == nil }
    }

    var body: some View {
        Map(position: $position) {
            let route = plan.placesInVisitOrder.map(\.coordinate)
            if route.count >= 2 {
                MapPolyline(coordinates: route)
                    .stroke(color.opacity(0.85),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [7, 7]))
            }

            ForEach(plan.places) { place in
                Annotation(place.name, coordinate: place.coordinate) {
                    PlanPlacePin(order: order[place.id], color: color,
                                 isSelected: selectedPlaceID == place.id)
                        .onTapGesture { focus(place) }
                }
            }
        }
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .ignoresSafeArea()
        .overlay(alignment: .topTrailing) {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding(16)
            .accessibilityLabel(Text("閉じる"))
        }
        .safeAreaInset(edge: .bottom) {
            placeList
        }
    }

    private var placeList: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(listedPlaces) { place in
                    Button(action: { focus(place) }) {
                        HStack(spacing: 6) {
                            PlanPlacePin(order: order[place.id], color: color)
                                .scaleEffect(0.75)
                            Text(place.name)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        }
                        .padding(.leading, 4)
                        .padding(.trailing, 12)
                        .padding(.vertical, 4)
                        .background(.regularMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private func focus(_ place: PlannedPlace) {
        selectedPlaceID = place.id
        withAnimation(.easeInOut(duration: 0.4)) {
            position = .region(MKCoordinateRegion(
                center: place.coordinate,
                latitudinalMeters: 1500,
                longitudinalMeters: 1500
            ))
        }
    }
}
