import SwiftUI
import MapKit

/// 地図で選んだ場所
struct PickedPlace: Equatable {
    var name: String
    var address: String?
    var latitude: Double
    var longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// 地図で場所を探して選ぶ画面（全画面で出す）。
///
/// - キーワードで検索して、結果から選ぶ
/// - **検索で出ない場所は、地図を長押ししてピンを立てて選ぶ**（名前は住所から付け、書き換えられる）
///
/// 予約の場所選びのために切り出した。予定の場所選びも順にこれへ寄せる
struct MapPlaceSearchView: View {
    let title: String
    /// 最初に見せる範囲（旅行の目的地のあたり）
    let startRegion: MKCoordinateRegion
    let accent: Color
    let onPick: (PickedPlace) -> Void

    @ObservedObject private var themeManager = ThemeManager.shared
    @StateObject private var locationHistory = LocationHistoryManager.shared
    @StateObject private var pinPicker = MapPlacePicker()
    @Environment(\.dismiss) private var dismiss

    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var searchText = ""
    @State private var results: [MKMapItem] = []
    @State private var selectedResult: MKMapItem?
    /// 地図の上で押したもの（検索結果のピン、または地図に初めから出ている施設）
    @State private var mapSelection: MapSelection<MKMapItem>?
    @State private var isSearching = false
    @State private var searchFailed = false
    /// 長押しで立てたピンの名前（住所から付け、書き換えられる）
    @State private var pinName = ""

    var body: some View {
        ZStack(alignment: .top) {
            MapReader { proxy in
                Map(position: $mapPosition, selection: $mapSelection) {
                    ForEach(results, id: \.self) { result in
                        Marker(item: result)
                            .tint(themeManager.currentTheme.error)
                            .tag(MapSelection(result))
                    }
                    droppedPinContent(at: pinPicker.coordinate, color: accent)
                }
                // 長押しは Map の直下に付ける（safeAreaInset の後だとずれる。`longPressToDropPin` の注意）
                .longPressToDropPin(proxy: proxy, picker: pinPicker)
                .onMapCameraChange { context in visibleRegion = context.region }
            }
            .ignoresSafeArea()
            .safeAreaInset(edge: .bottom) {
                bottomPanel
            }
            .onAppear {
                mapPosition = .region(startRegion)
                visibleRegion = startRegion
            }
            // ピンを立てたら検索の選択は外す（2つを同時に選んでいる状態にしない）
            .onChange(of: pinPicker.coordinate?.latitude) { _, _ in
                if pinPicker.coordinate != nil { selectedResult = nil }
            }
            .onChange(of: pinPicker.title) { _, newTitle in
                pinName = newTitle
            }
            .onChange(of: selectedResult) { _, result in
                if result != nil { pinPicker.clearPin() }
            }
            // 地図の施設（羽田空港など）を押したら、検索結果を選んだのと同じに扱う
            .onChange(of: mapSelection) { _, selection in
                if let value = selection?.value {
                    selectedResult = value
                } else if let feature = selection?.feature {
                    Task {
                        let item = await MapFeatureLookup.mapItem(for: feature)
                        selectedResult = item
                        searchFailed = false
                    }
                } else {
                    selectedResult = nil
                }
            }

            VStack(spacing: 0) {
                header
                searchBar
                if !results.isEmpty && selectedResult == nil && pinPicker.coordinate == nil {
                    resultList
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: results.isEmpty)
    }

    // MARK: - 上

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(accent)
                    .padding(10)
                    .background(Color(.systemBackground).opacity(0.9))
                    .clipShape(Circle())
            }
            .accessibilityLabel(Text("閉じる"))
            Spacer()
            Text(title)
                .font(.headline)
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private var searchBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: isSearching ? "clock" : "magnifyingglass")
                    .foregroundColor(accent)
                TextField("場所・スポット名を入力", text: $searchText)
                    .font(.subheadline)
                    .submitLabel(.search)
                    .onSubmit { Task { await search() } }
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        results = []
                        selectedResult = nil
                        searchFailed = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(themeManager.currentTheme.secondaryText)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Color(.systemBackground))
            .cornerRadius(12)

