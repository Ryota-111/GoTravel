import SwiftUI
import CoreLocation

/// 旅行の地図タブの「行きたい場所」（3.1、`WishPlace`）。
///
/// スケジュールに入れるほどではないが気になる場所を、「場所保存」から足して地図に ☆ で出す。
/// 今いる場所から近い順に並べ、押すと上の地図をその場所へ寄せる。決まったら「予定に入れる」
struct WishPlacesSection: View {
    let plan: TravelPlan
    /// 押した場所。上の地図がこれに合わせて寄る
    @Binding var focusedWishID: String?
    /// 「予定に入れる」。日程に足す画面を、この場所を入れた状態で開く
    let onAddToSchedule: (WishPlace) -> Void

    @EnvironmentObject var viewModel: TravelPlanViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var categoryManager = PlaceCategoryManager.shared
    @StateObject private var location = LocationManager()
    @Environment(\.colorScheme) private var colorScheme

    @State private var showsPicker = false
    @State private var navigationTarget: MapDestination?
    @State private var addedMessage: String?

    private var currentPlan: TravelPlan {
        viewModel.travelPlans.first(where: { $0.id == plan.id }) ?? plan
    }

    private var places: [WishPlace] {
        WishPlace.sorted(currentPlan.wishPlaces, near: location.currentLocation)
    }

    private var cardFill: Color {
        colorScheme == .dark
            ? themeManager.currentTheme.secondaryBackgroundDark
            : themeManager.currentTheme.secondaryBackgroundLight
    }

    private var textColor: Color { ThemePreset.readableText(on: cardFill) }
    private var accent: Color { themeManager.currentTheme.actionFill }

    /// 位置情報をもう許可しているか（許可していなければ、自分から求めない）
    private var canLocate: Bool {
        location.authorizationStatus == .authorizedWhenInUse || location.authorizationStatus == .authorizedAlways
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if places.isEmpty {
                Text("スケジュールに入れるほどではないけれど気になっている場所を、「場所保存」から足しておけます。地図に ☆ で出て、近くにあるものがすぐ分かります。")
                    .font(.system(size: 13))
                    .foregroundColor(textColor.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                sortNote
                VStack(spacing: 0) {
                    ForEach(places) { wish in
                        row(wish)
                        if wish.id != places.last?.id {
                            Divider().overlay(textColor.opacity(0.08))
                        }
                    }
                }
            }

            if let addedMessage {
                Text(addedMessage)
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.secondaryText)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardFill)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(textColor.opacity(0.12), lineWidth: 1))
        )
        .sheet(isPresented: $showsPicker) {
            SavedPlacePickerView(accentColor: accent, onSelect: { _ in },
                                 multiSelect: { add($0) },
                                 alreadyAdded: Set(currentPlan.wishPlaces.compactMap(\.sourcePlaceId)))
                .environmentObject(authVM)
        }
        .mapNavigation($navigationTarget)
        .task {
            if canLocate { location.requestCurrentLocation() }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "star.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(TravelPlanMapView.wishColor)
            Text("行きたい場所")
                .font(.subheadline.weight(.bold))
                .foregroundColor(textColor)
            if !places.isEmpty {
                Text("\(places.count)")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundColor(themeManager.currentTheme.secondaryText)
            }
            Spacer()
            Button {
                addedMessage = nil
                showsPicker = true
            } label: {
                Label("場所保存から追加", systemImage: "plus")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(accent)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var sortNote: some View {
        if location.currentLocation != nil {
            Label("今いる場所から近い順", systemImage: "location.fill")
                .font(.caption)
                .foregroundColor(themeManager.currentTheme.secondaryText)
        } else if !canLocate {
            Button {
                location.requestCurrentLocation()
            } label: {
                Label("今いる場所から近い順にする", systemImage: "location")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(accent)
            }
            .buttonStyle(.plain)
        }
    }

    private func row(_ wish: WishPlace) -> some View {
        let category = categoryManager.category(for: wish.categoryId ?? "other")
        let isFocused = focusedWishID == wish.id
        return HStack(spacing: 12) {
            Image(systemName: category.icon)
                .font(.system(size: 14))
                .foregroundColor(TravelPlanMapView.wishColor)
                .frame(width: 32, height: 32)
                .background(Circle().fill(TravelPlanMapView.wishColor.opacity(0.14)))

            VStack(alignment: .leading, spacing: 2) {
                Text(wish.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(textColor)
                    .lineLimit(1)
                if let subtitle = subtitle(of: wish) {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            Menu {
                Button {
                    navigationTarget = MapDestination(name: wish.name, coordinate: wish.coordinate)
                } label: {
                    Label("経路案内", systemImage: "arrow.triangle.turn.up.right.diamond")
                }
                Button {
                    onAddToSchedule(wish)
                } label: {
                    Label("予定に入れる", systemImage: "calendar.badge.plus")
                }
                if let link = wish.linkURL.flatMap(URL.init(string:)) {
                    Link(destination: link) {
                        Label("リンクを開く", systemImage: "safari")
                    }
                }
                Divider()
                Button(role: .destructive) {
                    remove(wish)
                } label: {
                    Label("行きたい場所から外す", systemImage: "minus.circle")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(themeManager.currentTheme.secondaryText)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Text("\(wish.name)の操作"))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isFocused ? TravelPlanMapView.wishColor.opacity(0.12) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            // 上の地図をこの場所へ寄せる（同じ場所をもう一度押しても寄せ直す）
            focusedWishID = nil
            DispatchQueue.main.async { focusedWishID = wish.id }
        }
    }

    /// 「1.2km・東京都渋谷区…」。今いる場所が分からなければ住所だけ
    private func subtitle(of wish: WishPlace) -> String? {
        let distance = location.currentLocation.map { WishPlace.distanceText(wish.distance(from: $0)) }
        let address = wish.address?.isEmpty == false ? wish.address : nil
        let parts = [distance, address].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: "・")
    }

    private func add(_ picked: [VisitedPlace]) {
        guard let userId = authVM.userId else { return }
        var updated = currentPlan
        let count = updated.addWishPlaces(picked, addedBy: userId)
        guard count > 0 else { return }
        viewModel.update(updated, userId: userId)
        addedMessage = "\(count)か所を足しました"
    }

    private func remove(_ wish: WishPlace) {
        guard let userId = authVM.userId else { return }
        var updated = currentPlan
        updated.wishPlaces.removeAll { $0.id == wish.id }
        if focusedWishID == wish.id { focusedWishID = nil }
        viewModel.update(updated, userId: userId)
    }
}
