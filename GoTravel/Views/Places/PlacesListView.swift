import SwiftUI
import MapKit

struct PlacesListView: View {

    // MARK: - Properties
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var vm = PlacesViewModel()
    @ObservedObject var themeManager = ThemeManager.shared
    @ObservedObject var categoryManager = PlaceCategoryManager.shared
    @State private var selectedCategoryId: String = Self.allCategoryId
    /// 県で絞り込む（nil ならすべて。3.1、ご要望から）。一覧と地図の両方に効く
    @State private var selectedArea: PlaceArea?
    @ObservedObject private var regionResolver = TripRegionResolver.shared

    static let allCategoryId = "all"
    @State private var hasLoadedData = false
    @State private var showManageCategories = false
    @State private var showMap = false
    @State private var selectedPlace: VisitedPlace?
    /// 地図に初めから出ている施設（羽田空港など）を押したもの
    @State private var featureSelection: MapFeature?
    @State private var selectedFeatureItem: MKMapItem?
    @State private var mapPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 36.2048, longitude: 138.2529),
        span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
    ))
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) var scenePhase

    /// 地図の長押しで場所を追加する導線。マップ画面と同じ処理を使う
    @StateObject private var placePicker = MapPlacePicker()

    // MARK: - Computed Properties
    private var filteredPlaces: [VisitedPlace] {
        var places = vm.places
        if selectedCategoryId != Self.allCategoryId {
            places = places.filter { $0.categoryId == selectedCategoryId }
        }
        if let selectedArea {
            _ = regionResolver.version
            places = places.filter { PlaceArea.of($0, region: regionResolver.region) == selectedArea }
        }
        return places
    }

    /// 場所のある県と数（絞り込みのメニューに出す）
    private var areaCounts: [(area: PlaceArea, count: Int)] {
        _ = regionResolver.version
        return PlaceArea.counts(of: vm.places, region: regionResolver.region)
    }

    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: colorScheme == .dark ? [themeManager.currentTheme.gradientDark, themeManager.currentTheme.dark] : [themeManager.currentTheme.gradientLight, themeManager.currentTheme.light]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    /// カード全体の基調となるテーマ色（予定計画カードと揃える）
    private var mainColor: Color {
        themeManager.currentTheme.xprimary
    }

    private var textColor: Color {
        colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1
    }
    
    private var xDLtextColor: Color {
        colorScheme == .dark ? themeManager.currentTheme.dark : themeManager.currentTheme.light
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? themeManager.currentTheme.accent2.opacity(0.7) : themeManager.currentTheme.accent1.opacity(0.6)
    }

    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient
                VStack(spacing: 0) {
                    planEventsTitleSection
                    // 地図でもカテゴリーと県で絞り込めるように、切り替えの上に置く
                    eventTypeSelectionSection
                    if showMap {
                        mapView
                    } else {
                        contentView
                    }
                }
            }
            // 地図の情報パネルと重なるときだけ引っ込める
            .overlay(alignment: .bottomTrailing) {
                if !(showMap && selectedPlace != nil) {
                    addPlaceFloatingButton
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        // sheetはNavigationView外に置いてview再構築による不安定化を防ぐ
        .sheet(isPresented: $showManageCategories) {
            ManageCategoriesView()
        }
        .sheet(isPresented: $placePicker.isPresentingSheet, onDismiss: { placePicker.clearPin() }) {
            if let coordinate = placePicker.coordinate {
                SavePlaceView(vm: {
                    let saveVM = SavePlaceViewModel(coord: coordinate, placesVM: vm)
                    saveVM.title = placePicker.title
                    return saveVM
                }())
                .environmentObject(authVM)
            }
        }
        // 住所から県が分からない場所は、緯度・経度から調べて覚える（旅の記録と同じ仕組み）
        .task(id: vm.places.count) {
            let points = PlaceArea.needsLookup(vm.places, region: regionResolver.region)
                .map { (latitude: $0.latitude, longitude: $0.longitude) }
            await regionResolver.resolve(points)
        }
        .task {
            // 初回のみCore DataのFetchedResultsControllerをセットアップ
            if !hasLoadedData, let userId = authVM.userId {
                vm.setupFetchedResultsController(userId: userId)
                hasLoadedData = true
            }
        }
    }

    /// 追加ボタン。
    /// リストの末尾に置くと件数が増えるほど遠ざかるため、内容に左右されない右下に浮かせる
    private var addPlaceFloatingButton: some View {
        NavigationLink(destination: MapHomeView()) {
            FloatingAddButtonLabel()
        }
        .padding(.trailing, FloatingAddButtonLabel.margin)
        .padding(.bottom, FloatingAddButtonLabel.margin)
        .accessibilityLabel(Text("場所を追加"))
    }

    // MARK: - View Components
    private var contentView: some View {
        Group {
            if vm.isLoading {
                loadingView
            } else if filteredPlaces.isEmpty {
                emptyStateView
            } else {
                placesListView
            }
        }
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: themeManager.currentTheme.accent1))
                .scaleEffect(1.5)
            Text("読み込み中...")
                .font(.subheadline)
                .foregroundColor(secondaryTextColor)
                .padding(.top, 20)
            Spacer()
        }
    }

    private var emptyStateView: some View {
        VStack {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "map.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundColor(secondaryTextColor)

                Text(vm.places.isEmpty ? "まだ保存された場所はありません" : "選んだカテゴリ・県の場所はありません")
                    .font(.headline)
                    .foregroundColor(textColor)

                // 以前は「マップをタップ」と案内していたが、その操作は存在しなかった
                Text(vm.places.isEmpty ? "マップで検索するか、地図を長押しして場所を追加できます" : "別のカテゴリや県を選ぶか、場所を追加しましょう")
                    .font(.subheadline)
                    .foregroundColor(secondaryTextColor)

                NavigationLink(destination: MapHomeView()) {
                    Text("場所を追加")
                        .font(.headline)
                        .foregroundColor(xDLtextColor)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 12)
                        .background(textColor)
                        .cornerRadius(25)
                }
            }
            .padding()

            Spacer()
        }
    }

    private var placesListView: some View {
        ScrollView {
            VStack(spacing: 15) {
                ForEach(filteredPlaces) { place in
                    placeCardView(place)
                }

                NavigationLink(destination: MapHomeView()) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(textColor)
                        Text("場所を追加")
                            .font(.headline)
                            .foregroundColor(textColor)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(themeManager.currentTheme.accent2.opacity(0.2))
                    .cornerRadius(15)
                }
                .padding(.top, 10)
            }
            .padding()
            // 右下の追加ボタンに最後の項目が隠れないようにする
            .padding(.bottom, 70)
        }
    }

    /// 予定カードと同じ言語で組む。面には色を敷かず、色はサムネイルとタグへ。
    /// 全カードにテーマ色を敷いていたときは、並べると一覧が騒がしかった
    private func placeCardView(_ place: VisitedPlace) -> some View {
        let category = categoryManager.category(for: place.categoryId)
        let accent = category.color
        let surface = themeManager.currentTheme.listCardSurface(for: colorScheme)

        return NavigationLink(destination: PlaceDetailView(place: place)) {
            // 写真を主役にした行（3.1）。名前の下は、印つきの訪問日と住所の2行だけにし、
            // カテゴリは右上に小さな札で置く
            HStack(spacing: 12) {
                placeThumbnail(place, category: category, accent: accent)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top, spacing: 6) {
                        Text(place.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(textColor)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 4)
                        Text(category.name)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(accent)
                            .lineLimit(1)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(accent.opacity(colorScheme == .dark ? 0.24 : 0.14), in: Capsule())
                    }

                    // 日付の無い場所は「いつか行きたい」（3.1、ご要望から）
                    Label(formattedDate(place), systemImage: place.visitedAt == nil ? "sparkles" : "calendar")
                        .font(.system(size: 12))
                        .foregroundColor(secondaryTextColor)
                        .lineLimit(1)

                    // 同じ名前の店が複数あっても見分けられるように住所を出す
                    if let address = place.address, !address.isEmpty {
                        Label(address, systemImage: "mappin.and.ellipse")
                            .font(.system(size: 12))
                            .foregroundColor(secondaryTextColor)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                placeMenuButton(place: place)
            }
            .padding(.leading, 10)
            .padding(.vertical, 10)
            .padding(.trailing, 2)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(surface)
            )
            // ダークでは影が沈んで効かないので、細い輪郭に置き換える
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(colorScheme == .dark ? mainColor.opacity(0.10) : .clear, lineWidth: 1)
            )
            .shadow(
                color: colorScheme == .dark ? .clear : Color.black.opacity(0.05),
                radius: 10,
                x: 0,
                y: 3
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    /// 保存した写真は詳細でしか見えていなかった。一覧でも出すと、
    /// 名前を読まなくてもどの場所か分かる
    private func placeThumbnail(_ place: VisitedPlace, category: CustomPlaceCategory, accent: Color) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(accent.opacity(colorScheme == .dark ? 0.24 : 0.14))
            .frame(width: 84, height: 72)
            .overlay {
                if let fileName = place.localPhotoFileName,
                   let image = FileManager.documentsImage(named: fileName) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: category.icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(accent)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// 長押しの contextMenu だけでは削除できることに気づけない。
    /// 予定カードと同じ44ptの「⋯」に揃える
    private func placeMenuButton(place: VisitedPlace) -> some View {
        Menu {
            deleteButton(place: place)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(secondaryTextColor)
                .frame(width: 44, height: 40)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("この場所の操作")
    }

    private func deleteButton(place: VisitedPlace) -> some View {
        Button(role: .destructive) {
            deletePlace(place)
        } label: {
            Label("削除", systemImage: "trash")
        }
    }
    
    private var planEventsTitleSection: some View {
        HStack {
            Text("保存した場所")
                .font(.title.weight(.semibold))
                .foregroundColor(textColor)

            Spacer()

            // マップ/リスト切り替え
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showMap.toggle()
                    selectedPlace = nil
                }
            }) {
                Image(systemName: showMap ? "list.bullet" : "map.fill")
                    .foregroundColor(textColor)
                    .padding(8)
                    .background(textColor.opacity(0.1))
                    .clipShape(Circle())
            }
            .accessibilityLabel(showMap ? "リスト表示に切り替え" : "マップ表示に切り替え")

            // 旅行計画（しおり）には提携リンクを置かないので、ここを入口にする
            NavigationLink(destination: ExperienceSearchView()) {
                Image(systemName: "ticket.fill")
                    .foregroundColor(textColor)
                    .padding(8)
                    .background(textColor.opacity(0.1))
                    .clipShape(Circle())
            }
            .accessibilityLabel(Text("あそび・体験を探す"))

            Button(action: { showManageCategories = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "slider.horizontal.3")
                    Text("管理")
                        .font(.subheadline)
                }
                .foregroundColor(textColor)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    // MARK: - Map View
    private var mapView: some View {
        ZStack(alignment: .bottom) {
            // 長押しの変換基準を合わせるため、ignoresSafeArea は MapReader 側に付ける。
            // Map だけが安全領域を無視すると枠がずれ、押した位置と違う所にピンが立つ
            MapReader { proxy in
                placesMap
                    .longPressToDropPin(proxy: proxy, picker: placePicker)
            }
            .ignoresSafeArea(edges: .bottom)

            if let place = selectedPlace {
                placeBottomPanel(place)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if let feature = selectedFeatureItem {
                // 地図に初めから出ている施設（羽田空港など）。経路を出したり、そのまま保存したりできる
                MapFeatureInfoCard(item: feature, accent: themeManager.currentTheme.actionFill, onSave: {
                    placePicker.presentSave(name: feature.name ?? "", at: feature.placemark.coordinate)
                    clearFeatureSelection()
                }, onClose: clearFeatureSelection)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                LongPressHintLabel()
            }
        }
    }

    private func clearFeatureSelection() {
        withAnimation {
            featureSelection = nil
            selectedFeatureItem = nil
        }
    }

    private var placesMap: some View {
        Map(position: $mapPosition, selection: $featureSelection) {
            // 長押しで立てたピン
            droppedPinContent(at: placePicker.coordinate, color: themeManager.currentTheme.success)

            ForEach(filteredPlaces) { place in
                let category = categoryManager.category(for: place.categoryId)
                let accent = category.color
                let isSelected = selectedPlace?.id == place.id

                Annotation(place.title, coordinate: place.coordinate) {
                        Button(action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                selectedPlace = place
                            }
                        }) {
                            ZStack {
                                // 色はカテゴリを表す。全部が同じ赤だと、
                                // 地図の上でホテルと風景の区別がつかない
                                Circle()
                                    .fill(accent)
                                    .frame(width: 38, height: 38)
                                    // 選んだピンは色ではなく白い縁と大きさで示す
                                    .overlay(
                                        Circle()
                                            .strokeBorder(Color.white.opacity(isSelected ? 0.95 : 0), lineWidth: 2.5)
                                    )
                                    .shadow(color: accent.opacity(0.45), radius: isSelected ? 7 : 4, x: 0, y: 2)
                                    .scaleEffect(isSelected ? 1.15 : 1.0)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)

                                Image(systemName: category.icon)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(ThemePreset.readableText(on: accent))
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        // 何もない所を押したら閉じる。施設を押したことは妨げない（simultaneous にする）
        .simultaneousGesture(TapGesture().onEnded {
            withAnimation { selectedPlace = nil }
        })
        // 県やカテゴリーで絞り込んだら、残った場所が入るように寄せる
        .onChange(of: selectedArea) { _, _ in fitMapToFilteredPlaces() }
        .onChange(of: selectedCategoryId) { _, _ in fitMapToFilteredPlaces() }
        .onChange(of: featureSelection) { _, feature in
            guard let feature else {
                selectedFeatureItem = nil
                return
            }
            selectedPlace = nil
            Task {
                let item = await MapFeatureLookup.mapItem(for: feature)
                withAnimation { selectedFeatureItem = item }
            }
        }
    }

    private func fitMapToFilteredPlaces() {
        selectedPlace = nil
        guard let region = MapRegionFitting.region(fitting: filteredPlaces.map(\.coordinate), minimumSpan: 0.02) else { return }
        withAnimation(.easeInOut(duration: 0.5)) { mapPosition = .region(region) }
    }

    private func placeBottomPanel(_ place: VisitedPlace) -> some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 14)

            HStack(alignment: .top, spacing: 12) {
                // カテゴリーアイコン。ピンと同じ色にして、
                // どのピンを開いているのか下のパネルでも分かるようにする
                ZStack {
                    let accent = categoryManager.category(for: place.categoryId).color

                    Circle()
                        .fill(accent.opacity(colorScheme == .dark ? 0.24 : 0.14))
                        .frame(width: 44, height: 44)
                    Image(systemName: categoryManager.category(for: place.categoryId).icon)
                        .font(.system(size: 18))
                        .foregroundColor(accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(place.title)
                        .font(.headline)
                        .foregroundColor(textColor)
                        .lineLimit(1)
                    Text(categoryManager.category(for: place.categoryId).name)
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                    if let visitedAt = place.visitedAt {
                        Text(DateFormatter.japaneseDate.string(from: visitedAt))
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.secondaryText)
                    }
                }

                Spacer()

                Button(action: { withAnimation { selectedPlace = nil } }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(Color(.systemGray3))
                }
            }
            .padding(.horizontal, 20)

            NavigationLink(destination: PlaceDetailView(place: place)) {
                Label("詳細を見る", systemImage: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(themeManager.currentTheme.xprimary)
                    .foregroundStyle(.white)
                    .cornerRadius(14)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(colorScheme == .dark
                      ? themeManager.currentTheme.secondaryBackgroundDark
                      : Color(.systemBackground))
                .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: -4)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
    
    /// カテゴリーの絞り込み。
    ///
    /// 60×60のタイルを横に並べていたため、1画面に3つしか入らず、
    /// 4つ目からは存在に気づけなかった。44ptのチップにして件数も出す
    private var eventTypeSelectionSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                areaMenu

                categoryChip(
                    title: "すべて",
                    icon: "square.grid.2x2.fill",
                    color: themeManager.currentTheme.actionFill,
                    count: vm.places.count,
                    isSelected: selectedCategoryId == Self.allCategoryId
                ) {
                    selectedCategoryId = Self.allCategoryId
                }

                ForEach(categoryManager.categories) { category in
                    categoryChip(
                        title: category.name,
                        icon: category.icon,
                        color: category.color,
                        count: vm.places.filter { $0.categoryId == category.id }.count,
                        isSelected: selectedCategoryId == category.id
                    ) {
                        selectedCategoryId = category.id
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    /// 県の絞り込み（3.1）。場所のある県だけを北から順に出す
    private var areaMenu: some View {
        let tint = themeManager.currentTheme.actionFill
        let isOn = selectedArea != nil
        return Menu {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selectedArea = nil }
            } label: {
                if selectedArea == nil { Label("すべての県", systemImage: "checkmark") } else { Text("すべての県") }
            }
            Divider()
            ForEach(areaCounts, id: \.area) { entry in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selectedArea = entry.area }
                } label: {
                    let title = "\(entry.area.title)（\(entry.count)）"
                    if selectedArea == entry.area { Label(title, systemImage: "checkmark") } else { Text(title) }
                }
            }
            if regionResolver.remaining > 0 {
                Divider()
                Text("県を調べています（あと\(regionResolver.remaining)か所）")
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "map")
                    .font(.system(size: 12, weight: .semibold))
                Text(selectedArea?.title ?? "県")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundColor(isOn ? ThemePreset.readableText(on: tint) : textColor)
            .padding(.horizontal, 13)
            .frame(height: 44)
            .background(
                Capsule().fill(isOn
                               ? AnyShapeStyle(tint)
                               : AnyShapeStyle(colorScheme == .dark
                                               ? themeManager.currentTheme.secondaryBackgroundDark
                                               : themeManager.currentTheme.backgroundLight))
            )
            .shadow(color: colorScheme == .dark ? .clear : Color.black.opacity(isOn ? 0.12 : 0.05),
                    radius: isOn ? 8 : 4, x: 0, y: 2)
        }
        .accessibilityLabel(Text("県で絞り込む：\(selectedArea?.title ?? "すべて")"))
    }

    /// 選ぶと色で塗り、選んでいないときは色をアイコンだけに置く。
    /// 全部を色で塗ると、カテゴリーが増えるほど帯が虹色になる
    private func categoryChip(
        title: String,
        icon: String,
        color: Color,
        count: Int,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                action()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isSelected ? ThemePreset.readableText(on: color) : color)

                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isSelected ? ThemePreset.readableText(on: color) : textColor)
                    .lineLimit(1)

                Text("\(count)")
                    .font(.system(size: 11, weight: .bold))
                    .monospacedDigit()
                    .foregroundColor(isSelected
                                     ? ThemePreset.readableText(on: color).opacity(0.85)
                                     : themeManager.currentTheme.secondaryText)
            }
            .padding(.horizontal, 13)
            .frame(height: 44)
            .background(
                Capsule()
                    .fill(isSelected
                          ? AnyShapeStyle(color)
                          : AnyShapeStyle(colorScheme == .dark
                                          ? themeManager.currentTheme.secondaryBackgroundDark
                                          : themeManager.currentTheme.backgroundLight))
            )
            .shadow(
                color: colorScheme == .dark ? .clear : Color.black.opacity(isSelected ? 0.12 : 0.05),
                radius: isSelected ? 8 : 4,
                x: 0,
                y: 2
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Helper Methods
    private func formattedDate(_ place: VisitedPlace) -> String {
        guard let visitedAt = place.visitedAt else { return "いつか行きたい" }
        return DateFormatter.japaneseDate.string(from: visitedAt)
    }

    // MARK: - Actions
    private func deletePlace(_ place: VisitedPlace) {
        guard let userId = authVM.userId else { return }
        vm.delete(place, userId: userId)
    }
}