            // 検索で出ないときの逃げ道を、その場で伝える
            Text(searchFailed
                 ? "見つかりませんでした。地図の施設を押すか、地図を長押ししてピンを立てて選べます。"
                 : "地図に出ている施設は、押すとそのまま選べます。見つからないときは長押しでピンを立てられます。")
                .font(.caption2)
                .foregroundColor(searchFailed ? themeManager.currentTheme.error : themeManager.currentTheme.secondaryText)
                .padding(.horizontal, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private var resultList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(results, id: \.self) { result in
                    Button {
                        withAnimation {
                            selectedResult = result
                            mapSelection = MapSelection(result)
                            mapPosition = .region(MKCoordinateRegion(
                                center: result.placemark.coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                            ))
                            results = [result]
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(themeManager.currentTheme.error)
                                .font(.system(size: 22))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(result.name ?? "名称なし")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.primary)
                                if let address = result.placemark.title {
                                    Text(address)
                                        .font(.caption)
                                        .foregroundColor(themeManager.currentTheme.secondaryText)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Divider().padding(.leading, 56)
                }
            }
        }
        .background(Color(.systemBackground))
        .frame(height: min(CGFloat(results.count) * 65, 300))
    }

    // MARK: - 下

    @ViewBuilder
    private var bottomPanel: some View {
        if let result = selectedResult {
            choiceCard(name: result.name ?? "名称なし", address: result.placemark.title) {
                pick(PickedPlace(name: result.name ?? "名称なし",
                                 address: result.placemark.title,
                                 latitude: result.placemark.coordinate.latitude,
                                 longitude: result.placemark.coordinate.longitude))
            }
        } else if let coordinate = pinPicker.coordinate {
            pinCard(coordinate)
        } else {
            LongPressHintLabel()
        }
    }

    private func choiceCard(name: String, address: String?, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.headline)
                if let address {
                    Text(address)
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                        .lineLimit(2)
                }
            }
            chooseButton(enabled: true, action: action)
        }
        .padding(18)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
    }

    /// 長押しで立てたピン。名前は住所から付けるが、駐車場や集合場所など自分の呼び方に変えられる
    private func pinCard(_ coordinate: CLLocationCoordinate2D) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ピンを立てた場所")
                .font(.caption.weight(.semibold))
                .foregroundColor(themeManager.currentTheme.secondaryText)
            TextField("場所の名前（例：〇〇駐車場）", text: $pinName)
                .font(.headline)
                .padding(12)
                .background(Color(.systemBackground))
                .cornerRadius(10)
            let name = pinName.trimmingCharacters(in: .whitespacesAndNewlines)
            chooseButton(enabled: !name.isEmpty) {
                pick(PickedPlace(name: name, address: nil,
                                 latitude: coordinate.latitude, longitude: coordinate.longitude))
            }
        }
        .padding(18)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
    }

    private func chooseButton(enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label("この場所を選ぶ", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(accent.opacity(enabled ? 1 : 0.4))
                .foregroundColor(ThemePreset.readableText(on: accent))
                .cornerRadius(12)
        }
        .disabled(!enabled)
    }

    // MARK: - 動き

    private func search() async {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        isSearching = true
        defer { isSearching = false }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.pointOfInterest, .address]
        request.region = visibleRegion ?? startRegion
        let items = (try? await MKLocalSearch(request: request).start())?.mapItems ?? []
        results = items
        selectedResult = nil
        searchFailed = items.isEmpty
        if let first = items.first {
            withAnimation {
                mapPosition = .region(MKCoordinateRegion(
                    center: first.placemark.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                ))
            }
        }
    }

    /// 選んだ場所は、予定の場所選びの「検索履歴」にも残す
    private func pick(_ place: PickedPlace) {
        locationHistory.add(name: place.name, address: place.address,
                            latitude: place.latitude, longitude: place.longitude)
        onPick(place)
        dismiss()
    }
}

extension TravelPlan {
    /// 日本全体
    static let japanRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 36.2048, longitude: 138.2529),
        span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
    )

    /// 場所を探し始める範囲（目的地のあたり）。目的地の座標が無ければ日本全体
    var placeSearchRegion: MKCoordinateRegion {
        guard let latitude, let longitude else { return Self.japanRegion }
        // 0.3度＝約33km。目的地の座標は「沖縄」「東京」のような広い言葉から
        // 引いた1点なので、寄りすぎると隣町が画面の外に出てしまう
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)
        )
    }
}
